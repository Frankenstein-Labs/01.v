# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Search::Client, feature_category: :global_search do
  let(:adapter) { ::Search::Elastic::Helper.default.client }

  subject(:client) { described_class.new(adapter: adapter) }

  describe '::AUTHORIZATION_ERRORS' do
    it 'includes all expected Elasticsearch authorization error classes' do
      expect(described_class::AUTHORIZATION_ERRORS).to include(
        ::Elasticsearch::Transport::Transport::Errors::Unauthorized,
        ::Elasticsearch::Transport::Transport::Errors::Forbidden,
        ::Elasticsearch::Transport::Transport::Errors::ProxyAuthenticationRequired
      )
    end

    it 'is frozen' do
      expect(described_class::AUTHORIZATION_ERRORS).to be_frozen
    end
  end

  describe '::TRANSPORT_ERRORS' do
    it 'includes all expected Elasticsearch transport error classes' do
      expect(described_class::TRANSPORT_ERRORS).to include(
        ::Faraday::Error,
        ::Elasticsearch::Transport::Transport::Errors::TooManyRequests,
        ::Elasticsearch::Transport::Transport::Errors::InternalServerError,
        ::Elasticsearch::Transport::Transport::Errors::BadGateway,
        ::Elasticsearch::Transport::Transport::Errors::ServiceUnavailable,
        ::Elasticsearch::Transport::Transport::Errors::HTTPVersionNotSupported
      )
    end

    it 'is frozen' do
      expect(described_class::TRANSPORT_ERRORS).to be_frozen
    end
  end

  describe '::TIMEOUT_ERRORS' do
    it 'includes all expected timeout error classes' do
      expect(described_class::TIMEOUT_ERRORS).to include(
        ::Faraday::TimeoutError,
        ::Faraday::RequestTimeoutError,
        ::Elasticsearch::Transport::Transport::Errors::RequestTimeout,
        ::Elasticsearch::Transport::Transport::Errors::GatewayTimeout
      )
    end

    it 'is frozen' do
      expect(described_class::TIMEOUT_ERRORS).to be_frozen
    end
  end

  describe '::AuthorizationError' do
    let(:error_details) { 'Unauthorized access' }

    subject(:authorization_error) { described_class::AuthorizationError.new(error_details) }

    it 'stores the error details' do
      expect(authorization_error.errors).to eq(error_details)
    end

    it 'returns a user-friendly message' do
      expect(authorization_error.message)
        .to eq('Search authentication failed. Please check your advanced search configuration.')
    end

    it 'is a StandardError' do
      expect(authorization_error).to be_a(StandardError)
    end
  end

  describe '::ConnectionError' do
    let(:error_details) { 'Connection refused' }

    subject(:connection_error) { described_class::ConnectionError.new(error_details) }

    it 'stores the error details' do
      expect(connection_error.errors).to eq(error_details)
    end

    it 'returns a user-friendly message' do
      expect(connection_error.message).to eq('Search is currently unavailable. Please try again later.')
    end

    it 'is a StandardError' do
      expect(connection_error).to be_a(StandardError)
    end
  end

  it 'delegates to adapter', :aggregate_failures do
    described_class::DELEGATED_METHODS.each do |msg|
      expect(client).to respond_to(msg)
      expect(adapter).to receive(msg)
      client.send(msg)
    end
  end

  describe '.execute_search' do
    let(:adapter) { described_class.search_adapter }
    let(:options) { { klass: Project } }
    let(:query) { { foo: 'bar' } }

    it 'calls search with the expected query' do
      expect(adapter).to receive(:search)
        .with(a_hash_including(timeout: '30s', index: Project.index_name, body: { foo: 'bar' })).and_return(true)

      described_class.execute_search(query: query, options: options) do |response|
        expect(response).to be(true)
      end
    end

    context 'when count_only is set to true in options' do
      let(:options) { { klass: Project, count_only: true } }

      it 'calls search with the expected query' do
        expect(adapter).to receive(:search)
          .with(a_hash_including(timeout: '1s', index: Project.index_name, body: { foo: 'bar' })).and_return(true)

        described_class.execute_search(query: query, options: options) do |response|
          expect(response).to be(true)
        end
      end
    end

    context 'when index_name is set to in options' do
      let(:options) { { index_name: 'foo-bar', count_only: true } }

      it 'calls search with the expected query' do
        expect(adapter).to receive(:search)
          .with(a_hash_including(timeout: '1s', index: 'foo-bar', body: { foo: 'bar' })).and_return(true)

        described_class.execute_search(query: query, options: options) do |response|
          expect(response).to be(true)
        end
      end
    end

    context 'when retry_on_failure is set' do
      let(:retry_on_failure) { 3 }

      before do
        stub_application_setting(elasticsearch_retry_on_failure: retry_on_failure)
      end

      it 'calls search with the expected query' do
        expect(adapter).to receive(:search)
          .with(a_hash_including(timeout: '30s', index: Project.index_name, body: { foo: 'bar' })).and_return(true)

        described_class.execute_search(query: query, options: options) do |response|
          expect(response).to be(true)
        end
      end

      it 'has the correct retry_on_failure option' do
        expect(adapter.transport.transport.options[:retry_on_failure]).to eq(retry_on_failure)
      end
    end
  end

  describe '.execute_count' do
    let(:adapter) { described_class.search_adapter }
    let(:options) { { klass: Project } }
    let(:query) { { query: {} } }

    it 'calls count with the expected query' do
      expect(adapter).to receive(:count)
                           .with(a_hash_including(index: Project.index_name, body: query))
                           .and_return(true)

      described_class.execute_count(query: query, options: options) do |response|
        expect(response).to be(true)
      end
    end
  end
end
