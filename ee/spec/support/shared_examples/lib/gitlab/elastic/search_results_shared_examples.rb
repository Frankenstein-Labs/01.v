# frozen_string_literal: true

# results must be defined to call one of the following classes: SearchResults, GroupResults, or ProjectResults
RSpec.shared_examples 'calls Elasticsearch the expected number of times' do |scopes:, scopes_with_multiple:|
  scopes.each do |scope|
    context "for scope #{scope}", :elastic, :request_store, feature_category: :global_search do
      before do
        allow(::Gitlab::PerformanceBar).to receive(:enabled_for_request?).and_return(true)
      end

      it 'makes 1 Elasticsearch query' do
        request = make_search_request(scope)

        expect(::Gitlab::Instrumentation::ElasticsearchTransport.get_request_count).to eq(1)
        expect(request.dig(:params, :timeout)).to eq('30s')
      end
    end
  end

  scopes_with_multiple.each do |scope|
    context "for scope #{scope}", :elastic, :request_store, feature_category: :global_search do
      before do
        allow(::Gitlab::PerformanceBar).to receive(:enabled_for_request?).and_return(true)
      end

      it 'makes 2 Elasticsearch queries' do
        request = make_search_request(scope)

        expect(::Gitlab::Instrumentation::ElasticsearchTransport.get_request_count).to eq(2)
        expect(request.dig(:params, :timeout)).to eq('30s')
      end
    end
  end

  private

  def make_search_request(scope)
    # We want to warm the cache for checking migrations have run since we
    # don't want to count these requests as searches
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    warm_elasticsearch_migrations_cache!
    ::Gitlab::SafeRequestStore.clear!

    results.objects(scope)
    results.public_send(:"#{scope}_count")

    ::Gitlab::Instrumentation::ElasticsearchTransport.detail_store.first
  end
end

RSpec.shared_examples 'does not load results for count only queries' do |scopes_and_indices|
  scopes_and_indices.each do |scope, index_name|
    context "for scope #{scope}", :elastic, :request_store, feature_category: :global_search do
      before do
        allow(::Gitlab::PerformanceBar).to receive(:enabled_for_request?).and_return(true)
      end

      it 'makes count query' do
        # We want to warm the cache for checking migrations have run since we
        # don't want to count these requests as searches
        allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
        warm_elasticsearch_migrations_cache!
        ::Gitlab::SafeRequestStore.clear!

        results.public_send(:"#{scope}_count")

        # Some requests make calls to find related data in other indices
        # Make sure to inspect the call to the index for the scope
        request = ::Gitlab::Instrumentation::ElasticsearchTransport.detail_store.find do |store|
          store[:path].include?(index_name)
        end
        expect(request.dig(:body, :size)).to eq(0)
        expect(request[:highlight]).to be_blank
        expect(request.dig(:params, :timeout)).to eq('1s')
      end
    end
  end
end

RSpec.shared_examples 'loads expected aggregations' do
  let(:query) { 'hello world' }

  it 'returns the expected aggregations', feature_category: :global_search do
    expect(aggregations).to be_kind_of(Array)

    if expected_aggregation_name && (!feature_flag || feature_enabled)
      expect(aggregations).not_to be_empty
      expect(aggregations.map(&:name)).to include(expected_aggregation_name)
    else
      expect(aggregations).to be_kind_of(Array)
      expect(aggregations).to be_empty
    end
  end
end

RSpec.shared_examples 'namespace ancestry_filter for aggregations' do
  let(:query_name) { "#{scope.singularize}:authorized:namespace:ancestry_filter:descendants" }

  before do
    group.add_developer(user)
  end

  it 'includes authorized:namespace:ancestry_filter:descendants name query' do
    results.aggregations(scope)
    assert_named_queries(query_name)
  end
end

RSpec.shared_examples_for 'a paginated object' do |object_type|
  let(:results) { described_class.new(user, query) }

  it 'does not explode when given a page as a string' do
    expect { results.objects(object_type, page: "2") }.not_to raise_error
  end

  it 'paginates' do
    objects = results.objects(object_type, page: 2)
    expect(objects).to respond_to(:total_count, :limit, :offset)
    expect(objects.offset_value).to eq(20)
  end

  it 'uses the per_page value if passed' do
    objects = results.objects(object_type, page: 5, per_page: 1)
    expect(objects.offset_value).to eq(4)
  end
end

RSpec.shared_examples_for 'searching notable entries in merge requests' do
  let(:query) { 'Goodbye' }

  before do
    ensure_elasticsearch_index!
  end

  it 'finds the merge_request' do
    expect(results.objects('merge_requests')).to match_array([note_merge_request])
  end
end
