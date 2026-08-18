# frozen_string_literal: true

RSpec.shared_context 'with fetch_model_definitions_example' do
  let_it_be(:fetch_model_definitions_example, freeze: false) do
    {
      'models' => [
        {
          'name' => 'Claude Sonnet',
          'identifier' => 'claude-sonnet',
          'provider' => 'Anthropic',
          'description' => 'Fast, cost-effective responses.',
          'cost_indicator' => '$$$'
        },
        {
          'name' => 'GPT-4',
          'identifier' => 'gpt-4',
          'provider' => 'OpenAI',
          'description' => 'For high-volume coding, reasoning, and routine workflows.',
          'cost_indicator' => '$'
        },
        {
          'name' => 'Claude Sonnet 3.7',
          'identifier' => 'claude-sonnet-3-7',
          'provider' => 'Anthropic',
          'description' => 'Fast, cost-effective responses.',
          'deprecation' => { 'deprecation_date' => '2025-10-28', 'removal_version' => '18.8' },
          'cost_indicator' => '$$'
        }
      ],
      'unit_primitives' => [
        {
          'feature_setting' => 'duo_chat',
          'default_model' => 'claude-sonnet',
          'selectable_models' => %w[claude-sonnet gpt-4],
          'beta_models' => []
        },
        {
          'feature_setting' => 'code_completions',
          'default_model' => 'gpt-4',
          'selectable_models' => %w[gpt-4],
          'beta_models' => []
        },
        {
          'feature_setting' => 'review_merge_request',
          'default_model' => 'claude-sonnet',
          'selectable_models' => %w[claude-sonnet claude-sonnet-3-7],
          'beta_models' => []
        }
      ]
    }
  end
end

RSpec.shared_context 'with mocked ::Ai::ModelSelection::FetchModelDefinitionsService' do
  include_context 'with fetch_model_definitions_example'

  let_it_be(:successful_model_definitions_service_response, freeze: false) do
    ServiceResponse.success(payload: fetch_model_definitions_example)
  end

  let_it_be(:error_model_definitions_service_response, freeze: false) do
    ServiceResponse.error(payload: nil, message: 'Something went wrong')
  end

  let(:model_definitions_service_response) { successful_model_definitions_service_response }

  before do
    allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
      allow(service).to receive(:execute).and_return(model_definitions_service_response)
    end
  end
end
