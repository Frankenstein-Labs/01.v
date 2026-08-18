# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Completions::MeasureCommentTemperature, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }

  let(:ai_action) { 'measure_comment_temperature' }
  let(:content) { 'This is a test comment' }
  let(:ai_client) { instance_double(Gitlab::Llm::AiGateway::Client) }
  let(:ai_response) { instance_double(HTTParty::Response, body: %("Success"), success?: true) }
  let(:uuid) { SecureRandom.uuid }
  let(:prompt_message) do
    build(:ai_message, :measure_comment_temperature, user: user, content: content, request_id: uuid)
  end

  subject(:completion) { described_class.new(prompt_message, nil, {}).execute }

  RSpec.shared_examples 'comment temperature measurement' do
    it 'executes a completion request and calls the response chains' do
      expect(Gitlab::Llm::AiGateway::Client).to receive(:new).with(
        user,
        unit_primitive_name: :measure_comment_temperature,
        tracking_context: { action: :measure_comment_temperature, request_id: uuid },
        namespace_id: nil,
        project_id: nil,
        governing_namespace_id: nil
      ).and_return(ai_client)
      expect(ai_client).to receive(:complete_prompt).with(
        base_url: Gitlab::AiGateway.url,
        prompt_name: :measure_comment_temperature,
        inputs: { content: content },
        model_metadata: nil,
        prompt_version: "^1.0.0",
        timeout: Gitlab::AiGateway.timeout
      ).and_return(ai_response)

      expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).and_call_original

      expect(completion[:ai_message].content).to eq("Success")
    end

    context 'with an unsuccessful request' do
      let(:ai_response) { instance_double(HTTParty::Response, body: %("Failed"), success?: false) }

      it 'returns an error' do
        expect(Gitlab::Llm::AiGateway::Client).to receive(:new).with(
          user,
          unit_primitive_name: :measure_comment_temperature,
          tracking_context: { action: :measure_comment_temperature, request_id: uuid },
          namespace_id: nil,
          project_id: nil,
          governing_namespace_id: nil
        ).and_return(ai_client)
        expect(ai_client).to receive(:complete_prompt).with(
          base_url: Gitlab::AiGateway.url,
          prompt_name: :measure_comment_temperature,
          inputs: { content: content },
          model_metadata: nil,
          prompt_version: "^1.0.0",
          timeout: Gitlab::AiGateway.timeout
        ).and_return(ai_response)

        expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).and_call_original

        expect(completion[:ai_message].content).to eq({ "detail" => "An unexpected error has occurred." })
      end
    end
  end

  describe "#execute" do
    it_behaves_like 'comment temperature measurement'
  end
end
