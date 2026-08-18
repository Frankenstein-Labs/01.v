# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group routing', "routing" do
  include RSpec::Rails::RoutingExampleGroup

  before do
    allow(Group).to receive(:find_by_full_path).with('gitlabhq', any_args).and_return(true)
  end

  describe 'subgroup "boards"' do
    it 'shows group show page' do
      allow(Group).to receive(:find_by_full_path).with('gitlabhq/boards', any_args).and_return(true)

      expect(get('/groups/gitlabhq/boards')).to route_to('groups#show', id: 'gitlabhq/boards')
    end

    it 'shows boards index page' do
      expect(get('/groups/gitlabhq/-/boards')).to route_to('groups/boards#index', group_id: 'gitlabhq')
    end
  end

  describe 'security' do
    it 'shows group dashboard' do
      expect(get('/groups/gitlabhq/-/security/dashboard')).to route_to('groups/security/dashboard#show', group_id: 'gitlabhq')
    end

    it 'shows vulnerability list' do
      expect(get('/groups/gitlabhq/-/security/vulnerabilities')).to route_to('groups/security/vulnerabilities#index', group_id: 'gitlabhq')
    end
  end

  describe 'packages' do
    it 'routes to packages index page' do
      expect(get('/groups/gitlabhq/-/packages')).to route_to('groups/packages#index', group_id: 'gitlabhq')
    end
  end

  describe 'issues' do
    it 'routes post to #bulk_update' do
      expect(post('/groups/gitlabhq/-/issues/bulk_update')).to route_to('groups/issues#bulk_update', group_id: 'gitlabhq')
    end
  end

  describe 'merge_requests' do
    it 'routes post to #bulk_update' do
      expect(post('/groups/gitlabhq/-/merge_requests/bulk_update')).to route_to('groups/merge_requests#bulk_update', group_id: 'gitlabhq')
    end
  end

  describe 'epics' do
    it 'routes post to #bulk_update' do
      expect(post('/groups/gitlabhq/-/epics/bulk_update')).to route_to('groups/epics#bulk_update', group_id: 'gitlabhq')
    end
  end

  #      group_wikis_git_access GET    /:group_id/-/wikis/git_access(.:format) groups/wikis#git_access
  #           group_wikis_pages GET    /:group_id/-/wikis/pages(.:format)      groups/wikis#pages
  #             group_wikis_new GET    /:group_id/-/wikis/new(.:format)        groups/wikis#new
  #                             POST   /:group_id/-/wikis(.:format)            groups/wikis#create
  #             group_wiki_edit GET    /:group_id/-/wikis/*id/edit             groups/wikis#edit
  #          group_wiki_history GET    /:group_id/-/wikis/*id/history          groups/wikis#history
  # group_wiki_preview_markdown POST   /:group_id/-/wikis/*id/preview_markdown groups/wikis#preview_markdown
  #                  group_wiki GET    /:group_id/-/wikis/*id                  groups/wikis#show
  #                             PUT    /:group_id/-/wikis/*id                  groups/wikis#update
  #                             DELETE /:group_id/-/wikis/*id                  groups/wikis#destroy
  describe Groups::WikisController, 'routing' do
    it_behaves_like 'wiki routing' do
      let(:base_path) { '/groups/gitlabhq/-/wikis' }
      let(:base_params) { { group_id: 'gitlabhq' } }
    end
  end

  #             test_group_hook POST   /groups/:group_id/-/hooks/:id/test(.:format) hooks#test
  #                 group_hooks GET    /groups/:group_id/-/hooks(.:format)          hooks#index
  #                             POST   /groups/:group_id/-/hooks(.:format)          hooks#create
  #             edit_group_hook GET    /groups/:group_id/-/hooks/:id/edit(.:format) hooks#edit
  #                  group_hook PUT    /groups/:group_id/-/hooks/:id(.:format)      hooks#update
  #                             DELETE /groups/:group_id/-/hooks/:id(.:format)      hooks#destroy
  describe Groups::HooksController, 'routing' do
    it 'to #test' do
      expect(post('/groups/gitlabhq/-/hooks/1/test')).to route_to('groups/hooks#test', group_id: 'gitlabhq', id: '1')
    end

    it_behaves_like 'resource routing' do
      let(:actions) { %i[index create destroy edit update] }
      let(:base_path) { '/groups/gitlabhq/-/hooks' }
      let(:base_params) { { group_id: 'gitlabhq' } }
    end
  end

  #   retry_group_hook_hook_log POST   /groups/:group_id/-/hooks/:hook_id/hook_logs/:id/retry(.:format) groups/hook_logs#retry
  #         group_hook_hook_log GET    /groups/:group_id/-/hooks/:hook_id/hook_logs/:id(.:format)       groups/hook_logs#show
  describe Groups::HookLogsController, 'routing' do
    it 'to #retry' do
      expect(post('/groups/gitlabhq/-/hooks/1/hook_logs/1/retry')).to route_to('groups/hook_logs#retry', group_id: 'gitlabhq', hook_id: '1', id: '1')
    end

    it 'to #show' do
      expect(get('/groups/gitlabhq/-/hooks/1/hook_logs/1')).to route_to('groups/hook_logs#show', group_id: 'gitlabhq', hook_id: '1', id: '1')
    end
  end

  describe Groups::Settings::RolesAndPermissionsController, 'routing' do
    it 'routes to the new member role' do
      expect(get('/groups/gitlabhq/-/settings/roles_and_permissions/new')).to route_to('groups/settings/roles_and_permissions#new', group_id: 'gitlabhq')
    end
  end

  describe Groups::Settings::ServiceAccountsController, 'routing' do
    it 'routes to service accounts' do
      expect(get('/groups/gitlabhq/-/settings/service_accounts')).to route_to('groups/settings/service_accounts#index', group_id: 'gitlabhq')
    end

    it 'routes to the vue route' do
      expect(get('/groups/gitlabhq/-/settings/service_accounts/access_tokens')).to route_to('groups/settings/service_accounts#index', group_id: 'gitlabhq', vueroute: 'access_tokens')
    end
  end

  describe 'Compliance Dashboard routing' do
    it 'routes JSON framework requests to the API controller' do
      expect(get: '/groups/gitlabhq/-/security/compliance_dashboard/frameworks/123.json').to route_to(
        controller: 'groups/security/compliance_dashboard/frameworks',
        action: 'show',
        group_id: 'gitlabhq',
        id: '123',
        format: 'json'
      )
    end

    it 'does not route non-numeric IDs for JSON requests' do
      expect(get: '/groups/gitlabhq/-/security/compliance_dashboard/frameworks/abc.json').to route_to(
        controller: 'groups/security/compliance_dashboards',
        action: 'show',
        group_id: 'gitlabhq',
        vueroute: 'frameworks/abc',
        format: 'json'
      )
    end

    it 'routes non-JSON framework requests to Vue' do
      expect(get: '/groups/gitlabhq/-/security/compliance_dashboard/frameworks/123').to route_to(
        controller: 'groups/security/compliance_dashboards',
        action: 'show',
        group_id: 'gitlabhq',
        vueroute: 'frameworks/123'
      )
    end

    it 'routes arbitrary Vue paths correctly' do
      expect(get: '/groups/gitlabhq/-/security/compliance_dashboard/some/nested/path').to route_to(
        controller: 'groups/security/compliance_dashboards',
        action: 'show',
        group_id: 'gitlabhq',
        vueroute: 'some/nested/path'
      )
    end

    describe 'exports' do
      it 'routes compliance status report export' do
        expect(get: '/groups/gitlabhq/-/security/compliance_dashboard/exports/compliance_status_report.csv').to route_to(
          controller: 'groups/security/compliance_dashboard/exports',
          action: 'compliance_status_report',
          group_id: 'gitlabhq',
          format: 'csv'
        )
      end

      it 'routes violations report export' do
        expect(get: '/groups/gitlabhq/-/security/compliance_dashboard/exports/violations_report.csv').to route_to(
          controller: 'groups/security/compliance_dashboard/exports',
          action: 'violations_report',
          group_id: 'gitlabhq',
          format: 'csv'
        )
      end
    end
  end

  describe Groups::Settings::GitlabCreditsDashboardController, 'routing',
    feature_category: :consumables_cost_management do
    it 'routes / to #index' do
      expect(get('/groups/gitlabhq/-/settings/gitlab_credits_dashboard')).to route_to(
        controller: 'groups/settings/gitlab_credits_dashboard',
        action: 'index',
        group_id: 'gitlabhq'
      )
    end
  end

  describe Groups::Settings::GitlabCreditsDashboard::UsersController, 'routing',
    feature_category: :consumables_cost_management do
    it 'routes / to #show' do
      expect(get('/groups/gitlabhq/-/settings/gitlab_credits_dashboard/users/john_doe')).to route_to(
        controller: 'groups/settings/gitlab_credits_dashboard/users',
        action: 'show',
        group_id: 'gitlabhq',
        username: 'john_doe'
      )
    end

    it 'routes correctly when username contains a period' do
      expect(get('/groups/gitlabhq/-/settings/gitlab_credits_dashboard/users/john.doe')).to route_to(
        controller: 'groups/settings/gitlab_credits_dashboard/users',
        action: 'show',
        group_id: 'gitlabhq',
        username: 'john.doe'
      )
    end
  end

  describe 'duo agents platform', feature_category: :duo_agent_platform do
    it 'routes mcp-servers to duo_agents_platform#show' do
      expect(get('/groups/gitlabhq/-/automate/mcp-servers')).to route_to(
        'groups/duo_agents_platform#show',
        group_id: 'gitlabhq',
        vueroute: 'mcp-servers'
      )
    end
  end

  describe 'saml_providers', feature_category: :system_access do
    it 'routes to saml_providers#show' do
      expect(get('/groups/gitlabhq/-/saml')).to route_to('groups/saml_providers#show', group_id: 'gitlabhq')
    end

    it 'routes to saml_providers#create' do
      expect(post('/groups/gitlabhq/-/saml')).to route_to('groups/saml_providers#create', group_id: 'gitlabhq')
    end

    it 'routes to saml_providers#update' do
      expect(patch('/groups/gitlabhq/-/saml')).to route_to('groups/saml_providers#update', group_id: 'gitlabhq')
    end

    it 'routes to omniauth_callbacks#group_saml for callback' do
      expect(post('/groups/gitlabhq/-/saml/callback')).to route_to('groups/omniauth_callbacks#group_saml', group_id: 'gitlabhq')
    end

    it 'routes to sso#saml for SSO GET' do
      expect(get('/groups/gitlabhq/-/saml/sso')).to route_to('groups/sso#saml', group_id: 'gitlabhq')
    end

    it 'routes to sso#saml for SSO POST' do
      expect(post('/groups/gitlabhq/-/saml/sso')).to route_to('groups/sso#saml', group_id: 'gitlabhq')
    end

    it 'routes to sso#unlink' do
      expect(delete('/groups/gitlabhq/-/saml/unlink')).to route_to('groups/sso#unlink', group_id: 'gitlabhq')
    end

    it 'routes to saml_providers#update_microsoft_application' do
      expect(put('/groups/gitlabhq/-/saml/update_microsoft_application')).to route_to('groups/saml_providers#update_microsoft_application', group_id: 'gitlabhq')
    end
  end
end
