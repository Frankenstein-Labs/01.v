# frozen_string_literal: true

module Security
  class SyncPolicyWorker
    include Gitlab::EventStore::Subscriber

    data_consistency :sticky

    deduplicate :until_executing, including_scheduled: true
    idempotent!

    concurrency_limit -> { 300 }

    feature_category :security_policy_management

    BATCH_DELAY_INTERVAL = 1.second
    BATCH_SIZE = 100

    def handle_event(event)
      security_policy_id = event.data[:security_policy_id]
      policy = Security::Policy.find_by_id(security_policy_id) || return

      case event
      when Security::PolicyCreatedEvent
        handle_create_event(policy)
      when Security::PolicyUpdatedEvent
        handle_update_event(policy, event.data)
      when Security::PolicyDeletedEvent
        ::Security::DeleteSecurityPolicyWorker.perform_async(security_policy_id)
      when Security::PolicyResyncEvent
        handle_resync_event(policy, event)
      end
    end

    private

    def handle_create_event(policy)
      return unless policy.enabled

      sync_pipeline_execution_policy_metadata(policy)
      sync_compliance_frameworks(policy)
      sync_policy_for_projects(policy)
    end

    def handle_resync_event(policy, event)
      return unless policy.enabled

      sync_pipeline_execution_policy_metadata(policy)
      sync_compliance_frameworks(policy)
      sync_policy_for_projects(policy, {}, event)
    end

    def handle_update_event(policy, event_data)
      policy_diff = Security::SecurityOrchestrationPolicies::PolicyDiff::Diff.from_json(
        event_data[:diff], event_data[:rules_diff]
      )

      sync_pipeline_execution_policy_metadata(policy) if policy_diff.content_changed?
      sync_compliance_frameworks(policy, policy_diff) if policy_diff.scope_changed?

      return unless policy_diff.needs_refresh? || policy_diff.needs_rules_refresh?

      sync_policy_for_projects(policy, event_data)
    end

    def sync_policy_for_projects(policy, event_data = {}, event = nil)
      event_payload = event ? { event: { event_type: event.class.name, data: event.data } } : {}
      config_context = if policy.security_orchestration_policy_configuration.namespace?
                         { namespace: policy.security_orchestration_policy_configuration.namespace }
                       else
                         { project: policy.security_orchestration_policy_configuration.project }
                       end

      batch_index = 0

      policy.security_orchestration_policy_configuration.all_project_ids do |project_ids|
        project_ids.each_slice(BATCH_SIZE).with_index do |batch, slice_index|
          delay = [BATCH_DELAY_INTERVAL, (batch_index + slice_index) * BATCH_DELAY_INTERVAL].max

          ::Security::SyncProjectPolicyWorker.bulk_perform_in_with_contexts(delay, batch,
            arguments_proc: ->(project_id) do
              [project_id, policy.id, event_data, event_payload.deep_stringify_keys]
            end,
            context_proc: ->(_) { config_context }
          )
        end

        batch_index += (project_ids.size.to_f / BATCH_SIZE).ceil
      end
    end

    def sync_compliance_frameworks(policy, policy_diff = nil)
      Security::SecurityOrchestrationPolicies::ComplianceFrameworks::SyncService.new(
        security_policy: policy,
        policy_diff: policy_diff
      ).execute
    end

    def sync_pipeline_execution_policy_metadata(policy)
      return unless policy.type_pipeline_execution_policy?

      config_project_id = policy.security_pipeline_execution_policy_config_link&.project_id
      return unless config_project_id

      ::Security::SyncPipelineExecutionPolicyMetadataWorker
        .perform_async(
          config_project_id,
          policy.security_orchestration_policy_configuration.policy_last_updated_by&.id,
          policy.content['content'],
          [policy.id])
    end
  end
end
