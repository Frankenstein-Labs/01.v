# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionPolicies::CancelPolicyPipelinesWorker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:security_policy) { create(:security_policy, :pipeline_execution_schedule_policy) }

  describe '#perform' do
    subject(:perform) { described_class.new.perform(security_policy_id, project_id) }

    let(:security_policy_id) { security_policy.id }
    let(:project_id) { project.id }

    context 'when security policy and project exist' do
      it 'calls the CancelPolicyPipelinesService' do
        expect(Security::PipelineExecutionPolicies::CancelPolicyPipelinesService)
          .to receive(:new)
          .with(security_policy: security_policy, project: project)
          .and_call_original

        perform
      end
    end

    context 'when security policy does not exist' do
      let(:security_policy_id) { non_existing_record_id }

      it 'does not call the service' do
        expect(Security::PipelineExecutionPolicies::CancelPolicyPipelinesService).not_to receive(:new)

        perform
      end
    end

    context 'when project does not exist' do
      let(:project_id) { non_existing_record_id }

      it 'does not call the service' do
        expect(Security::PipelineExecutionPolicies::CancelPolicyPipelinesService).not_to receive(:new)

        perform
      end
    end
  end

  describe 'worker configuration' do
    it { expect(described_class.idempotent?).to be(true) }
    it { expect(described_class.get_feature_category).to eq(:security_policy_management) }
    it { expect(described_class.get_urgency).to eq(:low) }
  end
end
