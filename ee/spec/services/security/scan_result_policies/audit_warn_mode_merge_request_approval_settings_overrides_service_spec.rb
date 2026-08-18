# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::AuditWarnModeMergeRequestApprovalSettingsOverridesService, :request_store, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, merge_requests_author_approval: true) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }

  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }

  let!(:policy_bot) { create(:user, :security_policy_bot) { |bot| project.add_guest(bot) } }

  let(:mr_reference) { merge_request.to_reference(full: true) }

  let(:message_prevent_author) do
    "The merge request #{mr_reference} is affected by a warn mode policy " \
      "that sets more restrictive `approval_settings` when enforced: " \
      "Prevent approval by merge request creator"
  end

  let(:message_require_password) do
    "The merge request #{mr_reference} is affected by a warn mode policy " \
      "that sets more restrictive `approval_settings` when enforced: " \
      "Require user re-authentication (password or SAML) to approve"
  end

  let(:base_audit_event_attributes) do
    {
      author_id: project.security_policy_bot.id,
      author_name: project.security_policy_bot.name,
      entity_id: policy_configuration.security_policy_management_project_id
    }
  end

  let(:recorded_audit_events) { [] }

  subject(:execute) { described_class.new(merge_request).execute }

  shared_examples 'does not create audit events' do
    specify do
      expect(Gitlab::Audit::Auditor).not_to receive(:new)

      execute
    end
  end

  shared_examples 'creates missing policy bot' do
    before do
      policy_bot.destroy!
    end

    specify do
      expect { execute }.to change { project.security_policy_bot }.from(nil).to(instance_of(User))
    end
  end

  shared_context 'with audit events created' do
    before do
      allow_next_instances_of(Gitlab::Audit::Auditor, 3) do |auditor|
        allow(auditor).to receive(:record) do |audit_events|
          recorded_audit_events.concat(audit_events)
        end
      end
    end
  end

  context 'without policies' do
    include_examples 'does not create audit events'
  end

  context 'without warn mode policies' do
    let_it_be(:enforced_policy_restrictive_violated) do
      create_policy(1, { prevent_approval_by_commit_author: true }, violated: true)
    end

    let_it_be(:enforced_policy_restrictive_unviolated) do
      create_policy(2, { require_password_to_approve: true }, violated: false)
    end

    include_examples 'does not create audit events'
  end

  context 'with warn mode policies only' do
    let_it_be(:warn_mode_policy_restrictive_violated_a) do
      create_policy(1, { prevent_approval_by_author: true, require_password_to_approve: true }, :enforcement_type_warn,
        violated: true)
    end

    let_it_be(:warn_mode_policy_restrictive_violated_b) do
      create_policy(2, { prevent_approval_by_author: true }, :enforcement_type_warn, violated: true)
    end

    let_it_be(:warn_mode_policy_permissive_violated) do
      create_policy(3, {}, :enforcement_type_warn, violated: true)
    end

    include_context 'with audit events created'
    include_examples 'creates missing policy bot'

    specify do
      execute

      expect(recorded_audit_events).to match_array(
        [
          an_object_having_attributes(
            **base_audit_event_attributes,
            details: hash_including(
              target_id: warn_mode_policy_restrictive_violated_a.id,
              target_details: warn_mode_policy_restrictive_violated_a.name,
              custom_message: message_prevent_author
            )
          ),
          an_object_having_attributes(
            **base_audit_event_attributes,
            details: hash_including(
              target_id: warn_mode_policy_restrictive_violated_b.id,
              target_details: warn_mode_policy_restrictive_violated_b.name,
              custom_message: message_prevent_author
            )
          ),
          an_object_having_attributes(
            **base_audit_event_attributes,
            details: hash_including(
              target_id: warn_mode_policy_restrictive_violated_a.id,
              target_details: warn_mode_policy_restrictive_violated_a.name,
              custom_message: message_require_password
            )
          )
        ]
      )
    end
  end

  context 'with warn mode and enforced policies' do
    let_it_be(:enforced_policy_require_password) do
      create_policy(1, { require_password_to_approve: true }, violated: true)
    end

    let_it_be(:warn_mode_policy_restrictive_violated_a) do
      create_policy(2, { prevent_approval_by_author: true, require_password_to_approve: true }, :enforcement_type_warn,
        violated: true)
    end

    let_it_be(:warn_mode_policy_restrictive_violated_b) do
      create_policy(3, { prevent_approval_by_author: true }, :enforcement_type_warn, violated: true)
    end

    include_context 'with audit events created'
    include_examples 'creates missing policy bot'

    it 'with audit events created only for the non-enforced warn mode override' do
      execute

      expect(recorded_audit_events).to match_array(
        [
          an_object_having_attributes(
            **base_audit_event_attributes,
            details: hash_including(
              target_id: warn_mode_policy_restrictive_violated_a.id,
              target_details: warn_mode_policy_restrictive_violated_a.name,
              custom_message: message_prevent_author
            )
          ),
          an_object_having_attributes(
            **base_audit_event_attributes,
            details: hash_including(
              target_id: warn_mode_policy_restrictive_violated_b.id,
              target_details: warn_mode_policy_restrictive_violated_b.name,
              custom_message: message_prevent_author
            )
          )
        ]
      )
    end
  end

  private

  def create_policy(policy_index, approval_settings, *traits, violated: false)
    build(:security_policy, *traits,
      security_orchestration_policy_configuration: policy_configuration,
      policy_index: policy_index).tap do |policy|
      policy.update!(content: policy.content.merge("approval_settings" => approval_settings))

      next unless violated

      approval_rule = create(:approval_policy_rule, security_policy: policy)
      policy_read = create(:scan_result_policy_read, security_orchestration_policy_configuration: policy_configuration)

      create(:scan_result_policy_violation,
        merge_request: merge_request,
        scan_result_policy_read: policy_read,
        approval_policy_rule: approval_rule)
    end
  end
end
