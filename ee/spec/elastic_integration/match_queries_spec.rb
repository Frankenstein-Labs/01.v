# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Match Queries', :elastic_delete_by_query, feature_category: :global_search do
  subject { Elastic::Latest::ProjectClassProxy.new(Project) }

  let(:options) { { search_level: :global } }
  let(:elastic_search) { subject.elastic_search(query, options: options) }
  let(:request) { Elasticsearch::Model::Searching::SearchRequest.new(Project, query) }
  let(:response) do
    Elasticsearch::Model::Response::Response.new(Project, request)
  end

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  context 'when not using advanced query syntax' do
    let(:query) { 'blob' }

    it 'has the multi_match named queries' do
      elastic_search.response
      assert_named_queries(
        'filters:doc:is_a:project',
        'project:multi_match_phrase:search_terms',
        'project:multi_match:and:search_terms', without: ['project:match:search_terms']
      )
    end

    context 'when we do a count only query' do
      let(:options) { { count_only: true, search_level: :global } }

      it 'has the multi_match filter query present' do
        elastic_search.response
        assert_named_queries(
          'filters:doc:is_a:project',
          'project:multi_match_phrase:search_terms',
          'project:multi_match:and:search_terms',
          without: ['project:match:search_terms']
        )
      end
    end
  end

  context 'when using advanced query syntax' do
    let(:query) { '*' }

    it 'does not have the multi_match named queries' do
      elastic_search.response

      assert_named_queries('filters:doc:is_a:project', 'project:match:search_terms', without:
        %w[project:multi_match_phrase:search_terms
          project:multi_match:and:search_terms])
    end

    context 'when we do a count only query' do
      let(:options) { { search_level: :global, count_only: true } }

      it 'does not have the multi_match named queries' do
        elastic_search.response

        assert_named_queries('filters:doc:is_a:project', 'project:match:search_terms', without:
          %w[project:multi_match_phrase:search_terms
            project:multi_match:and:search_terms])
      end
    end
  end
end
