# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Checking a self-hosted model connection', feature_category: :"self-hosted_models" do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, :self_managed)
  end

  let(:input) do
    {
      "name" => 'ollama1-mistral',
      "endpoint" => 'http://localhost:8080',
      "model" => 'MISTRAL',
      "provider" => 'API',
      "api_token" => "test_api_token",
      "identifier" => "provider/some-model"
    }
  end

  let(:mutation) { graphql_mutation(:ai_self_hosted_model_connection_check, input) }
  let(:mutation_response) { graphql_mutation_response(:ai_self_hosted_model_connection_check) }

  subject(:request) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'it calls the manage_self_hosted_models_settings policy' do
    it 'calls the manage_self_hosted_models_settings policy' do
      allow(::Ability).to receive(:allowed?).and_call_original
      expect(::Ability).to receive(:allowed?).with(current_user, :manage_self_hosted_models_settings)

      request
    end
  end

  context 'when user is not allowed to write changes' do
    let(:current_user) { create(:user) }

    it_behaves_like 'it calls the manage_self_hosted_models_settings policy'
    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when user is allowed to write changes' do
    let(:probe_graphql_result) { mutation_response['result'] }

    before do
      allow_next_instance_of(Gitlab::Llm::AiGateway::SelfHostedModels::ConnectionTester) do |tester|
        allow(tester).to receive(:execute)
      end

      allow(::Gitlab::AiGateway).to receive(:self_hosted_url).and_return('http://localhost:3000')
    end

    it_behaves_like 'it calls the manage_self_hosted_models_settings policy'

    context 'when there are errors with performing the code suggestions test' do
      let(:error_message) { 'API error' }

      before do
        allow_next_instance_of(Gitlab::Llm::AiGateway::SelfHostedModels::ConnectionTester) do |tester|
          allow(tester).to receive(:execute).and_return(error_message)
        end
      end

      it 'returns an error message' do
        request

        expect(response).to have_gitlab_http_status(:success)
        expect(probe_graphql_result['success']).to be(false)
        expect(probe_graphql_result['message']).to match(error_message)
      end
    end

    context 'when there are no errors' do
      before do
        allow_next_instance_of(Gitlab::Llm::AiGateway::SelfHostedModels::ConnectionTester) do |tester|
          allow(tester).to receive(:execute).and_return(nil)
        end
      end

      it 'returns a success result' do
        request

        expect(response).to have_gitlab_http_status(:success)
        expect(probe_graphql_result['success']).to be true
        expect(probe_graphql_result['message']).to match('Successfully connected')
      end
    end

    context 'when the local AI Gateway URL is not configured' do
      before do
        allow(::Gitlab::AiGateway).to receive(:self_hosted_url).and_return(nil)
      end

      it 'returns a failure result with a local AI Gateway URL not configured message' do
        request

        expect(response).to have_gitlab_http_status(:success)
        expect(probe_graphql_result['success']).to be false
        expect(probe_graphql_result['message']).to match(
          "You have not configured your local AI gateway URL. " \
            "Configure the URL in the GitLab Duo configuration settings."
        )
      end
    end
  end
end
