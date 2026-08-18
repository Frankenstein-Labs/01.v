# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::Latest::NoteClassProxy, feature_category: :global_search do
  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  subject(:proxy) { described_class.new(Note, use_separate_indices: true) }

  describe '#es_type' do
    it 'returns notes' do
      expect(proxy.es_type).to eq 'note'
    end
  end

  describe '#elastic_search', :elastic, :sidekiq_inline do
    let_it_be(:user) { create :user }
    let_it_be(:group) { create(:group, :public) }
    let_it_be(:project) { create :project, :public, group: group }
    let_it_be(:project2) { create :project, :public }
    let_it_be(:archived_project) { create :project, :archived, :public }
    let_it_be(:note) { create(:note_on_issue, note: 'test', project: project) }
    let_it_be(:note2) { create(:note_on_merge_request, note: 'test', project: project2) }
    let_it_be(:note3) { create(:note_on_merge_request, note: 'test', project: project) }
    let_it_be(:archived_note) { create(:note_on_issue, note: 'test', project: archived_project) }

    let(:base_options) do
      {
        current_user: user,
        project_ids: project_ids,
        group_ids: group_ids,
        public_and_internal_projects: public_and_internal_projects,
        search_level: search_level
      }
    end

    let(:options) { base_options }
    let(:query) { 'test' }
    let(:result) { proxy.elastic_search(query, options: options) }

    before_all do
      Elastic::ProcessBookkeepingService.track!(note, note2, note3, archived_note)
      ensure_elasticsearch_index!
    end

    context 'when searching at all levels' do
      let(:issues_context_name) { "filters:permissions:#{search_level}:issues_access_level:enabled" }
      let(:merge_requests_context_name) { "filters:permissions:#{search_level}:merge_requests_access_level:enabled" }
      let(:repository_context_name) { "filters:permissions:#{search_level}:repository_level:enabled" }
      let(:snippets_context_name) { "filters:permissions:#{search_level}:snippets_access_level:enabled" }

      describe 'global search' do
        let(:search_level) { :global }
        let(:project_ids) { [] }
        let(:group_ids) { [] }
        let(:public_and_internal_projects) { true }

        context 'when options[:include_archived] is true' do
          let(:options) { base_options.merge(include_archived: true) }

          it 'returns archived results' do
            expect(elasticsearch_hit_ids(result)).to match_array [note.id, note2.id, note3.id, archived_note.id]
            assert_named_queries('note:multi_match:and:search_terms', 'note:multi_match_phrase:search_terms',
              without: ['note:archived:non_archived'])
          end
        end

        it 'returns non-archived results by default' do
          expect(elasticsearch_hit_ids(result)).to match_array [note.id, note2.id, note3.id]
          assert_named_queries('note:multi_match:and:search_terms', 'note:multi_match_phrase:search_terms',
            'note:archived:non_archived')
        end

        context 'when advanced search syntax is used' do
          let(:query) { 'test*' }

          it 'uses simple_query_string in query' do
            expect(elasticsearch_hit_ids(result)).to match_array [note.id, note2.id, note3.id]
            assert_named_queries('note:match:search_terms',
              without: %w[note:multi_match:and:search_terms note:multi_match_phrase:search_terms])
          end
        end

        context 'when options[:noteable_type] and options[:related_ids_only] are set' do
          let(:options) { base_options.merge(noteable_type: 'Issue', related_ids_only: true) }

          it 'filters by noteable_type and returns noteable_id only in the _source array' do
            hits = result.response['hits']['hits']
            expect(hits.first['_source'].keys).to contain_exactly('noteable_id')
            expect(hits.map(&:_source).map(&:noteable_id)).to contain_exactly(note.noteable_id)
            assert_named_queries('note:multi_match:and:search_terms', 'note:multi_match_phrase:search_terms',
              'note:archived:non_archived', 'filters:related:issue',
              issues_context_name,
              without: %W[#{merge_requests_context_name} #{repository_context_name} #{snippets_context_name}])
          end
        end
      end

      describe 'group search' do
        let(:search_level) { :group }
        let(:group_ids) { [group.id] }
        let(:public_and_internal_projects) { false }
        let(:project_ids) do
          all_projects = ::ProjectsFinder.new(current_user: user).execute
          all_projects.preload(:topics, :project_topics, :route)
            .for_group_and_its_subgroups(group).pluck_primary_key
        end

        it 'returns results' do
          expect(elasticsearch_hit_ids(result)).to match_array [note.id, note3.id]
          assert_named_queries('note:multi_match:and:search_terms',
            'note:multi_match_phrase:search_terms', 'note:archived:non_archived')
        end

        context 'when advanced search syntax is used' do
          let(:query) { 'test*' }

          it 'uses simple_query_string in query' do
            expect(elasticsearch_hit_ids(result)).to match_array [note.id, note3.id]

            assert_named_queries('note:match:search_terms',
              without: %w[note:multi_match:and:search_terms note:multi_match_phrase:search_terms])
          end
        end

        context 'when options[:noteable_type] and options[:related_ids_only] are set' do
          let(:options) { base_options.merge(noteable_type: 'Issue', related_ids_only: true) }

          it 'filters by noteable_type and returns noteable_id only in the _source array' do
            expect(result.response['hits']['hits'].first['_source'].keys).to contain_exactly('noteable_id')
            expect(result.response['hits']['hits'].map(&:_source).map(&:noteable_id))
              .to contain_exactly(note.noteable_id)
            assert_named_queries('note:multi_match:and:search_terms', 'note:multi_match_phrase:search_terms',
              'note:archived:non_archived', 'filters:related:issue',
              issues_context_name,
              without: %W[#{merge_requests_context_name} #{repository_context_name} #{snippets_context_name}])
          end
        end
      end

      describe 'project search' do
        let(:search_level) { :project }
        let(:project_ids) { [project.id] }
        let(:group_ids) { [] }
        let(:public_and_internal_projects) { false }

        it 'returns results' do
          expect(elasticsearch_hit_ids(result)).to match_array [note.id, note3.id]
          assert_named_queries('note:multi_match:and:search_terms',
            'note:multi_match_phrase:search_terms', 'note:archived:non_archived')
        end

        context 'when advanced search syntax is used' do
          let(:query) { 'test*' }

          it 'uses simple_query_string in query' do
            expect(elasticsearch_hit_ids(result)).to match_array [note.id, note3.id]

            assert_named_queries('note:match:search_terms',
              without: %w[note:multi_match:and:search_terms note:multi_match_phrase:search_terms])
          end
        end

        context 'when options[:noteable_type] and options[:related_ids_only] are set' do
          let(:options) { base_options.merge(noteable_type: 'Issue', related_ids_only: true) }

          it 'filters by noteable_type and returns noteable_id only in the _source array' do
            expect(result.response['hits']['hits'].first['_source'].keys).to contain_exactly('noteable_id')
            expect(result.response['hits']['hits'].map(&:_source).map(&:noteable_id))
              .to contain_exactly(note.noteable_id)
            assert_named_queries('note:multi_match:and:search_terms', 'note:multi_match_phrase:search_terms',
              'note:archived:non_archived', 'filters:related:issue',
              issues_context_name,
              without: %W[#{merge_requests_context_name} #{repository_context_name} #{snippets_context_name}])
          end
        end
      end
    end
  end

  describe '#confidentiality_filter' do
    let_it_be(:user) { create(:user) }

    let(:query_hash) { { query: { bool: { filter: [] } } } }
    let(:options) do
      { current_user: user, search_level: 'global', min_access_level_confidential: ::Gitlab::Access::REPORTER,
        min_access_level_confidential_public_internal: ::Gitlab::Access::REPORTER }
    end

    subject(:confidentiality_filter) { proxy.send(:confidentiality_filter, query_hash, options) }

    it 'calls Search::Elastic::Filters.by_note_confidentiality' do
      expect(::Search::Elastic::Filters).to receive(:by_note_confidentiality)
        .with(query_hash: query_hash, options: options)
        .and_return(query_hash)

      confidentiality_filter
    end
  end
end
