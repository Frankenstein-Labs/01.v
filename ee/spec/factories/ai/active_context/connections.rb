# frozen_string_literal: true

FactoryBot.define do
  factory :ai_active_context_connection, class: 'Ai::ActiveContext::Connection' do
    sequence(:name) { |n| "connection_#{n}" }
    adapter_class { 'Ai::ActiveContext::Adapters::BaseAdapter' }
    active { true }
    options { { url: 'https://example.com', token: 'secret' } }
    prefix { ActiveContextHelpers::TEST_INDEX_PREFIX }

    trait :inactive do
      active { false }
    end

    trait :elasticsearch do
      adapter_class { 'ActiveContext::Databases::Elasticsearch::Adapter' }
      options { { url: ENV['ELASTIC_URL'] || 'http://localhost:9200' } }
    end

    # Uses ELASTIC_URL in CI, localhost:9202 for local development.
    # To run tests locally, configure OpenSearch on port 9202.
    # https://gitlab.com/gitlab-org/gitlab-development-kit/-/blob/main/doc/howto/elasticsearch.md#opensearch
    trait :opensearch do
      adapter_class { 'ActiveContext::Databases::Opensearch::Adapter' }
      options { { url: ENV['ELASTIC_URL'] || 'http://localhost:9202' } }
    end

    # Uses the pgvector service in CI and local development.
    # In CI, the pgvector service runs on port 5432.
    # To run tests locally, configure pgvector on port 5432.
    trait :postgresql do
      adapter_class { 'ActiveContext::Databases::Postgresql::Adapter' }
      options { ActiveContextHelpers.pgvector_connection_params }

      after(:create) do |connection|
        adapter = ::ActiveContext::Adapter.for_connection(connection)
        adapter.client.with_connection do |conn|
          conn.execute('CREATE EXTENSION IF NOT EXISTS vector')
        end
      end
    end
  end
end
