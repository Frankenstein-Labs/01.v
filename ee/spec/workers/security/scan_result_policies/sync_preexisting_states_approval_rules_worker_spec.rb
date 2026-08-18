# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker, feature_category: :security_policy_management do
  let_it_be(:merge_request) { create(:ee_merge_request) }

  describe '#perform' do
    subject(:run_worker) { described_class.new.perform(merge_request_id) }

    let(:merge_request_id) { merge_request.id }

    it 'calls sync services' do
      expect_next_instance_of(Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesService,
        merge_request) do |instance|
        expect(instance).to receive(:execute)
      end

      expect_next_instance_of(Security::ScanResultPolicies::UpdateLicenseApprovalsService,
        merge_request, nil, true) do |instance|
        expect(instance).to receive(:execute)
      end

      run_worker
    end

    context 'when merge_request does not exist' do
      let(:merge_request_id) { non_existing_record_id }

      it 'does not call sync services' do
        expect(Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesService).not_to receive(:new)
        expect(Security::ScanResultPolicies::UpdateLicenseApprovalsService).not_to receive(:new)

        run_worker
      end
    end
  end
end
