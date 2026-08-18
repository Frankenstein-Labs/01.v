# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::SelfHostedModels::IdentifierSuggester, feature_category: :"self-hosted_models" do
  let(:endpoint) { 'http://vllm.example.com:8000/v1' }
  let(:identifier) { 'custom_openai/wrong-model' }
  let(:api_token) { 'token' }
  let(:self_hosted_model) do
    build_stubbed(:ai_self_hosted_model, endpoint: endpoint, identifier: identifier, api_token: api_token)
  end

  let(:models_url) { 'http://vllm.example.com:8000/v1/models' }

  subject(:message) { described_class.new(self_hosted_model).suggestion_message }

  def stub_models(ids:, status: 200)
    stub_request(:get, models_url).to_return(
      status: status,
      body: { object: 'list', data: ids.map { |id| { id: id, object: 'model' } } }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  context 'when the model is not eligible for a suggestion' do
    context 'when there is no self-hosted model' do
      let(:self_hosted_model) { nil }

      it { is_expected.to be_nil }
    end

    context 'when the identifier is not a custom_openai identifier' do
      let(:identifier) { 'provider/some-model' }

      it 'returns nil without querying the model server' do
        expect(message).to be_nil
        expect(a_request(:get, models_url)).not_to have_been_made
      end
    end

    context 'when the identifier is blank' do
      let(:identifier) { '' }

      it 'returns nil without querying the model server' do
        expect(message).to be_nil
        expect(a_request(:get, models_url)).not_to have_been_made
      end
    end

    context 'when the endpoint is blank' do
      let(:endpoint) { '' }

      it { is_expected.to be_nil }
    end
  end

  context 'when the model server cannot provide a usable model list' do
    context 'when the model server is unreachable' do
      before do
        stub_request(:get, models_url).to_raise(Errno::ECONNREFUSED)
      end

      it { is_expected.to be_nil }
    end

    context 'when the model server returns a non-200 response' do
      before do
        stub_models(ids: %w[real-model], status: 500)
      end

      it { is_expected.to be_nil }
    end

    context 'when the response has no model list' do
      before do
        stub_request(:get, models_url).to_return(
          status: 200, body: {}.to_json, headers: { 'Content-Type' => 'application/json' }
        )
      end

      it { is_expected.to be_nil }
    end
  end

  context 'when the configured identifier already exists on the model server' do
    before do
      stub_models(ids: %w[wrong-model other-model])
    end

    it { is_expected.to be_nil }
  end

  context 'when the configured identifier does not exist on the model server' do
    using RSpec::Parameterized::TableSyntax

    where(:served_ids, :suggestions) do
      %w[real-model]                  | 'custom_openai/real-model'
      %w[model-a model-b]             | 'custom_openai/model-a or custom_openai/model-b'
      %w[model-a model-b model-c]     | 'custom_openai/model-a, custom_openai/model-b or custom_openai/model-c'
    end

    with_them do
      before do
        stub_models(ids: served_ids)
      end

      it 'suggests the identifiers served by the model server' do
        expect(message).to eq("The provided identifier does not exist. Did you mean #{suggestions}?")
      end
    end

    context 'when the model server serves more than five models' do
      before do
        stub_models(ids: %w[a b c d e f g])
      end

      it 'caps the suggestions at five and reports the remaining count' do
        expect(message).to eq(
          'The provided identifier does not exist. Did you mean custom_openai/a, custom_openai/b, ' \
            'custom_openai/c, custom_openai/d, custom_openai/e or 2 more?'
        )
      end
    end
  end

  describe 'authorization header' do
    before do
      stub_models(ids: %w[real-model])
    end

    context 'when the model has an API token' do
      it 'sends a bearer authorization header' do
        message

        expect(
          a_request(:get, models_url).with(headers: { 'Authorization' => 'Bearer token' })
        ).to have_been_made
      end
    end

    context 'when the model has no API token' do
      let(:api_token) { nil }

      it 'does not send an authorization header' do
        message

        expect(
          a_request(:get, models_url) { |req| !req.headers.key?('Authorization') }
        ).to have_been_made
      end
    end
  end
end
