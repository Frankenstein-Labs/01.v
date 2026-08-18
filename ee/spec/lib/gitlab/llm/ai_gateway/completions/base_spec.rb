# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Completions::Base, feature_category: :ai_abstraction_layer do
  let(:user) { build(:user) }
  let(:resource) { build(:issue) }
  let(:ai_action) { 'test_action' }
  let(:prompt_message) { build(:ai_message, ai_action: ai_action, user: user, resource: resource) }
  let(:inputs) { { prompt: "What's your name?" } }
  let(:response) { "I'm Duo" }
  let(:http_response) { instance_double(HTTParty::Response, body: %("#{response}"), success?: true) }
  let(:processed_response) { response }
  let(:response_modifier_class) { Gitlab::Llm::AiGateway::ResponseModifiers::Base }
  let(:response_modifier) { instance_double(Gitlab::Llm::AiGateway::ResponseModifiers::Base) }
  let(:response_service) { instance_double(Gitlab::Llm::GraphqlSubscriptionResponseService) }
  let(:tracking_context) { { action: ai_action, request_id: prompt_message.request_id } }
  let(:client) { instance_double(Gitlab::Llm::AiGateway::Client) }
  let(:response_options) do
    prompt_message.to_h.slice(:request_id, :client_subscription_id, :ai_action)
  end

  let(:subclass) do
    prompt_inputs = inputs

    Class.new(described_class) do
      define_method :inputs do
        prompt_inputs
      end
    end
  end

  subject(:completion) { subclass.new(prompt_message, nil) }

  describe 'required methods' do
    let(:subclass) { Class.new(described_class) }

    it { expect { completion.inputs }.to raise_error(NotImplementedError) }
  end

  describe '#execute' do
    before do
      allow(Gitlab::Llm::AiGateway::Client).to receive(:new)
        .with(user, unit_primitive_name: ai_action.to_sym, tracking_context: tracking_context,
          namespace_id: nil, project_id: nil, governing_namespace_id: nil).and_return(client)
    end

    let(:result) { { status: :success } }

    subject(:execute) { completion.execute }

    shared_examples 'executing successfully' do
      it 'executes the response service and returns its result' do
        if http_response
          expect(client).to receive(:complete_prompt).with(
            base_url: ::Gitlab::AiGateway.url,
            prompt_name: ai_action,
            inputs: inputs,
            prompt_version: "^1.0.0",
            model_metadata: nil,
            timeout: Gitlab::AiGateway.timeout
          ).and_return(http_response)
        end

        expect(response_modifier_class).to receive(:new).with(processed_response)
          .and_return(response_modifier)
        expect(Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new)
          .with(user, resource, response_modifier, options: response_options).and_return(response_service)
        expect(response_service).to receive(:execute).and_return(result)

        is_expected.to be(result)
      end
    end

    it_behaves_like 'executing successfully'

    context 'when the completion is not valid' do
      before do
        subclass.define_method(:valid?) { false }
      end

      it 'returns nil without making a request' do
        expect(client).not_to receive(:complete)

        expect(execute).to be_nil
      end
    end

    context 'when the subclass raises an ArgumentError when gathering inputs' do
      let(:http_response) { nil }
      let(:processed_response) { { 'detail' => 'Something went wrong.' } }

      before do
        subclass.define_method(:inputs) { raise ArgumentError, 'Something went wrong.' }
      end

      # Note: The completion "executes successfully" in that it relays the error to the user via GraphQL, which we check
      # by changing the `let(:processed_response)` in this context
      it_behaves_like 'executing successfully'
    end

    context 'when an unexpected error is raised' do
      let(:processed_response) { { 'detail' => 'An unexpected error has occurred.' } }

      before do
        allow(::Ai::AmazonQ).to receive(:connected?).and_return(false)
        allow(Gitlab::Json).to receive(:parse).and_raise(StandardError)
      end

      it_behaves_like 'executing successfully'
    end

    context 'when the subclass overrides the post_process method' do
      let(:processed_response) { response.upcase }

      before do
        subclass.define_method(:post_process) { |response| response.upcase }
      end

      it_behaves_like 'executing successfully'
    end

    context 'when the subclass overrides the response modifier' do
      let(:response_modifier_class) { Class.new }

      before do
        subclass.const_set(:RESPONSE_MODIFIER, response_modifier_class)
      end

      it_behaves_like 'executing successfully'
    end

    context 'when Amazon Q is connected' do
      before do
        allow(completion).to receive(:prompt_version).and_return('2.0.0')
        allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
      end

      it 'includes model_metadata in the request body, ignores the version' do
        expect(client).to receive(:complete_prompt).with(
          base_url: ::Gitlab::AiGateway.url,
          prompt_name: ai_action,
          inputs: inputs,
          prompt_version: "^1.0.0",
          model_metadata: { name: :amazon_q, provider: :amazon_q, role_arn: nil },
          timeout: Gitlab::AiGateway.timeout
        ).and_return(http_response)

        expect(response_modifier_class).to receive(:new)
          .with(processed_response)
          .and_return(response_modifier)

        expect(Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new)
          .with(user, resource, response_modifier, options: response_options)
          .and_return(response_service)

        expect(response_service).to receive(:execute).and_return(result)

        execute
      end
    end

    context 'when feature setting is present' do
      before do
        allow(completion).to receive(:prompt_version).and_return('2.0.0')
      end

      context 'when feature setting is set to self hosted' do
        let(:ai_action) { :explain_code }

        let!(:feature_setting) do
          create(:ai_feature_setting, feature: :duo_chat_explain_code)
        end

        it 'includes model_metadata in the request body, ignores the version' do
          expect(client).to receive(:complete_prompt).with(
            base_url: ::Gitlab::AiGateway.url,
            prompt_name: ai_action,
            inputs: inputs,
            prompt_version: "^1.0.0",
            model_metadata: {
              provider: :openai,
              name: 'mistral',
              endpoint: 'http://localhost:11434/v1',
              api_key: 'token',
              identifier: 'provider/some-model'
            },
            timeout: Gitlab::AiGateway.timeout
          ).and_return(http_response)

          expect(response_modifier_class).to receive(:new)
            .with(processed_response)
            .and_return(response_modifier)

          expect(Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new)
            .with(user, resource, response_modifier, options: response_options)
            .and_return(response_service)

          expect(response_service).to receive(:execute).and_return(result)

          execute
        end
      end

      context 'when feature setting is set to vendored' do
        let(:ai_action) { :fix_code }

        let!(:feature_setting) do
          create(:ai_feature_setting, feature: :duo_chat_fix_code, provider: :vendored)
        end

        it 'uses the version ignores the version' do
          expect(client).to receive(:complete_prompt).with(
            base_url: ::Gitlab::AiGateway.url,
            prompt_name: ai_action,
            inputs: inputs,
            model_metadata: {
              identifier: nil,
              provider: 'gitlab',
              feature_setting: 'duo_chat_fix_code'
            },
            prompt_version: "2.0.0",
            timeout: Gitlab::AiGateway.timeout
          ).and_return(http_response)

          expect(response_modifier_class).to receive(:new)
            .with(processed_response)
            .and_return(response_modifier)

          expect(Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new)
            .with(user, resource, response_modifier, options: response_options)
            .and_return(response_service)

          expect(response_service).to receive(:execute).and_return(result)

          execute
        end
      end
    end
  end
end
