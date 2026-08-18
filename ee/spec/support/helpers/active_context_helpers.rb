# frozen_string_literal: true

module ActiveContextHelpers
  TEST_INDEX_PREFIX = 'gitlab_active_context_test'
  PGVECTOR_DEFAULTS = {
    host: '127.0.0.1',
    port: 5432,
    database: 'postgres',
    user: 'postgres',
    password: 'password'
  }.freeze

  module_function

  def pgvector_connection_params
    defaults = PGVECTOR_DEFAULTS
    {
      host: ENV['PGVECTOR_HOST'] || defaults[:host],
      port: (ENV['PGVECTOR_PORT'] || defaults[:port]).to_i,
      database: ENV['PGVECTOR_DATABASE'] || defaults[:database],
      user: ENV['PGVECTOR_USER'] || defaults[:user],
      password: ENV['PGVECTOR_PASSWORD'] || defaults[:password]
    }
  end

  def code_collection_name
    "#{TEST_INDEX_PREFIX}_code"
  end

  def run_active_context_migrations!
    dictionary = ActiveContext::Migration::Dictionary.instance

    dictionary.migrations.each do |migration_class|
      migration_instance = migration_class.new
      next if migration_instance.skip?

      migration_instance.migrate!
    end
  end

  def delete_active_context_indices!
    active_context_indices.each do |index_name|
      active_context_client.indices.delete(index: index_name)
    end
  end

  def refresh_active_context_indices!
    return if postgres_adapter?

    active_context_client.indices.refresh(index: "#{TEST_INDEX_PREFIX}_*")
  end

  def postgres_adapter?(adapter = ActiveContext.adapter)
    adapter.is_a?(ActiveContext::Databases::Postgresql::Adapter)
  end

  def drop_active_context_postgres_tables!(adapter = ActiveContext.adapter)
    return unless postgres_adapter?(adapter)

    adapter.client.with_connection do |conn|
      result = conn.raw_connection.exec_params(
        "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE $1",
        ["#{TEST_INDEX_PREFIX}%"]
      )
      result.each { |row| conn.execute("DROP TABLE IF EXISTS \"#{row['table_name']}\"") }
    end
  end

  def schema(collection_name = code_collection_name)
    case ActiveContext.adapter
    when ActiveContext::Databases::Elasticsearch::Adapter, ActiveContext::Databases::Opensearch::Adapter
      elastic_opensearch_mappings(collection_name)
    when ActiveContext::Databases::Postgresql::Adapter
      postgres_schema(collection_name)
    end
  end

  private

  def elastic_opensearch_mappings(index)
    active_context_client.indices.get_mapping(index: index).each_value.first['mappings']['properties']
  end

  def postgres_schema(table_name)
    ActiveContext.adapter.client.with_connection do |conn|
      result = conn.raw_connection.exec_params(
        "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = $1",
        [table_name]
      )
      result.each_with_object({}) { |row, hash| hash[row['column_name']] = row['data_type'] }
    end
  end

  def active_context_client
    ::ActiveContext.adapter.client.client
  end

  def active_context_indices
    response = active_context_client.cat.indices(format: 'json')
    response.select { |index| index['index'].start_with?(TEST_INDEX_PREFIX) }.pluck('index')
  end
end
