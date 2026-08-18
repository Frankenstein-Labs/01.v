# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::ModelSelection::UpdateInstanceAllowlistService, feature_category: :"self-hosted_models" do
  let(:feature) { :duo_agent_platform_agentic_chat }
  let(:enabled) { true }
  let(:model_refs) { %w[claude-3-5-sonnet-20240620] }

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

  include_context 'with the model selections fetch definition service as side-effect'

  subject(:response) do
    described_class.new(feature: feature, enabled: enabled, model_refs: model_refs).execute
  end

  describe '#execute' do
    context 'when fetch model definitions is successful' do
      before do
        stub_request(:get, fetch_service_endpoint_url)
          .to_return(
            status: 200,
            body: model_definitions_response,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      context 'when the allowlist is enabled' do
        it 'creates the instance feature setting with the normalized refs', :aggregate_failures do
          expect { response }.to change { ::Ai::ModelSelection::InstanceModelSelectionFeatureSetting.count }.by(1)

          expect(response).to be_success
          setting = response.payload
          expect(setting.model_allowlist_enabled).to be(true)
          expect(setting.model_allowlist_gitlab_model_refs).to contain_exactly('claude-3-5-sonnet-20240620')
        end

        context 'when an existing setting is present' do
          let_it_be(:existing_setting) do
            create(:instance_model_selection_feature_setting, feature: :duo_agent_platform_agentic_chat,
              offered_model_ref: 'claude-3-7-sonnet-20250219')
          end

          it 'updates it without creating a new row', :aggregate_failures do
            expect { response }.not_to change { ::Ai::ModelSelection::InstanceModelSelectionFeatureSetting.count }

            expect(response).to be_success
            expect(existing_setting.reload.model_allowlist_enabled).to be(true)
            expect(existing_setting.model_allowlist_gitlab_model_refs).to contain_exactly('claude-3-5-sonnet-20240620')
          end
        end

        context 'when the submitted refs include the currently chosen ref' do
          let_it_be(:existing_setting) do
            create(:instance_model_selection_feature_setting, feature: :duo_agent_platform_agentic_chat,
              offered_model_ref: 'claude-3-7-sonnet-20250219')
          end

          let(:model_refs) { %w[claude-3-7-sonnet-20250219 claude-3-5-sonnet-20240620] }

          it 'strips the currently chosen ref before persisting' do
            expect(response).to be_success
            expect(response.payload.model_allowlist_gitlab_model_refs)
              .to contain_exactly('claude-3-5-sonnet-20240620')
          end
        end

        context 'when the submitted refs include a stale ref not in the model definitions' do
          let(:model_refs) { %w[claude-3-5-sonnet-20240620 deprecated_model] }

          it 'drops the stale ref' do
            expect(response).to be_success
            expect(response.payload.model_allowlist_gitlab_model_refs)
              .to contain_exactly('claude-3-5-sonnet-20240620')
          end
        end

        context 'when the submitted refs contain duplicates and blanks' do
          let(:model_refs) { ['claude-3-5-sonnet-20240620', 'claude-3-5-sonnet-20240620', '', nil] }

          it 'compacts and deduplicates' do
            expect(response).to be_success
            expect(response.payload.model_allowlist_gitlab_model_refs)
              .to contain_exactly('claude-3-5-sonnet-20240620')
          end
        end
      end

      context 'when the allowlist is disabled' do
        let(:enabled) { false }
        let(:model_refs) { %w[claude-3-5-sonnet-20240620] }

        context 'when a setting already exists' do
          let_it_be(:existing_setting) do
            create(:instance_model_selection_feature_setting, :with_allowlist,
              feature: :duo_agent_platform_agentic_chat)
          end

          it 'wipes the stored refs and disables the allowlist', :aggregate_failures do
            expect(response).to be_success
            expect(existing_setting.reload.model_allowlist_enabled).to be(false)
            expect(existing_setting.model_allowlist_gitlab_model_refs).to eq([])
          end
        end

        context 'when a setting does not already exist' do
          it 'creates a disabled setting with empty refs', :aggregate_failures do
            expect { response }.to change { ::Ai::ModelSelection::InstanceModelSelectionFeatureSetting.count }.by(1)

            expect(response).to be_success
            setting = response.payload
            expect(setting.model_allowlist_enabled).to be(false)
            expect(setting.model_allowlist_gitlab_model_refs).to eq([])
          end
        end
      end

      context 'when the model update fails' do
        let(:setting) do
          build(:instance_model_selection_feature_setting, feature: :duo_agent_platform_agentic_chat)
        end

        before do
          allow(::Ai::ModelSelection::InstanceModelSelectionFeatureSetting)
            .to receive(:find_or_initialize_by_feature)
            .with(feature)
            .and_return(setting)
          allow(setting).to receive(:update).and_return(false)
          allow(setting.errors).to receive(:full_messages).and_return(['Model allowlist refs are invalid'])
        end

        it 'returns an error response with the feature setting and error message', :aggregate_failures do
          expect(response).to be_error
          expect(response.payload).to eq(setting)
          expect(response.message).to eq('Model allowlist refs are invalid')
        end
      end

      context 'when the feature does not support allowlists' do
        let(:feature) { :code_generations }

        it 'returns an error without fetching model definitions', :aggregate_failures do
          expect(::Ai::ModelSelection::FetchModelDefinitionsService).not_to receive(:new)

          expect(response).to be_error
          expect(response.message).to include("Model allowlists are not supported for the feature 'code_generations'")
        end
      end
    end

    context 'when fetch model definitions fails' do
      let(:error_message) { 'Received error 401 from AI gateway when fetching model definitions' }

      before do
        stub_request(:get, fetch_service_endpoint_url)
          .to_return(
            status: 401,
            body: "{\"error\":\"No authorization header presented\"}",
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns an error response with the error message' do
        expect(response).to be_error
        expect(response.message).to eq(error_message)
      end
    end
  end
end
