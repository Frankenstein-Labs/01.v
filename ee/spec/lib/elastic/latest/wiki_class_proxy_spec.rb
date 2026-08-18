# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::Latest::WikiClassProxy, feature_category: :global_search do
  let_it_be_with_reload(:project) { create(:project, :wiki_repo, :public, :wiki_enabled) }

  subject(:proxy) { described_class.new(Wiki, use_separate_indices: Wiki.use_separate_indices?) }

  describe 'assert query', :elastic do
    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    end

    let(:options) do
      {
        current_user: nil,
        project_ids: [project.id],
        public_and_internal_projects: false,
        search_level: 'project',
        repository_id: "wiki_#{project.id}"
      }
    end

    it 'returns the result from the separate index' do
      proxy.elastic_search_as_wiki_page('*', options: options)
      assert_named_queries('wiki_blob:match:search_terms:separate_index')
    end

    describe 'authorization' do
      using RSpec::Parameterized::TableSyntax

      let_it_be(:user) { create(:user) }
      let(:query) { 'test' }

      where(:search_level, :group_ids, :project_ids) do
        'global'  | []  | []
        'group'   | [1] | []
        'project' | []  | [1]
      end

      with_them do
        let(:options) do
          {
            current_user: user,
            search_level: search_level,
            group_ids: group_ids,
            project_ids: project_ids
          }
        end

        it 'uses new authorization filter with traversal_ids' do
          proxy.elastic_search(query, options: options)

          expected_queries = %W[
            filters:permissions:#{search_level}:visibility_level:public_and_internal
            filters:permissions:#{search_level}:wiki_access_level:enabled
          ]
          assert_named_queries(*expected_queries)
        end
      end
    end
  end

  describe '#routing_options' do
    let(:n_routing) { 'n_1,n_2,n_3' }
    let(:ids) { [1, 2, 3] }
    let(:default_ops) { { root_ancestor_ids: ids, scope: 'wiki_blob' } }

    context 'when routing is disabled' do
      context 'and option routing_disabled is set' do
        it 'returns empty hash' do
          expect(proxy.routing_options(default_ops.merge(routing_disabled: true))).to be_empty
        end
      end

      context 'and option public_and_internal_projects is set' do
        it 'returns empty hash' do
          expect(proxy.routing_options(default_ops.merge(public_and_internal_projects: true))).to be_empty
        end
      end
    end

    context 'when ids count are more than 128' do
      it 'returns empty hash' do
        max_count = Elastic::Latest::Routing::ES_ROUTING_MAX_COUNT
        expect(proxy.routing_options(default_ops.merge(root_ancestor_ids: 1.upto(max_count + 1).to_a))).to be_empty
      end
    end

    it 'returns routing hash' do
      expect(proxy.routing_options(default_ops)).to eq({ routing: n_routing })
    end
  end

  describe '#elastic_search_as_wiki_page', :elasticsearch_settings_enabled, :elastic_delete_by_query, :sidekiq_inline do
    # `freeze: false` is required here: WikiPage is a PORO that memoizes
    # repository/page state; `deep_freeze` raises FrozenError. Keep the
    # opt-out (see gitlab-org/gitlab#602925).
    let_it_be(:wiki_page, freeze: false) { create(:wiki_page, title: 'foo', content: 'bar', project: project) }
    # `freeze: false` is required here: WikiPage is a PORO that memoizes
    # repository/page state; `deep_freeze` raises FrozenError. Keep the
    # opt-out (see gitlab-org/gitlab#602925).
    let_it_be(:wiki_page_nested, freeze: false) do
      create(:wiki_page, title: 'nested/twice/start-page', content: 'bar', project: project)
    end

    let(:query) { 'bar' }
    let(:options) do
      {
        current_user: nil,
        project_ids: [],
        public_and_internal_projects: true,
        search_level: 'global',
        root_ancestor_ids: nil
      }
    end

    before do
      project.wiki.index_wiki_blobs

      ensure_elasticsearch_index!
    end

    it 'returns matching results' do
      results = proxy.elastic_search_as_wiki_page(query, options: options)
      paths = results.map(&:path)

      expect(paths).to contain_exactly(wiki_page.path, wiki_page_nested.path)
    end

    describe 'filters support' do
      context 'for path' do
        let(:query) { 'bar extension:md path:nested/twice' }

        it 'returns matching results' do
          results = proxy.elastic_search_as_wiki_page(query, options: options)
          paths = results.map(&:path)

          expect(paths).to contain_exactly(wiki_page_nested.path)
        end

        context 'when exclusion is used' do
          let(:query) { 'bar -path:nested/twice' }

          it 'returns matching results' do
            results = proxy.elastic_search_as_wiki_page(query, options: options)
            paths = results.map(&:path)

            expect(paths).to contain_exactly(wiki_page.path)
          end
        end

        context 'when part of the path is used' do
          let(:query) { 'bar extension:md path:nested' }

          it 'returns the same results as when the full path is used' do
            results = proxy.elastic_search_as_wiki_page(query, options: { search_level: 'global' })
            paths = results.map(&:path)

            expect(paths).to contain_exactly(wiki_page_nested.path)
          end

          context 'when the path query is in the middle of the file path' do
            let(:query) { 'bar extension:md path:twice' }

            it 'returns the same results as when the full path is used' do
              results = proxy.elastic_search_as_wiki_page(query, options: { search_level: 'global' })
              paths = results.map(&:path)

              expect(paths).to contain_exactly(wiki_page_nested.path)
            end
          end
        end
      end

      context 'for filename' do
        let(:query) { 'bar filename:start-page.md' }

        it 'returns matching results' do
          results = proxy.elastic_search_as_wiki_page(query, options: options)
          paths = results.map(&:path)

          expect(paths).to contain_exactly(wiki_page_nested.path)
        end

        context 'when exclude filter is used' do
          let(:query) { 'bar -filename:start-page.md' }

          it 'removes matching filenames from results' do
            results = proxy.elastic_search_as_wiki_page(query, options: options)
            paths = results.map(&:path)

            expect(paths).to contain_exactly(wiki_page.path)
          end
        end
      end
    end
  end
end
