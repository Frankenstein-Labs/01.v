# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'New project', :js, feature_category: :importers do
  include ListboxHelpers

  let(:user) { create(:admin) }
  let(:premium_plan) { create(:license, plan: License::PREMIUM_PLAN) }

  before do
    stub_application_setting(import_sources: Gitlab::ImportSources.values)

    sign_in(user)
  end

  context 'with premium license' do
    before do
      allow(License).to receive(:current).and_return(premium_plan)
    end

    it 'creates a new project in personal namespace' do
      visit(new_project_path)

      click_link 'Create blank project'

      page.within('#blank-project-pane') do
        fill_in(:project_name, with: 'Project with premium license')

        click_on 'Select a group or namespace'
        select_listbox_item user.username

        click_button('Create project')
      end

      expect(page).to have_current_path(%r{#{user.username}}, ignore_query: true)
      expect(page).to have_content("was successfully created")
      wait_for_requests

      project = Project.last
      expect(project).to be_present
      expect(page).to have_current_path(project_path(project), ignore_query: true)
    end

    it '"Import project" tab creates projects with features enabled' do
      allow(Gitlab::GitalyClient::RemoteService).to receive(:exists?).with('http://foo.com/project.git').and_return(true)

      visit new_project_path
      click_link 'Import project'
      click_link 'Repository by URL'

      wait_for_requests

      fill_in 'project[import_url]', with: 'http://foo.com/project.git'

      wait_for_requests

      click_on 'Choose a group or namespace'
      select_listbox_item user.username

      fill_in 'project[name]', with: 'import-project-with-features1'

      click_button 'Create project'

      # Import projects redirect to the import status page (ProjectsController#show
      # detects import_in_progress? and redirects to project_import_path), so the
      # "successfully created" flash is lost in the double redirect. Wait for the
      # import page content instead.
      expect(page).to have_content("Import in progress")
      wait_for_requests

      created_project = Project.last
      expect(created_project).to be_present
      expect(created_project.project_feature).to be_issues_enabled
    end
  end

  describe 'repository mirrors' do
    context 'when licensed' do
      before do
        stub_licensed_features(repository_mirrors: true)
      end

      it 'shows mirror repository checkbox enabled', :js do
        visit new_project_path
        click_link 'Import project'
        find_by_testid('new-project-import-url-button').click

        wait_for_requests

        expect(page).to have_unchecked_field('Mirror repository')

        checkbox = find_by_testid('import-project-by-url-repo-mirror')
        expect(checkbox).not_to be_disabled
      end
    end

    context 'when unlicensed' do
      before do
        stub_licensed_features(repository_mirrors: false)
      end

      it 'shows mirror repository option as disabled' do
        visit new_project_path
        click_link 'Import project'
        find_by_testid('new-project-import-url-button').click
        wait_for_requests

        checkbox = find_by_testid('import-project-by-url-repo-mirror')
        expect(checkbox).to be_disabled
      end
    end
  end

  describe 'CI/CD for external repositories', :js do
    let(:repo) do
      OpenStruct.new(
        id: 123,
        login: 'some-github-repo',
        owner: OpenStruct.new(login: 'some-github-repo'),
        name: 'some-github-repo',
        full_name: 'my-user/some-github-repo',
        clone_url: 'https://github.com/my-user/some-github-repo.git'
      )
    end

    shared_examples 'CI/CD for GitHub' do
      it 'creates CI/CD project from GitHub' do
        visit new_project_path
        click_link 'Run CI/CD for external repository'

        page.within '#ci-cd-project-pane' do
          find('.js-import-github').click
        end

        expect(page).to have_text('Authenticate with GitHub')

        octokit = instance_double(Octokit::Client,
          access_token: 'fake-token',
          organizations: [])

        allow_next_instance_of(Gitlab::GithubImport::Clients::Proxy) do |proxy|
          allow(proxy).to receive(:repos).and_return({ repos: [repo] })
        end
        allow_next_instance_of(Gitlab::GithubImport::Client) do |client|
          allow(client).to receive(:user).and_return({ login: 'my-user' })
          allow(client).to receive_message_chain(:octokit, :rate_limit)
          allow(client).to receive(:octokit).and_return(octokit)
        end

        allow(octokit).to receive_message_chain(:rate_limit, :remaining).and_return(100)
        allow(octokit).to receive(:repository).and_return({ status: 200 })
        allow(octokit).to receive(:collaborators).and_return({ status: 200 })

        fill_in 'personal_access_token', with: 'fake-token'

        click_button 'Authenticate'
        wait_for_requests

        # Wait for the repo table to fully render before creating the project.
        # This ensures the initial status.json (fetched when Vue mounts, which
        # can happen after wait_for_requests returns) sees the repo as 'none'.
        # Once importedProject is null in the Vuex store, realtime_changes
        # polling cannot update it via RECEIVE_JOBS_SUCCESS, so the repo stays
        # as 'none' and a single Connect click opens the memberships modal.
        expect(page).to have_button('Connect')

        # Mock the POST `/import/github`
        allow_any_instance_of(Gitlab::GithubImport::Client).to receive(:repository).and_return(repo)
        project = create(
          :project,
          name: 'some-github-repo', creator: user,
          import_type: 'github', import_source: 'my-user/some-github-repo'
        )
        create(:import_state, :finished, import_url: repo.clone_url, project: project)
        allow_any_instance_of(CiCd::SetupProject).to receive(:setup_external_service)
        CiCd::SetupProject.new(project, user).execute
        allow_any_instance_of(Gitlab::LegacyGithubImport::ProjectCreator)
          .to receive(:execute).with(hash_including(ci_cd_only: true))
          .and_return(project)

        # Avoid click_button since this has been patched to call
        # wait_for_requests, which might wait endlessly since the
        # frontend polls the import status constantly.
        find(:button, 'Connect').click
        wait_for_requests
        find(:button, 'Continue import').click

        expect(page).to have_text('Complete')

        created_project = Project.last
        expect(created_project.name).to eq('some-github-repo')
        expect(created_project.mirror).to be(true)
        expect(created_project.project_feature).not_to be_issues_enabled
      end

      it 'redirects to configuration page after access token failure' do
        visit new_project_path
        click_link 'Run CI/CD for external repository'

        page.within '#ci-cd-project-pane' do
          find('.js-import-github').click
        end

        allow_next_instance_of(Gitlab::GithubImport::Client) do |client|
          allow(client).to receive(:search_repos_by_name_graphql).and_raise(Octokit::Unauthorized)
        end

        fill_in 'personal_access_token', with: 'unauthorized-fake-token'
        click_button 'Authenticate'

        expect(page).to have_current_path(new_import_github_path(ci_cd_only: true))
      end
    end

    context 'when licensed' do
      before do
        stub_licensed_features(ci_cd_projects: true)
      end

      it 'shows CI/CD tab and pane' do
        visit new_project_path

        expect(page).to have_link 'Run CI/CD for external repository'

        click_link 'Run CI/CD for external repository'

        expect(page).to have_css('#ci-cd-project-pane')
      end

      it 'creates CI/CD project from repo URL', :sidekiq_might_not_need_inline do
        visit new_project_path
        click_link 'Run CI/CD for external repository'

        allow(Gitlab::GitalyClient::RemoteService).to receive(:exists?).with('http://foo.git').and_return(true)

        page.within '#ci-cd-project-pane' do
          find('.js-import-git-toggle-button').click

          fill_in 'project_import_url', with: 'http://foo.git'
          fill_in 'project_name', with: 'CI CD Project1'
          fill_in 'project_path', with: 'ci-cd-project1'
          click_on 'Select a group or namespace'
          select_listbox_item user.username
          choose 'project_visibility_level_20'
          click_button 'Create project'
        end

        expect(page).to have_content("was successfully created")
        wait_for_requests

        created_project = Project.last
        expect(created_project).to be_present
        expect(created_project.mirror).to be(true)
        expect(created_project.project_feature).not_to be_issues_enabled
      end

      it_behaves_like 'CI/CD for GitHub'
    end

    context 'when available through usage ping features' do
      before do
        stub_usage_ping_features(true)
      end

      it_behaves_like 'CI/CD for GitHub'
    end

    context 'when unlicensed' do
      before do
        stub_licensed_features(ci_cd_projects: false)
      end

      it 'does not show CI/CD only tab' do
        visit new_project_path

        expect(page).not_to have_text 'Run CI/CD for external repository'
      end
    end
  end

  describe 'Group-level project templates', :js do
    let(:template_group) do
      create(:group, project_creation_level: ::Gitlab::Access::MAINTAINER_PROJECT_ACCESS).tap do |group|
        group.add_maintainer(user)
      end
    end

    let(:url) { new_project_path }

    context 'when licensed' do
      before do
        stub_licensed_features(custom_project_templates: true, group_project_templates: true)
      end

      shared_examples 'shows Group tab without badge count' do
        it 'shows Group tab without badge count' do
          visit url
          click_link 'Create from template'

          expect(page).to have_link('Instance', href: '#custom-instance-project-templates')
          expect(page).to have_link('Built-in', href: '#built-in')
          expect(page).to have_link('Group', href: '#custom-group-project-templates')
          expect(page).not_to have_css('[data-testid="group-template-tab-badge-content"]')
        end

        context 'when SaaS', :saas, :with_namespace_eligible_trials do
          it 'hides Instance tab and shows Group tab without badge count' do
            visit url
            click_link 'Create from template'

            expect(page).not_to have_link('Instance', href: '#custom-instance-project-templates')
            expect(page).to have_link('Built-in', href: '#built-in')
            expect(page).to have_link('Group', href: '#custom-group-project-templates')
            expect(page).not_to have_css('[data-testid="group-template-tab-badge-content"]')
          end
        end
      end

      shared_examples 'shows Group tab with badge count' do
        it 'shows all template tabs with Group badge count' do
          visit url
          click_link 'Create from template'

          expect(page).to have_link('Instance', href: '#custom-instance-project-templates')
          expect(page).to have_link('Built-in', href: '#built-in')
          expect(page).to have_link('Group', href: '#custom-group-project-templates')
          expect(page).to have_css('[data-testid="group-template-tab-badge-content"]')
        end

        context 'when SaaS', :saas, :with_namespace_eligible_trials do
          it 'hides Instance tab and shows Group tab with badge count' do
            visit url
            click_link 'Create from template'

            expect(page).not_to have_link('Instance', href: '#custom-instance-project-templates')
            expect(page).to have_link('Built-in', href: '#built-in')
            expect(page).to have_link('Group', href: '#custom-group-project-templates')
            expect(page).to have_css('[data-testid="group-template-tab-badge-content"]')
          end
        end
      end

      context 'when no namespace_id is passed' do
        it_behaves_like 'shows Group tab without badge count'
      end

      context 'when namespace_id is empty' do
        let(:url) { new_project_path(namespace_id: '') }

        it_behaves_like 'shows Group tab without badge count'
      end

      context 'when namespace_id is invalid' do
        let(:url) { new_project_path(namespace_id: non_existing_record_id) }

        it 'returns 404 to protect against namespace enumeration' do
          visit url

          expect(page).to have_content('Page not found')
        end
      end

      context 'when namespace_id is for a user namespace' do
        let(:url) { new_project_path(namespace_id: user.namespace_id) }

        it_behaves_like 'shows Group tab without badge count'
      end

      context 'when namespace_id matches a group user can create projects in' do
        let(:url) { new_project_path(namespace_id: template_group.id) }

        it_behaves_like 'shows Group tab with badge count'
      end

      context 'when namespace_id matches a group user cannot create projects in' do
        let(:restricted_group) do
          create(:group, project_creation_level: ::Gitlab::Access::MAINTAINER_PROJECT_ACCESS).tap do |group|
            group.add_developer(user)
          end
        end

        let(:url) { new_project_path(namespace_id: restricted_group.id) }

        it 'returns 404 to protect against group enumeration' do
          visit url

          expect(page).to have_content('Page not found')
        end
      end
    end

    context 'when unlicensed' do
      before do
        stub_licensed_features(custom_project_templates: false)
      end

      it 'does not show Group tab in Templates section' do
        visit url
        click_link 'Create from template'

        expect(page).not_to have_css('.custom-group-project-templates-tab')
      end
    end
  end

  describe 'Built-in project templates' do
    let(:enterprise_templates) { Gitlab::ProjectTemplate.localized_ee_templates_table }

    context 'when `enterprise_templates` is licensed', :js do
      before do
        stub_licensed_features(enterprise_templates: true)
      end

      it 'shows enterprise templates' do
        visit_create_from_built_in_templates_tab

        enterprise_templates.each do |template|
          expect(page).to have_content(template.title)
          expect(page).to have_link('Preview', href: template.preview)
        end
      end
    end

    context 'when `enterprise_templates` is unlicensed', :js do
      before do
        stub_licensed_features(enterprise_templates: false)
      end

      it 'does not show enterprise templates' do
        visit_create_from_built_in_templates_tab

        enterprise_templates.each do |template|
          expect(page).not_to have_content(template.title)
          expect(page).not_to have_link('Preview', href: template.preview)
        end
      end
    end

    private

    def visit_create_from_built_in_templates_tab
      visit new_project_path

      click_link 'Create from template'
    end
  end
end
