# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating an instance AI feature model allowlist', feature_category: :"self-hosted_models" do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, :self_managed) }

  # The fetch-definition side-effect context references `user` in its before block.
  let(:user) { current_user }

  let(:model_definitions) do
    {
      'models' => [
        { 'name' => 'Claude Sonnet 3.7', 'identifier' => 'claude-3-7-sonnet-20250219' },
        { 'name' => 'Claude Sonnet 3.5', 'identifier' => 'claude-3-5-sonnet-20240620' }
      ],
      'unit_primitives' => [
        {
          'feature_setting' => 'duo_agent_platform_agentic_chat',
          'default_model' => 'claude-3-7-sonnet-20250219',
          'selectable_models' => %w[claude-3-7-sonnet-20250219 claude-3-5-sonnet-20240620],
          'beta_models' => []
        }
      ]
    }
  end

  let(:model_definitions_response) { model_definitions.to_json }

  let(:mutation_name) { :ai_feature_setting_model_allowlist_update }
  let(:mutation_params) do
    {
      feature: 'DUO_AGENT_PLATFORM_AGENTIC_CHAT',
      allowlistEnabled: true,
      allowlistModelRefs: ['claude-3-5-sonnet-20240620']
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

  include_context 'with the model selections fetch definition service as side-effect'

  subject(:request) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    stub_request(:get, fetch_service_endpoint_url)
      .to_return(
        status: 200,
        body: model_definitions_response,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def mutation_response
    graphql_mutation_response(mutation_name)
  end

  describe '#resolve' do
    context 'when the user cannot update the model selection allowlist' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?)
          .with(current_user, :update_model_selection_allowlist)
          .and_return(false)
      end

      it 'returns a top-level access error' do
        request

        expect(graphql_errors.pluck('message')).to include(
          "The resource that you are attempting to access does not exist or " \
            "you don't have permission to perform this action"
        )
      end
    end

    context 'when the user can update the model selection allowlist' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?)
          .with(current_user, :update_model_selection_allowlist)
          .and_return(true)
      end

      context 'when enabling the allowlist' do
        it 'persists the allowlist and returns the updated allow_list payload', :aggregate_failures do
          request

          expect(mutation_response['errors']).to eq([])

          allow_list = mutation_response['allowList']
          expect(allow_list['enabled']).to be(true)

          models = allow_list.dig('models', 'nodes').index_by { |m| m['ref'] }
          expect(models['claude-3-5-sonnet-20240620']).to include(
            'allowed' => true, 'currentlyChosenModelForFeature' => false
          )
          expect(models['claude-3-7-sonnet-20250219']).to include(
            'allowed' => true, 'currentlyChosenModelForFeature' => true
          )

          setting = ::Ai::ModelSelection::InstanceModelSelectionFeatureSetting
                      .find_by(feature: :duo_agent_platform_agentic_chat)
          expect(setting.model_allowlist_enabled).to be(true)
          expect(setting.model_allowlist_gitlab_model_refs).to contain_exactly('claude-3-5-sonnet-20240620')
        end
      end

      context 'when disabling the allowlist' do
        let_it_be(:existing_setting) do
          create(:instance_model_selection_feature_setting, :with_allowlist,
            feature: :duo_agent_platform_agentic_chat)
        end

        let(:mutation_params) do
          {
            feature: 'DUO_AGENT_PLATFORM_AGENTIC_CHAT',
            allowlistEnabled: false,
            allowlistModelRefs: ['claude-3-5-sonnet-20240620']
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
            feature: 'CODE_GENERATIONS',
            allowlistEnabled: true,
            allowlistModelRefs: ['claude-3-5-sonnet-20240620']
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
    end

    context 'with granular token permissions', :enable_admin_mode do
      before do
        create(:license, plan: License::ULTIMATE_PLAN, cloud: true)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL',
        %i[read_model_selection_allowlist update_model_selection_allowlist] do
        let(:user) { current_user }
        let(:boundary_object) { :instance }
        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      context 'when only the allowList payload is requested' do
        # Only the allowList payload without model rows, to test the gPAT
        # directive on the AiModelSelectionAllowList type (instance boundary)
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
          let(:boundary_object) { :instance }
          let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
        end
      end
    end
  end
end
