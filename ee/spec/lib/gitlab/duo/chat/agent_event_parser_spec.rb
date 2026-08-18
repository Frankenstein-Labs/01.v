# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Chat::AgentEventParser, feature_category: :duo_chat do
  let(:logger) { instance_double('Gitlab::Llm::Logger') }
  let(:parser) { described_class.new }

  describe '#parse' do
    before do
      allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
    end

    context 'when chunk is valid JSON' do
      it 'returns a correct event' do
        chunk = '{"type": "final_answer_delta", "data": {"text": "Hello"}}'

        ret = parser.parse(chunk)

        expect(ret).to be_a(Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta)
        expect(ret.text).to eq("Hello")
      end

      it 'returns a correct event' do
        chunk = '{"type": "action", "data": {"thought": "I think I need to use issue_reader", ' \
          '"tool": "issue_reader", "tool_input": "#123"}}'

        ret = parser.parse(chunk)

        expect(ret).to be_a(Gitlab::Duo::Chat::AgentEvents::Action)
        expect(ret.thought).to eq("I think I need to use issue_reader")
        expect(ret.tool).to eq("issue_reader")
        expect(ret.tool_input).to eq("#123")
      end

      it 'returns a correct event' do
        chunk = '{"type": "unknown", "data": {"text": "indeterministic response"}}'

        ret = parser.parse(chunk)

        expect(ret).to be_a(Gitlab::Duo::Chat::AgentEvents::Unknown)
        expect(ret.text).to eq("indeterministic response")
      end

      context 'and event type is random_event' do
        let(:chunk) { '{"type": "random_event", "data": {}}' }

        it 'logs an error and returns nil' do
          expect(logger).to receive(:error).with(a_hash_including(
            message: "Failed to find the event class in GitLab-Rails.",
            event_type: "random_event"
          ))
          expect(parser.parse(chunk)).to be_nil
        end
      end
    end

    context 'when chunk is not a String' do
      let(:chunk) { { type: 'action' } }

      it 'logs an error without calling safe_parse' do
        expect(Gitlab::Json).not_to receive(:safe_parse)

        expect(logger).to receive(:warn).with(a_hash_including(
          message: "Failed to parse a chunk from Duo Chat Agent"
        ))

        parser.parse(chunk)
      end
    end

    context 'when chunk is invalid JSON' do
      let(:chunk) { 'invalid json' }

      it 'logs an error' do
        expect(logger).to receive(:warn).with(a_hash_including(
          message: "Failed to parse a chunk from Duo Chat Agent",
          event_json_size: chunk.length
        ))

        parser.parse(chunk)
      end
    end
  end
end
