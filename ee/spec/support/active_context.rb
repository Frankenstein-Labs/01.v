# frozen_string_literal: true

# Use the following tags to control test behavior:
#
# - :active_context_integration: Include this tag on any test that runs integration tests on vector stores.
#   It handles adapter setup/teardown and index/table cleanup.
#
# - :postgres_adapter: Use this tag for tests that require PostgreSQL with pgvector.
#   Tests will be skipped if PostgreSQL is not available. Disables transactional tests
#   to ensure DDL changes are visible to external processes.
#
# - :elasticsearch_adapter: Use this tag for tests that require Elasticsearch 8.0.0+.
#   Tests will be skipped if Elasticsearch is not available or version is too old.
#
# - :opensearch_adapter: Use this tag for tests that require OpenSearch 2.1.0+.
#   Tests will be skipped if OpenSearch is not available or version is too old.
#
# - :with_active_context_adapter_reset: Use this tag to reset the adapter cache before
#   and after each test. Useful when tests skip and you want to prevent stale adapters
#   from leaking to subsequent tests.

ELASTICSEARCH_MIN_VERSION = '8.0.0'
OPENSEARCH_MIN_VERSION = '2.1.0'

RSpec.configure do |config|
  config.include ActiveContextHelpers, :active_context_integration

  config.before(:each, :postgres_adapter) do
    connection.update!(active: true)
    stub_const('Gitlab::Database::GitlabSchema::IMPLICIT_GITLAB_SCHEMAS',
      Gitlab::Database::GitlabSchema::IMPLICIT_GITLAB_SCHEMAS.merge('gitlab_active_context_test' => :gitlab_shared))
    drop_active_context_postgres_tables!
    run_active_context_migrations!
    # Warm up the adapter now so the connection pool is established with the correct config.
    # Then prevent mid-test resets (triggered by connection after_save callbacks) from
    # discarding the pool, which would cause reconnection failures when use_transactional_tests=false.
    ::ActiveContext::Adapter.current
    allow(::ActiveContext::Adapter).to receive(:reset)
  end

  config.after(:each, :postgres_adapter) do
    connection.update!(active: false)
  end

  config.after(:each, :active_context_integration) do |example|
    next unless ::ActiveContext.adapter.present?

    if example.metadata[:postgres_adapter]
      drop_active_context_postgres_tables!
    else
      delete_active_context_indices!
    end
  end

  config.around(:each, :active_context_integration) do |example|
    ::ActiveContext::Adapter.reset
    skip_if_adapter_mismatch(example)

    unless example.metadata[:postgres_adapter]
      delete_active_context_indices!
      run_active_context_migrations!
    end

    # Disable transactions for postgres so DDL changes are committed and visible to external processes like Go indexer
    self.class.use_transactional_tests = false if example.metadata[:postgres_adapter]

    example.run
  ensure
    self.class.use_transactional_tests = true if example.metadata[:postgres_adapter]
    ::ActiveContext::Adapter.reset
  end

  # Reset adapter cache before and after each example to prevent stale adapters from leaking
  # to subsequent tests or hooks. This is especially important when tests skip
  # (e.g., OpenSearch tests skipping in an Elasticsearch-only CI job), as the
  # after(:all) hook would otherwise use the wrong adapter.
  config.around(:each, :with_active_context_adapter_reset) do |example|
    ::ActiveContext::Adapter.reset
    example.run
  ensure
    ::ActiveContext::Adapter.reset
  end

  private

  # Skip tests if the configured adapter doesn't match the test's expected adapter.
  # CI runs the same test suite against multiple adapters (Elasticsearch 8, Elasticsearch 9,
  # OpenSearch 1, OpenSearch 2, PostgreSQL with pgvector, etc.) by reusing environment variables
  # to point to different services. This means all tests run against whatever adapter is configured
  # in the current CI job, regardless of which adapter they were written for.
  #
  # This method ensures tests only run against their intended adapter by
  # checking the adapter metadata tags and skipping if there's a mismatch.
  def skip_if_adapter_mismatch(example)
    if example.metadata[:postgres_adapter]
      skip_if_not_postgres
    elsif example.metadata[:elasticsearch_adapter]
      skip_if_not_elasticsearch
    elsif example.metadata[:opensearch_adapter]
      skip_if_not_opensearch
    end
  end

  def skip_if_not_elasticsearch
    unless elastic_helper.matching_distribution?(:elasticsearch)
      skip "Elasticsearch test requires Elasticsearch service running"
      return
    end

    # Active Context requires Elasticsearch 8.x+.
    return if elastic_helper.matching_distribution?(:elasticsearch, min_version: ELASTICSEARCH_MIN_VERSION)

    skip "Elasticsearch test requires Elasticsearch #{ELASTICSEARCH_MIN_VERSION}+ service running"
  end

  def skip_if_not_opensearch
    unless elastic_helper.matching_distribution?(:opensearch)
      skip "OpenSearch test requires OpenSearch service running"
      return
    end

    # Active Context requires OpenSearch 2.1.0+ which supports the lucene engine for vector search.
    return if elastic_helper.matching_distribution?(:opensearch, min_version: OPENSEARCH_MIN_VERSION)

    skip "OpenSearch test requires OpenSearch #{OPENSEARCH_MIN_VERSION}+ service running"
  end

  def skip_if_not_postgres
    params = ActiveContextHelpers.pgvector_connection_params.dup
    params[:dbname] = params.delete(:database)
    pg_connection = PG.connect(params)

    pg_connection.exec("CREATE EXTENSION IF NOT EXISTS vector")
  rescue PG::Error, Errno::ECONNREFUSED => e
    skip "PostgreSQL pgvector service is not available: #{e.message}"
  ensure
    pg_connection&.close
  end

  def elastic_helper
    Search::Elastic::Helper.new(client: ActiveContext::Adapter.current.client.client)
  end
end
