# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating a namespace AI feature model allowlist', :saas_gitlab_com_subscriptions, feature_category: :"self-hosted_models" do
  include GraphqlHelpers

  let_it_be(:group_owner) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }

  let(:current_user) { group_owner }
  let(:user) { current_user }

  let(:is_saas) { true }
  let(:namespace_duo_enabled) { true }

  let(:group_gid) { group.to_global_id.to_s }

  let(:mutation_name) { :ai_model_selection_namespace_model_allowlist_update }
  let(:mutation_params) do
    {
      groupId: group_gid,
      feature: 'DUO_AGENT_PLATFORM_AGENTIC_CHAT',
      allowlistEnabled: true,
      allowlistModelRefs: ['claude_sonnet_3_7']
    }
  end

  let(:mutation_fields) do
    <<~FIELDS
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
      errors
    FIELDS
  end

  let(:mutation) { graphql_mutation(mutation_name, mutation_params, mutation_fields) }

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

  def mutation_response
    graphql_mutation_response(mutation_name)
  end

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

      context 'when the user does not have write access to the group' do
        let(:current_user) { create(:user) }

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'when the group is not found' do
        let(:group_gid) { "gid://gitlab/Group/#{non_existing_record_id}" }

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'when the given gid is a subgroup' do
        let(:sub_group) { create(:group, parent: group) }

        let(:group_gid) { sub_group.to_global_id.to_s }

        before do
          sub_group.add_owner(group_owner)
        end

        it_behaves_like 'a mutation that returns a top-level access error'
      end
    end

    context 'when enabling the allowlist' do
      it 'persists the allowlist and returns the updated allow_list payload', :aggregate_failures do
        request

        expect(mutation_response['errors']).to eq([])

        allow_list = mutation_response['allowList']
        expect(allow_list['enabled']).to be(true)

        models = allow_list.dig('models', 'nodes').index_by { |m| m['ref'] }
        expect(models['claude_sonnet_3_7']).to include(
          'allowed' => true, 'currentlyChosenModelForFeature' => false
        )
        expect(models['claude_sonnet_4_20250514']).to include(
          'allowed' => true, 'currentlyChosenModelForFeature' => true
        )

        setting = ::Ai::ModelSelection::NamespaceFeatureSetting
                    .find_by(namespace: group, feature: :duo_agent_platform_agentic_chat)
        expect(setting.model_allowlist_enabled).to be(true)
        expect(setting.model_allowlist_gitlab_model_refs).to contain_exactly('claude_sonnet_3_7')
      end
    end

    context 'when disabling the allowlist' do
      let_it_be(:existing_setting) do
        create(:ai_namespace_feature_setting, :with_allowlist,
          feature: :duo_agent_platform_agentic_chat, namespace: group,
          offered_model_ref: 'claude_sonnet_4_20250514')
      end

      let(:mutation_params) do
        {
          groupId: group_gid,
          feature: 'DUO_AGENT_PLATFORM_AGENTIC_CHAT',
          allowlistEnabled: false,
          allowlistModelRefs: ['claude_sonnet_3_7']
        }
      end

      it 'wipes stored refs and disables the allowlist', :aggregate_failures do
        request

        expect(mutation_response['errors']).to eq([])
        expect(mutation_response.dig('allowList', 'enabled')).to be(false)

        expect(existing_setting.reload.model_allowlist_enabled).to be(false)
        expect(existing_setting.model_allowlist_gitlab_model_refs).to eq([])
      end
    end

    context 'when the feature does not support allowlists' do
      let(:mutation_params) do
        {
          groupId: group_gid,
          feature: 'CODE_GENERATIONS',
          allowlistEnabled: true,
          allowlistModelRefs: ['claude_sonnet_3_7']
        }
      end

      it 'returns an error and a null allow_list', :aggregate_failures do
        request

        expect(mutation_response['allowList']).to be_nil
        expect(mutation_response['errors']).to include(
          "Model allowlists are not supported for the feature 'code_generations'."
        )
      end
    end

    context 'with granular token permissions' do
      # Only requesting error field to test the gPAT directive on the mutation
      let(:mutation_fields) { 'errors' }

      it_behaves_like 'authorizing granular token permissions for GraphQL',
        %i[update_model_selection_allowlist] do
        let(:user) { current_user }
        let(:boundary_object) { group }
        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end
    end

    context 'with granular token permissions on the allowList payload' do
      # Only the allowList payload without model rows, to test the gPAT
      # directive on the AiModelSelectionAllowList type (group boundary)
      let(:mutation_fields) do
        <<~FIELDS
          allowList {
            enabled
          }
          errors
        FIELDS
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL',
        %i[read_model_selection_allowlist update_model_selection_allowlist] do
        let(:user) { current_user }
        let(:boundary_object) { group }
        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end
    end

    context 'with granular token permissions on the allowList model rows' do
      # The default mutation fields include the model rows, testing the gPAT
      # directive on the AiModelSelectionAllowListModel type (group boundary)
      it_behaves_like 'authorizing granular token permissions for GraphQL',
        %i[read_model_selection_allowlist update_model_selection_allowlist] do
        let(:user) { current_user }
        let(:boundary_object) { group }
        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end
    end
  end
end
