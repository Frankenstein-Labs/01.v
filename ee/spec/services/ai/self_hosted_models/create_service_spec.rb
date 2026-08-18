# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::SelfHostedModels::CreateService, feature_category: :"self-hosted_models" do
  let(:user) { create(:user) }
  let(:base_params) do
    {
      name: 'Test Model',
      model: 'codestral',
      endpoint: 'https://api.example.com',
      api_token: 'test_token',
      identifier: 'custom_openai/codestral-test-model'
    }
  end

  let(:params) { base_params }
  let(:service) { described_class.new(user, params) }

  before do
    allow(Gitlab::Audit::Auditor).to receive(:audit).and_call_original
  end

  describe '#execute', :aggregate_failures do
    subject(:result) { service.execute }

    let(:model) { result.payload }
    let(:audit_event) do
      {
        name: 'self_hosted_model_created',
        author: user,
        scope: be_an_instance_of(Gitlab::Audit::InstanceScope),
        target: model,
        message: "Self-hosted model #{params[:name]}/#{params[:model]}/#{params[:endpoint]} created"
      }
    end

    context 'when params are valid' do
      it 'creates the model' do
        expect { result }.to change { ::Ai::SelfHostedModel.count }.by(1)
        expect(result).to be_success

        expect(model.name).to eq('Test Model')
        expect(model.model).to eq('codestral')
        expect(model.endpoint).to eq('https://api.example.com')
        expect(model.api_token).to eq('test_token')

        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(audit_event)
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { 'create_ai_self_hosted_model' }
        let(:category) { described_class.name }
        let(:additional_properties) do
          {
            label: base_params[:model],
            property: base_params[:identifier]
          }
        end

        subject(:service_action) { result }
      end
    end

    context 'when model is invalid' do
      let(:params) { base_params.merge(model: 'invalid_model') }

      it 'raises error' do
        expect { result }.to raise_error(ArgumentError, /'invalid_model' is not a valid model/)

        expect(Gitlab::Audit::Auditor).not_to receive(:audit).with(hash_including(name: "self_hosted_model_created"))
      end
    end

    context 'when params are invalid' do
      let(:params) { base_params.merge(name: '', endpoint: 'not_a_url') }

      it 'returns an error response' do
        expect { result }.not_to change { ::Ai::SelfHostedModel.count }

        expect(result).to be_error
        expect(result.message).to include("Name can't be blank")
        expect(result.message).to include("Endpoint is blocked: Only allowed schemes are http, https")

        expect(Gitlab::Audit::Auditor).not_to receive(:audit).with(hash_including(name: "self_hosted_model_created"))
      end
    end
  end
end
