# frozen_string_literal: true

module EE
  module Projects
    module CreateService
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize

      AUDIT_EVENT_TYPE = 'project_created'
      AUDIT_EVENT_MESSAGE = 'Added project'

      attr_reader :security_policy_target_project_id, :security_policy_target_namespace_id

      override :initialize
      def initialize(user, params)
        super

        @security_policy_target_project_id = @params.delete(:security_policy_target_project_id)
        @security_policy_target_namespace_id = @params.delete(:security_policy_target_namespace_id)

        @mirror = ::Gitlab::Utils.to_boolean(@params.delete(:mirror), default: false)
        @mirror_trigger_builds = ::Gitlab::Utils.to_boolean(@params.delete(:mirror_trigger_builds), default: false)
      end

      override :execute
      def execute
        remove_unallowed_params

        if create_from_template?
          return ::Projects::CreateFromTemplateService.new(current_user, params).execute
        end

        params.delete(:use_custom_template)

        ci_cd_only = ::Gitlab::Utils.to_boolean(params.delete(:ci_cd_only))
        group_with_project_templates_id = params.delete(:group_with_project_templates_id) if params[:template_name].blank? && params[:template_project_id].blank?

        project = super do |project|
          limit = params.delete(:repository_size_limit)
          # Repository size limit comes as MB from the view
          project.repository_size_limit = ::Gitlab::Utils.try_megabytes_to_bytes(limit) if limit

          validate_namespace_used_with_template(project, group_with_project_templates_id)
        end

        if project&.persisted?
          setup_ci_cd_project if ci_cd_only

          log_audit_event(project)
        end

        project
      end

      private

      def create_from_template?
        super || ::Gitlab::Utils.to_boolean(params[:use_custom_template])
      end

      attr_reader :mirror, :mirror_trigger_builds

      def remove_unallowed_params
        params.delete(:repository_size_limit) unless current_user&.can_admin_all_resources?
      end

      override :after_create_actions
      def after_create_actions
        super do
          create_security_policy_configuration_if_exists
        end

        create_predefined_push_rule if ::Feature.disabled?(:inherited_push_rule_for_project, project)
        set_default_compliance_framework
        setup_pull_mirroring

        return unless project.group

        reset_duo_features_to_inherit_from_namespace
        reset_ai_audit_events_storage_to_inherit_from_namespace
        run_compliance_standards_checks
        sync_group_scan_result_policies
        create_security_policy_project_bot
        sync_foundational_flows_from_namespace
        seed_work_item_type_visibility_defaults
      end

      def seed_work_item_type_visibility_defaults
        ::WorkItems::TypesFramework::SeedVisibilityDefaultsService.new(project.project_namespace).execute
      end

      def setup_pull_mirroring
        if mirror && can?(current_user, :admin_mirror, project)
          project.update!(
            mirror: mirror,
            mirror_trigger_builds: mirror_trigger_builds,
            mirror_user_id: current_user.id
          )
        end
      end

      override :execute_hooks
      def execute_hooks
        super
        return unless project.has_active_hooks?(:project_hooks)

        hook_data = ::Gitlab::HookData::ProjectBuilder.new(project).build(:create)
        project.execute_hooks(hook_data, :project_hooks)
      end

      def create_security_policy_configuration_if_exists
        return if security_policy_target.blank?

        ::Security::Orchestration::AssignService
            .new(container: security_policy_target, current_user: current_user, params: { policy_project_id: project.id })
            .execute
      end

      def security_policy_target
        if security_policy_target_project_id.present?
          ::Project.find_by_id(security_policy_target_project_id)
        elsif security_policy_target_namespace_id.present?
          ::Namespace.find_by_id(security_policy_target_namespace_id)
        end
      end
      strong_memoize_attr :security_policy_target

      def sync_group_scan_result_policies
        configurations = group_security_orchestration_policy_configurations

        configurations.each do |configuration|
          ::Security::SyncProjectPoliciesWorker.perform_in(1.second, project.id, configuration.id)
        end
      end

      def create_security_policy_project_bot
        return unless group_security_orchestration_policy_configurations.any?

        ::Security::OrchestrationConfigurationCreateBotWorker.perform_in(1.second, project.id, current_user.id)
      end

      def group_security_orchestration_policy_configurations
        project.group.all_security_orchestration_policy_configurations
      end
      strong_memoize_attr :group_security_orchestration_policy_configurations

      # rubocop: disable CodeReuse/ActiveRecord
      def create_predefined_push_rule
        PushRules::CreatePredefinedRuleService
          .new(container: project)
          .execute(override_push_rule: security_policy_target.present?)
      end

      def set_default_compliance_framework
        return unless project.group

        return unless project.licensed_feature_available?(:custom_compliance_frameworks)

        default_compliance_framework_id = project.root_namespace.namespace_settings.default_compliance_framework_id

        return if default_compliance_framework_id.blank?

        user_id = current_user.id

        project.run_after_commit_or_now do
          ::ComplianceManagement::UpdateDefaultFrameworkWorker.perform_async(
            user_id,
            id,
            default_compliance_framework_id
          )
        end
      end

      def run_compliance_standards_checks
        ::ComplianceManagement::Standards::Gitlab::PreventApprovalByAuthorWorker
          .perform_async({ 'project_id' => project.id, 'user_id' => current_user.id })

        ::ComplianceManagement::Standards::Gitlab::PreventApprovalByCommitterWorker
          .perform_async({ 'project_id' => project.id, 'user_id' => current_user.id })

        ::ComplianceManagement::Standards::Gitlab::AtLeastTwoApprovalsWorker
          .perform_async({ 'project_id' => project.id, 'user_id' => current_user.id })

        ::ComplianceManagement::Standards::Soc2::AtLeastOneNonAuthorApprovalWorker
          .perform_async({ 'project_id' => project.id, 'user_id' => current_user.id })
      end

      # When using a project template from a Group, the new project can only be created
      # under the template owner's group or subgroups
      def validate_namespace_used_with_template(project, group_with_project_templates_id)
        return unless project.group

        subgroup_with_templates_id = group_with_project_templates_id || params[:group_with_project_templates_id]
        return if subgroup_with_templates_id.blank?

        templates_owner = ::Group.find(subgroup_with_templates_id).parent

        unless templates_owner.self_and_descendants.exists?(id: project.namespace_id)
          project.errors.add(:namespace, _("is not a descendant of the Group owning the template"))
        end
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def setup_ci_cd_project
        return unless ::License.feature_available?(:ci_cd_projects)

        ::CiCd::SetupProject.new(project, current_user).execute
      end

      def log_audit_event(project)
        audit_context = {
          name: AUDIT_EVENT_TYPE,
          author: current_user,
          scope: project,
          target: project,
          message: AUDIT_EVENT_MESSAGE,
          target_details: project.full_path
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def reset_duo_features_to_inherit_from_namespace
        # The project_settings table has a database default of `true` for duo_features_enabled,
        # but new projects should inherit the actual value from their inheritance chain
        inherited_value = project.group.duo_features_enabled

        return if inherited_value # no need to update from default if inherited value will be `true`

        # Check if the setting is locked by an ancestor or ApplicationSetting before attempting to update
        # If locked, the cascading framework will handle inheritance automatically
        return if project.project_setting.duo_features_enabled_locked?

        project.project_setting.update!(duo_features_enabled: inherited_value)
      end

      def reset_ai_audit_events_storage_to_inherit_from_namespace
        # The project_settings table has a database default of `false` for ai_audit_events_storage_enabled,
        # but new projects should inherit the actual value from their inheritance chain
        inherited_value = project.group.ai_audit_events_storage_enabled

        return unless inherited_value # no need to update from default if inherited value will be `false`

        # Check if the setting is locked by an ancestor or ApplicationSetting before attempting to update
        # If locked, the cascading framework will handle inheritance automatically
        return if project.project_setting.ai_audit_events_storage_enabled_locked?

        project.project_setting.update!(ai_audit_events_storage_enabled: inherited_value)
      end

      def sync_foundational_flows_from_namespace
        return unless project.duo_foundational_flows_enabled

        cascaded_target_catalog_item_ids = project.enabled_flow_catalog_item_ids
        project.sync_enabled_foundational_flows!(cascaded_target_catalog_item_ids)

        ::Ai::Catalog::Flows::SyncFoundationalFlowsService.new(
          project,
          current_user: current_user
        ).execute
      end
    end
  end
end
