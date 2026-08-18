# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SearchController, :with_current_organization, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, maintainers: user) }

  let(:project) { create(:project, :public, :repository, :wiki_repo, name: 'awesome project', group: group) }
  let(:projects) { create_list(:project, 5, :public, :repository, :wiki_repo) }

  def send_search_request(params)
    get search_path, params: params
  end

  shared_examples 'an efficient database result' do
    it 'avoids N+1 database queries', :use_sql_query_cache do
      create(object, *creation_traits, creation_args)

      ensure_elasticsearch_index!

      # Warm up cache
      send_search_request(params)

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { send_search_request(params) }
      expect(response.body).to include('search-results') # Confirm there are search results to prevent false positives

      projects.each do |project|
        creation_args[:source_project] = project if creation_args.key?(:source_project)
        creation_args[:project] = project if creation_args.key?(:project)
        create(object, *creation_traits, creation_args)
      end

      ensure_elasticsearch_index!

      expect { send_search_request(params) }.not_to exceed_all_query_limit(control).with_threshold(threshold)
      expect(response.body).to include('search-results') # Confirm there are search results to prevent false positives
    end
  end

  describe 'GET /search' do
    before do
      login_as(user)
    end

    describe 'SSO enforcement' do
      before do
        # this is required to allow ability checks, example: can?(:read_project)
        allow(::Gitlab::Auth::GroupSaml::SsoEnforcer).to receive(:access_restricted?).and_return(false)
      end

      context 'for global level search' do
        let(:params) { { search: 'title', scope: 'issues' } }

        it 'does not redirect user to sso sign-in' do
          send_search_request(params)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'for group level search' do
        let(:params) { { group_id: group.id, search: 'title', scope: 'issues' } }

        it 'redirects user to sso sign-in' do
          # this mock handles multiple calls
          # 1. loading `@group` from params[:group_id]
          # 2. in the sso_enforcement_redirect method
          expect(::Gitlab::Auth::GroupSaml::SsoEnforcer).to receive(:access_restricted?)
            .with(resource: group, user: user, skip_owner_check: true).and_return(true)

          send_search_request(params)

          expect(response).to have_gitlab_http_status(:redirect)
          expect(response).to redirect_to(sso_group_saml_providers_url(group, { redirect: request.fullpath }))
        end

        context 'when searching a subgroup' do
          let(:params) { { group_id: subgroup.id, search: 'title', scope: 'issues' } }
          let(:subgroup) { create(:group, parent: group) }

          it 'redirects user to sso sign-in' do
            expect(::Gitlab::Auth::GroupSaml::SsoEnforcer).to receive(:access_restricted?)
              .with(resource: subgroup, user: user, skip_owner_check: true).and_return(true)

            send_search_request(params)

            expect(response).to have_gitlab_http_status(:redirect)
            expect(response).to redirect_to(sso_group_saml_providers_url(group, { redirect: request.fullpath }))
          end
        end
      end

      context 'for project level search' do
        let(:params) { { project_id: project.id, search: 'title', scope: 'issues' } }

        it 'does not redirect user to sso sign-in' do
          send_search_request(params)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'when elasticsearch is enabled', :elastic, :sidekiq_inline do
      before do
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
      end

      let(:creation_traits) { [] }

      context 'for issues scope' do
        let(:object) { :issue }
        let(:labels) { create_list(:label, 3, project: project) }
        let(:creation_args) { { project: project, title: 'foo', labels: labels } }
        let(:params) { { search: 'foo', scope: 'issues' } }
        # some N+1 queries still exist
        # each issue runs an extra query for project routes
        # +5 from configurable work item types (custom_types lookup per new root namespace)
        let(:threshold) { 10 }

        it_behaves_like 'an efficient database result'
      end

      context 'for work_items scope' do
        let(:object) { :issue }
        let(:labels) { create_list(:label, 3, project: project) }
        let(:creation_args) { { project: project, title: 'foo', labels: labels } }
        let(:params) { { search: 'foo', scope: 'work_items' } }
        # some N+1 queries still exist
        # each issue runs an extra query for project routes
        # +5 from configurable work item types (custom_types lookup per new root namespace)
        let(:threshold) { 10 }

        it_behaves_like 'an efficient database result'
      end

      context 'for merge_request scope' do
        let(:creation_traits) { [:unique_branches] }
        let(:labels) { create_list(:label, 3, project: project) }
        let(:object) { :merge_request }
        let(:creation_args) { { source_project: project, title: 'foo', labels: labels } }
        let(:params) { { search: 'foo', scope: 'merge_requests' } }
        # some N+1 queries still exist
        # each merge request runs an extra query for project routes
        let(:threshold) { 4 }

        it_behaves_like 'an efficient database result'
      end

      context 'for project scope' do
        let(:creation_traits) { [:public, :with_namespace_settings] }
        let(:object) { :project }
        let(:creation_args) { { name: 'foo' } }
        let(:params) { { search: 'foo', scope: 'projects' } }
        # some N+1 queries still exist
        # 1 for users
        # 1 for root ancestor for each project
        let(:threshold) { 7 }

        it_behaves_like 'an efficient database result'
      end

      context 'for notes scope' do
        let(:creation_traits) { [:on_commit] }
        let(:object) { :note }
        let(:creation_args) { { project: project, note: 'foo' } }
        let(:params) { { search: 'foo', scope: 'notes' } }
        let(:threshold) { 1 } # required for avatar cache clearance: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/122639

        it_behaves_like 'an efficient database result'
      end

      context 'for milestones scope' do
        let(:object) { :milestone }
        let(:creation_args) { { project: project } }
        let(:params) { { search: 'title', scope: 'milestones' } }
        let(:threshold) { 1 } # required for avatar cache clearance: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/122639

        it_behaves_like 'an efficient database result'
      end

      context 'for users scope' do
        let(:object) { :user }
        let(:creation_args) { { name: 'georgia' } }
        let(:params) { { search: 'georgia', scope: 'users' } }
        let(:threshold) { 1 } # required for avatar cache clearance: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/122639

        it_behaves_like 'an efficient database result'
      end

      context 'for epics scope' do
        let(:object) { :epic }
        let(:creation_args) { { group: group } }
        let(:params) { { group_id: group.id, search: 'title', scope: 'epics' } }
        let(:threshold) { 1 } # required for avatar cache clearance: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/122639

        before do
          stub_licensed_features(epics: true)
        end

        it_behaves_like 'an efficient database result'
      end

      context 'for blobs scope' do
        # blobs are enabled for project search only in basic search
        let(:params_for_one) { { search: 'test', project_id: project.id, scope: 'blobs', per_page: 1 } }
        let(:params_for_many) { { search: 'test', project_id: project.id, scope: 'blobs', per_page: 5 } }
        let(:threshold) { 7 } # temporary fix for broken master

        before do
          project.repository.index_commits_and_blobs
          ensure_elasticsearch_index!
        end

        it 'avoids N+1 database queries' do
          control = ActiveRecord::QueryRecorder.new { send_search_request(params_for_one) }
          expect(response.body).to include('search-results') # Confirm search results to prevent false positives

          expect { send_search_request(params_for_many) }.not_to exceed_query_limit(control).with_threshold(threshold)
          expect(response.body).to include('search-results') # Confirm search results to prevent false positives
        end

        it 'does not raise an exeption when blob.path is nil' do
          update_by_query(project.id, "ctx._source['blob']['path'] = null")

          send_search_request(params_for_many)
          expect(response.body).to include('search-results') # Confirm search results to prevent false positives
        end
      end

      context 'for commits scope' do
        let(:params_for_one) { { search: 'test', project_id: project.id, scope: 'commits', per_page: 1 } }
        let(:params_for_many) { { search: 'test', project_id: project.id, scope: 'commits', per_page: 5 } }

        it 'avoids N+1 database queries', :use_sql_query_cache do
          project.repository.index_commits_and_blobs
          ensure_elasticsearch_index!

          # warm up cache
          send_search_request(params_for_one)
          send_search_request(params_for_many)

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) { send_search_request(params_for_one) }
          expect(response.body).to include('search-results') # Confirm search results to prevent false positives

          expect do
            send_search_request(params_for_many)
          end.not_to exceed_query_limit(control).allow_skip_cache_inconsistency
          expect(response.body).to include('search-results') # Confirm search results to prevent false positives
        end
      end

      describe 'search index integrity' do
        shared_examples 'does not call index integrity workers' do
          it 'does nothing' do
            expect(::Search::NamespaceIndexIntegrityWorker).not_to receive(:perform_async)
            expect(::Search::ProjectIndexIntegrityWorker).not_to receive(:perform_async)

            send_search_request(params)
          end
        end

        context 'when the search_type is zoekt', :zoekt_settings_enabled do
          let(:params) { { search: 'test', scope: 'blobs', project_id: project.id } }

          before do
            zoekt_ensure_project_indexed!(project)
          end

          it_behaves_like 'does not call index integrity workers'
        end

        context 'when project is present and group is not present' do
          let(:params) { { search: 'test', scope: 'blobs', project_id: project.id } }

          it 'queues the project integrity worker' do
            expect(::Search::NamespaceIndexIntegrityWorker).not_to receive(:perform_async)
            expect(::Search::ProjectIndexIntegrityWorker).to receive(:perform_async).with(project.id).and_call_original

            send_search_request(params)
          end
        end

        context 'when project is not present and group is not present' do
          let(:params) { { search: 'test', scope: 'blobs' } }

          it_behaves_like 'does not call index integrity workers'
        end

        context 'when project is not present and group is present' do
          let(:params) { { search: 'test', scope: 'blobs', group_id: group.id } }

          it 'queues the namespace integrity worker which then schedules the project integrity worker' do
            stub_const("#{described_class.name}::DELAY_INTERVAL", 10)

            expect(::Search::ProjectIndexIntegrityWorker).to receive(:perform_in).with(
              anything,
              project.id
            ).and_call_original

            expect(::Search::NamespaceIndexIntegrityWorker).to receive(:perform_async).with(group.id).and_call_original

            send_search_request(params)
          end
        end

        context 'when project is present and group is present' do
          let(:params) { { search: 'test', scope: 'blobs', project_id: project.id, group_id: group.id } }

          it 'queues the project integrity worker' do
            expect(::Search::NamespaceIndexIntegrityWorker).not_to receive(:perform_async)
            expect(::Search::ProjectIndexIntegrityWorker).to receive(:perform_async).with(project.id).and_call_original

            send_search_request(params)
          end

          context 'when search results are returned', :sidekiq_inline do
            before do
              project.repository.index_commits_and_blobs

              ensure_elasticsearch_index!
            end

            it_behaves_like 'does not call index integrity workers'
          end

          context 'when scope is not blobs' do
            let(:params) { { search: 'test', scope: 'issues', project_id: project.id, group_id: group.id } }

            it_behaves_like 'does not call index integrity workers'
          end
        end
      end
    end
  end

  def update_by_query(project_id, script)
    client = Repository.__elasticsearch__.client
    index_name = Repository.__elasticsearch__.index_name
    client.update_by_query({
      index: index_name,
      wait_for_completion: true,
      refresh: true,
      body: {
        script: script,
        query: {
          bool: {
            must: [
              {
                term: {
                  type: 'blob'
                }
              },
              {
                term: {
                  project_id: project_id
                }
              }
            ]
          }
        }
      }
    })
  end
end
