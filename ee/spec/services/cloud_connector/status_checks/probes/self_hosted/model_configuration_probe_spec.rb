# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::CloudConnector::StatusChecks::Probes::SelfHosted::ModelConfigurationProbe, feature_category: :"self-hosted_models" do
  let_it_be(:user) { build(:user) }
  let_it_be(:self_hosted_model) { build(:ai_self_hosted_model) }

  subject(:probe) { described_class.new(user, self_hosted_model) }

  before do
    allow(::Gitlab::AiGateway).to receive(:self_hosted_url).and_return('http://localhost:3000')
  end

  describe '#execute' do
    context 'when the user is not present' do
      let(:user) { nil }

      it 'returns a failure result with a user not found message' do
        result = probe.execute

        expect(result.success).to be false
        expect(result.errors.full_messages).to include('User not provided')
      end
    end

    context 'when the Self-hosted model is not present' do
      let(:self_hosted_model) { nil }

      it 'returns a failure result with a user not found message' do
        result = probe.execute

        expect(result.success).to be false
        expect(result.errors.full_messages).to include('Self-hosted model was not provided')
      end
    end

    context 'when the local AI Gateway URL is not configured' do
      before do
        allow(::Gitlab::AiGateway).to receive(:self_hosted_url).and_return(nil)
      end

      it 'returns a failure result with a local AI Gateway URL not configured message' do
        result = probe.execute

        expect(result.success).to be false
        expect(result.errors.full_messages).to include(
          "You have not configured your local AI gateway URL. " \
            "Configure the URL in the GitLab Duo configuration settings."
        )
      end
    end

    context 'when code completion test is successful' do
      before do
        allow_next_instance_of(Gitlab::Llm::AiGateway::SelfHostedModels::ConnectionTester) do |tester|
          allow(tester).to receive(:execute).and_return(nil)
        end
      end

      it 'returns a success result' do
        result = probe.execute

        expect(result.success).to be true
        expect(result.message).to match('Successfully connected to the self-hosted model')
      end
    end

    context 'when code completion test fails' do
      let(:error_message) { 'API error' }

      before do
        allow_next_instance_of(Gitlab::Llm::AiGateway::SelfHostedModels::ConnectionTester) do |tester|
          allow(tester).to receive(:execute).and_return(error_message)
        end
      end

      it 'returns a failure result with the error message' do
        result = probe.execute

        expect(result.success).to be false
        expect(result.message).to match("ERROR: API error")
      end
    end
  end
end
