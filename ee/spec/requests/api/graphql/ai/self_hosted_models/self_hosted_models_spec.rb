# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'List of self-hosted LLM servers.', feature_category: :"self-hosted_models" do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, :self_managed)
  end

  let! :model_params do
    [
      { name: 'ollama1-mistral', model: :mistral, provider: :api },
      { name: 'vllm-mistral', model: :mistral, api_token: "test_api_token", provider: :bedrock },
      { name: 'ollama2-codegemma', model: :codegemma, provider: :vertex_ai }
    ]
  end

  let! :self_hosted_models do
    model_params.map { |params| create(:ai_self_hosted_model, **params) }
  end

  let(:model_name_mapper) { ::Admin::Ai::SelfHostedModelsHelper::MODEL_NAME_MAPPER }

  let :expected_data do
    self_hosted_models.map do |self_hosted_model|
      {
        "id" => self_hosted_model.to_global_id.to_s,
        "name" => self_hosted_model.name,
        "model" => self_hosted_model.model,
        "modelDisplayName" => model_name_mapper[self_hosted_model.model],
        "endpoint" => self_hosted_model.endpoint,
        "hasApiToken" => self_hosted_model.api_token.present?,
        "releaseState" => self_hosted_model.release_state,
        "provider" => self_hosted_model.provider.to_s.upcase
      }
    end
  end

  let(:ai_self_hosted_models_data) { graphql_data_at(:aiSelfHostedModels, :nodes) }

  let(:query) do
    %(
      query SelfHostedModel {
        aiSelfHostedModels {
          nodes {
            id
            name
            model
            modelDisplayName
            endpoint
            hasApiToken
            releaseState
            provider
          }
        }
      }
    )
  end

  subject(:request) { post_graphql(query, current_user: current_user) }

  context 'when user has the required authorization' do
    let(:expect_to_be_authorized) { true }

    context 'when user has accepted the testing terms' do
      before do
        ::Ai::TestingTermsAcceptance.create!(user_id: current_user.id, user_email: current_user.email)
      end

      it 'returns all self-hosted models' do
        request

        expect(ai_self_hosted_models_data).to include(*expected_data)
      end
    end

    context 'when user has not accepted the testing terms' do
      it 'does not return beta models' do
        request

        expected_data.reject! { |model| model['releaseState'] == 'BETA' }
        expect(ai_self_hosted_models_data).to match_array(expected_data)
      end
    end

    it_behaves_like 'performs the right authorization'
  end

  context 'when user is not an admin' do
    let_it_be(:current_user) { create(:user) }
    let(:expect_to_be_authorized) { true }

    it 'does not return self-hosted model data' do
      request

      expect(ai_self_hosted_models_data).to be_nil
    end

    it_behaves_like 'performs the right authorization'
  end

  context 'when a self-hosted model id is provided' do
    let(:self_hosted_model_gid) { self_hosted_models.first.to_global_id }
    let(:query) do
      %(
        query SelfHostedModel {
          aiSelfHostedModels(id: "#{self_hosted_model_gid}") {
            nodes {
              id
              name
              model
              modelDisplayName
              endpoint
              apiToken
              releaseState
              provider
            }
          }
        }
      )
    end

    let(:expected_data) do
      [
        { "id" => self_hosted_models.first.to_global_id.to_s,
          "name" => self_hosted_models.first.name,
          "model" => self_hosted_models.first.model,
          "modelDisplayName" => model_name_mapper[self_hosted_models.first.model],
          "endpoint" => self_hosted_models.first.endpoint,
          "apiToken" => self_hosted_models.first.api_token,
          "releaseState" => self_hosted_models.first.release_state,
          "provider" => self_hosted_models.first.provider.to_s.upcase }
      ]
    end

    it 'returns the self-hosted model' do
      request

      expect(ai_self_hosted_models_data.length).to eq(1)
      expect(ai_self_hosted_models_data).to include(*expected_data)
    end
  end
end
