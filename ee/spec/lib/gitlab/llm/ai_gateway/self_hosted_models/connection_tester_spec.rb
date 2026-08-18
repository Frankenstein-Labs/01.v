# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::SelfHostedModels::ConnectionTester, :with_cloud_connector, feature_category: :"self-hosted_models" do
  let_it_be(:user) { create(:user) }
  let(:self_hosted_model) { build_stubbed(:ai_self_hosted_model, name: 'Test Model') }

  let(:ai_gateway_headers) { { 'header' => 'value' } }
  let(:endpoint) { "#{Gitlab::AiGateway.url}/v1/prompts/model_configuration%2Fcheck" }

  subject(:result) { described_class.new(user, self_hosted_model).execute }

  before do
    allow(Gitlab::AiGateway).to receive(:headers).and_return(ai_gateway_headers)
  end

  context 'when no self-hosted model is provided' do
    subject(:result) { described_class.new(user, nil).execute }

    it { is_expected.to eq('No self-hosted model was provided') }
  end

  context 'when the AI gateway returns 200' do
    before do
      stub_request(:post, endpoint)
        .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
    end

    it { is_expected.to be_nil }
  end

  context 'when the model server returns a 421 Misdirected Request' do
    before do
      stub_request(:post, endpoint).to_return(
        status: 421,
        body: { detail: "401: Unauthorized" }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end

    it { is_expected.to eq("The self-hosted model server returned code 401: Unauthorized") }
  end

  context 'when the model server returns a 421 without an extractable error code' do
    before do
      stub_request(:post, endpoint).to_return(
        status: 421,
        body: 'null',
        headers: { 'Content-Type' => 'application/json' }
      )
    end

    it { is_expected.to eq("The self-hosted model server returned an error") }
  end

  context 'when the AI gateway returns a non-200 with a structured error body' do
    before do
      stub_request(:post, endpoint).to_return(
        status: 401,
        body: { detail: [{ msg: "a specific error" }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end

    it { is_expected.to eq("AI Gateway returned code 401: a specific error") }
  end

  context 'when the AI gateway returns a non-200 with an unparseable body' do
    before do
      stub_request(:post, endpoint).to_return(
        status: 404,
        body: "a string",
        headers: { 'Content-Type' => 'application/json' }
      )
    end

    it 'returns the fallback message' do
      expect(result).to eq(
        "AI Gateway returned code 404: Unknown error. Make sure your self-hosted model is running " \
          "and that your AI Gateway URL is configured correctly."
      )
    end
  end

  context 'when the request raises an error' do
    before do
      stub_request(:post, endpoint).to_raise(StandardError.new('an error'))
    end

    it 'tracks the exception and returns its message' do
      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(StandardError))

      expect(result).to eq('an error')
    end
  end

  [Net::ReadTimeout, Net::OpenTimeout, Errno::ECONNREFUSED, SocketError].each do |raised_error|
    context "when the request fails with #{raised_error}" do
      before do
        stub_request(:post, endpoint).to_raise(raised_error)
      end

      it 'tracks the exception and returns an actionable connection message', :aggregate_failures do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(raised_error))

        expect(result).to eq(
          'AI Gateway could not connect to the model endpoint. Verify the model endpoint URL is correct ' \
            'and reachable from the AI Gateway, and that any firewall or proxy is not blocking the connection.'
        )
      end
    end
  end

  context 'when a custom_openai model identifier is wrongly specified' do
    let(:self_hosted_model) do
      build_stubbed(:ai_self_hosted_model, identifier: 'custom_openai/wrong-model', endpoint: 'http://vllm:8000/v1')
    end

    before do
      stub_request(:post, endpoint).to_return(
        status: 421,
        body: { detail: "404: model not found" }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      stub_request(:get, 'http://vllm:8000/v1/models').to_return(
        status: 200,
        body: { object: 'list', data: [{ id: 'real-model', object: 'model' }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end

    it 'returns the right identifier suggestion instead of the raw model server error' do
      expect(result).to eq('The provided identifier does not exist. Did you mean custom_openai/real-model?')
    end
  end

  context 'when a custom_openai model server fails with a non-404 error' do
    let(:self_hosted_model) do
      build_stubbed(:ai_self_hosted_model, identifier: 'custom_openai/some-model', endpoint: 'http://vllm:8000/v1')
    end

    before do
      stub_request(:post, endpoint).to_return(
        status: 421,
        body: { detail: "500: internal server error" }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end

    it 'returns the model server error without querying the model list', :aggregate_failures do
      expect(result).to eq('The self-hosted model server returned code 500: internal server error')
      expect(a_request(:get, 'http://vllm:8000/v1/models')).not_to have_been_made
    end
  end

  it 'scopes the request to the complete_code unit primitive for the model under test' do
    expect(Gitlab::AiGateway).to receive(:headers) do |args|
      expect(args[:unit_primitive_name]).to eq(:complete_code)
      expect(args[:ai_feature_name]).to eq(:code_suggestions)
      expect(args[:feature_setting].self_hosted_model).to eq(self_hosted_model)
      expect(args[:feature_setting].self_hosted?).to be(true)

      ai_gateway_headers
    end
    stub_request(:post, endpoint).to_return(status: 200, body: '{}')

    result
  end

  it 'sends the model metadata to the AI gateway' do
    stub_request(:post, endpoint).to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })

    result

    expect(a_request(:post, endpoint).with do |req|
      metadata = ::Gitlab::Json.safe_parse(req.body)['model_metadata']
      metadata['name'] == self_hosted_model.model &&
        metadata['endpoint'] == self_hosted_model.endpoint &&
        metadata['provider'] == 'openai'
    end).to have_been_made
  end
end
