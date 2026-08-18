# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe 'Remote Development workspaces dropdown group', :api, :js, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'
  include_context 'file upload requests helpers'

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, name: 'test-group', developers: user) }

  let_it_be(:devfile_path) { '.devfile.yaml' }

  let_it_be(:project) do
    files = { devfile_path => example_devfile_yaml }
    create(:project, :public, :in_group, :custom_repo, path: 'test-project', files: files, namespace: group)
  end

  let_it_be(:agent) do
    create(:ee_cluster_agent, :with_existing_workspaces_agent_config, project: project, created_by_user: user)
  end

  let_it_be(:agent_token) { create(:cluster_agent_token, agent: agent, created_by_user: user) }

  let_it_be(:workspace) do
    create(:workspace, user: user, updated_at: 2.days.ago, project_id: project.id,
      actual_state: states_module::RUNNING,
      desired_state: states_module::RUNNING
    )
  end

  let(:workspaces_dropdown_selector) { '[data-testid="workspaces-dropdown-group"]' }

  before do
    allow(Gitlab::Kas).to receive(:verify_api_request).and_return(true)

    stub_licensed_features(remote_development: true)

    # rubocop:disable RSpec/AnyInstanceOf -- It's NOT the next instance...
    allow_any_instance_of(Gitlab::Auth::AuthFinders)
      .to receive(:cluster_agent_token_from_authorization_token).and_return(agent_token)
    # rubocop:enable RSpec/AnyInstanceOf

    sign_in(user)
  end

  shared_examples 'handles workspaces dropdown group visibility' do |feature_available, visible|
    before do
      stub_licensed_features(remote_development: feature_available)

      visit subject
    end

    context "when remote_development feature availability=#{feature_available}" do
      it 'does not display workspaces dropdown group' do
        click_code_dropdown

        expect(page.has_css?(workspaces_dropdown_selector)).to be(visible)
      end
    end
  end

  shared_examples 'views and manages workspaces in workspaces dropdown group' do
    let_it_be(:cluster_agent_mapping) do
      create(
        :namespace_cluster_agent_mapping,
        user: user, agent: agent,
        namespace: group
      )
    end

    it_behaves_like 'handles workspaces dropdown group visibility', true, true
    it_behaves_like 'handles workspaces dropdown group visibility', false, false

    context 'when workspaces dropdown group is visible' do
      before do
        visit subject

        click_code_dropdown
      end

      it 'allows navigating to the new workspace page' do
        click_link 'New workspace'

        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        expect(page.current_url).to include(
          "#{new_remote_development_workspace_path}?project=#{project.full_path.gsub('/', '%2F')}"
        )
        expect(page).to have_css('button', text: project.name_with_namespace)
      end

      it 'allows managing a user workspace' do
        # Asserts workspace is displayed
        expect(page).to have_content(workspace.name)

        # Asserts the workspace state is correctly displayed
        expect_workspace_state_indicator(workspace.actual_state)

        within_testid('workspace-actions-dropdown') do
          click_button('Actions')
        end

        # Asserts that all workspace actions are visible
        expect(page).to have_button('Stop')
        expect(page).to have_button('Terminate')

        click_button('Stop')

        # Ensures that the user can change a workspace state
        expect(page).to have_content('Stopping')
      end

      # @param [String] state
      # @return [void]
      def expect_workspace_state_indicator(state)
        indicator = find_by_testid("workspace-state-indicator")

        expect(indicator).to have_text(state)

        nil
      end
    end
  end

  describe 'when viewing project overview page' do
    subject { project_path(project) }

    # @return [void]
    def click_code_dropdown
      find_by_testid("code-dropdown").click

      nil
    end

    it_behaves_like 'views and manages workspaces in workspaces dropdown group'
  end

  describe 'when viewing blob page' do
    # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
    subject { project_blob_path(project, "#{project.default_branch}/#{devfile_path}") }

    # @return [void]
    def click_code_dropdown
      click_button 'Edit'

      nil
    end

    it_behaves_like 'views and manages workspaces in workspaces dropdown group'
  end
end
