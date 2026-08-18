# frozen_string_literal: true

require 'spec_helper'
require_relative "../../support/helpers/remote_development/integration_spec_helpers"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe 'Remote Development workspaces', :freeze_time, :api, :js, feature_category: :workspaces do
  include RemoteDevelopment::IntegrationSpecHelpers

  include_context "with constant modules"

  include_context 'with remote development shared fixtures'
  include_context 'file upload requests helpers'
  include_context 'with kubernetes agent service'

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, name: 'test-group', developers: user, owners: user) }
  let_it_be(:devfile_path) { '.devfile.yaml' }

  let_it_be(:project) do
    files = { devfile_path => example_devfile_yaml }
    create(:project, :public, :in_group, :custom_repo, path: 'test-project', files: files, namespace: group)
  end

  let_it_be(:image_pull_secrets) { [{ name: 'secret-name', namespace: 'secret-namespace' }] }

  let_it_be_with_refind(:agent) { create(:cluster_agent, project: project, created_by_user: user) }
  let_it_be_with_refind(:workspaces_agent_config) do
    create(:workspaces_agent_config, agent: agent, image_pull_secrets: image_pull_secrets)
  end

  let_it_be(:agent_token) { create(:cluster_agent_token, agent: agent, created_by_user: user) }

  let(:variable_key) { "VAR1" }
  let(:variable_value) { "value 1" }
  let(:workspaces_group_settings_path) { "/groups/#{group.name}/-/settings/workspaces" }

  let(:user_defined_commands) do
    [
      {
        id: "db-component-command-with-working-dir",
        exec: {
          component: "database-container",
          commandLine: "echo 'executes postStart command in the specified workingDir'",
          workingDir: "test-dir",
          hotReloadCapable: false
        }
      },
      {
        id: "db-component-command-without-working-dir",
        exec: {
          component: "database-container",
          commandLine: "echo 'executes postStart command in the the container's default WORKDIR'",
          hotReloadCapable: false
        }
      },
      {
        id: "main-component-command-without-working-dir",
        exec: {
          component: "tooling-container",
          commandLine: "echo 'executes postStart command in the projects/project_path directory'",
          hotReloadCapable: false
        }
      },
      {
        id: "user-defined-command",
        exec: {
          component: "tooling-container",
          commandLine: "echo 'executes postStart command in the specified workingDir'",
          workingDir: "test-dir",
          hotReloadCapable: false
        }
      }
    ]
  end

  # @param [String] state
  # @return [void]
  def expect_workspace_state_indicator(state)
    indicator = find_by_testid('workspace-state-indicator')

    expect(indicator).to have_text(state)

    nil
  end

  # @param [String] agent_name
  # @param [String] group_name
  # @return [void]
  def do_create_mapping(agent_name:, group_name:)
    workspaces_group_settings_path = "/groups/#{group_name}/-/settings/workspaces"
    gitlab_badge_selector = '.gl-badge-content'
    visit workspaces_group_settings_path
    wait_for_requests

    # enable agent for group
    click_link 'All agents'
    expect(page).to have_content agent_name
    first_agent_row_selector = 'tbody tr:first-child'
    expect(page).not_to have_selector(gitlab_badge_selector, text: 'Allowed')
    within first_agent_row_selector do
      click_button 'Allow'
      wait_for_requests
    end

    click_button 'Allow agent'

    expect(page).to have_selector(gitlab_badge_selector, text: 'Allowed')

    nil
  end

  # @param [Hash] params
  # @param [QA::Resource::Clusters::AgentToken] agent_token
  # @return [Hash] response_json with deep symbolized keys
  def do_reconcile_post(params:, agent_token:)
    # Custom logic to perform the reconcile post for a _FEATURE_ (Capybara) spec

    agent_token_headers = { 'Content-Type' => 'application/json' }
    reconcile_url = capybara_url(
      api('/internal/kubernetes/modules/remote_development/reconcile', personal_access_token: agent_token)
    )

    # Note: HTTParty doesn't handle empty arrays right, so we have to be explicit with content type and send JSON.
    #       See https://github.com/jnunemaker/httparty/issues/494
    reconcile_post_response = HTTParty.post(
      reconcile_url,
      headers: agent_token_headers,
      body: params.compact.to_json
    )

    expect(reconcile_post_response.code).to eq(HTTP::Status::CREATED)

    json_response = Gitlab::Json.safe_parse(reconcile_post_response.body)

    # noinspection RubyMismatchedReturnType -- Typing is wrong, RubyMine doesn't think this returns a Hash
    json_response.deep_symbolize_keys
  end

  shared_examples 'workspace lifecycle' do
    before do
      stub_licensed_features(remote_development: true)
      allow(Gitlab::Kas).to receive(:verify_api_request).and_return(true)

      # rubocop:disable RSpec/AnyInstanceOf -- It's NOT the next instance...
      allow_any_instance_of(Gitlab::Auth::AuthFinders)
        .to receive(:cluster_agent_token_from_authorization_token) { agent_token }
      # rubocop:enable RSpec/AnyInstanceOf

      sign_in(user)
      wait_for_requests
    end

    it "successfully exercises the full lifecycle of a workspace", :unlimited_max_formatted_output_length do
      # Tips:
      # use live_debug to pause when WEBDRIVER_HEADLESS=0
      # live_debug

      # CREATE THE MAPPING, SO WE HAVE PROPER AUTHORIZATION
      do_create_mapping(agent_name: agent.name, group_name: group.name)

      # NAVIGATE TO WORKSPACES PAGE
      # noinspection RubyResolve -- https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      visit remote_development_workspaces_path
      wait_for_requests

      # CREATE WORKSPACE

      click_link 'New workspace', match: :first
      click_button 'Select a project'
      find_by_testid("listbox-item-#{project.full_path}").click
      wait_for_requests
      # noinspection RubyMismatchedArgumentType -- Rubymine is finding the wrong `select`
      select agent.name, from: 'Cluster agent'
      # this field should be autofilled when selecting agent
      click_button 'Add variable'
      fill_in 'Variable Key', with: variable_key
      fill_in 'Variable Value', with: variable_value
      click_button 'Create workspace'

      # We look for the project GID because that's all we know about the workspace at this point. For the new UI,
      # we will have to either expose this as a field on the new workspaces UI, or else come up
      # with some more clever finder to assert on the workspace showing up in the list after a refresh.
      page.find('span[data-testid="workspaces-project-name"]', text: project.name_with_namespace)

      # GET NAME AND NAMESPACE OF NEW WORKSPACE
      workspaces = RemoteDevelopment::Workspace.all.to_a
      expect(workspaces.length).to eq(1)
      workspace = workspaces[0]

      # ASSERT ON NEW WORKSPACE IN LIST
      expect(page).to have_content(workspace.name)

      # ASSERT WORKSPACE STATE BEFORE POLLING NEW STATES
      expect_workspace_state_indicator('Creating')

      # ASSERT TERMINATE BUTTON IS AVAILABLE
      click_button 'Actions'
      expect(page).to have_button('Terminate')

      # CLOSE THE ACTIONS DROPDOWN
      click_button 'Actions'

      additional_args_for_expected_config_to_apply =
        build_additional_args_for_expected_config_to_apply_yaml_stream(
          network_policy_enabled: true,
          dns_zone: workspaces_agent_config.dns_zone,
          namespace_path: group.path,
          project_name: project.path,
          image_pull_secrets: image_pull_secrets,
          user_defined_commands: user_defined_commands
        )

      # SIMULATE RECONCILE RESPONSE TO AGENTK SENDING NEW WORKSPACE
      simulate_first_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states_module::CREATION_REQUESTED,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO RUNNING ACTUAL_STATE
      simulate_second_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states_module::RUNNING,
        **additional_args_for_expected_config_to_apply
      )

      # ASSERT WORKSPACE SHOWS RUNNING STATE IN UI AND UPDATES URL
      expect_workspace_state_indicator(states_module::RUNNING)
      expect(find_open_workspace_button).to have_text('Open workspace')
      expect(find_open_workspace_button[:href]).to eq(workspace.url)

      # ASSERT ACTION BUTTONS ARE CORRECT FOR RUNNING STATE
      click_button 'Actions'
      expect(page).to have_button('Stop')
      expect(page).to have_button('Terminate')

      # UPDATE WORKSPACE DESIRED_STATE TO STOPPED
      click_button 'Stop'

      # ASSERT WORKSPACE SHOWS STOPPING STATE IN UI
      expect_workspace_state_indicator(states_module::STOPPING)

      # ASSERT ACTION BUTTONS ARE CORRECT FOR STOPPING STATE
      click_button 'Actions'
      expect(page).to have_button('Terminate')

      # SIMULATE RECONCILE RESPONSE TO AGENTK UPDATING WORKSPACE TO STOPPED DESIRED_STATE
      simulate_third_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states_module::RUNNING,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO STOPPING ACTUAL_STATE
      simulate_fourth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states_module::STOPPING,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO STOPPED ACTUAL_STATE
      simulate_fifth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states_module::STOPPED,
        **additional_args_for_expected_config_to_apply
      )

      # ASSERT WORKSPACE SHOWS STOPPED STATE IN UI
      expect_workspace_state_indicator(states_module::STOPPED)

      # ASSERT ACTION BUTTONS ARE CORRECT FOR STOPPED STATE
      expect(page).to have_button('Start')
      expect(page).to have_button('Terminate')

      # SIMULATE RECONCILE RESPONSE TO AGENTK FOR PARTIAL RECONCILE TO SHOW NO RAILS_INFOS ARE SENT
      simulate_sixth_poll(agent_token: agent_token)

      # SIMULATE RECONCILE RESPONSE TO AGENTK FOR FULL RECONCILE TO SHOW ALL WORKSPACES ARE SENT IN RAILS_INFOS
      simulate_seventh_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states_module::STOPPED,
        **additional_args_for_expected_config_to_apply
      )

      # UPDATE WORKSPACE DESIRED_STATE BACK TO RUNNING
      click_button 'Start'

      # ASSERT WORKSPACE SHOWS STARTING STATE IN UI AND UPDATES URL
      expect_workspace_state_indicator(states_module::STARTING)

      # SIMULATE RECONCILE RESPONSE TO AGENTK UPDATING WORKSPACE TO RUNNING DESIRED_STATE
      simulate_eighth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states_module::STOPPED,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO RUNNING ACTUAL_STATE
      simulate_ninth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states_module::RUNNING,
        # TRAVEL FORWARD IN TIME MAX_ACTIVE_HOURS_BEFORE_STOP HOURS
        time_to_travel_after_poll: workspace.workspaces_agent_config.max_active_hours_before_stop.hours,
        **additional_args_for_expected_config_to_apply
      )

      # ASSERT WORKSPACE SHOWS RUNNING STATE IN UI AND UPDATES URL
      expect_workspace_state_indicator(states_module::RUNNING)

      # SIMULATE RECONCILE RESPONSE TO AGENTK UPDATING WORKSPACE TO STOPPED DESIRED_STATE
      simulate_tenth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states_module::RUNNING,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO STOPPING ACTUAL_STATE
      simulate_eleventh_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states_module::STOPPING,
        **additional_args_for_expected_config_to_apply
      )

      # ASSERT WORKSPACE SHOWS STOPPING STATE IN UI
      expect_workspace_state_indicator(states_module::STOPPING)

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO STOPPED ACTUAL_STATE
      simulate_twelfth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states_module::STOPPED,
        # TRAVEL FORWARD IN TIME MAX_STOPPED_HOURS_BEFORE_TERMINATION HOURS
        time_to_travel_after_poll: workspace.workspaces_agent_config.max_stopped_hours_before_termination.hours,
        **additional_args_for_expected_config_to_apply
      )

      # ASSERT WORKSPACE SHOWS STOPPED STATE IN UI
      expect_workspace_state_indicator(states_module::STOPPED)

      # SIMULATE RECONCILE RESPONSE TO AGENTK UPDATING WORKSPACE TO TERMINATED DESIRED_STATE
      simulate_thirteenth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states_module::TERMINATED,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO TERMINATING ACTUAL_STATE
      simulate_fourteenth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states_module::TERMINATING,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO TERMINATED ACTUAL_STATE
      simulate_fifteenth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        **additional_args_for_expected_config_to_apply
      )
    end
  end

  # @return [Object]
  def find_open_workspace_button
    page.first('[data-testid="workspace-open-button"]', minimum: 0)
  end

  describe "a happy path workspace lifecycle" do
    # NOTE: Even though this is only called once, we leave it as a shared example, so that we can easily
    #       introduce additional contexts with different behavior for temporary feature flag testing.
    it_behaves_like 'workspace lifecycle'
  end
end
