# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating a self-hosted model', feature_category: :"self-hosted_models" do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, :self_managed)
  end

  let_it_be(:self_hosted_model) do
    create(
      :ai_self_hosted_model,
      name: 'test-deployment',
      model: :mistral,
      endpoint: 'https://test-endpoint.com',
      identifier: 'provider/some-model',
      provider: :api
    )
  end

  let(:mutation_name) { :ai_self_hosted_model_update }
  let(:mutation_params) do
    {
      id: GitlabSchema.id_from_object(self_hosted_model).to_s,
      name: 'new-test-deployment',
      model: 'CODEGEMMA',
      endpoint: 'https://new-test-endpoint.com',
      api_token: '',
      identifier: 'provider/some-model-2',
      provider: 'API'
    }
  end

  let(:mutation) { graphql_mutation(mutation_name, mutation_params) }

  subject(:request) { post_graphql_mutation(mutation, current_user: current_user) }

  describe '#resolve' do
    context 'when the user does not have write access' do
      let(:current_user) { create(:user) }

      it_behaves_like 'performs the right authorization'
      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'when the user has write access' do
      it_behaves_like 'performs the right authorization'

      context 'when there are ActiveRecord validation errors' do
        let(:mutation_params) do
          {
            id: GitlabSchema.id_from_object(self_hosted_model).to_s,
            name: '',
            model: 'CODEGEMMA',
            provider: 'API',
            endpoint: 'https://new-test-endpoint.com',
            api_token: '',
            identifier: 'provider/some-model-2'
          }
        end

        it 'returns an error' do
          request

          result = json_response['data']['aiSelfHostedModelUpdate']

          expect(result['selfHostedModel']).to be_nil
          expect(result['errors']).to eq(["Name can't be blank"])
        end

        it 'does not update the self-hosted model' do
          request

          expect { self_hosted_model.reload }.not_to change { self_hosted_model.name }
        end
      end

      context 'when required arguments are missing' do
        let(:mutation_params) { { id: GitlabSchema.id_from_object(self_hosted_model).to_s } }

        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect_graphql_errors_to_include(/was provided invalid value for name \(Expected value to not be null\)/)
        end
      end

      context 'when there are no errors' do
        it 'updates the self-hosted model' do
          request

          expect(response).to have_gitlab_http_status(:success)

          self_hosted_model.reload

          expect(self_hosted_model.name).to eq('new-test-deployment')
          expect(self_hosted_model.model).to eq('codegemma')
          expect(self_hosted_model.endpoint).to eq('https://new-test-endpoint.com')
          expect(self_hosted_model.identifier).to eq('provider/some-model-2')
          expect(self_hosted_model.provider).to eq('api')
        end
      end
    end
  end
end
