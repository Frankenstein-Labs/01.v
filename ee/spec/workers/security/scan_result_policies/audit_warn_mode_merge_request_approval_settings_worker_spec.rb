# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::AuditWarnModeMergeRequestApprovalSettingsWorker, feature_category: :security_policy_management do
  let_it_be_with_reload(:merge_request) { create(:merge_request) }
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
  let_it_be(:security_policy) do
    create(:security_policy, :approval_policy, security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be(:approval_rule) { create(:approval_policy_rule, security_policy: security_policy) }
  let_it_be(:policy_read) do
    create(:scan_result_policy_read, security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be_with_reload(:violation) do
    create(:scan_result_policy_violation,
      merge_request: merge_request,
      scan_result_policy_read: policy_read,
      approval_policy_rule: security_policy.approval_policy_rules.first!)
  end

  subject(:perform) { described_class.new.perform(merge_request_id) }

  before do
    stub_licensed_features(security_orchestration_policies: true)
  end

  shared_examples 'calls service' do
    specify do
      expect_next_instance_of(Security::ScanResultPolicies::AuditWarnModeMergeRequestApprovalSettingsOverridesService,
        merge_request) do |service|
        expect(service).to receive(:execute)
      end

      perform
    end
  end

  shared_examples 'does not call service' do
    specify do
      expect(Security::ScanResultPolicies::AuditWarnModeMergeRequestApprovalSettingsOverridesService)
        .not_to receive(:execute)

      perform
    end
  end

  context 'with valid merge request ID' do
    let(:merge_request_id) { merge_request.id }

    include_examples 'calls service'

    context 'without licensed feature' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      include_examples 'does not call service'
    end

    context 'when merge request is not open' do
      before do
        merge_request.close
      end

      include_examples 'does not call service'
    end

    context 'with running violations' do
      before do
        violation.update!(status: :running)
      end

      include_examples 'does not call service'
    end
  end

  context 'with invalid merge request ID' do
    let(:merge_request_id) { non_existing_record_id }

    include_examples 'does not call service'
  end
end
