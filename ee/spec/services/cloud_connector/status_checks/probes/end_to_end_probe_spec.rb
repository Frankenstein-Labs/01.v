# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::EndToEndProbe, feature_category: :duo_setting do
  let(:probe) { described_class.new(user) }
  let(:user) { build(:user) }

  describe '#execute' do
    context 'when the user is not present' do
      let(:user) { nil }

      it 'returns a failure result with a user not found message' do
        result = probe.execute

        expect(result.success).to be false
        expect(result.errors.full_messages).to include('User not provided')
      end
    end

    context 'when code completion test is successful' do
      before do
        allow_next_instance_of(Gitlab::Llm::AiGateway::CodeSuggestionsClient) do |client|
          allow(client).to receive(:test_completion).and_return(nil)
        end
      end

      it 'returns a success result' do
        result = probe.execute

        expect(result.success).to be true
        expect(result.message).to match('Authentication with the AI gateway services succeeded')
      end
    end

    context 'when code completion test fails' do
      let(:error_message) { 'API error' }

      before do
        allow_next_instance_of(Gitlab::Llm::AiGateway::CodeSuggestionsClient) do |client|
          allow(client).to receive(:test_completion).and_return(error_message)
        end
      end

      it 'returns a failure result with the error message' do
        result = probe.execute

        expect(result.success).to be false
        expect(result.message).to match("Authentication with the AI gateway services failed: #{error_message}")
      end
    end
  end
end
