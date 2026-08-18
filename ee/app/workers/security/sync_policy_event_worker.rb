# frozen_string_literal: true

module Security
  class SyncPolicyEventWorker
    include Gitlab::EventStore::Subscriber
    include Gitlab::Utils::StrongMemoize

    data_consistency :always
    deduplicate :until_executing
    idempotent!

    feature_category :security_policy_management

    def handle_event(event)
      case event
      when ::Repositories::ProtectedBranchCreatedEvent, ::Repositories::ProtectedBranchDestroyedEvent
        sync_rules_for_protected_branch_event(event)
      when ::Repositories::DefaultBranchChangedEvent
        sync_rules_for_default_branch_changed_event(event)
      when ::Projects::ComplianceFrameworkChangedEvent
        sync_rules_for_compliance_framework_changed_event(event)
      when ::Projects::SecurityAttributeChangedEvent
        sync_rules_for_security_attribute_changed_event(event)
      else
        raise ArgumentError, "Unknown event: #{event.class}"
      end
    end

    private

    def sync_rules_for_default_branch_changed_event(event)
      return if event.data[:container_type] != 'Project'

      project = Project.find_by_id(event.data[:container_id])

      return unless project
      return unless project.licensed_feature_available?(:security_orchestration_policies)

      sync_rules_for_project(project, event)
    end

    def sync_rules_for_protected_branch_event(event)
      project_or_group = parent(event)

      return unless project_or_group
      return unless project_or_group.licensed_feature_available?(:security_orchestration_policies)

      if project_or_group.is_a?(Group)
        sync_rules_for_group(project_or_group, event)
      else
        sync_rules_for_project(project_or_group, event)
      end
    end

    def sync_rules_for_compliance_framework_changed_event(event)
      project = Project.find_by_id(event.data[:project_id])
      framework = ComplianceManagement::Framework.find_by_id(event.data[:compliance_framework_id])
      return unless project && framework

      policy_configuration_ids = project.all_security_orchestration_policy_configuration_ids
      return unless policy_configuration_ids.any?

      framework
        .security_orchestration_policy_configurations
        .with_security_policies.id_in(policy_configuration_ids)
        .find_each do |config|
          config.security_policies.undeleted.pluck_primary_key.each do |security_policy_id|
            sync_project_policy(project, security_policy_id, event)
          end
        end
    end

    def sync_rules_for_security_attribute_changed_event(event)
      project = Project.find_by_id(event.data[:project_id])
      return unless project
      return unless project.licensed_feature_available?(:security_orchestration_policies)

      policy_configuration_ids = project.all_security_orchestration_policy_configuration_ids
      return unless policy_configuration_ids.any?

      Security::Policy.for_policy_configuration_ids(policy_configuration_ids).undeleted.find_each do |policy|
        next unless policy.policy_scope.references_any_security_attribute?(event.data[:security_attribute_id])

        sync_project_policy(project, policy.id, event)
      end
    end

    def sync_rules_for_group(group, event)
      group.all_project_ids_with_csp_in_batches do |projects|
        projects.each do |project|
          sync_rules_for_project(project, event)
        end
      end
    end

    def sync_rules_for_project(project, event)
      project.approval_policies.undeleted.pluck_primary_key.each do |security_policy_id|
        sync_project_policy(project, security_policy_id, event)
      end
    end

    def parent(event)
      parent_id = event.data[:parent_id]
      if event.data[:parent_type] == 'project'
        Project.find_by_id(parent_id)
      else
        Group.find_by_id(parent_id)
      end
    end

    def sync_project_policy(project, security_policy_id, event)
      Security::SyncProjectPolicyWorker.perform_async(
        project.id, security_policy_id, {},
        { event: { event_type: event.class.name, data: event.data } }.deep_stringify_keys
      )
    end
  end
end
