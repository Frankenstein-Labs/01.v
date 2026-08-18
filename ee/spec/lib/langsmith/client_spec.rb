# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Langsmith::Client, :aggregate_failures, feature_category: :ai_evaluation do
  subject(:client) { described_class.new }

  let(:enabled) { true }
  let(:endpoint) { 'https://api.smith.langchain.com' }
  let(:api_key) { 'secret' }
  let(:project_name) { 'default' }

  before do
    stub_env('LANGCHAIN_TRACING_V2', enabled.to_s)
    stub_env('LANGCHAIN_ENDPOINT', endpoint)
    stub_env('LANGCHAIN_API_KEY', api_key)
    stub_env('LANGCHAIN_PROJECT', project_name)
  end

  describe '#post_run' do
    subject(:post_run) { client.post_run(**params) }

    let(:base_params) do
      {
        run_id: '123',
        name: 'Request to LLM',
        run_type: 'llm',
        inputs: { prompt: "hello" }
      }
    end

    let(:url) { "#{endpoint}/runs" }
    let(:params) { base_params }

    let(:expected_body) do
      {
        id: '123',
        name: 'Request to LLM',
        run_type: 'llm',
        inputs: { prompt: "hello" },
        start_time: client.send(:current_time),
        session_name: project_name,
        tags: [],
        extra: {}
      }
    end

    before do
      WebMock.stub_request(:post, url)
    end

    it 'successfully creates a new run', :freeze_time do
      expect(Gitlab::HTTP).to receive(:post).with(
        url,
        headers: { "x-api-key": api_key },
        body: expected_body.to_json
      )

      post_run
    end

    context 'with parent_id' do
      let(:params) { base_params.merge({ parent_id: '345' }) }

      it 'successfully creates a new run', :freeze_time do
        expect(Gitlab::HTTP).to receive(:post).with(
          url,
          headers: { "x-api-key": api_key },
          body: expected_body.merge(parent_run_id: '345').to_json
        )

        post_run
      end
    end

    context 'with tags' do
      let(:params) { base_params.merge({ tags: %w[label1 label2] }) }

      it 'successfully creates a new run', :freeze_time do
        expect(Gitlab::HTTP).to receive(:post).with(
          url,
          headers: { "x-api-key": api_key },
          body: expected_body.merge(tags: %w[label1 label2]).to_json
        )

        post_run
      end
    end

    context 'with extra' do
      let(:params) { base_params.merge(extra: { metadata: { correlation_id: 'abc' } }) }

      it 'successfully creates a new run', :freeze_time do
        expect(Gitlab::HTTP).to receive(:post).with(
          url,
          headers: { "x-api-key": api_key },
          body: expected_body.merge(extra: { metadata: { correlation_id: 'abc' } }).to_json
        )

        post_run
      end
    end
  end

  describe '#patch_run' do
    subject(:patch_run) { client.patch_run(**params) }

    let(:run_id) { '123' }
    let(:url) { "#{endpoint}/runs/#{run_id}" }

    let(:base_params) do
      {
        run_id: run_id,
        outputs: { response: "I'm good!" }
      }
    end

    let(:params) { base_params }

    let(:expected_body) do
      {
        outputs: { response: "I'm good!" },
        end_time: client.send(:current_time),
        error: '',
        events: []
      }
    end

    before do
      WebMock.stub_request(:patch, url)
    end

    it 'successfully patches the run', :freeze_time do
      expect(Gitlab::HTTP).to receive(:patch).with(
        url,
        headers: { "x-api-key": api_key },
        body: expected_body.to_json
      )

      patch_run
    end

    context 'with events' do
      let(:params) { base_params.merge(events: %w[a b c]) }

      it 'successfully creates a new run', :freeze_time do
        expect(Gitlab::HTTP).to receive(:patch).with(
          url,
          headers: { "x-api-key": api_key },
          body: expected_body.merge(events: %w[a b c]).to_json
        )

        patch_run
      end
    end

    context 'with error' do
      let(:params) { base_params.merge(error: 'something went wrong') }

      it 'successfully creates a new run', :freeze_time do
        expect(Gitlab::HTTP).to receive(:patch).with(
          url,
          headers: { "x-api-key": api_key },
          body: expected_body.merge(error: 'something went wrong').to_json
        )

        patch_run
      end
    end
  end

  describe '#enabled?' do
    it { expect(described_class).to be_enabled }

    context 'when disabled' do
      let(:enabled) { false }

      it { expect(described_class).not_to be_enabled }
    end
  end
end
