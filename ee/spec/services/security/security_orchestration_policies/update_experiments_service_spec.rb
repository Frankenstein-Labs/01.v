# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::UpdateExperimentsService, feature_category: :security_policy_management do
  let(:policy_configuration) { create(:security_orchestration_policy_configuration) }

  subject(:service) { described_class.new(policy_configuration: policy_configuration) }

  before do
    allow(policy_configuration).to receive(:policy_hash).and_return(policy_hash)
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    context 'when policy YAML is nil' do
      let(:policy_hash) { nil }

      it 'does not update experiments' do
        expect { execute }.not_to change { policy_configuration.experiments }
      end
    end

    context 'when policy YAML is empty' do
      let(:policy_hash) { {} }

      it 'does not update experiments' do
        expect { execute }.not_to change { policy_configuration.experiments }
      end
    end

    context 'when policy YAML has no experiments' do
      let(:policy_hash) { { scan_execution_policy: [] } }

      it 'does not update experiments' do
        expect { execute }.not_to change { policy_configuration.experiments }
      end
    end

    context 'when policy YAML has experiments' do
      let(:experiments) do
        {
          'test_feature' => {
            'enabled' => true,
            'configuration' => { 'option' => 'value' }
          }
        }
      end

      let(:policy_hash) { { experiments: experiments } }

      it 'updates experiments with the provided configuration' do
        expect { execute }.to change { policy_configuration.experiments }.to(experiments)
      end

      context 'when policy has both policy configuration and experiments' do
        let(:policy) do
          {
            name: 'Scheduled DAST 1',
            description: 'This policy runs DAST for every 20 mins',
            enabled: true,
            rules: [{ type: 'schedule', branches: %w[production], cadence: '*/20 * * * *' }],
            actions: [
              { scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile' }
            ]
          }
        end

        let(:policy_hash) { { scan_execution_policy: [policy], experiments: experiments } }

        it 'updates experiments with the provided configuration' do
          expect { execute }.to change { policy_configuration.experiments }.to(experiments)
        end
      end
    end

    context 'when update fails' do
      let(:policy_hash) { { experiments: { test_key: 'test_value' } } }

      it 'returns error response' do
        expect { execute }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
