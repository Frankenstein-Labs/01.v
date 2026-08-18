# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::Identifier, feature_category: :duo_chat do
  let(:context) do
    instance_double(
      Gitlab::Llm::Chain::GitlabContext,
      request_id: '1234',
      container: nil,
      resource: nil,
      current_user: build_stubbed(:user)
    )
  end

  let(:dummy_class) do
    Class.new(described_class) do
      def resource_name
        'project'
      end

      def passed_content(_json)
        "Extracted content"
      end
    end
  end

  subject(:tool) { dummy_class.new(context: context, options: { suggestions: "" }) }

  describe '#perform' do
    context 'when the LLM response contains malformed JSON' do
      let(:invalid_json) { %(```json\n{"ResourceIdentifierType": "url", "ResourceIdentifier": "http://example.com" \n```) }

      it 'rescues JSON::ParserError, adds suggestion, and retries', :aggregate_failures do
        expect(tool).to receive(:request).exactly(described_class::MAX_RETRIES).times.and_return(invalid_json)

        tool.perform

        expect(tool.options[:suggestions]).to include("Observation: JSON has an invalid format. Please retry")
      end
    end

    context 'when the LLM response contains well-formed JSON' do
      let(:valid_json) { %(```json\n{"ResourceIdentifierType": "url", "ResourceIdentifier": "http://example.com"}\n```) }
      let(:resource) { build_stubbed(:project) }

      before do
        allow(tool).to receive(:identify_resource).with('url', 'http://example.com').and_return(resource)
        allow(Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive(:resource)
          .with(resource: resource, user: context.current_user, context: context)
          .and_return(instance_double(Gitlab::Llm::Utils::Authorizer::Response, allowed?: true))
      end

      it 'returns a successful answer' do
        expect(tool).to receive(:request).once.and_return(valid_json)
        expect(context).to receive(:resource=).with(resource)
        answer = tool.perform

        expect(answer).to be_a(Gitlab::Llm::Chain::Answer)
        expect(answer.status).to eq(:ok)
        expect(answer.content).to eq("Extracted content")
      end
    end
  end
end
