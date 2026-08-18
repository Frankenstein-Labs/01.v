# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SyncScanPoliciesWorker, feature_category: :security_policy_management do
  describe '#perform' do
    let_it_be(:configuration) { create(:security_orchestration_policy_configuration, configured_at: nil) }

    subject(:worker) { described_class.new }

    include_examples 'an idempotent worker' do
      let(:job_args) { [configuration.id, { 'force_resync' => false }] }
    end

    it 'has the `until_executed` deduplicate strategy' do
      expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
    end

    it 'calls SyncPoliciesService' do
      expect_next_instance_of(
        Security::SecurityOrchestrationPolicies::SyncPoliciesService,
        configuration: configuration,
        params: {}
      ) do |service|
        expect(service).to receive(:execute)
      end

      worker.perform(configuration.id)
    end

    it 'does not call SyncPoliciesService when configuration is not present' do
      expect(Security::SecurityOrchestrationPolicies::SyncPoliciesService).not_to receive(:new)

      worker.perform(non_existing_record_id)
    end

    context 'when force_resync is true' do
      it 'calls SyncPoliciesService with force_resync: true' do
        expect_next_instance_of(
          Security::SecurityOrchestrationPolicies::SyncPoliciesService,
          configuration: configuration,
          params: { force_resync: true }
        ) do |service|
          expect(service).to receive(:execute)
        end

        worker.perform(configuration.id, { 'force_resync' => true })
      end
    end
  end
end
