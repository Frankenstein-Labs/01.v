# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'List of configurable namespace Model Selection feature settings.',
  :saas_gitlab_com_subscriptions, feature_category: :"self-hosted_models" do
  include GraphqlHelpers

  let_it_be(:group_owner) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }

  let_it_be(:feature_settings) do
    [
      create(:ai_namespace_feature_setting, feature: :code_completions, namespace: group),
      create(:ai_namespace_feature_setting, feature: :code_generations, namespace: group)
    ]
  end

  let_it_be(:test_ai_feature_enum) do
    {
      code_generations: 0,
      code_completions: 1,
      duo_chat: 2
    }
  end

  let(:is_saas) { true }
  let(:namespace_duo_enabled) { true }
  let(:user) { group_owner }
  let(:group_gid) { group.to_global_id.to_s }
  let(:request_params) { { groupId: group_gid } }

  let(:query) do
    %(
      query AiModelSelectionNamespaces($groupId: GroupID!) {
        aiModelSelectionNamespaceSettings(groupId: $groupId) {
          nodes {
            feature
            title
            mainFeature
            selectedModel {
              ref
              name
            }
            selectableModels {
              ref
              name
            }
            defaultModel {
              ref
              name
            }
          }
        }
      }
    )
  end

  let(:fetch_service_stubbed_params) do
    {
      status: 200,
      body: model_definitions_response,
      headers: { 'Content-Type' => 'application/json' }
    }
  end

  include_context 'with model selections fetch definition service side-effect context'

  before_all do
    group.add_owner(group_owner)
  end

  before do
    allow(::Ai::ModelSelection::NamespaceFeatureSetting).to(
      receive(:enabled_features_for)
        .with(group)
        .and_return(test_ai_feature_enum)
    )

    stub_saas_features(gitlab_com_subscriptions: is_saas)
    create(:gitlab_subscription, :ultimate, namespace: group)

    group.namespace_settings.update!(duo_features_enabled: namespace_duo_enabled)

    stub_request(:get, fetch_service_endpoint_url)
      .to_return(fetch_service_stubbed_params)
  end

  subject(:request) { post_graphql(query, current_user: user, variables: request_params) }

  describe '#resolve' do
    before do
      request
    end

    context 'with access issues' do
      context 'when the instance is not saas' do
        let(:is_saas) { false }

        it_behaves_like 'a query that returns a top-level access error'
      end

      context 'when duo is disabled for the namespace' do
        let(:namespace_duo_enabled) { false }

        it_behaves_like 'a query that returns a top-level access error'
      end

      context 'when the user does not have write access to the group' do
        let(:user) { create(:user) }

        it_behaves_like 'a query that returns a top-level access error'
      end

      context 'when the group is not found' do
        let(:group_gid) { "gid://gitlab/Group/0" }

        it_behaves_like 'a query that returns a top-level access error'
      end
    end

    context 'when the model definition fetch service fails' do
      let(:fetch_service_stubbed_params) do
        {
          status: 401,
          body: "{\"error\":\"No authorization header presented\"}",
          headers: { 'Content-Type' => 'application/json' }
        }
      end

      let(:expected_error_message) { 'Received error 401 from AI gateway when fetching model definitions' }

      it 'returns an error message' do
        result_data = json_response['data']['aiModelSelectionNamespaceSettings']
        result_errors = json_response['errors']

        expect(result_data).to be_nil

        expect(result_errors.first['message']).to eq(expected_error_message)
      end
    end

    context 'when there are no errors' do
      let(:request_data) { graphql_data_at(:aiModelSelectionNamespaceSettings, :nodes) }
      let(:expected_features) { %w[duo_chat code_generations code_completions] }

      let(:expected_selectable_models) do
        [
          { 'name' => 'Claude Sonnet 3.5', 'ref' => 'claude_sonnet_3_5' },
          { 'name' => 'Claude Sonnet 3.7', 'ref' => 'claude_sonnet_3_7' },
          { 'name' => 'OpenAI Chat GPT 4o', 'ref' => 'openai_chatgpt_4o' }
        ]
      end

      let(:expected_selected_models) do
        [
          { 'name' => 'Claude Sonnet 3.7', 'ref' => 'claude_sonnet_3_7' },
          { 'name' => 'Claude Sonnet 3.7', 'ref' => 'claude_sonnet_3_7' },
          nil
        ]
      end

      it 'returns the expected response' do
        result = json_response['data']['aiModelSelectionNamespaceSettings']

        expect(result['errors']).to be_nil
        expect(request_data.length).to eq(3)
        expect(request_data.pluck('feature')).to match_array(expected_features)
        expect(request_data.first['selectableModels']).to match_array(expected_selectable_models)
        expect(request_data.pluck('selectedModel')).to match_array(expected_selected_models)
      end
    end
  end

  describe 'allowList field' do
    let_it_be(:agentic_chat_setting) do
      create(:ai_namespace_feature_setting,
        namespace: group,
        feature: :duo_agent_platform_agentic_chat,
        offered_model_ref: 'claude_sonnet_4_20250514',
        model_allowlist_enabled: true,
        model_allowlist_gitlab_model_refs: %w[claude_sonnet_3_7])
    end

    let_it_be(:allowlist_test_ai_feature_enum) do
      test_ai_feature_enum.merge(duo_agent_platform_agentic_chat: 17)
    end

    let(:query) do
      %(
        query AiModelSelectionNamespaces($groupId: GroupID!) {
          aiModelSelectionNamespaceSettings(groupId: $groupId) {
            nodes {
              feature
              allowList {
                enabled
                models {
                  nodes {
                    ref
                    name
                    allowed
                    currentlyChosenModelForFeature
                  }
                }
              }
            }
          }
        }
      )
    end

    before do
      allow(::Ai::ModelSelection::NamespaceFeatureSetting).to(
        receive(:enabled_features_for)
          .with(group)
          .and_return(allowlist_test_ai_feature_enum)
      )
    end

    context 'when the user can read the model selection allowlist' do
      it 'returns the allow_list payload with allowed flags and the currently chosen ref',
        :aggregate_failures do
        request

        result = graphql_data_at(:aiModelSelectionNamespaceSettings, :nodes)
        row = result.find { |node| node['feature'] == 'duo_agent_platform_agentic_chat' }
        models = row.dig('allowList', 'models', 'nodes').index_by { |m| m['ref'] }

        expect(row['allowList']['enabled']).to be(true)
        expect(models['claude_sonnet_4_20250514']).to include(
          'allowed' => true, 'currentlyChosenModelForFeature' => true
        )
        expect(models['claude_sonnet_3_7']).to include(
          'allowed' => true, 'currentlyChosenModelForFeature' => false
        )
      end

      it 'returns null allowList for non-Agentic-Chat features' do
        request

        result = graphql_data_at(:aiModelSelectionNamespaceSettings, :nodes)
        row = result.find { |node| node['feature'] == 'code_completions' }

        expect(row['allowList']).to be_nil
      end
    end

    context 'when the user cannot read the model selection allowlist' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?)
          .with(user, :read_model_selection_allowlist, anything)
          .and_return(false)
      end

      it 'returns null for allowList' do
        request

        result = graphql_data_at(:aiModelSelectionNamespaceSettings, :nodes)
        row = result.find { |node| node['feature'] == 'duo_agent_platform_agentic_chat' }

        expect(row['allowList']).to be_nil
      end
    end
  end
end
