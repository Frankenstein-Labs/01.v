# frozen_string_literal: true

module EE
  module Groups
    module UpdateService
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize

      EE_SETTINGS_PARAMS = [
        :prevent_forking_outside_group,
        :remove_dormant_members,
        :remove_dormant_members_period,
        :allow_enterprise_bypass_placeholder_confirmation,
        :enterprise_bypass_expires_at,
        :display_gitlab_credits_user_data,
        :policy_store_experiment_enabled,
        :dependency_firewall_enabled
      ].freeze

      override :execute
      def execute
        capture_previous_foundational_flow_refs
        strip_feature_flag_gated_foundational_flows!

        previous_agent_statuses = group.foundational_agents_statuses if params[:foundational_agents_statuses]
        agents_default_enabled = group.foundational_agents_default_enabled if params[:foundational_agents_statuses]
        new_agent_statuses = params[:foundational_agents_statuses]

        if changes_file_template_project_id?
          check_file_template_project_id_change!
          return false if group.errors.present?
        end

        check_duo_template_project_id_change!
        return false if group.errors.present?

        prepare_params!

        handle_changes

        return false if group.errors.present?

        super.tap do |success|
          if success
            log_audit_events
            audit_foundational_agent_status_changes(new_agent_statuses, previous_agent_statuses,
              agents_default_enabled)
          end
        end
      end

      private

      override :after_update
      def after_update
        super

        if group.saved_change_to_max_personal_access_token_lifetime?
          group.update_personal_access_tokens_lifetime
        end

        update_cascading_settings
        handle_pending_members
        update_amazon_q!
        update_duo_workflow!
        publish_ai_settings_changed_event
        publish_mcp_server_settings_changed_event
        schedule_remove_dormant_users
      end

      override :before_assignment_hook
      def before_assignment_hook(group, params)
        super

        # Repository size limit comes as MB from the view
        limit = params.delete(:repository_size_limit)
        group.repository_size_limit = ::Gitlab::Utils.try_megabytes_to_bytes(limit) if limit
      end

      override :remove_unallowed_params
      def remove_unallowed_params
        reject_admin_locked_duo_availability_params

        unless current_user&.admin?
          params.delete(:shared_runners_minutes_limit)
          params.delete(:extra_shared_runners_minutes_limit)
        end

        params.delete(:repository_size_limit) unless current_user&.can_admin_all_resources?

        insight_project_id = params.dig(:insight_attributes, :project_id)
        if insight_project_id
          group_projects = ::GroupProjectsFinder.new(group: group, current_user: current_user, options: { exclude_shared: true, include_subgroups: true }).execute
          params.delete(:insight_attributes) unless group_projects.exists?(insight_project_id) # rubocop:disable CodeReuse/ActiveRecord
        end

        unless ::Gitlab::Saas.feature_available?(:repositories_web_based_commit_signing)
          params.delete(:web_based_commit_signing_enabled)
        end

        unless group.auto_duo_code_review_settings_available?
          params.delete(:auto_duo_code_review_enabled)
        end

        unless group.built_in_project_templates_enabled_available?
          params.delete(:built_in_project_templates_enabled)
          params.delete(:lock_built_in_project_templates_enabled)
        end

        super
      end

      # When a group's GitLab Duo availability is admin-locked, it can only be updated by an instance admin
      # through the dedicated AdminSet/ClearDuoAvailability mutations (which bypass this service).
      # Reject any attempt to change it through the regular group settings update path here.
      #
      # Only a genuine value change is rejected: the group settings form always resubmits the current
      # duo_availability, so an unchanged value is ignored silently to avoid failing unrelated saves.
      # A real change adds the error to group.errors so the update fails and the message is surfaced to
      # the API caller (via render_validation_error!) instead of being silently dropped.
      #
      # A nil value is never treated as a change: the param is dropped regardless (so the lock can never
      # be bypassed), and comparing nil against the stored boolean would otherwise register as a change.
      def reject_admin_locked_duo_availability_params
        settings = group.namespace_settings
        return unless settings&.admin_locked_duo_features_enabled?

        {
          duo_availability: ->(value) { value.to_s == settings.duo_availability.to_s },
          duo_features_enabled: ->(value) { ::Gitlab::Utils.to_boolean(value) == settings.duo_features_enabled },
          lock_duo_features_enabled: ->(value) { ::Gitlab::Utils.to_boolean(value) == settings.lock_duo_features_enabled? }
        }.each do |param_key, unchanged|
          next unless params.key?(param_key)

          param_value = params.delete(param_key)
          next if param_value.nil? || unchanged.call(param_value)

          group.errors.add(
            param_key,
            _('is locked by an instance administrator and can only be changed by an instance administrator.')
          )
        end
      end

      def changes_file_template_project_id?
        return false unless params.key?(:file_template_project_id)

        params[:file_template_project_id] != group.checked_file_template_project_id
      end

      def check_file_template_project_id_change!
        unless can?(current_user, :admin_group, group)
          group.errors.add(:file_template_project_id, s_('GroupSettings|cannot be changed by you'))
          return
        end

        # Clearing the current value is always permitted if you can admin the group
        return unless params[:file_template_project_id].present?

        # Ensure the user can see the new project, avoiding information disclosures
        return if file_template_project_visible?

        group.errors.add(:file_template_project_id, 'is invalid')
      end

      def file_template_project_visible?
        ::ProjectsFinder.new(
          current_user: current_user,
          project_ids_relation: [params[:file_template_project_id]]
        ).execute.exists?
      end

      def check_duo_template_project_id_change!
        unless can?(current_user, :admin_group, group)
          params.delete(:duo_template_project_id)
        end

        return if params[:duo_template_project_id].blank?
        return if params[:duo_template_project_id] == group.namespace_template_setting&.duo_template_project_id

        if duo_template_project.nil?
          # Ensure the user can see the new project, avoiding any disclosures
          group.errors.add(
            :namespace_template_setting,
            s_('GroupSettings|Duo template project is invalid or not accessible')
          )
        elsif duo_template_project.root_ancestor != group
          # Ensure project belongs to this group
          group.errors.add(
            :namespace_template_setting,
            s_('GroupSettings|Duo template project does not belong to this group')
          )
        end
      end

      def duo_template_project
        return if params[:duo_template_project_id].blank?

        current_user.authorized_projects.find_by_id(params[:duo_template_project_id])
      end
      strong_memoize_attr :duo_template_project

      def prepare_params!
        destroy_association_if_project_is_empty(:insight)
        destroy_association_if_project_is_empty(:analytics_dashboards_pointer, project_key: :target_project_id)
      end

      def destroy_association_if_project_is_empty(association_name, project_key: :project_id)
        attributes_path = :"#{association_name}_attributes"
        if params.dig(attributes_path, project_key) == ''
          params[attributes_path][:_destroy] = true
          params[attributes_path].delete(project_key)
        end
      end

      override :handle_changes
      def handle_changes
        handle_code_review_flow_consent_update
        handle_allowed_email_domains_update
        handle_ip_restriction_update
        handle_ai_feature_rules
        handle_duo_template_project_update
        super
      end

      def handle_code_review_flow_consent_update
        # Make sure we delete the param regardless the feature flag being enabled just in case the frontend
        # sends it when it shouldn't (flag was just disabled and the page was already loaded before submitting the form)
        create_code_review_flow_consent = params.delete(:create_code_review_flow_consent)
        updating_foundational_flows = params.key?(:enabled_foundational_flows)
        code_review_enabled = Array(params[:enabled_foundational_flows]).include?(
          Ai::Catalog::FoundationalFlow.code_review.foundational_flow_reference
        )

        # If NOT updating foundational flows, skip entirely to avoid accidentally revoking the consent.
        return unless updating_foundational_flows

        has_duo_enterprise = group.root_ancestor.has_active_add_on_purchase?([:duo_enterprise])
        should_give_consent = has_duo_enterprise && code_review_enabled && create_code_review_flow_consent
        should_revoke_consent = !has_duo_enterprise || !code_review_enabled

        if should_give_consent
          ::Namespaces::Consent.give!(
            namespace: group.root_ancestor,
            feature_name: :code_review_flow_dap_routing,
            user: current_user
          )
        elsif should_revoke_consent
          # Revoke so re-enabling the flow later requires explicit confirmation.
          ::Namespaces::Consent.revoke!(
            namespace: group.root_ancestor,
            feature_name: :code_review_flow_dap_routing
          )
        end
      end

      def handle_duo_template_project_update
        return unless params.key?(:duo_template_project_id)
        return unless group.root?

        duo_template_project_id = params.delete(:duo_template_project_id)

        if group.namespace_template_setting
          group.namespace_template_setting.duo_template_project_id = duo_template_project_id
        elsif duo_template_project_id
          group.build_namespace_template_setting(duo_template_project_id: duo_template_project_id)
        end
      end

      def handle_ip_restriction_update
        comma_separated_ranges = params.delete(:ip_restriction_ranges)

        return if comma_separated_ranges.nil?

        # rubocop:disable Gitlab/ModuleWithInstanceVariables
        @ip_restriction_update_service = IpRestrictions::UpdateService.new(current_user, group, comma_separated_ranges)
        @ip_restriction_update_service.execute
        # rubocop:enable Gitlab/ModuleWithInstanceVariables
      end

      def handle_allowed_email_domains_update
        return unless params.key?(:allowed_email_domains_list)

        comma_separated_domains = params.delete(:allowed_email_domains_list)

        # rubocop:disable Gitlab/ModuleWithInstanceVariables -- Reason: We need this instance to log audit event post save
        @allowed_email_domains_update_service = AllowedEmailDomains::UpdateService.new(current_user, group, comma_separated_domains)
        @allowed_email_domains_update_service.execute
        # rubocop:enable Gitlab/ModuleWithInstanceVariables
      end

      def handle_ai_feature_rules
        return unless params.key?(:duo_namespace_access_rules)

        ai_feature_rules = params.delete(:duo_namespace_access_rules)

        namespace_ids = ai_feature_rules.filter_map { |rule| rule.dig(:through_namespace, :id) }.uniq

        unless namespace_ids.empty?
          namespaces = ::Group.by_id(namespace_ids).to_a
          # Preloading is only worthwhile for 3+ namespaces. The preloader
          # carries a fixed overhead (~11 queries) that exceeds the per-namespace
          # savings for smaller counts, where individual policy checks are cheaper.
          ::Preloaders::GroupPolicyPreloader.new(namespaces, current_user).execute if namespaces.size > 2
          raise ::Gitlab::Access::AccessDeniedError unless current_user.can_admin_all_namespaces?(namespaces)

          existing_ids = namespaces.map(&:id).to_set
          ai_feature_rules = ai_feature_rules.select do |rule|
            through_namespace_id = rule.dig(:through_namespace, :id)
            # Keep the rule if it's a default rule (through_namespace is null) or if the namespace exists
            through_namespace_id.nil? || existing_ids.include?(through_namespace_id)
          end
        end

        group.ai_feature_rules = ai_feature_rules

        audit_duo_namespace_access_rules_update(ai_feature_rules)
      rescue ArgumentError, ActiveRecord::RecordInvalid => e
        group.errors.add(:duo_namespace_access_rules, e.message)
      end

      override :allowed_settings_params
      def allowed_settings_params
        @allowed_settings_params ||= super + EE_SETTINGS_PARAMS
      end

      def log_audit_events
        @ip_restriction_update_service&.log_audit_event # rubocop:disable Gitlab/ModuleWithInstanceVariables
        @allowed_email_domains_update_service&.log_audit_event(group.allowed_email_domains.map(&:domain)) # rubocop:disable Gitlab/ModuleWithInstanceVariables

        ::Namespaces::GroupChangesAuditor.new(current_user, group).execute
      end

      def update_cascading_settings
        previous_changes = group.namespace_settings.previous_changes
        submitted_flow_refs = group.namespace_settings.enabled_foundational_flows

        return unless previous_changes.present? || submitted_flow_refs

        cascading_ai_settings = [
          :duo_features_enabled,
          :lock_duo_features_enabled,
          :duo_remote_flows_enabled,
          :auto_duo_code_review_enabled,
          :duo_foundational_flows_enabled,
          :duo_custom_agents_enabled,
          :duo_custom_flows_enabled,
          :duo_external_agents_enabled,
          :ai_audit_events_storage_enabled
        ]

        # Collect all changed AI settings and their values
        changed_ai_settings = cascading_ai_settings.filter_map do |setting|
          if previous_changes.include?(setting)
            [setting, group.namespace_settings[setting]]
          end
        end.to_h

        if submitted_flow_refs
          audit_enabled_foundational_flows_change(submitted_flow_refs)
          changed_ai_settings[:enabled_foundational_flows] = submitted_flow_refs
        end

        if changed_ai_settings.any?
          ::Namespaces::CascadeDuoSettingsWorker.perform_async(
            group.id,
            changed_ai_settings,
            current_user&.id
          )
        end

        if previous_changes.include?(:web_based_commit_signing_enabled)
          ::Namespaces::CascadeWebBasedCommitSigningEnabledWorker.perform_async(group.id)
        end

        if previous_changes.include?(:built_in_project_templates_enabled)
          ::Namespaces::CascadeBuiltInProjectTemplatesEnabledWorker.perform_async(
            group.id, group.built_in_project_templates_enabled
          )
        end
      end

      def handle_pending_members
        settings = group.namespace_settings

        case settings.previous_changes[:seat_control]
        when %w[user_cap off]
          ::Members::ActivateService.for_group(group).execute(current_user: current_user)
        when %w[user_cap block_overages]
          ::Members::DeletePendingMembersWorker.perform_async(group.id, current_user.id)
        end
      end

      def update_amazon_q!
        return unless ::Ai::AmazonQ.connected?

        # Amazon Q integration does not have an 'always_on' availability option;
        # map it to 'default_on' (both mean Duo features are enabled for the group).
        amazon_q_availability = params[:duo_availability] == 'always_on' ? 'default_on' : params[:duo_availability]
        integration_params = {
          availability: amazon_q_availability, auto_review_enabled: params[:amazon_q_auto_review_enabled]
        }.compact

        if group.amazon_q_integration.update(integration_params)
          PropagateIntegrationWorker.perform_async(group.amazon_q_integration.id)
        end

        return unless params[:duo_availability] == 'never_on'

        amazon_q_service_account_user =
          ::Ai::Setting.for_organization_read_only(group.organization).amazon_q_service_account_user
        ::Ai::ServiceAccountMemberRemoveService.new(current_user, group, amazon_q_service_account_user).execute
      end

      def update_duo_workflow!
        return unless ::Ai::DuoWorkflow.connected? && params[:duo_availability] == 'never_on'

        duo_workflow_service_account_user =
          ::Ai::Setting.for_organization_read_only(group.organization).duo_workflow_service_account_user
        ::Ai::ServiceAccountMemberRemoveService.new(current_user, group, duo_workflow_service_account_user).execute
      end

      def publish_ai_settings_changed_event
        return unless ai_settings_changed?

        ::Gitlab::EventStore.publish(
          ::NamespaceSettings::AiRelatedSettingsChangedEvent.new(data: { group_id: group.id })
        )
      end

      def publish_mcp_server_settings_changed_event
        return unless mcp_server_settings_changed?

        ::Gitlab::EventStore.publish(
          ::Mcp::ServerSettingsChangedEvent.new(data: { group_id: group.id })
        )
      end

      def schedule_remove_dormant_users
        return unless group.namespace_settings.previous_changes.include?(:remove_dormant_members)
        return unless group.namespace_settings.remove_dormant_members

        ::Namespaces::RemoveDormantMembersWorker.perform_with_capacity
      end

      def ai_settings_changed?
        return false unless group.namespace_settings

        ::NamespaceSettings::AiRelatedSettingsChangedEvent::AI_RELATED_SETTINGS.any? do |setting|
          group.namespace_settings.saved_change_to_attribute?(setting)
        end
      end

      def mcp_server_settings_changed?
        return false unless group.namespace_settings

        ::Mcp::ServerSettingsChangedEvent::NAMESPACE_SETTINGS.any? do |setting|
          group.namespace_settings.saved_change_to_attribute?(setting)
        end
      end

      def non_assignable_group_params
        super + [:amazon_q_auto_review_enabled, :duo_template_project_id]
      end

      def audit_duo_namespace_access_rules_update(rules)
        ::Ai::FeatureAccessRuleAuditor.new(
          current_user: current_user,
          rules: rules,
          scope: group
        ).execute
      end

      def capture_previous_foundational_flow_refs
        return unless params[:enabled_foundational_flows]

        @previous_foundational_flow_refs = group.selected_foundational_flow_references # rubocop:disable Gitlab/ModuleWithInstanceVariables -- Reason: We need this instance to log audit event post save
      end

      def strip_feature_flag_gated_foundational_flows!
        return unless params.key?(:enabled_foundational_flows)

        params[:enabled_foundational_flows] = Array(params[:enabled_foundational_flows]).reject do |ref|
          flow = ::Ai::Catalog::FoundationalFlow[ref]
          flow.nil? || flow.blocked_by_feature_flag?(group.root_ancestor)
        end
      end

      # Called in after_update
      def audit_enabled_foundational_flows_change(new_flow_refs)
        ::Ai::EnabledFoundationalFlowsAuditor.new(
          current_user: current_user,
          group: group,
          previous_flow_refs: @previous_foundational_flow_refs, # rubocop:disable Gitlab/ModuleWithInstanceVariables -- Reason: We need this instance to log audit event post save
          new_flow_refs: new_flow_refs
        ).execute
      end

      def audit_foundational_agent_status_changes(new_statuses, previous_statuses, default_enabled)
        return unless previous_statuses

        ::Ai::FoundationalAgentStatusAuditor.new(
          current_user: current_user,
          scope: group,
          previous_statuses: previous_statuses,
          new_statuses: new_statuses,
          default_enabled: default_enabled
        ).execute
      end
    end
  end
end
