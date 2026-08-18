# frozen_string_literal: true

module ElasticsearchHelpers
  def assert_names_in_query(query, with: [], without: [])
    with = Array.wrap(with)
    without = Array.wrap(without)

    query.extend(Hashie::Extensions::DeepFind)
    names = query.deep_find_all(:_name) || []

    expect(names).to include(*with) unless with.empty?
    expect(names).not_to include(*without) unless without.empty?
  end

  def assert_fields_in_query(query, with: [], without: [])
    with = Array.wrap(with)
    without = Array.wrap(without)

    query.extend(Hashie::Extensions::DeepFind)
    fields = query.deep_find(:fields)

    expect(fields).to include(*with) unless with.empty?
    expect(fields).not_to include(*without) unless without.empty?
  end

  def assert_named_queries(*expected_names, without: [])
    es_host = Gitlab::CurrentSettings.elasticsearch_url.first
    search_uri = %r{#{es_host}/[\w-]+/_search}

    ensure_names_present = ->(req) do
      payload = Gitlab::Json.parse(req.body)
      query = payload["query"]

      return false unless query.present?

      inspector = ElasticQueryNameInspector.new

      inspector.inspect(query)
      inspector.query_with?(expected_names: expected_names, unexpected_names: without)
    rescue ::JSON::ParserError
      false
    end

    a_named_query = a_request(:post, search_uri).with(&ensure_names_present)
    message = "Expected a query with the names #{expected_names.inspect}"
    message << " and without the names #{without.inspect}" if without.any?
    expect(a_named_query).to have_been_made.at_least_once, message
  end

  def assert_routing_field(value)
    es_host = Gitlab::CurrentSettings.elasticsearch_url.first
    search_uri = %r{#{es_host}/[\w-]+/_search}

    expect(a_request(:post, search_uri).with(query: hash_including({ 'routing' => value }))).to have_been_made
  end

  def ensure_elasticsearch_index!
    # Ensure that any enqueued updates are processed
    Elastic::ProcessBookkeepingService.new.execute
    Elastic::ProcessInitialBookkeepingService.new.execute

    # Make any documents added to the index visible
    refresh_index!
  end

  def refresh_index!
    es_helper.refresh_index
    es_helper.refresh_index(index_name: es_helper.migrations_index_name)
  end

  def set_elasticsearch_migration_to(name_or_version, including: true)
    version = if name_or_version.is_a?(Numeric)
                name_or_version
              else
                Elastic::DataMigrationService.find_by_name!(name_or_version).version
              end

    Elastic::DataMigrationService.migrations.each do |migration|
      return_value = if including
                       migration.version <= version
                     else
                       migration.version < version
                     end

      allow(Elastic::DataMigrationService).to receive(:migration_has_finished?)
        .with(migration.name_for_key.to_sym)
        .and_return(return_value)
    end
  end

  def warm_elasticsearch_migrations_cache!
    ::Elastic::DataMigrationService.migrations.each do |migration|
      ::Elastic::DataMigrationService.migration_has_finished?(migration.name.underscore.to_sym)
    end
  end

  def es_helper
    Search::Elastic::Helper.default
  end

  def es_client
    Gitlab::Search::Client.new
  end

  def elasticsearch_hit_ids(result)
    result.response['hits']['hits'].map(&:_source).map(&:id)
  end

  def elastic_wiki_indexer_worker_random_delay_range
    a_value_between(0, ElasticWikiIndexerWorker::MAX_JOBS_PER_HOUR.pred)
  end

  def elastic_delete_group_wiki_worker_random_delay_range
    a_value_between(0, Search::Wiki::ElasticDeleteGroupWikiWorker::MAX_JOBS_PER_HOUR.pred)
  end

  def elastic_group_association_deletion_worker_random_delay_range
    a_value_between(0, Search::ElasticGroupAssociationDeletionWorker::MAX_JOBS_PER_HOUR.pred)
  end

  def items_in_index(index_name, id = 'id', source: false)
    hits = es_client.search(index: index_name).dig('hits', 'hits')

    if source
      hits.pluck('_source')
    else
      hits.map { |hit| hit['_source'][id] }
    end
  end
end
