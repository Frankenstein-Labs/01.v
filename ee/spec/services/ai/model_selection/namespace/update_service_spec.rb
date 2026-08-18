# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::ModelSelection::Namespace::UpdateService,
  :saas,
  feature_category: :"self-hosted_models" do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let(:offered_model_ref) { 'openai_chatgpt_4o' }
  let(:params) { { offered_model_ref: offered_model_ref } }
  let(:model_definitions) do
    {
      'models' => [
        { 'name' => 'Claude Sonnet 3.5', 'identifier' => 'claude_sonnet_3_5' },
        { 'name' => 'Claude Sonnet 3.7', 'identifier' => 'claude_sonnet_3_7' },
        { 'name' => 'OpenAI Chat GPT 4o', 'identifier' => 'openai_chatgpt_4o' }
      ],
      'unit_primitives' => [
        {
          'feature_setting' => 'code_generations',
          'default_model' => 'claude_sonnet_3_5',
          'selectable_models' => %w[claude_sonnet_3_5 claude_sonnet_3_7 openai_chatgpt_4o],
          'beta_models' => []
        }
      ]
    }
  end

  let(:feature_setting) do
    build(:ai_namespace_feature_setting, feature: :code_generations, namespace: group)
  end

  let(:model_definitions_response) { model_definitions.to_json }

  let(:audit_event) do
    feature = feature_setting.feature
    scope_type = 'Group'
    scope_id = group.id

    {
      name: 'model_selection_feature_changed',
      author: user,
      scope: group,
      target: group,
      message:
      "The LLM #{offered_model_ref} has been selected for the feature #{feature} of #{scope_type} with ID #{scope_id}",
      additional_details: {
        model_ref: offered_model_ref,
        feature: feature
      }
    }
  end

  include_context 'with the model selections fetch definition service as side-effect'

  subject(:service) { described_class.new(feature_setting, user, params) }

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

      context 'when feature setting update is successful' do
        context 'when feature setting is new' do
          it 'returns a success response with the feature setting' do
            expect(feature_setting.persisted?).to be(false)

            response = service.execute
            feature_setting.reload

            expect(response).to be_success
            expect(feature_setting.persisted?).to be(true)
            expect(response.payload.id).to eq(feature_setting.id)
            expect(feature_setting.offered_model_ref).to eq(offered_model_ref)
            expect(feature_setting.offered_model_name).to eq('OpenAI Chat GPT 4o')
          end
        end

        context 'when feature setting is already persisted' do
          let(:feature_setting) do
            create(:ai_namespace_feature_setting, feature: :code_generations)
          end

          it 'returns a success response with the feature setting' do
            expect(feature_setting.offered_model_ref).not_to eq(offered_model_ref)
            expect(feature_setting.offered_model_name).not_to eq('OpenAI Chat GPT 4o')

            response = service.execute
            feature_setting.reload

            expect(response).to be_success
            expect(response.payload.id).to eq(feature_setting.id)
            expect(feature_setting.offered_model_ref).to eq(offered_model_ref)
            expect(feature_setting.offered_model_name).to eq('OpenAI Chat GPT 4o')
          end
        end

        context 'when the inputted model ref is empty' do
          let(:offered_model_ref) { '' }

          it 'returns a success response with the feature setting' do
            expect(feature_setting.offered_model_ref).not_to eq(offered_model_ref)
            expect(feature_setting.offered_model_name).not_to eq('OpenAI Chat GPT 4o')

            response = service.execute
            feature_setting.reload

            expect(response).to be_success
            expect(response.payload.id).to eq(feature_setting.id)
            expect(feature_setting.offered_model_ref).to be_empty
            expect(feature_setting.offered_model_name).to be_empty
          end
        end

        context 'with recorded events' do
          it 'tracks event' do
            expect { service.execute }
              .to trigger_internal_events('update_model_selection_feature')
                    .with(
                      user: user,
                      category: described_class.name,
                      additional_properties: {
                        label: offered_model_ref,
                        property: feature_setting.feature,
                        selection_scope_gid: group.to_global_id.to_s
                      }
                    )
                    .and increment_usage_metrics('counts.count_total_update_model_selection_feature_weekly')
          end

          it 'records an audit event' do
            expect(Gitlab::Audit::Auditor).to receive(:audit).with(audit_event).and_call_original

            service.execute
          end
        end
      end

      context 'when feature setting update fails' do
        let(:offered_model_ref) { 'bad_ref' }
        let(:error_message) { "Offered model ref Selected model '#{offered_model_ref}' is not compatible" }

        it 'returns an error response with the feature setting and error message' do
          response = service.execute

          expect(response).to be_error
          expect(response.payload).to eq(feature_setting)
          expect(response.message).to include(error_message)
        end

        context 'with recorded events' do
          it 'does not record an audit event' do
            expect(Gitlab::Audit::Auditor).not_to receive(:audit)

            service.execute
          end

          it 'does not track the event internally' do
            expect { service.execute }.not_to trigger_internal_events('update_model_selection_feature')
          end
        end
      end

      context 'when selecting a dev-only model' do
        let(:offered_model_ref) { 'gpt_5_2' }
        let(:model_definitions) do
          {
            'models' => [
              { 'name' => 'Claude Sonnet 3.5', 'identifier' => 'claude_sonnet_3_5' },
              { 'name' => 'Claude Sonnet 3.7', 'identifier' => 'claude_sonnet_3_7' },
              { 'name' => 'GPT 5.2', 'identifier' => 'gpt_5_2' }
            ],
            'unit_primitives' => [
              {
                'feature_setting' => 'code_generations',
                'default_model' => 'claude_sonnet_3_5',
                'selectable_models' => %w[claude_sonnet_3_5 claude_sonnet_3_7],
                'beta_models' => [],
                'dev' => {
                  'selectable_models' => %w[gpt_5_2]
                }
              }
            ]
          }
        end

        context 'when user is a GitLab team member' do
          before do
            allow(user).to receive(:gitlab_team_member?).and_return(true)
          end

          it 'returns a success response with the dev-only model' do
            response = service.execute
            feature_setting.reload

            expect(response).to be_success
            expect(feature_setting.offered_model_ref).to eq('gpt_5_2')
            expect(feature_setting.offered_model_name).to eq('GPT 5.2')
          end
        end

        context 'when user is not a GitLab team member' do
          before do
            allow(user).to receive(:gitlab_team_member?).and_return(false)
          end

          it 'returns an error response' do
            response = service.execute

            expect(response).to be_error
            expect(response.message).to include("is not compatible")
          end
        end

        context 'when some unit primitives have no dev config' do
          let(:model_definitions) do
            {
              'models' => [
                { 'name' => 'Claude Sonnet 3.5', 'identifier' => 'claude_sonnet_3_5' },
                { 'name' => 'GPT 5.2', 'identifier' => 'gpt_5_2' }
              ],
              'unit_primitives' => [
                {
                  'feature_setting' => 'code_generations',
                  'default_model' => 'claude_sonnet_3_5',
                  'selectable_models' => %w[claude_sonnet_3_5],
                  'beta_models' => [],
                  'dev' => {
                    'selectable_models' => %w[gpt_5_2]
                  }
                },
                {
                  'feature_setting' => 'review_merge_request',
                  'default_model' => 'claude_sonnet_3_5',
                  'selectable_models' => %w[claude_sonnet_3_5],
                  'beta_models' => []
                }
              ]
            }
          end

          before do
            allow(user).to receive(:gitlab_team_member?).and_return(true)
          end

          it 'skips unit primitives without dev config and merges the rest' do
            response = service.execute
            feature_setting.reload

            expect(response).to be_success
            expect(feature_setting.offered_model_ref).to eq('gpt_5_2')
          end
        end

        context 'when dev config has blank selectable_models' do
          let(:offered_model_ref) { 'claude_sonnet_3_5' }
          let(:model_definitions) do
            {
              'models' => [
                { 'name' => 'Claude Sonnet 3.5', 'identifier' => 'claude_sonnet_3_5' }
              ],
              'unit_primitives' => [
                {
                  'feature_setting' => 'code_generations',
                  'default_model' => 'claude_sonnet_3_5',
                  'selectable_models' => %w[claude_sonnet_3_5],
                  'beta_models' => [],
                  'dev' => {
                    'selectable_models' => []
                  }
                }
              ]
            }
          end

          before do
            allow(user).to receive(:gitlab_team_member?).and_return(true)
          end

          it 'does not modify selectable_models when dev models are blank' do
            response = service.execute
            feature_setting.reload

            expect(response).to be_success
            expect(feature_setting.offered_model_ref).to eq('claude_sonnet_3_5')
          end
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
        response = service.execute

        expect(response).to be_error
        expect(response.message).to eq(error_message)
      end
    end
  end
end
