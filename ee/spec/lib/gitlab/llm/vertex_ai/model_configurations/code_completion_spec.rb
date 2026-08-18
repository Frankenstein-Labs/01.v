# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::VertexAi::ModelConfigurations::CodeCompletion, feature_category: :ai_abstraction_layer do
  let_it_be(:host) { 'cloud.gitlab.com' }
  let_it_be(:project) { 'PROJECT' }
  let_it_be(:host_url) { 'https://cloud.gitlab.com/ai' }
  let_it_be(:user) { create(:user) }

  subject(:code_completion) { described_class.new(user: user) }

  before do
    allow(Gitlab::AiGateway).to receive(:url).and_return(host_url)
    stub_application_setting(vertex_ai_host: host)
    stub_application_setting(vertex_ai_project: project)
  end

  describe '#payload' do
    it 'returns default payload' do
      messages = { content_above_cursor: 'foo', content_below_cursor: 'bar' }

      expect(subject.payload(messages)).to eq(
        {
          instances: [
            {
              content_above_cursor: 'foo',
              content_below_cursor: 'bar'
            }
          ],
          parameters: Gitlab::Llm::VertexAi::Configuration.payload_parameters(
            maxOutputTokens: Gitlab::Llm::VertexAi::ModelConfigurations::CodeCompletion::MAX_OUTPUT_TOKENS
          )
        }
      )
    end
  end

  describe '#url' do
    it 'returns correct url replacing default value' do
      expect(subject.url).to eq(
        'https://cloud.gitlab.com/ai/v1/proxy/vertex-ai/v1/projects/PROJECT/locations/LOCATION/publishers/google/models/code-gecko:predict'
      )
    end
  end

  describe '#as_json' do
    it 'returns serializable attributes' do
      attrs = {
        vertex_ai_host: host,
        vertex_ai_project: project,
        model: described_class::NAME,
        temperature: Gitlab::Llm::VertexAi::Configuration::DEFAULT_TEMPERATURE,
        maxOutputTokens: described_class::MAX_OUTPUT_TOKENS,
        topK: Gitlab::Llm::VertexAi::Configuration::DEFAULT_TOP_K,
        topP: Gitlab::Llm::VertexAi::Configuration::DEFAULT_TOP_P
      }

      expect(subject.as_json).to eq(attrs)
    end
  end
end
