# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::UpdatePipelineExecutionPolicyMetadataService, feature_category: :security_policy_management do
  let(:service) do
    described_class.new(security_policy: policy, enforced_scans: enforced_scans, prefill_variables: prefill_variables)
  end

  let_it_be(:project) { create(:project) }
  let_it_be(:configuration) { create(:security_orchestration_policy_configuration, project: project) }
  let(:policy) do
    create(:security_policy, :pipeline_execution_policy, security_orchestration_policy_configuration: configuration)
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    let(:enforced_scans) { %w[sast] }
    let(:prefill_variables) { { 'ENVIRONMENT' => { description: 'Policy environment' } } }
    let(:expected_metadata) do
      { 'enforced_scans' => enforced_scans, 'prefill_variables' => prefill_variables.deep_stringify_keys }
    end

    it 'updates the metadata' do
      expect(execute).to be_success
      expect(policy.reload.metadata).to eq(expected_metadata)
    end

    context 'when metadata contain other information' do
      let(:policy) do
        create(:security_policy, :pipeline_execution_policy, security_orchestration_policy_configuration: configuration,
          metadata: { foo: 'bar' })
      end

      it 'updates the metadata keeping the original information' do
        expect(execute).to be_success
        expect(policy.reload.metadata).to eq(expected_metadata.merge('foo' => 'bar'))
      end
    end

    context 'when policy is not a pipeline execution policy' do
      let(:policy) do
        create(:security_policy, :approval_policy, security_orchestration_policy_configuration: configuration)
      end

      it 'does not update the metadata' do
        expect(execute).to be_success
        expect(policy.reload.metadata).to eq({})
      end
    end

    context 'when error occurs' do
      before do
        allow(policy).to receive(:save!).and_raise(StandardError.new('error'))
      end

      it 'returns error' do
        expect(execute).to be_error
        expect(execute.message).to eq('error')
      end

      it 'does not update the metadata' do
        execute
        expect(policy.reload.metadata).to eq({})
      end
    end
  end
end
