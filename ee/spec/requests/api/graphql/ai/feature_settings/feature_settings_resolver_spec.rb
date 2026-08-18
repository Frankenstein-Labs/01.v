# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'List of configurable AI feature with metadata.', feature_category: :"self-hosted_models" do
  include GraphqlHelpers

  include_context 'with mocked ::Ai::ModelSelection::FetchModelDefinitionsService'

  let_it_be(:current_user) { create(:admin) }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, :self_managed)
  end

  let(:query) do
    %(
      query aiFeatureSettings {
        aiFeatureSettings {
          nodes {
            feature
            title
            mainFeature
            compatibleLlms
            provider
            releaseState
            selfHostedModel {
              id
              name
              model
              modelDisplayName
              releaseState
            }
            validModels {
              nodes {
                id
                name
                model
                modelDisplayName
                releaseState
              }
            }
            defaultGitlabModel {
              ref
              name
              modelProvider
              modelDescription
              costIndicator
            }
            gitlabModel {
              ref
              name
              modelProvider
              modelDescription
              costIndicator
            }
            validGitlabModels {
              nodes {
                ref
                name
                modelProvider
                modelDescription
                costIndicator
              }
            }
          }
        }
      }
    )
  end

  let_it_be(:self_hosted_model) do
    create(:ai_self_hosted_model, name: 'model_name', model: :mistral)
  end

  let_it_be(:feature_setting) do
    create(:ai_feature_setting,
      self_hosted_model: self_hosted_model,
      feature: :code_completions,
      provider: :self_hosted
    )
  end

  let(:ai_feature_settings_data) { graphql_data_at(:aiFeatureSettings, :nodes) }

  let(:test_ai_feature_enum) do
    {
      code_generations: 0,
      code_completions: 1,
      glab_ask_git_command: 2,
      duo_agent_platform: 3,
      embeddings_code: 4
    }
  end

  let_it_be(:generation_feature_setting) do
    create(:ai_feature_setting, self_hosted_model: nil, feature: :code_generations, provider: :vendored)
  end

  let(:model_name_mapper) { ::Admin::Ai::SelfHostedModelsHelper::MODEL_NAME_MAPPER }

  before do
    allow(::Ai::FeatureSetting).to receive(:allowed_features).and_return(test_ai_feature_enum)
  end

  describe 'authorization' do
    where(:manage_instance_model_selection, :manage_self_hosted_models_settings, :authorized) do
      [
        [false, false, false],
        [true,  false, true],
        [false, true,  true],
        [true,  true,  true]
      ]
    end

    with_them do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?)
          .with(current_user, :manage_instance_model_selection)
          .and_return(manage_instance_model_selection)
        allow(Ability).to receive(:allowed?)
          .with(current_user, :manage_self_hosted_models_settings)
          .and_return(manage_self_hosted_models_settings)
      end

      it 'returns the correct result based on authorization' do
        post_graphql(query, current_user: current_user)

        if authorized
          expect(ai_feature_settings_data).not_to be_nil
        else
          expect(ai_feature_settings_data).to be_nil
        end
      end
    end
  end

  context "for feature setting decorator" do
    before do
      allow(::Gitlab::Graphql::Representation::AiFeatureSetting).to receive(:decorate)
      .and_return(generate_feature_setting_data(feature_setting))
    end

    context 'with self-hosted models permissions' do
      where(:manage_self_hosted_models_settings, :read_dap_self_hosted_model) do
        [
          [true, true],
          [true, false],
          [false, true],
          [false, false]
        ]
      end

      with_them do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?)
            .with(current_user, :manage_self_hosted_models_settings)
            .and_return(manage_self_hosted_models_settings)
          allow(Ability).to receive(:allowed?)
            .with(current_user, :read_dap_self_hosted_model)
            .and_return(read_dap_self_hosted_model)
        end

        it "decorates DAP features with_self_hosted_models: #{params[:read_dap_self_hosted_model]}" \
          "and classic features with_self_hosted_models: #{params[:manage_self_hosted_models_settings]}" do
          post_graphql(query, current_user: current_user)

          expect(::Gitlab::Graphql::Representation::AiFeatureSetting)
            .to have_received(:decorate)
            .with(
              array_including(an_object_having_attributes(feature: "duo_agent_platform")),
              hash_including(with_self_hosted_models: read_dap_self_hosted_model)
            ).ordered
            .at_least(:once)

          # Classic feature settings
          expect(::Gitlab::Graphql::Representation::AiFeatureSetting)
            .to have_received(:decorate)
            .with(
              anything,
              hash_including(with_self_hosted_models: manage_self_hosted_models_settings)
            ).ordered
            .at_least(:once)
        end
      end
    end

    context 'with instance-level model selection permissions' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?)
          .with(current_user, :manage_instance_model_selection)
          .and_return(true)
      end

      it "decorates with_gitlab_models: true" do
        post_graphql(query, current_user: current_user)

        expect(::Gitlab::Graphql::Representation::AiFeatureSetting)
          .to have_received(:decorate)
          .with(
            anything,
            hash_including(with_gitlab_models: true)
          ).twice
      end
    end
  end

  context 'when no query parameters are given' do
    let(:expected_response) do
      test_ai_feature_enum.keys.filter_map do |feature|
        # semantic_search features are excluded
        next if feature == :embeddings_code

        feature_setting = ::Ai::FeatureSetting.find_or_initialize_by_feature(feature)

        generate_feature_setting_data(feature_setting)
      end
    end

    it 'returns the expected response' do
      post_graphql(query, current_user: current_user)

      result = ai_feature_settings_data

      expect(result).to match_array(expected_response)
    end
  end

  context 'when validModels is not requested in the query' do
    let(:query_without_valid_models) do
      %(
        query aiFeatureSettings {
          aiFeatureSettings {
            nodes {
              feature
              title
              provider
            }
          }
        }
      )
    end

    it 'checks instance model selection permissions' do
      allow(Ability).to receive(:allowed?).and_call_original

      post_graphql(query_without_valid_models, current_user: current_user)

      expect(Ability).to have_received(:allowed?).with(current_user, :manage_instance_model_selection)
    end

    it 'does not check self-hosted models permissions' do
      allow(Ability).to receive(:allowed?).and_call_original

      post_graphql(query_without_valid_models, current_user: current_user)

      expect(Ability).not_to have_received(:allowed?).with(current_user, :read_dap_self_hosted_model)
      expect(Ability).not_to have_received(:allowed?).with(current_user, :manage_self_hosted_models_settings)
    end

    it 'decorates with_self_hosted_models as false for both DAP and classic features' do
      allow(::Gitlab::Graphql::Representation::AiFeatureSetting).to receive(:decorate).and_call_original

      post_graphql(query_without_valid_models, current_user: current_user)

      # DAP features
      expect(::Gitlab::Graphql::Representation::AiFeatureSetting)
        .to have_received(:decorate)
        .with(
          anything,
          hash_including(with_self_hosted_models: false)
        ).at_least(:once)

      # Classic features
      expect(::Gitlab::Graphql::Representation::AiFeatureSetting)
        .to have_received(:decorate)
        .with(
          anything,
          hash_including(with_self_hosted_models: false)
        ).at_least(:once)
    end
  end

  context 'when an Self-hosted model ID query parameters are given' do
    let(:query) do
      %(
          query aiFeatureSettings {
            aiFeatureSettings(selfHostedModelId: "#{model_gid}") {
              nodes {
                feature
                title
                mainFeature
                compatibleLlms
                provider
                releaseState
                selfHostedModel {
                  id
                  name
                  model
                  modelDisplayName
                  releaseState
                }
                validModels {
                  nodes {
                    id
                    name
                    model
                    modelDisplayName
                    releaseState
                  }
                }
                defaultGitlabModel {
                  ref
                  name
                  modelProvider
                  modelDescription
                  costIndicator
                }
                gitlabModel {
                  ref
                  name
                  modelProvider
                  modelDescription
                  costIndicator
                }
                validGitlabModels {
                  nodes {
                    ref
                    name
                    modelProvider
                    modelDescription
                    costIndicator
                  }
                }
              }
            }
          }
        )
    end

    context 'when the self-hosted model id exists' do
      let(:model_gid) { self_hosted_model.to_global_id }

      let(:expected_response) do
        [generate_feature_setting_data(feature_setting)]
      end

      it 'returns the expected response' do
        post_graphql(query, current_user: current_user)

        expect(ai_feature_settings_data).to match_array(expected_response)
      end
    end

    context 'when the self-hosted model id does not exist' do
      let(:model_gid) { "gid://gitlab/Ai::SelfHostedModel/999999" }

      it 'returns the expected response' do
        post_graphql(query, current_user: current_user)

        expect(ai_feature_settings_data).to be_empty
      end
    end
  end

  context 'when FetchModelDefinitionsService returns error ServiceResponse' do
    before do
      error_service = instance_double(::Ai::ModelSelection::FetchModelDefinitionsService)
      allow(::Ai::ModelSelection::FetchModelDefinitionsService).to receive(:new).and_return(error_service)
      allow(error_service).to receive(:execute).and_return(
        ServiceResponse.success(payload: nil)
      )

      stub_application_setting(duo_features_enabled: false)
    end

    it 'handles ServiceResponse gracefully without crashing' do
      expect { post_graphql(query, current_user: current_user) }.not_to raise_error
      expect(graphql_errors).to be_nil
    end
  end

  context 'when FetchModelDefinitionsService returns selectable GitLab models for glab_ask_git_command' do
    let(:model_definitions) do
      {
        'models' => [
          {
            'name' => 'GPT-4',
            'identifier' => 'gpt-4',
            "provider" => "OpenAI",
            "description" => 'For high-volume coding, reasoning, and routine workflows.',
            'cost_indicator' => '$'
          }
        ],
        'unit_primitives' => [
          { 'feature_setting' => 'code_generations', 'selectable_models' => %w[gpt-4] },
          { 'feature_setting' => 'code_completions', 'selectable_models' => %w[gpt-4] },
          { 'feature_setting' => 'glab_ask_git_command', 'selectable_models' => %w[gpt-4] }
        ]
      }
    end

    before do
      model_definitions_service = instance_double(::Ai::ModelSelection::FetchModelDefinitionsService)
      allow(::Ai::ModelSelection::FetchModelDefinitionsService).to receive(:new).and_return(model_definitions_service)
      allow(model_definitions_service).to receive(:execute).and_return(
        ServiceResponse.success(payload: model_definitions)
      )
    end

    it 'includes the selectable models in the response' do
      post_graphql(query, current_user: current_user)

      result = ai_feature_settings_data.index_by { |node| node['feature'] }
      expected_valid_gitlab_model = {
        'name' => 'GPT-4',
        'ref' => 'gpt-4',
        'modelProvider' => "OpenAI",
        'modelDescription' => 'For high-volume coding, reasoning, and routine workflows.',
        'costIndicator' => '$'
      }

      %w[code_generations code_completions glab_ask_git_command].each do |feature|
        expect(result.dig(feature, 'validGitlabModels', 'nodes')).to contain_exactly(expected_valid_gitlab_model)
      end
    end
  end

  describe 'allowList field' do
    let(:allow_list_query) do
      %(
        query aiFeatureSettings {
          aiFeatureSettings {
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

    let(:allowlist_feature_enum) do
      test_ai_feature_enum.merge(duo_agent_platform_agentic_chat: 4)
    end

    let(:model_definitions_payload) do
      {
        'models' => [
          { 'identifier' => 'claude-3-7-sonnet-20250219', 'name' => 'Claude Sonnet 3.7', 'provider' => 'anthropic',
            'description' => 'Claude Sonnet 3.7', 'cost_indicator' => '$$$' },
          { 'identifier' => 'claude-3-5-sonnet-20240620', 'name' => 'Claude Sonnet 3.5', 'provider' => 'anthropic',
            'description' => 'Claude Sonnet 3.5', 'cost_indicator' => '$$' }
        ],
        'unit_primitives' => [
          { 'feature_setting' => 'duo_agent_platform_agentic_chat', 'default_model' => 'claude-3-7-sonnet-20250219',
            'selectable_models' => %w[claude-3-7-sonnet-20250219 claude-3-5-sonnet-20240620] }
        ]
      }
    end

    let_it_be(:agentic_chat_ai_feature_setting) do
      create(:ai_feature_setting,
        feature: :duo_agent_platform_agentic_chat,
        provider: :vendored,
        self_hosted_model: nil)
    end

    let_it_be(:agentic_chat_instance_setting) do
      create(:instance_model_selection_feature_setting,
        feature: :duo_agent_platform_agentic_chat,
        offered_model_ref: 'claude-3-7-sonnet-20250219',
        model_allowlist_enabled: true,
        model_allowlist_gitlab_model_refs: %w[claude-3-5-sonnet-20240620])
    end

    before do
      allow(::Ai::FeatureSetting).to receive(:allowed_features).and_return(allowlist_feature_enum)

      model_definitions_service = instance_double(::Ai::ModelSelection::FetchModelDefinitionsService)
      allow(::Ai::ModelSelection::FetchModelDefinitionsService).to receive(:new).and_return(model_definitions_service)
      allow(model_definitions_service).to receive(:execute).and_return(
        ServiceResponse.success(payload: model_definitions_payload)
      )
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?)
        .with(current_user, :manage_instance_model_selection)
        .and_return(true)
    end

    context 'when the user can read the model selection allowlist' do
      before do
        allow(Ability).to receive(:allowed?)
          .with(current_user, :read_model_selection_allowlist)
          .and_return(true)
      end

      it 'returns the allow_list payload with allowed flags and the currently chosen ref',
        :aggregate_failures do
        post_graphql(allow_list_query, current_user: current_user)

        row = ai_feature_settings_data.find { |node| node['feature'] == 'duo_agent_platform_agentic_chat' }
        models = row.dig('allowList', 'models', 'nodes').index_by { |m| m['ref'] }

        expect(row['allowList']['enabled']).to be(true)
        expect(models['claude-3-7-sonnet-20250219']).to include(
          'allowed' => true, 'currentlyChosenModelForFeature' => true
        )
        expect(models['claude-3-5-sonnet-20240620']).to include(
          'allowed' => true, 'currentlyChosenModelForFeature' => false
        )
      end

      it 'returns null allowList for non-Agentic-Chat features' do
        post_graphql(allow_list_query, current_user: current_user)

        row = ai_feature_settings_data.find { |node| node['feature'] == 'code_generations' }

        expect(row['allowList']).to be_nil
      end
    end

    context 'when the user cannot read the model selection allowlist' do
      before do
        allow(Ability).to receive(:allowed?)
          .with(current_user, :read_model_selection_allowlist)
          .and_return(false)
      end

      it 'returns null for allowList' do
        post_graphql(allow_list_query, current_user: current_user)

        row = ai_feature_settings_data.find { |node| node['feature'] == 'duo_agent_platform_agentic_chat' }

        expect(row['allowList']).to be_nil
      end
    end
  end

  def generate_feature_setting_data(feature_setting)
    gitlab_data = if feature_setting.feature.to_s == 'code_completions'
                    {
                      'defaultGitlabModel' => {
                        'name' => 'GPT-4',
                        'ref' => 'gpt-4',
                        'modelProvider' => 'OpenAI',
                        'modelDescription' => 'For high-volume coding, reasoning, and routine workflows.',
                        'costIndicator' => '$'
                      },
                      'gitlabModel' => nil,
                      'validGitlabModels' => {
                        'nodes' => [
                          {
                            'name' => 'GPT-4',
                            'ref' => 'gpt-4',
                            'modelProvider' => 'OpenAI',
                            'modelDescription' => 'For high-volume coding, reasoning, and routine workflows.',
                            'costIndicator' => '$'
                          }
                        ]
                      }
                    }
                  else
                    {
                      'defaultGitlabModel' => nil,
                      'gitlabModel' => nil,
                      'validGitlabModels' => { 'nodes' => [] }
                    }
                  end

    {
      'feature' => feature_setting.feature.to_s,
      'title' => feature_setting.title,
      'mainFeature' => feature_setting.main_feature,
      'compatibleLlms' => feature_setting.compatible_llms,
      'provider' => feature_setting.provider.to_s,
      'releaseState' => feature_setting.release_state,
      'selfHostedModel' => generate_self_hosted_data(feature_setting.self_hosted_model),
      'validModels' => {
        'nodes' => compute_valid_models(feature_setting).map { |s| generate_self_hosted_data(s) }
      },
      **gitlab_data
    }
  end

  # Uses the production decorator to compute valid models, ensuring test stays in sync
  # with production logic in Gitlab::Graphql::Representation::AiFeatureSetting
  def compute_valid_models(feature_setting)
    decorated = ::Gitlab::Graphql::Representation::AiFeatureSetting.decorate(
      [feature_setting],
      with_self_hosted_models: true
    ).first

    decorated&.valid_models || []
  end

  def generate_self_hosted_data(self_hosted_model)
    return unless self_hosted_model

    {
      'id' => self_hosted_model.to_global_id.to_s,
      'name' => self_hosted_model.name,
      'model' => self_hosted_model.model,
      'modelDisplayName' => model_name_mapper[self_hosted_model.model],
      'releaseState' => self_hosted_model.release_state
    }
  end
end
