# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::SelfHostedModels::DestroyService, feature_category: :"self-hosted_models" do
  let_it_be(:user) { create(:user) }

  let(:self_hosted_model) { create(:ai_self_hosted_model) }

  let(:service) { described_class.new(self_hosted_model, user) }

  let(:audit_event) do
    model = self_hosted_model
    {
      name: 'self_hosted_model_destroyed',
      author: user,
      scope: be_an_instance_of(Gitlab::Audit::InstanceScope),
      target: model,
      message: "Self-hosted model #{model.name}/#{model.model}/#{model.endpoint} destroyed"
    }
  end

  describe '#execute', :aggregate_failures do
    subject(:result) { service.execute }

    context 'when the model is successfully destroyed' do
      it 'returns a success response' do
        expect(Gitlab::Audit::Auditor).to receive(:audit).with(audit_event)

        expect { result }.to change { ::Ai::SelfHostedModel.count }.by(-1)

        expect(result).to be_success
        expect(result.payload).to eq(self_hosted_model)
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { 'delete_ai_self_hosted_model' }
        let(:category) { described_class.name }
        let(:additional_properties) do
          {
            label: self_hosted_model.model,
            property: self_hosted_model.identifier
          }
        end

        subject(:service_action) { result }
      end
    end

    context 'when the model fails to be destroyed' do
      before do
        allow(self_hosted_model).to receive(:destroy).and_return(false)
        allow(self_hosted_model).to receive_message_chain(:errors, :full_messages).and_return(['Error message'])
      end

      it 'returns an error response' do
        expect(Gitlab::Audit::Auditor).not_to receive(:audit)
        expect { result }.not_to change { ::Ai::SelfHostedModel.count }

        expect(result).to be_error
        expect(result.message).to eq('Error message')
      end

      it 'does not track the event' do
        expect { result }.not_to trigger_internal_events('delete_ai_self_hosted_model')
      end
    end
  end
end
