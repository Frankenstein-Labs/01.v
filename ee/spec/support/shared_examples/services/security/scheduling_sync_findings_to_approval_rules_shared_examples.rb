# frozen_string_literal: true

RSpec.shared_examples 'schedules synchronization of findings to approval rules' do
  describe 'scheduling `SyncFindingsToApprovalRulesWorker`' do
    before do
      allow(Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker).to receive(:perform_async)
      stub_licensed_features(security_orchestration_policies: security_orchestration_policies_enabled)

      ingest_reports
    end

    context 'when the security_orchestration_policies is not licensed for the project' do
      let(:security_orchestration_policies_enabled) { false }

      it 'does not schedule the background job' do
        expect(Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker).not_to have_received(:perform_async)
      end
    end

    context 'when the security_orchestration_policies is licensed for the project' do
      let(:security_orchestration_policies_enabled) { true }

      it 'schedules the background job' do
        expect(Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker).to have_received(:perform_async)
          .with(latest_pipeline.id)
      end
    end
  end
end
