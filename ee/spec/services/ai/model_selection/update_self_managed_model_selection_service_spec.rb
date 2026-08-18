# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ModelSelection::UpdateSelfManagedModelSelectionService, feature_category: :"self-hosted_models" do
  let_it_be(:user) { create(:user) }
  let_it_be(:self_hosted_model) { create(:ai_self_hosted_model) }
  let_it_be(:model_definitions) do
    {
      'models' => [
        { 'name' => 'Claude Sonnet 3.5', 'identifier' => 'claude_sonnet_3_5' },
        { 'name' => 'Claude Sonnet 3.7', 'identifier' => 'claude_sonnet_3_7' },
        { 'name' => 'OpenAI Chat GPT 4o', 'identifier' => 'openai_chatgpt_4o' }
      ],
      'unit_primitives' => [
        {
          'feature_setting' => 'code_generations',
          'default_model' => 'claude_sonnet_3_5',
          'selectable_models' => %w[claude_sonnet_3_5 claude_sonnet_3_7 openai_chatgpt_4o],
          'beta_models' => []
        }
      ]
    }
  end

  let(:feature) { :code_completions }
  let(:provider) { "self_hosted" }
  let(:offered_model_ref) { nil }
  let(:params) do
    {
      feature: feature,
      provider: provider,
      offered_model_ref: nil,
      ai_self_hosted_model_id: self_hosted_model.id
    }
  end

  subject(:response) { described_class.new(user, params).execute }

  include_context 'with the model selections fetch definition service as side-effect'

  before do
    stub_request(:get, fetch_service_endpoint_url)
      .to_return(
        status: 200,
        body: model_definitions.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe '#execute' do
    context 'when provider is not vendored' do
      let(:provider) { "self_hosted" }

      it 'only calls the feature setting update service' do
        expect(Ai::ModelSelection::UpsertInstanceFeatureSettingService).not_to receive(:new)

        expect(response).to be_success
        expect(response.payload).to be_an(Ai::FeatureSetting)
        expect(response.payload.feature).to eq(feature.to_s)
        expect(response.payload.provider).to eq('self_hosted')
      end
    end

    context 'when provider is vendored' do
      let(:provider) { "vendored" }
      let(:instance_feature_setting) { create(:instance_model_selection_feature_setting, feature: feature) }

      it 'calls both instance feature setting service and feature setting update service' do
        expect(Ai::ModelSelection::UpsertInstanceFeatureSettingService).to receive(:new).with(
          user,
          feature,
          offered_model_ref
        ).and_call_original
        expect(Ai::FeatureSettings::UpdateService).to receive(:new).with(
          an_instance_of(Ai::FeatureSetting),
          user,
          {
            feature: feature,
            provider: provider,
            ai_self_hosted_model_id: nil
          }).and_call_original

        expect(response).to be_success
        expect(response.payload).to be_an(Ai::FeatureSetting)
        expect(response.payload.feature).to eq(feature.to_s)
        expect(response.payload.provider).to eq(provider.to_s)
      end

      context 'when instance feature setting service returns error' do
        let(:params) do
          {
            feature: feature,
            provider: provider,
            offered_model_ref: 'invalid',
            ai_self_hosted_model_id: nil
          }
        end

        it 'returns the error from instance service without calling feature setting service' do
          expect(Ai::FeatureSettings::UpdateService).not_to receive(:new)

          expect(response).to be_error
          expect(response.payload).to be_an(::Ai::ModelSelection::InstanceModelSelectionFeatureSetting)
          expect(response.message).to include 'Offered model ref Feature not found in model definitions'
        end
      end

      context 'when instance feature setting service succeeds but feature setting service fails' do
        let(:params) do
          {
            feature: feature,
            provider: "vendored",
            offered_model_ref: nil,
            ai_self_hosted_model_id: 'invalid_id'
          }
        end

        it 'returns the error from feature setting service' do
          allow_next_instance_of(::Ai::FeatureSettings::UpdateService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(message: "Something went wrong"))
          end

          expect(response).to be_error
          expect(response.message).to eq("Something went wrong")
        end
      end
    end
  end
end
