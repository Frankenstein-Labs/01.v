# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::Latest::GitClassProxy, :elastic, :sidekiq_inline, feature_category: :global_search do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, :public, :repository, group: group) }
  let_it_be_with_reload(:user) { create(:user) }

  let(:included_class) { Elastic::Latest::RepositoryClassProxy }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

    ::Elastic::ProcessBookkeepingService.track!(project)
    project.repository.index_commits_and_blobs
    ensure_elasticsearch_index!
  end

  subject(:proxy) { included_class.new(project.repository.class) }

  describe '#elastic_search' do
    context 'when type is blob' do
      shared_examples 'a search that respects custom roles' do |search_level:|
        let_it_be(:member_role) { create(:member_role, :guest, :read_code, namespace: group) }

        let_it_be(:sub_group) { create(:group, :private, parent: group) }

        let_it_be(:project_2) { create(:project, :private, :repository, developers: user, group: sub_group) }
        let_it_be(:project_3) { create(:project, :private, :repository, guests: user) }

        before_all do
          create(:group_member, :guest, member_role: member_role, user: user, group: group)
          create(:project_member, :guest, member_role: member_role, user: user, project: project)
        end

        subject(:search_results) do
          proxy.elastic_search('Mailer.deliver', type: 'blob', options: search_options)
        end

        it 'returns matching search results' do
          expect(search_results[:blobs][:results].count).to eq(1)
          expect(search_results[:blobs][:results][0][:_source][:blob][:path]).to eq(
            'files/markdown/ruby-style-guide.md'
          )
        end

        it 'avoids N+1 queries' do
          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            proxy.elastic_search('Mailer.deliver', type: 'blob', options: search_options)
          end

          project_ids = [project.id, project_2.id]

          project_ids << project_3.id if search_level.to_sym == :group

          options = search_options.merge(project_ids: project_ids)

          # for global search, user does not have direct access to all project's namespaces
          # so one extra call is made
          threshold = search_level.to_sym == :global ? 1 : 0

          expect do
            proxy.elastic_search('Mailer.deliver', type: 'blob', options: options)
          end.not_to exceed_query_limit(control).allow_skip_cache_inconsistency.with_threshold(threshold)
        end
      end

      context 'when performing a global search' do
        let(:search_options) do
          {
            search_level: 'global',
            current_user: user,
            public_and_internal_projects: true,
            project_ids: [project.id],
            order_by: nil,
            sort: nil
          }
        end

        it 'uses the correct elasticsearch query' do
          proxy.elastic_search('*', type: 'blob', options: search_options)
          assert_named_queries('doc:is_a:blob',
            'filters:permissions:global:visibility_level:public_and_internal', 'blob:match:search_terms')
        end

        it_behaves_like 'a search that respects custom roles', search_level: :global
      end

      context 'when performing a group search' do
        let(:search_options) do
          {
            current_user: user,
            project_ids: [project.id],
            group_ids: [group.id],
            public_and_internal_projects: false,
            search_level: 'group',
            order_by: nil,
            sort: nil
          }
        end

        it 'uses the correct elasticsearch query' do
          proxy.elastic_search('*', type: 'blob', options: search_options)
          assert_named_queries('doc:is_a:blob',
            'filters:permissions:group:visibility_level:public_and_internal', 'blob:match:search_terms')
        end

        context 'when user is authorized for the namespace' do
          it 'uses the correct elasticsearch query' do
            group.add_reporter(user)

            proxy.elastic_search('*', type: 'blob', options: search_options)
            assert_named_queries('doc:is_a:blob', 'blob:match:search_terms', 'filters:level:group',
              'filters:permissions:group:visibility_level:public_and_internal')
          end
        end

        context 'when the project is private' do
          before do
            project.update!(visibility_level: ::Gitlab::VisibilityLevel::PRIVATE)
            ensure_elasticsearch_index!
          end

          subject(:search_results) do
            proxy.elastic_search('Mailer.deliver', type: 'blob', options: search_options)
          end

          context 'when the user is not authorized' do
            it 'returns no search results' do
              expect(search_results[:blobs][:results]).to be_empty
            end
          end

          context 'when the user is a member' do
            where(:role, :expected_count) do
              [
                [:guest, 0],
                [:reporter, 1],
                [:developer, 1],
                [:maintainer, 1],
                [:owner, 1]
              ]
            end

            with_them do
              before do
                project.add_member(user, role)
              end

              it { expect(search_results[:blobs][:results].count).to eq(expected_count) }
            end
          end
        end

        it_behaves_like 'a search that respects custom roles', search_level: :group
      end

      context 'when performing a project search' do
        let(:search_options) do
          {
            search_level: 'project',
            current_user: user,
            project_ids: [project.id],
            public_and_internal_projects: false,
            order_by: nil,
            sort: nil,
            repository_id: project.id
          }
        end

        it 'uses the correct elasticsearch query' do
          proxy.elastic_search('*', type: 'blob', options: search_options)
          assert_named_queries('doc:is_a:blob', 'filters:level:project',
            'filters:permissions:project:visibility_level:public_and_internal',
            'blob:match:search_terms', 'blob:related:repositories')
        end

        it_behaves_like 'a search that respects custom roles', search_level: :project

        context 'when the user is not authorized' do
          before do
            project.update!(visibility_level: ::Gitlab::VisibilityLevel::PRIVATE)
            ensure_elasticsearch_index!
          end

          it 'returns no search results' do
            search_results = proxy.elastic_search('Mailer.deliver', type: 'blob', options: search_options)

            expect(search_results[:blobs][:results]).to be_empty
          end
        end
      end
    end

    context 'when type is commit' do
      context 'when performing a global search' do
        let(:search_options) do
          {
            current_user: user,
            search_level: 'global',
            public_and_internal_projects: true,
            project_ids: [project.id],
            order_by: nil,
            sort: nil
          }
        end

        it 'uses the correct elasticsearch query' do
          proxy.elastic_search('*', type: 'commit', options: search_options)
          assert_named_queries('doc:is_a:commit',
            'filters:permissions:global:visibility_level:public_and_internal', 'commit:match:search_terms')
        end
      end

      context 'when performing a group search' do
        let(:search_options) do
          {
            current_user: user,
            search_level: 'group',
            project_ids: [project.id],
            group_ids: [group.id],
            public_and_internal_projects: false,
            order_by: nil,
            sort: nil
          }
        end

        it 'uses the correct elasticsearch query' do
          proxy.elastic_search('*', type: 'commit', options: search_options)
          assert_named_queries('doc:is_a:commit',
            'filters:permissions:group:visibility_level:public_and_internal', 'commit:match:search_terms')
        end

        context 'when user is authorized for the namespace' do
          it 'uses the correct elasticsearch query' do
            group.add_reporter(user)

            proxy.elastic_search('*', type: 'commit', options: search_options)
            assert_named_queries('doc:is_a:commit', 'commit:match:search_terms', 'filters:level:group',
              'filters:permissions:group:visibility_level:public_and_internal',
              'filters:permissions:group:private_access:ancestry_filter:descendants')
          end
        end
      end

      context 'when performing a project search' do
        let(:search_options) do
          {
            current_user: user,
            search_level: 'project',
            project_ids: [project.id],
            public_and_internal_projects: false,
            order_by: nil,
            sort: nil,
            repository_id: project.id
          }
        end

        it 'uses the correct elasticsearch query' do
          proxy.elastic_search('*', type: 'commit', options: search_options)
          assert_named_queries('doc:is_a:commit', 'filters:level:project',
            'filters:permissions:project:visibility_level:public_and_internal',
            'commit:match:search_terms', 'commit:related:repositories')
        end
      end

      context 'when requesting highlighting' do
        let(:search_options) do
          {
            current_user: user,
            search_level: 'project',
            project_ids: [project.id],
            public_and_internal_projects: false,
            order_by: nil,
            sort: nil,
            repository_id: project.id,
            highlight: true
          }
        end

        it 'returns highlight in the results' do
          results = proxy.elastic_search('Add', type: 'commit', options: search_options)
          expect(results[:commits][:results].results.first.keys).to include('highlight')
        end
      end
    end
  end

  describe '#elastic_search_as_found_blob', :aggregate_failures do
    it 'returns FoundBlob' do
      results = proxy.elastic_search_as_found_blob('def popen', options: { search_level: 'global' })

      expect(results).not_to be_empty
      expect(results).to all(be_a(Gitlab::Search::FoundBlob))

      result = results.first

      expect(result.ref).to eq('b83d6e391c22777fca1ed3012fce84f633d7fed0')
      expect(result.path).to eq('files/ruby/popen.rb')
      expect(result.startline).to eq(2)
      expect(result.data).to include('Popen')
      expect(result.project).to eq(project)
    end

    context 'with filters in the query' do
      let(:query) { 'def extension:rb path:files/ruby' }

      it 'returns matching results' do
        results = proxy.elastic_search_as_found_blob(query, options: { search_level: 'global' })
        paths = results.map(&:path)

        expect(paths).to contain_exactly('files/ruby/regex.rb',
          'files/ruby/popen.rb',
          'files/ruby/version_info.rb')
      end

      context 'when part of the path is used' do
        let(:query) { 'def extension:rb path:files' }

        it 'returns the same results as when the full path is used' do
          results = proxy.elastic_search_as_found_blob(query, options: { search_level: 'global' })
          paths = results.map(&:path)

          expect(paths).to contain_exactly('files/ruby/regex.rb',
            'files/ruby/popen.rb',
            'files/ruby/version_info.rb')
        end

        context 'when the path query is in the middle of the file path' do
          let(:query) { 'def extension:rb path:ruby' }

          it 'returns the same results as when the full path is used' do
            results = proxy.elastic_search_as_found_blob(query, options: { search_level: 'global' })
            paths = results.map(&:path)

            expect(paths).to contain_exactly('files/ruby/regex.rb',
              'files/ruby/popen.rb',
              'files/ruby/version_info.rb')
          end
        end
      end
    end
  end

  describe '#blob_aggregations' do
    let_it_be(:user) { create(:user) }

    let(:options) do
      {
        current_user: user,
        search_level: 'project',
        project_ids: [project.id],
        public_and_internal_projects: false,
        order_by: nil,
        sort: nil
      }
    end

    before_all do
      project.add_developer(user)
    end

    it 'returns aggregations' do
      result = proxy.blob_aggregations('This guide details how contribute to GitLab', options)

      expect(result.first.name).to eq('language')
      expect(result.first.buckets.first[:key]).to eq('Markdown')
      expect(result.first.buckets.first[:count]).to eq(2)
    end

    it 'assert names queries for global blob search when migration is complete' do
      search_options = {
        current_user: user,
        search_level: 'global',
        public_and_internal_projects: true,
        order_by: nil,
        sort: nil
      }
      proxy.blob_aggregations('*', search_options)
      assert_named_queries('doc:is_a:blob', 'filters:permissions:global:visibility_level:public_and_internal',
        'blob:match:search_terms')
    end

    it 'assert names queries for group blob search' do
      group_search_options = {
        current_user: user,
        search_level: 'group',
        project_ids: [project.id],
        group_ids: [project.namespace.id],
        public_and_internal_projects: false,
        order_by: nil,
        sort: nil
      }
      proxy.blob_aggregations('*', group_search_options)
      assert_named_queries('doc:is_a:blob', 'filters:level:group',
        'filters:permissions:group:visibility_level:public_and_internal', 'blob:match:search_terms')
    end

    it 'assert names queries for project blob search' do
      project_search_options = {
        current_user: user,
        search_level: 'project',
        project_ids: [project.id],
        public_and_internal_projects: false,
        order_by: nil,
        sort: nil
      }
      proxy.blob_aggregations('*', project_search_options)
      assert_named_queries('doc:is_a:blob', 'filters:level:project',
        'filters:permissions:project:visibility_level:public_and_internal', 'blob:match:search_terms')
    end
  end
end
