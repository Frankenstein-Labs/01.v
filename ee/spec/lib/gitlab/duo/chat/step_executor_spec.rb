# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Style/StringConcatenation -- To distinguish new line as the delimiter and new line as tokens
RSpec.describe Gitlab::Duo::Chat::StepExecutor, feature_category: :duo_chat do
  let(:user) { create(:user) }
  let(:agent) { described_class.new(user, feature_setting) }
  let(:self_hosted_url) { nil }
  let(:cloud_connector_url) { 'https://staging.cloud.gitlab.com' }

  shared_examples_for '#step' do
    let(:params) do
      {
        prompt: "Hello",
        options: { chat_history: "" }
      }
    end

    let(:response) { instance_double(HTTParty::Response, headers: {}) }
    let(:expected_http_options) do
      hash_including(headers: {}, body: anything, timeout: 60, allow_local_requests: true, stream_body: true)
    end

    before do
      allow(response).to receive(:success?).and_return(true)
      allow(response).to receive(:code).and_return(200)
      allow(Gitlab::AiGateway).to receive_messages(
        self_hosted_url: self_hosted_url,
        cloud_connector_url: cloud_connector_url,
        headers: {}
      )
    end

    context 'when final answer delta events' do
      before do
        allow(Gitlab::HTTP).to receive(:post).with(
          expected_url,
          expected_http_options
        ).and_yield(
          '{"type": "final_answer_delta", "data": {"text": "Hi"}}' + described_class::EVENT_DELIMITER
        ).and_yield(
          '{"type": "final_answer_delta", "data": {"text": "I am good", "finish_reason": "stop"}}' \
            + described_class::EVENT_DELIMITER
        ).and_return(response)
      end

      it 'streams events' do
        events = agent.step(params)

        expect(events.count).to eq(2)
        expect(events.first).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta)
        expect(events.first.text).to eq('Hi')
        expect(events.last).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta)
        expect(events.last.text).to eq('I am good')
      end
    end

    context 'when tool action event' do
      before do
        allow(Gitlab::HTTP).to receive(:post).with(
          expected_url,
          expected_http_options
        ).and_yield(
          '{"type": "action", "data": {"thought": "I think I need to use issue_reader", ' \
            '"tool": "issue_reader", "tool_input": "#123"}}' + described_class::EVENT_DELIMITER
        ).and_return(response)
      end

      it 'streams events' do
        events = agent.step(params)

        expect(events.count).to eq(1)
        expect(events.first).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::Action)
        expect(events.first.thought).to eq('I think I need to use issue_reader')
        expect(events.first.tool).to eq('issue_reader')
        expect(events.first.tool_input).to eq('#123')
      end

      it 'step multiple times' do
        agent.step(params)

        expect(agent.agent_steps).to eq([
          {
            action:
              { thought: 'I think I need to use issue_reader',
                tool: 'issue_reader',
                tool_input: '#123' }
          }
        ])

        agent.update_observation('Issue #123 is about deep learning models.')

        expect(agent.agent_steps).to eq([
          {
            action:
              { thought: 'I think I need to use issue_reader',
                tool: 'issue_reader',
                tool_input: '#123' },
            observation: 'Issue #123 is about deep learning models.'
          }
        ])

        agent.step(params)
      end
    end

    context 'when unknown event' do
      before do
        allow(Gitlab::HTTP).to receive(:post).with(
          expected_url,
          expected_http_options
        ).and_yield(
          '{"type": "unknown", "data": {"text": "indeterministic response"}}' + described_class::EVENT_DELIMITER
        ).and_return(response)
      end

      it 'streams events' do
        events = agent.step(params)

        expect(events.count).to eq(1)
        expect(events.first).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::Unknown)
        expect(events.first.text).to eq('indeterministic response')
      end
    end

    context 'when data size of unknown event exceeds buffer size of Gitlab::HTTP' do
      before do
        allow(Gitlab::HTTP).to receive(:post).with(
          expected_url,
          expected_http_options
        ).and_yield(
          '{"type": "unknown",'
        ).and_yield(
          '"data": {"text": "indeterministic response"}}' + described_class::EVENT_DELIMITER
        ).and_return(response)
      end

      it 'streams events' do
        events = agent.step(params)

        expect(events.count).to eq(1)
        expect(events.first).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::Unknown)
        expect(events.first.text).to eq('indeterministic response')
      end
    end

    context 'when multiple events exist in a single chunk' do
      before do
        allow(Gitlab::HTTP).to receive(:post).with(
          expected_url,
          expected_http_options
        ).and_yield(
          <<~CHUNK
            {"type": "final_answer_delta", "data": {"text": "Hi"}}
            {"type": "final_answer_delta", "data": {"text": "I am good", "finish_reason": "stop"}}

          CHUNK
        ).and_return(response)
      end

      it 'streams events' do
        events = agent.step(params)

        expect(events.count).to eq(2)
        expect(events.first).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta)
        expect(events.first.text).to eq('Hi')
        expect(events.last).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta)
        expect(events.last.text).to eq('I am good')
      end
    end

    context 'when multiple events are spread in multiple chunks' do
      before do
        allow(Gitlab::HTTP).to receive(:post).with(
          expected_url,
          expected_http_options
        ).and_yield(
          '{"type": "final_answer_delta", "data": {"text": "Hi"}}' + described_class::EVENT_DELIMITER +
            '{"type": "final_answer_delta"'
        ).and_yield(
          ', "data": {"text": "I am good", "finish_reason": "stop"}}' + described_class::EVENT_DELIMITER
        ).and_return(response)
      end

      it 'streams events' do
        events = agent.step(params)

        expect(events.count).to eq(2)
        expect(events.first).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta)
        expect(events.first.text).to eq('Hi')
        expect(events.last).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta)
        expect(events.last.text).to eq('I am good')
      end
    end

    context 'when new lines included in final answer delta data' do
      before do
        allow(Gitlab::HTTP).to receive(:post).with(
          expected_url,
          expected_http_options
        ).and_yield(
          '{"type": "final_answer_delta", "data": {"text": "\n\n```toml", "finish_reason": "stop"}}' \
            + described_class::EVENT_DELIMITER
        ).and_return(response)
      end

      it 'streams events' do
        events = agent.step(params)

        expect(events.count).to eq(1)
        expect(events.first).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta)
        expect(events.first.text).to eq("\n\n```toml")
      end
    end

    context 'when got forbidden response' do
      before do
        allow(response).to receive(:success?).and_return(false)
        allow(response).to receive(:forbidden?).and_return(true)
        allow(Gitlab::HTTP).to receive(:post).with(
          expected_url,
          expected_http_options
        ).and_return(response)
      end

      it 'raises error' do
        expect { agent.step(params) }.to raise_error(Gitlab::AiGateway::ForbiddenError)
      end
    end

    context 'when got 4xx response' do
      before do
        allow(response).to receive(:success?).and_return(false)
        allow(response).to receive(:forbidden?).and_return(false)
        allow(response).to receive(:code).and_return(400)
        allow(Gitlab::HTTP).to receive(:post).with(
          expected_url,
          expected_http_options
        ).and_return(response)
      end

      it 'raises error' do
        expect { agent.step(params) }.to raise_error(Gitlab::AiGateway::ClientError)
      end
    end

    context 'when got 5xx response' do
      before do
        allow(response).to receive(:success?).and_return(false)
        allow(response).to receive(:forbidden?).and_return(false)
        allow(response).to receive(:code).and_return(500)
        allow(Gitlab::HTTP).to receive(:post).with(
          expected_url,
          expected_http_options
        ).and_return(response)
      end

      it 'raises error' do
        expect { agent.step(params) }.to raise_error(Gitlab::AiGateway::ServerError)
      end
    end

    context 'when the other error case' do
      before do
        allow(response).to receive(:success?).and_return(false)
        allow(response).to receive(:forbidden?).and_return(false)
        allow(response).to receive(:code).and_return(0)
        allow(Gitlab::HTTP).to receive(:post).with(
          expected_url,
          expected_http_options
        ).and_return(response)
      end

      it 'raises error' do
        expect { agent.step(params) }.to raise_error(described_class::ConnectionError)
      end
    end

    context 'when governing_namespace is set' do
      let_it_be(:group) { create(:group) }

      before do
        allow(user).to receive(:governing_namespace).and_return(group)
        allow(Gitlab::HTTP).to receive(:post).with(expected_url, anything)
          .and_yield('{"type": "final_answer_delta", "data": {"text": "Hi"}}' + described_class::EVENT_DELIMITER)
          .and_return(response)
      end

      it 'passes non-nil organization_id to headers' do
        expect(Gitlab::AiGateway).to receive(:headers).with(
          hash_including(organization_id: group.organization_id)
        ).and_return({})

        agent.step(params)
      end
    end

    context 'when governing_namespace is not set' do
      before do
        allow(user).to receive(:governing_namespace).and_return(nil)
        allow(Gitlab::HTTP).to receive(:post).with(expected_url, anything)
          .and_yield('{"type": "final_answer_delta", "data": {"text": "Hi"}}' + described_class::EVENT_DELIMITER)
          .and_return(response)
      end

      it 'passes nil organization_id to headers' do
        expect(Gitlab::AiGateway).to receive(:headers).with(
          hash_including(organization_id: nil)
        ).and_return({})

        agent.step(params)
      end
    end

    context 'when namespace_id, project_id, and governing_namespace_id are provided' do
      let(:agent) do
        described_class.new(user, feature_setting, namespace_id: 10, project_id: 20, governing_namespace_id: 30)
      end

      before do
        allow(Gitlab::HTTP).to receive(:post).with(expected_url, anything)
          .and_yield('{"type": "final_answer_delta", "data": {"text": "Hi"}}' + described_class::EVENT_DELIMITER)
          .and_return(response)
      end

      it 'forwards them to Gitlab::AiGateway.headers' do
        expect(Gitlab::AiGateway).to receive(:headers).with(
          hash_including(namespace_id: 10, project_id: 20, governing_namespace_id: 30)
        ).and_return({})

        agent.step(params)
      end
    end
  end

  describe '#step' do
    context 'when is_duo_code_review is false (default)' do
      let(:agent) { described_class.new(user, nil) }

      it 'uses duo_classic_chat unit primitive' do
        expect(Gitlab::AiGateway).to receive(:headers).with(
          hash_including(unit_primitive_name: :duo_classic_chat)
        ).and_return({})

        allow(Gitlab::HTTP).to receive(:post).and_return(
          instance_double(HTTParty::Response, headers: {}, success?: true, code: 200)
        )

        agent.step({})
      end
    end

    context 'when is_duo_code_review is true' do
      let(:agent) { described_class.new(user, nil, is_duo_code_review: true) }

      it 'uses duo_chat unit primitive' do
        expect(Gitlab::AiGateway).to receive(:headers).with(
          hash_including(unit_primitive_name: :duo_chat)
        ).and_return({})

        allow(Gitlab::HTTP).to receive(:post).and_return(
          instance_double(HTTParty::Response, headers: {}, success?: true, code: 200)
        )

        agent.step({})
      end
    end

    context 'when there is no feature setting' do
      context 'when self-hosted AI Gateway url is set up' do
        it_behaves_like '#step' do
          let(:feature_setting) { nil }
          let(:self_hosted_url) { 'http://local-aigw:5052' }
          let(:expected_url) { "#{self_hosted_url}/v2/chat/agent" }
        end
      end

      context 'when self-hosted AI Gateway url is not set up' do
        it_behaves_like '#step' do
          let(:feature_setting) { nil }
          let(:expected_url) { "#{cloud_connector_url}/v2/chat/agent" }
        end
      end
    end

    context 'when duo is self-hosted' do
      it_behaves_like '#step' do
        let(:feature_setting) { create(:ai_feature_setting, feature: :duo_chat) }
        let(:self_hosted_url) { 'http://local-aigw:5052' }
        let(:expected_url) { "#{self_hosted_url}/v2/chat/agent" }
      end
    end

    context 'when duo is vendored' do
      it_behaves_like '#step' do
        let(:feature_setting) { create(:ai_feature_setting, feature: :duo_chat, provider: :vendored) }
        let(:self_hosted_url) { 'http://local-aigw:5052' }
        let(:expected_url) { "#{cloud_connector_url}/v2/chat/agent" }
      end
    end

    describe 'cut-off warning' do
      let(:feature_setting) { nil }
      let(:agent) { described_class.new(user, feature_setting) }
      let(:params) { { prompt: "Hello", options: { chat_history: "" } } }
      let(:response) { instance_double(HTTParty::Response, headers: {}, success?: true, code: 200) }
      let(:flag_enabled) { true }
      let(:finish_reason) { nil }
      let(:event_data) { { "text" => "Hi", "finish_reason" => finish_reason }.compact }
      let(:event_json) do
        { "type" => "final_answer_delta", "data" => event_data }.to_json + described_class::EVENT_DELIMITER
      end

      before do
        stub_feature_flags(duo_non_agentic_chat_ai_message_cut_off_warning: flag_enabled)
        allow(Gitlab::AiGateway).to receive_messages(
          self_hosted_url: nil, cloud_connector_url: cloud_connector_url, headers: {}
        )
        allow(Gitlab::HTTP).to receive(:post).and_yield(event_json).and_return(response)
      end

      shared_examples 'does not append the cut-off warning' do
        it 'does not append the cut-off warning event' do
          events = agent.step(params)

          expect(events.last.try(:text)).not_to eq(described_class::CUT_OFF_WARNING)
        end
      end

      context 'when the last final answer delta has no finish_reason' do
        it 'appends the network cut-off warning event to the events array' do
          events = agent.step(params)

          expect(events.last).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta)
          expect(events.last.text).to eq(described_class::CUT_OFF_WARNING)
        end

        it 'yields the cut-off warning event to the block' do
          yielded = []
          agent.step(params) { |event| yielded << event }

          expect(yielded.last).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta)
          expect(yielded.last.text).to eq(described_class::CUT_OFF_WARNING)
        end

        it 'logs an error' do
          expect(agent).to receive(:log_error).with(
            hash_including(message: "Final answer streaming wasn't completed.")
          )

          agent.step(params)
        end
      end

      context 'when the feature flag is disabled' do
        let(:flag_enabled) { false }

        it_behaves_like 'does not append the cut-off warning'
      end

      context "when the last final answer delta has finish_reason 'stop'" do
        let(:finish_reason) { 'stop' }

        it_behaves_like 'does not append the cut-off warning'
      end

      described_class::MAX_TOKENS_FINISH_REASONS.each do |reason|
        context "when the last final answer delta has finish_reason '#{reason}'" do
          let(:finish_reason) { reason }

          it 'appends the max-tokens warning event to the events array' do
            events = agent.step(params)

            expect(events.last).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta)
            expect(events.last.text).to eq(described_class::MAX_TOKENS_WARNING)
          end

          it 'yields the max-tokens warning event to the block' do
            yielded = []
            agent.step(params) { |event| yielded << event }

            expect(yielded.last).to be_instance_of(Gitlab::Duo::Chat::AgentEvents::FinalAnswerDelta)
            expect(yielded.last.text).to eq(described_class::MAX_TOKENS_WARNING)
          end

          it 'logs an error' do
            expect(agent).to receive(:log_error).with(
              hash_including(message: "Final answer streaming wasn't completed.")
            )

            agent.step(params)
          end
        end
      end

      context 'when the last event is a tool action' do
        let(:event_json) do
          '{"type": "action", "data": {"thought": "x", "tool": "issue_reader", "tool_input": "#123"}}' \
            + described_class::EVENT_DELIMITER
        end

        it_behaves_like 'does not append the cut-off warning'
      end

      context 'when the last event is an unknown event' do
        let(:event_json) do
          '{"type": "unknown", "data": {"text": "indeterministic response"}}' + described_class::EVENT_DELIMITER
        end

        it_behaves_like 'does not append the cut-off warning'
      end

      context 'when no events are received' do
        let(:event_json) { '' }

        it_behaves_like 'does not append the cut-off warning'
      end
    end
  end
end
# rubocop:enable Style/StringConcatenation
