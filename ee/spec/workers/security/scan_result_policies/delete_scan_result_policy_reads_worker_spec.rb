# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::DeleteScanResultPolicyReadsWorker, feature_category: :security_policy_management do
  describe '#perform' do
    let_it_be(:configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:read) { create(:scan_result_policy_read, security_orchestration_policy_configuration: configuration) }
    let_it_be(:policy) { create(:security_policy, security_orchestration_policy_configuration: configuration) }

    subject(:perform) { described_class.new.perform(configuration_id) }

    context 'with existing configuration' do
      let(:configuration_id) { configuration.id }

      it 'deletes scan result policy reads' do
        expect { perform }.to change { Security::ScanResultPolicyRead.exists?(read.id) }.from(true).to(false)
      end

      it 'schedules deletion of associated security policies' do
        expect(Security::DeleteSecurityPolicyWorker).to receive(:perform_async).with(policy.id)

        perform
      end
    end

    context 'with non-existing configuration' do
      let(:configuration_id) { non_existing_record_id }

      it 'does not delete scan result policy reads' do
        expect { perform }.not_to change { Security::ScanResultPolicyRead.count }
      end

      it 'does not schedule any policy deletions' do
        expect(Security::DeleteSecurityPolicyWorker).not_to receive(:perform_async)

        perform
      end
    end

    context 'with configuration having multiple policies' do
      let_it_be(:policy2) do
        create(:security_policy, security_orchestration_policy_configuration: configuration, policy_index: 2)
      end

      let(:configuration_id) { configuration.id }

      it 'schedules deletion for all associated policies' do
        expect(Security::DeleteSecurityPolicyWorker).to receive(:perform_async).with(policy.id)
        expect(Security::DeleteSecurityPolicyWorker).to receive(:perform_async).with(policy2.id)

        perform
      end
    end

    context 'with configuration having no policies' do
      let(:configuration_without_policies) { create(:security_orchestration_policy_configuration) }
      let(:configuration_id) { configuration_without_policies.id }

      before do
        create(:scan_result_policy_read, security_orchestration_policy_configuration: configuration_without_policies)
      end

      it 'only deletes scan result policy reads' do
        expect(Security::DeleteSecurityPolicyWorker).not_to receive(:perform_async)

        expect { perform }.to change { configuration_without_policies.scan_result_policy_reads.count }.from(1).to(0)
      end
    end
  end
end
