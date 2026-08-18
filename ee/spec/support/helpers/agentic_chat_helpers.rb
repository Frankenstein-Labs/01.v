# frozen_string_literal: true

module AgenticChatHelpers
  def ensure_duo_workflow_service_running!(max_attempts: 20, interval: 5.0)
    max_attempts.times do |attempt|
      puts "Checking Duo Workflow Service is running ... attempt: #{attempt + 1}"

      u = defined?(current_user) ? current_user : user

      result = ::CloudConnector::StatusChecks::Probes::DuoAgentPlatformProbe.new(u,
        deployment: :cloud_connected).execute

      break if result.success?

      puts "Check failure ... result: #{result.message}"

      raise 'Duo Workflow Service is not running' if attempt >= max_attempts - 1

      sleep interval
    end
  end

  def wait_for_grpc_stream_to_start!(timeout: 10)
    expect(page).to have_css('.duo-chat-loader', wait: timeout)
  end

  def wait_for_grpc_stream_to_finish!(timeout: 40)
    expect(page).to have_no_css('.duo-chat-loader', wait: timeout)
  end

  def send_message(message = nil)
    # Mock responses are generated via `AIGW_USE_AGENTIC_MOCK` in DWS
    # See https://gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist/-/blob/main/docs/workflows/agentic_mock.md
    # for more info.
    message ||= "<response>hi</response>"
    find_by_testid('chat-prompt-input').fill_in(with: message)
    send_keys :enter
  end

  def send_message_and_wait_for_stream_finished!(message = nil)
    send_message(message)
    wait_for_grpc_stream_to_start!
    wait_for_grpc_stream_to_finish!
  end

  def approve_tool
    within_testid('chat-component') do
      click_button "Approve"
    end
  end

  def approve_tool_and_wait_for_stream_finished!
    approve_tool
    wait_for_grpc_stream_to_finish!
  end

  def add_new_chat
    click_button "Add new chat"
    find('.gl-new-dropdown-item', text: 'GitLab Duo').click

    within_testid('chat-subheader') do
      expect(page).to have_content('GitLab Duo')
    end
  end

  def open_current_thread
    click_button "Active GitLab Duo Chat"
  end

  def expand_included_references_of_user_message_at(position)
    # Wait for at least `position` user messages before taking the snapshot.
    # 'Me:' is the sr-only role label rendered by duo-ui for every user message.
    expect(page).to have_css('.duo-chat-message-container', text: 'Me:', minimum: position)
    within(all('.duo-chat-message-container', text: 'Me:')[position - 1]) do
      click_button "Included reference"

      yield
    end
  end

  def cancel_response
    within_testid('chat-footer') do
      click_button "Cancel"
    end
  end

  def cancel_response_and_wait_for_stream_finished!
    cancel_response
    wait_for_grpc_stream_to_finish!
  end

  def create_rules_in_project_repository(project, files = nil)
    files ||= %w[AGENTS.md .gitlab/duo/chat-rules.md]
    u = defined?(current_user) ? current_user : user

    files.each do |file|
      project.repository.create_file(
        u,
        file,
        "content of #{file}",
        message: "Add #{file}",
        branch_name: 'master'
      )
    end

    true
  rescue # rubocop:disable Style/RescueStandardError -- any errors should be returned false
    false
  end
end
