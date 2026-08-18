# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating a Namespace Model Selection Feature setting', :saas_gitlab_com_subscriptions, feature_category: :"self-hosted_models" do
  include GraphqlHelpers

  let_it_be(:group_owner) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }

  let(:current_user) { group_owner }
  let(:user) { current_user }

  let(:is_saas) { true }
  let(:namespace_duo_enabled) { true }

  let(:offered_model_ref) { 'openai_chatgpt_4o' }
  let(:group_gid) { group.to_global_id.to_s }
  let(:feature_list) { %w[CODE_COMPLETIONS DUO_CHAT] }

  let(:mutation_params) do
    {
      groupId: group_gid,
      features: feature_list,
      offeredModelRef: offered_model_ref
    }
  end

  let(:mutation_name) { :ai_model_selection_namespace_update }

  let(:mutation) { graphql_mutation(mutation_name, mutation_params) }

  include_context 'with model selections fetch definition service side-effect context'

  before_all do
    group.add_owner(group_owner)
  end

  before do
    stub_saas_features(gitlab_com_subscriptions: is_saas, gitlab_duo_saas_only: is_saas)
    create(:gitlab_subscription, :ultimate, namespace: group)

    group.namespace_settings.update!(duo_features_enabled: namespace_duo_enabled)

    stub_request(:get, fetch_service_endpoint_url)
      .to_return(
        status: 200,
        body: model_definitions_response,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  subject(:request) { post_graphql_mutation(mutation, current_user: current_user) }

  describe '#resolve' do
    context 'with access issues' do
      context 'when the instance is not SAAS' do
        let(:is_saas) { false }

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'when duo is disabled for the namespace' do
        let(:namespace_duo_enabled) { false }

        it_behaves_like 'a mutation that returns a top-level access error'
      end
    end

    context 'with problem with the associated group' do
      context 'when the user does not have write access to the group' do
        let(:current_user) { create(:user) }

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'when the group is not found' do
        let(:group_gid) { "gid://gitlab/Group/0" }

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'when the given gid is not a group' do
        let(:sub_group) { create(:group, parent: group) }

        let(:group_gid) { sub_group.to_global_id.to_s }

        before do
          sub_group.add_owner(group_owner)
        end

        it_behaves_like 'a mutation that returns a top-level access error'
      end
    end

    context 'when features array is empty' do
      let(:feature_list) { [] }

      it 'returns an error message' do
        request
        result = json_response['data']['aiModelSelectionNamespaceUpdate']

        expect(result['aiFeatureSettings']).to eq([])
        expect(result['errors']).to eq(['At least one feature is required'])
      end
    end

    context 'when there are no errors' do
      let!(:feature_setting) { create(:ai_namespace_feature_setting, feature: :code_completions, namespace: group) }

      it 'updates the existing feature setting and creates new entries correctly' do
        expect { request }.to change { ::Ai::ModelSelection::NamespaceFeatureSetting.count }.from(1).to(2)
        expect(response).to have_gitlab_http_status(:success)

        feature_settings = ::Ai::ModelSelection::NamespaceFeatureSetting
                             .where(feature: feature_list.map(&:downcase))
                             .order(:feature)

        expect(feature_settings.count).to eq(2)

        feature_settings.each do |setting|
          expect(setting.reload.offered_model_ref).to eq(offered_model_ref)
        end
      end

      it 'returns a success response' do
        request

        result = json_response['data']['aiModelSelectionNamespaceUpdate']
        feature_settings_payload = result['aiFeatureSettings']

        expect(result['errors']).to eq([])
        expect(feature_settings_payload.length).to eq(2)

        expect(feature_settings_payload.first['feature']).to eq(feature_setting.reload.feature)
        expect(feature_settings_payload.first['selectedModel']['ref']).to eq(feature_setting.reload.offered_model_ref)
      end
    end
  end
end
