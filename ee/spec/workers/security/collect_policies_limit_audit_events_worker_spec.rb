# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::CollectPoliciesLimitAuditEventsWorker, feature_category: :security_policy_management do
  describe '#perform' do
    let_it_be(:configuration) { create(:security_orchestration_policy_configuration) }
    let(:configuration_id) { configuration.id }

    subject(:perform) { described_class.new.perform(configuration_id) }

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [configuration_id] }
    end

    it 'calls CollectPoliciesLimitAuditEventsService with the correct configuration' do
      service = instance_double(Security::SecurityOrchestrationPolicies::CollectPoliciesLimitAuditEventsService)

      expect(Security::SecurityOrchestrationPolicies::CollectPoliciesLimitAuditEventsService)
        .to receive(:new).with(configuration).and_return(service)
      expect(service).to receive(:execute)

      perform
    end

    context 'when configuration is not found' do
      let(:configuration_id) { non_existing_record_id }

      it { expect { perform }.not_to raise_error }

      it 'does not call CollectPoliciesLimitAuditEventsService' do
        expect(Security::SecurityOrchestrationPolicies::CollectPoliciesLimitAuditEventsService).not_to receive(:new)

        perform
      end
    end
  end
end
