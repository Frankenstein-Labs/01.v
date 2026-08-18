# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::AuditWarnModeGroupProtectedBranchesOverridesService, "#perform", :request_store, feature_category: :security_policy_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
  let_it_be(:policy_project) { policy_configuration.security_policy_management_project }
  let_it_be(:security_policy) do
    create(:security_policy, security_orchestration_policy_configuration: policy_configuration)
  end

  let!(:policy_bot) do
    create(:user, :security_policy_bot) { |bot| policy_configuration.security_policy_management_project.add_guest(bot) }
  end

  let(:enforced_block_modification) { false }
  let(:warn_mode_block_modification) { true }
  let(:blocking_policies) { [] }
  let(:recorded_audit_events) { [] }
  let(:service) { described_class.new(group: group) }

  subject(:execute) { service.execute }

  before do
    group_protected_branch_check_service = \
      Security::SecurityOrchestrationPolicies::GroupProtectedBranchesDeletionCheckService
    enforced_check_service = instance_double(group_protected_branch_check_service)
    warn_check_service = instance_double(group_protected_branch_check_service)

    allow(group_protected_branch_check_service).to receive(:new).with(group: group)
      .and_return(enforced_check_service)

    allow(group_protected_branch_check_service).to receive(:new)
      .with(
        group: group,
        params: { policy_enforcement_type: "warn", collect_blocking_policies: true }
      ).and_return(warn_check_service)

    allow(enforced_check_service).to receive(:execute).and_return(enforced_block_modification)
    allow(warn_check_service).to receive_messages(execute: warn_mode_block_modification,
      blocking_policies: blocking_policies)

    allow_next_instances_of(Gitlab::Audit::Auditor, 3) do |auditor|
      allow(auditor).to receive(:record) do |audit_events|
        recorded_audit_events.concat(audit_events)
      end
    end
  end

  shared_examples 'does not create audit event' do
    specify do
      execute

      expect(recorded_audit_events).to be_empty
    end
  end

  shared_examples 'creates audit event' do
    let(:message) do
      "The group #{group.full_path} is affected by the warn mode policy #{security_policy.name} " \
        "that prevents modification of the group's protected branches if the policy changes from warn mode to enforced."
    end

    specify do
      execute

      expect(recorded_audit_events).to match_array(
        [
          an_object_having_attributes(
            author_id: policy_project.security_policy_bot.id,
            author_name: policy_project.security_policy_bot.name,
            entity_id: policy_project.id,
            details: hash_including(
              target_id: security_policy.id,
              target_details: security_policy.name,
              custom_message: message
            )
          )
        ])
    end

    context 'without policy bot' do
      before do
        policy_bot.destroy!
      end

      specify do
        expect { execute }.to change { policy_project.security_policy_bot }.from(nil).to(instance_of(User))
      end
    end

    it 'loads the blocking policies only once' do
      recorder = ActiveRecord::QueryRecorder.new { execute }

      expect(recorder.log.grep(/FROM "security_policies"/).size).to eq(1)
    end
  end

  context 'when enforced policies block modification' do
    let(:enforced_block_modification) { true }

    include_examples 'does not create audit event'
  end

  context 'with blocking warn mode policies' do
    let(:warn_mode_block_modification) { true }

    let(:blocking_policies) do
      [blocking_policy(policy_configuration.id, security_policy.name)]
    end

    include_examples 'creates audit event'

    context 'with blocking enforced policies' do
      let(:enforced_block_modification) { true }

      include_examples 'does not create audit event'
    end
  end

  private

  def blocking_policy(...)
    Security::SecurityOrchestrationPolicies::GroupProtectedBranchesDeletionCheckService::BlockingPolicy.new(...)
  end
end
