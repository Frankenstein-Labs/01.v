# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SyncLicenseScanningRulesService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, :public, :repository) }

  let_it_be_with_refind(:merge_request) do
    create(:merge_request, :opened, source_project: project, source_branch: 'feature', target_branch: 'master')
  end

  let_it_be(:other_merge_request) do
    create(:merge_request, :opened, source_project: project, source_branch: 'feature', target_branch: 'merge-test')
  end

  let_it_be(:closed_merge_request) do
    create(:merge_request, :closed, source_project: project, source_branch: 'feature', target_branch: 'merged-target')
  end

  let_it_be_with_reload(:pipeline) do
    create(:ee_ci_pipeline, :success, project: project, ref: 'feature', sha: merge_request.diff_head_sha)
  end

  describe '.execute' do
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    subject(:execute) { described_class.execute(pipeline) }

    before do
      allow(described_class).to receive(:new).with(pipeline).and_return(mock_service_object)
    end

    it 'delegates the call to an instance of `Security::SyncLicenseScanningRulesService`' do
      execute

      expect(described_class).to have_received(:new).with(pipeline)
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    subject(:execute) { described_class.new(pipeline).execute }

    before do
      allow(Security::ScanResultPolicies::UpdateLicenseApprovalsService).to receive(:new)
        .and_return(instance_double(Security::ScanResultPolicies::UpdateLicenseApprovalsService, execute: true))
    end

    it 'calls update service for each merge request' do
      execute

      expect(Security::ScanResultPolicies::UpdateLicenseApprovalsService).to have_received(:new)
        .with(merge_request, pipeline)
      expect(Security::ScanResultPolicies::UpdateLicenseApprovalsService).to have_received(:new)
        .with(other_merge_request, pipeline)
      expect(Security::ScanResultPolicies::UpdateLicenseApprovalsService).not_to have_received(:new)
        .with(closed_merge_request, pipeline)
    end
  end
end
