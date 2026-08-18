# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::DuoAgentPlatformModelMetadataService, feature_category: :duo_agent_platform do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:user_selected_model_identifier) { nil }
  let(:feature_name) { ::Ai::ModelSelection::FeaturesConfigurable.agentic_chat_feature_name }

  subject(:service) do
    described_class.new(
      root_namespace: root_namespace,
      current_user: user,
      user_selected_model_identifier: user_selected_model_identifier,
      feature_name: feature_name
    )
  end

  shared_examples 'returns empty headers' do
    it 'returns empty hash' do
      result = service.execute
      expect(result).to eq({})
    end
  end

  shared_examples 'uses the gitlab default model' do
    it 'uses the gitlab default model' do
      result = service.execute
      expect(result).to include(
        'x-gitlab-agent-platform-model-metadata' => {
          'provider' => 'gitlab',
          'feature_setting' => 'duo_agent_platform_agentic_chat',
          'identifier' => nil
        }.to_json
      )
    end
  end

  describe '#execute' do
    context 'for self-hosted Duo instances' do
      let(:root_namespace) { nil }

      context 'for self hosted duo agent platform' do
        context 'with self-hosted feature setting' do
          let_it_be(:feature_setting) do
            create(:ai_feature_setting,
              feature: :duo_agent_platform_agentic_chat,
              provider: :self_hosted,
              self_hosted_model: create(:ai_self_hosted_model, model: :claude_3))
          end

          it 'returns model metadata headers from existing ModelMetadata class' do
            result = service.execute

            expect(result).to have_key('x-gitlab-agent-platform-model-metadata')

            metadata_json = result['x-gitlab-agent-platform-model-metadata']
            metadata = ::Gitlab::Json.parse(metadata_json)
            expect(metadata).to include(
              'provider' => 'openai',
              'name' => feature_setting.self_hosted_model.model
            )
          end
        end

        context 'when feature setting is not ready (disabled provider)' do
          before do
            create(:ai_feature_setting,
              feature: :duo_agent_platform_agentic_chat,
              provider: :disabled,
              self_hosted_model: nil)
          end

          it_behaves_like 'returns empty headers'
        end
      end
    end

    context 'for cloud-connected self-managed instances' do
      let(:root_namespace) { nil }

      context 'with instance model selection setting (priority 1)' do
        let!(:instance_setting) do
          create(:instance_model_selection_feature_setting,
            feature: :duo_agent_platform_agentic_chat,
            offered_model_ref: 'claude-3-7-sonnet-20250219'
          )
        end

        context 'with a model pinned for instance-level model selection' do
          let(:pinned_model_identifier) { 'claude-3-7-sonnet-20250219' }
          let!(:instance_setting) do
            create(:instance_model_selection_feature_setting,
              feature: :duo_agent_platform_agentic_chat,
              offered_model_ref: pinned_model_identifier)
          end

          shared_examples 'uses the pinned instance model' do
            it 'uses the pinned model' do
              result = service.execute

              expect(result).to eq(
                'x-gitlab-agent-platform-model-metadata' => {
                  'provider' => 'gitlab',
                  'feature_setting' => 'duo_agent_platform_agentic_chat',
                  'identifier' => pinned_model_identifier
                }.to_json
              )
            end
          end

          it_behaves_like 'uses the pinned instance model'

          context 'when a valid user_selected_model_identifier is provided' do
            let(:user_selected_model_identifier) { 'claude_sonnet_4_20250514' }

            it_behaves_like 'uses the pinned instance model'
          end

          context 'when an invalid user_selected_model_identifier is provided' do
            let(:user_selected_model_identifier) { 'invalid-model-for-duo-agent-platform' }

            it_behaves_like 'uses the pinned instance model'
          end

          context 'when an empty user_selected_model_identifier is provided' do
            let(:user_selected_model_identifier) { '' }

            it_behaves_like 'uses the pinned instance model'
          end
        end

        context 'with no model pinned for instance-level model selection' do
          let!(:instance_setting) do
            create(:instance_model_selection_feature_setting,
              feature: :duo_agent_platform_agentic_chat,
              offered_model_ref: nil)
          end

          it_behaves_like 'uses the gitlab default model'

          context 'for user model selection' do
            include_context 'with model selections fetch definition service side-effect context'

            before do
              stub_request(:get, fetch_service_endpoint_url)
                .to_return(
                  status: 200,
                  body: model_definitions_response,
                  headers: { 'Content-Type' => 'application/json' }
                )
            end

            context 'when a valid user_selected_model_identifier is provided' do
              let(:user_selected_model_identifier) { 'claude_sonnet_4_20250514' }

              it 'uses the user-selected model' do
                result = service.execute

                expect(result).to include(
                  'x-gitlab-agent-platform-model-metadata' => {
                    'provider' => 'gitlab',
                    'feature_setting' => 'duo_agent_platform_agentic_chat',
                    'identifier' => user_selected_model_identifier
                  }.to_json
                )
              end

              context 'when the response from AI Gateway is not successful' do
                before do
                  stub_request(:get, fetch_service_endpoint_url)
                    .to_return(status: 400)
                end

                it_behaves_like 'uses the gitlab default model'
              end

              context 'when FetchModelDefinitionsService returns nil' do
                before do
                  allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |fetch_service|
                    allow(fetch_service).to receive(:execute).and_return(nil)
                  end
                end

                it_behaves_like 'uses the gitlab default model'
              end

              context 'when setting is nil' do
                before do
                  allow(::Ai::ModelSelection::InstanceModelSelectionFeatureSetting)
                    .to receive(:find_or_initialize_by_feature)
                    .and_return(nil)
                end

                it_behaves_like 'returns empty headers'
              end
            end

            context 'when an invalid user_selected_model_identifier is provided' do
              let(:user_selected_model_identifier) { 'invalid-model-for-duo-agent-platform' }

              it_behaves_like 'uses the gitlab default model'
            end

            context 'when an empty user_selected_model_identifier is provided' do
              let(:user_selected_model_identifier) { '' }

              it_behaves_like 'uses the gitlab default model'
            end
          end
        end
      end

      context 'when instance setting has no model ref' do
        let!(:instance_setting) do
          create(:instance_model_selection_feature_setting,
            feature: :duo_agent_platform_agentic_chat,
            offered_model_ref: nil
          )
        end

        it 'returns model metadata headers for cloud-connected wit gitlab default model' do
          result = service.execute

          expect(result).to eq(
            'x-gitlab-agent-platform-model-metadata' => {
              'provider' => 'gitlab',
              'feature_setting' => 'duo_agent_platform_agentic_chat',
              'identifier' => nil
            }.to_json
          )
        end
      end

      context 'when no instance setting exists' do
        before do
          allow(::Ai::ModelSelection::InstanceModelSelectionFeatureSetting)
            .to receive(:find_or_initialize_by_feature)
            .and_return(nil)
        end

        it_behaves_like 'returns empty headers'
      end
    end

    context 'for GitLab.com instances', :saas_gitlab_com_subscriptions do
      let(:root_namespace) { group }

      context 'for namesapce model selection' do
        context 'with a model pinned for namespace-level model selection' do
          let(:pinned_model_identifier) { 'claude_sonnet_3_7_20250219' }
          let!(:namespace_setting) do
            create(:ai_namespace_feature_setting,
              namespace: group,
              feature: :duo_agent_platform_agentic_chat,
              offered_model_ref: pinned_model_identifier)
          end

          shared_examples 'uses the pinned model' do
            it 'uses the pinned model' do
              result = service.execute

              expect(result).to include(
                'x-gitlab-agent-platform-model-metadata' => {
                  'provider' => 'gitlab',
                  'feature_setting' => 'duo_agent_platform_agentic_chat',
                  'identifier' => pinned_model_identifier
                }.to_json
              )
            end
          end

          it_behaves_like 'uses the pinned model'

          context 'when a valid user_selected_model_identifier is provided' do
            let(:user_selected_model_identifier) { 'claude_sonnet_4_20250514' }

            it_behaves_like 'uses the pinned model'
          end

          context 'when an invalid user_selected_model_identifier is provided' do
            let(:user_selected_model_identifier) { 'invalid-model-for-duo-agent-platform' }

            it_behaves_like 'uses the pinned model'
          end

          context 'when an empty user_selected_model_identifier is provided' do
            let(:user_selected_model_identifier) { '' }

            it_behaves_like 'uses the pinned model'
          end
        end

        context 'with no model is pinned for namespace-level model selection' do
          it_behaves_like 'uses the gitlab default model'

          context 'for user model selection' do
            include_context 'with model selections fetch definition service side-effect context'

            before do
              stub_request(:get, fetch_service_endpoint_url)
                .to_return(
                  status: 200,
                  body: model_definitions_response,
                  headers: { 'Content-Type' => 'application/json' }
                )

              # Stub FeatureSetting.decorate to handle new parameters
              allow(::Gitlab::Graphql::Representation::ModelSelection::FeatureSetting)
                .to receive(:decorate)
                      .and_wrap_original do |_method, settings, **_kwargs|
                # Return decorated settings with selectable_models
                settings.map do |setting|
                  instance_double(
                    Gitlab::Graphql::Representation::ModelSelection::FeatureSetting,
                    feature_setting: setting,
                    selectable_models: [
                      { ref: 'claude_sonnet_3_7_20250219' },
                      { ref: 'claude_sonnet_4_20250514' },
                      { ref: 'claude_sonnet_4_20250514_vertex' }
                    ]
                  )
                end
              end
            end

            context 'when a valid user_selected_model_identifier is provided' do
              let(:user_selected_model_identifier) { 'claude_sonnet_4_20250514' }

              it 'uses the user-selected model' do
                result = service.execute

                expect(result).to include(
                  'x-gitlab-agent-platform-model-metadata' => {
                    'provider' => 'gitlab',
                    'feature_setting' => 'duo_agent_platform_agentic_chat',
                    'identifier' => user_selected_model_identifier
                  }.to_json
                )
              end

              context 'when the response from AI Gateway is not successful' do
                before do
                  stub_request(:get, fetch_service_endpoint_url)
                  .to_return(status: 400)
                end

                it_behaves_like 'uses the gitlab default model'
              end

              context 'when FetchModelDefinitionsService returns nil' do
                before do
                  allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |fetch_service|
                    allow(fetch_service).to receive(:execute).and_return(nil)
                  end
                end

                it_behaves_like 'uses the gitlab default model'
              end

              context 'when setting is nil' do
                before do
                  allow(::Ai::ModelSelection::NamespaceFeatureSetting)
                    .to receive(:find_or_initialize_by_feature)
                    .and_return(nil)
                end

                it_behaves_like 'returns empty headers'
              end
            end

            context 'when an invalid user_selected_model_identifier is provided' do
              let(:user_selected_model_identifier) { 'invalid-model-for-duo-agent-platform' }

              it_behaves_like 'uses the gitlab default model'
            end

            context 'when an empty user_selected_model_identifier is provided' do
              let(:user_selected_model_identifier) { '' }

              it_behaves_like 'uses the gitlab default model'
            end
          end
        end

        context 'without root_namespace provided' do
          let(:root_namespace) { nil }

          it_behaves_like 'returns empty headers'
        end

        context 'when no namespace setting exists' do
          before do
            allow(::Ai::ModelSelection::NamespaceFeatureSetting)
              .to receive(:find_or_initialize_by_feature)
              .and_return(nil)
          end

          it_behaves_like 'returns empty headers'
        end
      end

      context 'for self managed instances' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it_behaves_like 'uses the gitlab default model'
      end
    end
  end

  describe 'feature_name parameter' do
    let(:root_namespace) { group }

    context 'when feature_name is provided' do
      let(:feature_name) { :duo_agent_platform }

      it 'uses the provided feature_name when finding feature settings', :saas do
        expect(::Ai::ModelSelection::NamespaceFeatureSetting)
          .to receive(:find_or_initialize_by_feature)
          .with(group, :duo_agent_platform)
          .and_call_original

        service.execute
      end

      it 'uses the provided feature_name when finding instance feature settings' do
        expect(::Ai::ModelSelection::InstanceModelSelectionFeatureSetting)
          .to receive(:find_or_initialize_by_feature)
          .with(:duo_agent_platform)
          .and_call_original

        service.execute
      end

      it 'uses the provided feature_name when finding self-hosted feature settings' do
        expect(::Ai::FeatureSetting)
          .to receive(:find_by_feature)
          .with(:duo_agent_platform)
          .and_call_original

        service.execute
      end
    end

    context 'when feature_name is nil' do
      let(:feature_name) { nil }

      it 'sets feature_name to nil' do
        expect(service.send(:feature_name)).to be_nil
      end
    end

    context 'when feature_name is different from agentic_chat_feature_name' do
      let(:feature_name) { :duo_chat }
      let(:user_selected_model_identifier) { 'claude_sonnet_3_7_20250219' }

      include_context 'with model selections fetch definition service side-effect context'

      before do
        stub_request(:get, fetch_service_endpoint_url)
          .to_return(
            status: 200,
            body: model_definitions_response,
            headers: { 'Content-Type' => 'application/json' }
          )

        create(:ai_namespace_feature_setting,
          namespace: group,
          feature: :duo_chat,
          offered_model_ref: nil)
      end

      it 'does not consider user selected model even when valid' do
        result = service.execute

        expect(result).to include(
          'x-gitlab-agent-platform-model-metadata' => {
            'provider' => 'gitlab',
            'feature_setting' => 'duo_chat',
            'identifier' => nil
          }.to_json
        )
      end
    end

    context 'when feature_name is agentic_chat_feature_name' do
      let(:feature_name) { ::Ai::ModelSelection::FeaturesConfigurable.agentic_chat_feature_name }
      let(:user_selected_model_identifier) { 'claude_sonnet_4_20250514' }

      include_context 'with model selections fetch definition service side-effect context'

      before do
        stub_request(:get, fetch_service_endpoint_url)
          .to_return(
            status: 200,
            body: model_definitions_response,
            headers: { 'Content-Type' => 'application/json' }
          )

        create(:ai_namespace_feature_setting,
          namespace: group,
          feature: :duo_agent_platform,
          offered_model_ref: nil)
      end

      it 'considers user selected model when valid' do
        result = service.execute

        expect(result).to include(
          'x-gitlab-agent-platform-model-metadata' => {
            'provider' => 'gitlab',
            'feature_setting' => 'duo_agent_platform_agentic_chat',
            'identifier' => user_selected_model_identifier
          }.to_json
        )
      end
    end
  end
end
