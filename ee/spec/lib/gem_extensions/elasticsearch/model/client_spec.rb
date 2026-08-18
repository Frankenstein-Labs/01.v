# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GemExtensions::Elasticsearch::Model::Client, feature_category: :global_search do
  let!(:dummy_class) { Class.new { include GemExtensions::Elasticsearch::Model::Client } }
  let(:instance) { dummy_class.new }
  let(:config) { { url: 'http://localhost:9200' } }
  let(:retry_on_failure) { 3 }
  let(:adapter) { :typhoeus }
  let(:stubbed_client) { double('ElasticsearchClient') } # rubocop: disable RSpec/VerifiedDoubles -- actual client is defined in the gem

  before do
    allow(::Gitlab::CurrentSettings).to receive_messages(
      elasticsearch_config: config,
      elasticsearch_retry_on_failure: retry_on_failure
    )
    allow(::Search::Elastic::Client).to receive_messages(
      adapter: adapter,
      build: stubbed_client
    )
  end

  around do |example|
    clear_cache!
    example.run
    clear_cache!
  end

  describe '#client' do
    it 'returns a general client by default' do
      expect(::Search::Elastic::Client).to receive(:build).with(config)
      instance.client
    end

    it 'returns a search client when :search operation is specified' do
      expect(::Search::Elastic::Client).to receive(:build).with(config.merge(retry_on_failure: retry_on_failure))
      instance.client(:search)
    end

    it 'caches the clients' do
      expect(::Search::Elastic::Client).to receive(:build).twice.and_return(stubbed_client)
      3.times { instance.client }
      3.times { instance.client(:search) }
    end

    it 'creates new clients when config changes' do
      instance.client
      instance.client(:search)

      new_config = { url: 'http://newhost:9200' }
      allow(::Gitlab::CurrentSettings).to receive(:elasticsearch_config).and_return(new_config)

      expect(::Search::Elastic::Client).to receive(:build).with(new_config)
      expect(::Search::Elastic::Client).to receive(:build).with(new_config.merge(retry_on_failure: retry_on_failure))

      instance.client
      instance.client(:search)
    end

    it 'creates new clients when retry_on_failure changes' do
      instance.client
      instance.client(:search)

      new_retry_on_failure = 5
      allow(::Gitlab::CurrentSettings).to receive(:elasticsearch_retry_on_failure).and_return(new_retry_on_failure)

      expect(::Search::Elastic::Client).to receive(:build).with(config)
      expect(::Search::Elastic::Client).to receive(:build).with(config.merge(retry_on_failure: new_retry_on_failure))

      instance.client
      instance.client(:search)
    end

    describe 'retry_on_failure' do
      before do
        allow(::Search::Elastic::Client).to receive(:build).and_call_original
      end

      context 'for general requests' do
        it 'is the default' do
          client = instance.client
          expect(client.transport.transport.options[:retry_on_failure]).to eq(0)
        end
      end

      context 'for search requests' do
        it 'is equal to the application setting' do
          client = instance.client(:search)
          expect(client.transport.transport.options[:retry_on_failure]).to eq(retry_on_failure)
        end
      end
    end
  end

  def clear_cache!
    described_class.cached_client = nil
    described_class.cached_search_client = nil
    described_class.cached_config = nil
    described_class.cached_retry_on_failure = nil
  end
end
