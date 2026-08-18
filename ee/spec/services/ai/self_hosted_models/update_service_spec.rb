# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::SelfHostedModels::UpdateService, feature_category: :"self-hosted_models" do
  let_it_be(:user) { create(:user) }

  let(:self_hosted_model) { create(:ai_self_hosted_model) }

  let(:params) { {} }
  let(:service) { described_class.new(self_hosted_model, user, params) }

  let(:audit_event) do
    model = self_hosted_model
    {
      name: 'self_hosted_model_updated',
      author: user,
      scope: be_an_instance_of(Gitlab::Audit::InstanceScope),
      target: model,
      message: "Self-hosted model new model name/#{model.model}/#{model.endpoint} updated"
    }
  end

  describe '#execute', :aggregate_failures do
    subject(:result) { service.execute }

    context 'when the model is successfully updated' do
      let(:params) { { name: "new model name" } }

      it 'returns a success response' do
        expect(Gitlab::Audit::Auditor).to receive(:audit).with(audit_event).and_call_original

        result

        expect(self_hosted_model.reload.name).to eq("new model name")

        expect(result).to be_success
        expect(result.payload).to eq(self_hosted_model)
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { 'update_ai_self_hosted_model' }
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

    context 'when the model fails to be updated' do
      let(:params) { { endpoint: nil } }

      it 'returns an error response' do
        expect(Gitlab::Audit::Auditor).not_to receive(:audit)

        expect(result).to be_error
        expect(result.message).to eq("Endpoint can't be blank")
      end

      it 'does not track the event' do
        expect { result }.not_to trigger_internal_events('update_ai_self_hosted_model')
      end
    end
  end
end
