# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Search with default scope setting', :elastic, :clean_gitlab_redis_rate_limiting, :with_current_organization, feature_category: :global_search do
  let_it_be(:user) { create(:user, :with_namespace, name: 'Test User') }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project) { create(:project, :public, group: group, name: 'Test Project') }
  let_it_be(:issue) { create(:issue, project: project, title: 'Test Issue') }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, title: 'Test MR') }

  before do
    sign_in(user)
  end

  # Default make_search_request for global search (can be overridden in specific contexts)
  def make_search_request(params)
    get search_path, params: params
  end

  shared_examples 'uses configured default scope' do
    it 'uses configured default scope when no scope param is provided' do
      stub_application_setting(default_search_scope: 'work_items')

      make_search_request(search: 'Test')

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to include(CGI.escapeHTML(::Gitlab::UrlBuilder.instance.issue_path(issue)))
    end
  end

  shared_examples 'respects explicit scope override' do
    it 'respects explicit scope parameter over configured default' do
      stub_application_setting(default_search_scope: 'work_items')

      make_search_request(search: 'Test', scope: 'merge_requests')

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to match(/merge.?requests results for term/)
      expect(response.body).to include(CGI.escapeHTML("/-/merge_requests/#{merge_request.iid}"))
    end
  end

  shared_examples 'uses system default when configured' do
    it 'uses system default when setting is "system default"' do
      stub_application_setting(default_search_scope: 'system default')

      make_search_request(search: 'Test')

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to include(CGI.escapeHTML(project.path))
    end

    it 'uses system default when setting is blank' do
      stub_application_setting(default_search_scope: '')

      make_search_request(search: 'Test')

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to include(CGI.escapeHTML(project.path))
    end
  end

  shared_examples 'respects configured default scope' do |context_type|
    context "in #{context_type} search" do
      include_examples 'uses configured default scope'
      include_examples 'respects explicit scope override'
      include_examples 'uses system default when configured'
    end
  end

  shared_examples 'respects scope availability' do
    it 'falls back when configured default is disabled by settings' do
      stub_application_setting(default_search_scope: 'work_items', global_search_work_items_enabled: false)

      make_search_request(search: 'Test')

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to include(CGI.escapeHTML(project.path))
    end
  end

  shared_examples 'handles code search literals' do
    it 'does not auto-redirect to blobs scope for searches with code literals' do
      stub_application_setting(default_search_scope: 'work_items')

      make_search_request(search: 'blob:test.rb')

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).not_to redirect_to(anything)
      expect(response.body).to include('any work items matching')
    end

    it 'does not auto-redirect for extension: literal' do
      stub_application_setting(default_search_scope: 'merge_requests')

      make_search_request(search: 'extension:rb test')

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to match(/merge.?requests results for term/)
    end

    it 'does not auto-redirect for path: literal' do
      stub_application_setting(default_search_scope: 'projects')

      make_search_request(search: 'path:app/models')

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to include('any projects matching')
    end

    it 'does not auto-redirect for filename: literal' do
      stub_application_setting(default_search_scope: 'users')

      make_search_request(search: 'filename:config.yml')

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to match(/users results for term/)
    end

    it 'still respects explicit blobs scope selection' do
      stub_application_setting(default_search_scope: 'work_items')

      get search_path, params: { search: 'blob:test.rb', scope: 'blobs', project_id: project.id }

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to include('any code results matching')
    end
  end

  describe 'global search' do
    include_examples 'respects configured default scope', 'global'

    it 'falls back to first available scope when configured default is not available' do
      stub_application_setting(default_search_scope: 'blobs')

      make_search_request(search: 'Test')

      expect(response).to have_gitlab_http_status(:ok)
      # Blobs scope not available in global search, falls back to projects
      expect(response.body).to include(CGI.escapeHTML(project.path))
    end

    include_examples 'respects scope availability'

    context 'with different default scopes' do
      it 'uses work_items as default when configured' do
        stub_application_setting(default_search_scope: 'work_items')

        make_search_request(search: 'Test')

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include(CGI.escapeHTML(::Gitlab::UrlBuilder.instance.issue_path(issue)))
      end

      it 'uses merge_requests as default when configured' do
        stub_application_setting(default_search_scope: 'merge_requests')

        make_search_request(search: 'Test')

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include(CGI.escapeHTML("/-/merge_requests/#{merge_request.iid}"))
      end

      it 'uses users as default when configured' do
        stub_application_setting(default_search_scope: 'users')

        make_search_request(search: 'Test')

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include(CGI.escapeHTML("/#{user.username}"))
      end
    end
  end

  describe 'project search' do
    def make_search_request(params)
      get search_path, params: params.merge(project_id: project.id)
    end

    include_examples 'respects configured default scope', 'project'

    it 'falls back to blobs scope when projects scope is not available in project context' do
      stub_application_setting(default_search_scope: 'projects')

      make_search_request(search: 'Test')

      expect(response).to have_gitlab_http_status(:ok)
      # 'projects' scope is not available in project context, falls back to blobs scope
      expect(response.body).to include('any code results matching')
    end

    it 'respects project-specific scope availability' do
      stub_application_setting(default_search_scope: 'blobs')

      make_search_request(search: 'Test')

      expect(response).to have_gitlab_http_status(:ok)
      # Should use blobs scope in project context
      expect(response.body).to include('any code results matching')
    end
  end

  describe 'group search' do
    def make_search_request(params)
      get search_path, params: params.merge(group_id: group.id)
    end

    include_examples 'respects configured default scope', 'group'

    context 'when searching at group level with global_search settings disabled' do
      before do
        stub_ee_application_setting(
          elasticsearch_search: true,
          elasticsearch_indexing: true,
          elasticsearch_code_scope: true
        )
        ensure_elasticsearch_index!
      end

      it 'does not redirect to projects scope when global_search_code_enabled is false' do
        stub_ee_application_setting(global_search_code_enabled: false)

        make_search_request(search: 'Test', scope: 'blobs')
        expect(response).to have_gitlab_http_status(:ok)
        # Group search for code should work even when global code search is disabled
        expect(response.body).to include('any code results matching')
      end

      it 'does not redirect to projects scope when global_search_wiki_enabled is false' do
        stub_ee_application_setting(global_search_wiki_enabled: false)

        make_search_request(search: 'Test', scope: 'wiki_blobs')
        expect(response).to have_gitlab_http_status(:ok)
        # Group search for wiki should work even when global wiki search is disabled
        expect(response.body).to include('any wiki results matching')
      end

      it 'does not redirect to projects scope when global_search_commits_enabled is false' do
        stub_ee_application_setting(global_search_commits_enabled: false)

        make_search_request(search: 'Test', scope: 'commits')
        expect(response).to have_gitlab_http_status(:ok)
        # Group search for commits should work even when global commits search is disabled
        expect(response.body).to include('any commits matching')
      end
    end

    it 'uses projects scope in group context' do
      stub_application_setting(default_search_scope: 'projects')

      make_search_request(search: 'Test')

      expect(response).to have_gitlab_http_status(:ok)
      # In group context, projects scope shows project results
      expect(response.body).to include(CGI.escapeHTML(project.path))
    end
  end

  describe 'automatic code search routing removed' do
    include_examples 'handles code search literals'
  end

  it 'uses work_items scope for search' do
    stub_application_setting(default_search_scope: 'work_items')

    get search_path, params: { search: 'Test' }

    expect(response).to have_gitlab_http_status(:ok)
    expect(response.body).to include(CGI.escapeHTML(::Gitlab::UrlBuilder.instance.issue_path(issue)))
  end

  # Advanced search (Elasticsearch) specific tests
  context 'with advanced search enabled', :elastic, :sidekiq_inline do
    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
      ensure_elasticsearch_index!
    end

    it 'uses default scope with elasticsearch backend' do
      stub_application_setting(default_search_scope: 'work_items')

      make_search_request(search: 'Test')

      expect(response).to have_gitlab_http_status(:ok)
      # Verify the search UI is showing the work_items scope as active
      # The actual results depend on elasticsearch indexing
      expect(response.body).to include('any work items matching')
    end

    it 'respects explicit scope with elasticsearch' do
      stub_application_setting(default_search_scope: 'work_items')

      make_search_request(search: 'Test', scope: 'merge_requests')

      expect(response).to have_gitlab_http_status(:ok)
      # Verify we're in merge_requests scope
      expect(response.body).to include('any merge requests matching')
    end

    it 'respects global search enabled settings for scopes' do
      # Test that global_search_work_items_enabled setting is respected
      # When disabled, it should fall back to another available scope
      stub_application_setting(default_search_scope: 'work_items', global_search_work_items_enabled: false)

      make_search_request(search: 'Test')

      expect(response).to have_gitlab_http_status(:ok)
      # Should fall back to a different scope when work_items are disabled
      expect(response.body).to include('any projects matching')
    end

    it 'respects global_search_code_enabled setting for blobs scope' do
      stub_application_setting(default_search_scope: 'blobs', global_search_code_enabled: false)

      make_search_request(search: 'Test')

      expect(response).to have_gitlab_http_status(:ok)
      # Should fall back to projects scope when code search is disabled
      expect(response.body).to include('any projects matching')
    end
  end
end
