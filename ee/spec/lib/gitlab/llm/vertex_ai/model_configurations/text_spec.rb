# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::VertexAi::ModelConfigurations::Text, feature_category: :ai_abstraction_layer do
  let_it_be(:host) { 'cloud.gitlab.com' }
  let_it_be(:project) { 'PROJECT' }
  let_it_be(:user) { create(:user) }
  let_it_be(:host_url) { 'https://cloud.gitlab.com/ai' }

  subject(:text) { described_class.new(user: user) }

  before do
    allow(Gitlab::AiGateway).to receive(:url).and_return(host_url)
    stub_application_setting(vertex_ai_host: host)
    stub_application_setting(vertex_ai_project: project)
  end

  describe '#payload' do
    it 'returns default payload' do
      expect(subject.payload('foo')).to eq(
        {
          instances: [
            {
              content: 'foo'
            }
          ],
          parameters: Gitlab::Llm::VertexAi::Configuration.default_payload_parameters
        }
      )
    end
  end

  describe '#url' do
    it 'returns correct url replacing default value' do
      expect(subject.url).to eq(
        'https://cloud.gitlab.com/ai/v1/proxy/vertex-ai/v1/projects/PROJECT/locations/LOCATION/publishers/google/models/text-bison:predict'
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
        maxOutputTokens: Gitlab::Llm::VertexAi::Configuration::DEFAULT_MAX_OUTPUT_TOKENS,
        topK: Gitlab::Llm::VertexAi::Configuration::DEFAULT_TOP_K,
        topP: Gitlab::Llm::VertexAi::Configuration::DEFAULT_TOP_P
      }

      expect(subject.as_json).to eq(attrs)
    end
  end
end
