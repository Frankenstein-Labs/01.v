# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Deleting a self-hosted model', feature_category: :"self-hosted_models" do
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
      endpoint: 'https://test-endpoint.com'
    )
  end

  let(:mutation_name) { :ai_self_hosted_model_delete }
  let(:mutation_params) { { id: GitlabSchema.id_from_object(self_hosted_model).to_s } }

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

      context 'when the self-hosted model is not found' do
        let(:mutation_params) { { id: "gid://gitlab/Ai::SelfHostedModel/#{non_existing_record_id}" } }

        it 'returns an error' do
          request

          result = json_response['data']['aiSelfHostedModelDelete']
          expect(result['selfHostedModel']).to be_nil
          expect(result['errors']).to eq(["Self-hosted model not found"])
        end

        it 'does not delete any models' do
          expect { request }.to not_change { ::Ai::SelfHostedModel.count }
        end
      end

      context 'when id param is invalid' do
        let(:mutation_params) { { id: "invalid id string" } }

        it 'returns an error' do
          request

          expect_graphql_errors_to_include(/was provided invalid value for id/)
        end
      end

      context 'when there are no errors' do
        it 'deletes the self-hosted model' do
          expect { request }.to change { ::Ai::SelfHostedModel.count }.by(-1)

          result = json_response['data']['aiSelfHostedModelDelete']
          expect(result['errors']).to eq([])
        end
      end
    end
  end
end
