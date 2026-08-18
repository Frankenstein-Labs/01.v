# frozen_string_literal: true

RSpec.shared_context 'with duo workflow service' do
  include AgenticChatHelpers

  let(:model_definitions) do
    {
      'models' => [
        { 'name' => 'Claude Sonnet', 'identifier' => 'claude_sonnet_4_5_20250929' },
        { 'name' => 'Claude Haiku', 'identifier' => 'claude_haiku_4_5_20251001' }
      ],
      'unit_primitives' => [
        {
          'feature_setting' => 'duo_agent_platform_agentic_chat',
          'default_model' => 'claude_sonnet_4_5_20250929',
          'selectable_models' => %w[claude_sonnet_4_5_20250929 claude_haiku_4_5_20251001],
          'beta_models' => []
        }
      ]
    }
  end

  let(:model_definitions_response) { model_definitions.to_json }

  before do
    # Write-only skips the full checkpoint row; the incremental read path is not
    # yet live, so keep it off here where the flow still reads full checkpoints.
    stub_feature_flags(duo_ui_next: false, use_generic_gitlab_api_tools: false,
      agentic_chat_flow_registry_migration: false, duo_workflow_write_incremental_only: false)

    allow_next_instance_of(::Gitlab::Llm::DuoChat) do |instance|
      allow(instance).to receive(:credits_available?).and_return(true)
    end

    stub_config(
      duo_workflow: {
        service_url: "0.0.0.0:#{Tasks::Gitlab::AiGateway::Utils.duo_workflow_service_port}",
        secure: false
      }
    )

    stub_request(:get, "https://cloud.gitlab.com/ai/v1/models%2Fdefinitions")
      .to_return(
        status: 200,
        body: model_definitions_response,
        headers: { 'Content-Type' => 'application/json' }
      )

    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')

    # Currently this health check runs for each test case while the DWS instance runs throughout the test cases.
    # This is because the health check uses the ListToolsRequest gRPC and the request requires
    # a user instance with stub_config configured to point duo_workflow.service_url to the DWS.
    # (at the moment, a proper health check RPC is not implemented yet)
    ensure_duo_workflow_service_running!
  end
end

RSpec.shared_examples 'user can use agentic chat' do
  context 'when using duo agentic chat', :duo_workflow_service do
    include_context 'with duo workflow service'

    it 'allows basic UI interactions' do
      visit subject

      # opens AI sidepanel
      expect(page).to have_selector("[data-testid='add-new-agent-toggle']")
      expect(page).to have_selector("[data-testid='ai-chat-toggle']")
      expect(page).to have_selector("[data-testid='ai-history-toggle']")
      expect(page).to have_selector("[data-testid='ai-sessions-toggle']")
      expect(page).not_to have_selector("[data-testid='chat-component']")

      open_current_thread

      within_testid('chat-component') do
        expect(page).to have_content('GitLab Duo Agent Platform')
      end

      # Ask a question - Mock responses are generated via `AIGW_USE_AGENTIC_MOCK`
      question = 'dummy-question'
      expected_answer = 'mock'
      send_message_and_wait_for_stream_finished!(question)

      within_testid('chat-component') do
        expect(page).to have_content(question)
        expect(page).to have_content(expected_answer)
      end

      # Check the chat history
      click_button 'GitLab Duo Chat history'

      within_testid('chat-history') do
        expect(page).to have_content(question)
      end

      # Go back to the active conversation to check the history is loaded
      open_current_thread

      within_testid('chat-component') do
        expect(page).to have_content(question)
        expect(page).to have_content(expected_answer)
      end

      # Ask a question again
      question_2 = 'dummy-question-2'
      send_message_and_wait_for_stream_finished!(question_2)

      within_testid('chat-component') do
        expect(page).to have_content(question_2)
        expect(page).to have_content(expected_answer)
      end
    end

    it 'shows session ID dropdown during active chat' do
      visit subject

      open_current_thread
      send_message_and_wait_for_stream_finished!

      # The "More options" button (ellipsis dropdown) should appear
      # once a workflow is active and session ID has been emitted.
      # Scope within the AI panel to avoid ambiguity with other
      # "More options" buttons on the page (e.g., issue sidebar).
      within('#ai-panel-portal') do
        more_options = find_button('More options')
        # Hover the button first to dismiss any unrelated tooltips
        # (e.g., sidebar shortcut hints) that may overlay it
        more_options.hover
        more_options.click
      end

      expect(page).to have_content('Copy Chat Session ID')
    end

    it 'allows user to cancel mid-stream and retry' do
      visit subject

      # opens AI sidepanel
      click_button "Active GitLab Duo Chat"

      within_testid('chat-component') do
        expect(page).to have_content('GitLab Duo Agent Platform')
      end

      # Ask a question with a slow streaming response so we can cancel mid-stream.
      # This message makes LLM and DWS streaming the response for 10 seconds (10 words * 1 second)
      user_msg = "<response stream='true' chunk_delay_ms='1000'>1 2 3 4 5 6 7 8 9 10</response>"
      send_message(user_msg)

      # Wait for user message + in-progress assistant message to appear,
      # and for streaming to actually begin (partial content visible) before cancelling
      within_testid('chat-history') do
        expect(page).to have_css('.duo-chat-message', count: 2)
      end

      # Cancel the in-progress response
      cancel_response_and_wait_for_stream_finished!

      # Send a follow-up message to verify chat is still functional after cancellation
      retry_msg = "<response>workflow retried</response>"
      send_message_and_wait_for_stream_finished!(retry_msg)

      # Expect 4 messages: original user msg, cancelled assistant msg, retry user msg, retry assistant msg
      within_testid('chat-history') do
        expect(page).to have_css('.duo-chat-message', count: 4)
        expect(page).to have_content('workflow retried')
      end
    end

    it 'allows user to cancel before response arrives and retry' do
      visit subject

      # opens AI sidepanel
      click_button "Active GitLab Duo Chat"

      within_testid('chat-component') do
        expect(page).to have_content('GitLab Duo Agent Platform')
      end

      # Ask a question with a slow streaming response so we have time to cancel before it arrives.
      # This message makes LLM and DWS waits for 10 seconds before the response streaming starts.
      user_msg = "<response stream='true' latency_ms='10000'>slow initial response</response>"
      send_message(user_msg)

      # Cancel immediately, before chat-history updates with an assistant message
      cancel_response_and_wait_for_stream_finished!

      # Send a follow-up message to verify chat is still functional after early cancellation
      retry_msg = "<response>workflow retried</response>"
      send_message_and_wait_for_stream_finished!(retry_msg)

      within_testid('chat-history') do
        expect(page).to have_content('workflow retried')
      end
    end

    it 'allows user to ask about entity' do
      skip unless defined?(container) && defined?(entity)

      visit subject

      # opens AI sidepanel
      click_button "Active GitLab Duo Chat"

      within_testid('chat-component') do
        expect(page).to have_content('GitLab Duo Agent Platform')
      end

      # Ask a question - Mock responses are generated via `AIGW_USE_AGENTIC_MOCK`
      tool_call = { name: "", args: {} }
      expected_label = nil
      expected_secondary = nil

      if entity.is_a?(::Issue) || entity.is_a?(::Epic)
        tool_call[:name] = "get_work_item"
        tool_call[:args][:work_item_iid] = entity.iid
        expected_label = "Read work item"
        expected_secondary = "##{entity.iid}"
      elsif entity.is_a?(::MergeRequest)
        tool_call[:name] = "get_merge_request"
        tool_call[:args][:merge_request_iid] = entity.iid
        expected_label = "Read merge request"
        expected_secondary = "!#{entity.iid}"
      else
        raise NotImplementedError
      end

      expected_project_chip = nil

      if container.is_a?(::Project)
        tool_call[:args][:project_id] = container.id
        expected_project_chip = "Project: #{container.id}"
      elsif container.is_a?(::Group)
        tool_call[:args][:group_id] = container.id
      else
        raise NotImplementedError
      end

      tool_calls = [tool_call]
      agent_msg_1 = "<response>I should search the entity<tool_calls>#{tool_calls.to_json}</tool_calls></response>"
      agent_msg_2 = "<response>Found the entity</response>"
      user_msg = "<responses>#{agent_msg_1}#{agent_msg_2}</responses>"
      send_message_and_wait_for_stream_finished!(user_msg)

      # Check agent response
      within_testid('chat-component') do
        expect(page).to have_content('I should search the entity')
        expect(page).to have_selector('[data-testid="tool-row-label"]',
          text: expected_label, visible: :all)

        if expected_secondary
          expect(page).to have_selector('[data-testid="tool-row-secondary"]',
            text: expected_secondary, visible: :all)
        end

        if expected_project_chip
          expect(page).to have_selector('[data-testid="tool-message-project-info"]',
            text: expected_project_chip, visible: :all)
        end

        expect(page).to have_content('Found the entity')
      end
    end

    it 'allows user to create a new entity' do
      skip unless defined?(container) && defined?(entity)

      visit subject

      # opens AI sidepanel
      click_button "Active GitLab Duo Chat"

      within_testid('chat-component') do
        expect(page).to have_content('GitLab Duo Agent Platform')
      end

      # Ask a task. Mock responses are generated via `AIGW_USE_AGENTIC_MOCK`
      tool_call = { name: "", args: {} }
      expected_tool_message = ""
      assert_db = nil

      if entity.is_a?(::Issue) && container.is_a?(::Project)
        tool_call[:name] = "create_work_item"
        tool_call[:args][:title] = "New issue"
        tool_call[:args][:type_name] = "Issue"
        tool_call[:args][:project_id] = container.id
        expected_tool_message = "Create work item"

        assert_db = -> do
          expect(::Issue.exists?(title: "New issue", project_id: container.id)).to be(true)
        end
      elsif entity.is_a?(::Epic) && container.is_a?(::Group)
        tool_call[:name] = "create_work_item"
        tool_call[:args][:title] = "New epic"
        tool_call[:args][:type_name] = "Epic"
        tool_call[:args][:group_id] = container.id
        expected_tool_message = "Create work item"

        assert_db = -> do
          expect(::Epic.exists?(title: "New epic", group_id: container.id)).to be(true)
        end
      elsif entity.is_a?(::MergeRequest) && container.is_a?(::Project)
        entity.destroy! # Destroying the MR at first as a duplicate MR can't be created.

        tool_call[:name] = "create_merge_request"
        tool_call[:args][:title] = "New feature"
        tool_call[:args][:project_id] = container.id
        tool_call[:args][:source_branch] = entity.source_branch
        tool_call[:args][:target_branch] = entity.target_branch
        expected_tool_message = "Create merge request"

        assert_db = -> do
          expect(::MergeRequest.exists?(title: "New feature", project_id: container.id)).to be(true)
        end
      else
        raise NotImplementedError
      end

      tool_calls = [tool_call]
      agent_msg_1 = "<response>I should create a new entity<tool_calls>#{tool_calls.to_json}</tool_calls></response>"
      agent_msg_2 = "<response>Entity created</response>"
      user_msg = "<responses>#{agent_msg_1}#{agent_msg_2}</responses>"
      send_message_and_wait_for_stream_finished!(user_msg)

      # Approve the tool use
      approve_tool_and_wait_for_stream_finished!

      # Check agent response
      within_testid('chat-component') do
        expect(page).to have_content('I should create a new entity')
        expect(page).to have_content(expected_tool_message)
        expect(page).to have_content('Approved')
        expect(page).to have_content('Entity created')
      end

      # Check internal DB record that the entity was persisted.
      assert_db&.call
    end

    it 'allows user to select a custom agent' do
      visit subject

      # Show the list of agents
      click_button "Add new chat"

      find('.gl-new-dropdown-item', text: 'Data Analyst').click

      # Select the other agent
      within_testid('chat-subheader') do
        expect(page).to have_content('Data Analyst')
      end

      # Ask a question - Mock responses are generated via `AIGW_USE_AGENTIC_MOCK`
      agent_msg = "Based on my analysis..."
      user_msg = "<response>#{agent_msg}</response>"
      send_message_and_wait_for_stream_finished!(user_msg)

      # Check agent response
      within_testid('chat-history') do
        expect(page).to have_css('.duo-chat-message', count: 2)
        expect(page).to have_css('.duo-chat-message:nth-child(2)', text: agent_msg)
      end

      created_workflow = ::Ai::DuoWorkflows::Workflow.last
      expect(created_workflow.workflow_definition).to eq('analytics_agent/v1')
    end

    it 'allows user to select a model' do
      visit subject

      # Shows the list of agents
      click_button "Add new chat"

      find('.gl-new-dropdown-item', text: 'GitLab Duo').click

      within_testid('chat-subheader') do
        expect(page).to have_content('GitLab Duo')
      end

      # Show the list of models
      within_testid('chat-component') do
        click_button "Claude Sonnet - Default"
      end

      # Select the other model
      within_testid('model-dropdown-container') do
        find('.gl-new-dropdown-item', text: 'Claude Haiku').click
      end

      # Ask a question - Mock responses are generated via `AIGW_USE_AGENTIC_MOCK`
      agent_msg = "I am Haiku"
      user_msg = "<response>#{agent_msg}</response>"
      send_message_and_wait_for_stream_finished!(user_msg)

      # Check agent response
      within_testid('chat-history') do
        expect(page).to have_css('.duo-chat-message', count: 2)
        expect(page).to have_css('.duo-chat-message:nth-child(2)', text: agent_msg)
      end
    end

    it 'injects additional context' do
      skip unless defined?(container) && defined?(entity)
      skip unless container.is_a?(::Project)
      skip unless create_rules_in_project_repository(container)

      visit subject

      #  ------------------------- New chat -------------------------
      add_new_chat

      # Ask a question
      send_message_and_wait_for_stream_finished!

      # Check agent response
      within_testid('chat-history') do
        expect(page).to have_css('.duo-chat-message-complete', count: 2)
        expect(page).to have_css('.duo-chat-message-complete', text: 'Duo:')

        # Check how many included reference buttons are rendered
        expect(page).to have_css('[data-testid="chat-context-selections-title"]', count: 1)

        # Expand included reference
        expand_included_references_of_user_message_at(1) do
          within_testid('chat-context-tokens-wrapper') do
            # Check if page context item is added by PageContextProvider
            expect(page).to have_selector('[aria-label="Current page"]')
            # Check if AGENTS.md context item is added by RuleContextProvider
            expect(page).to have_selector('[aria-label="AGENTS.md"]')
            # Check if chat-rules.md context item is added by RuleContextProvider
            expect(page).to have_selector('[aria-label="chat-rules.md"]')
          end
        end
      end

      # Ask a question again
      send_message_and_wait_for_stream_finished!

      # Check agent response
      within_testid('chat-history') do
        expect(page).to have_css('.duo-chat-message-complete', count: 4)
        expect(page).to have_css('.duo-chat-message-complete', text: 'Duo:', count: 2)

        # Check how many included reference buttons are rendered.
        # In this case, the new message shouldn't include the same reference again.
        expect(page).to have_css('[data-testid="chat-context-selections-title"]', count: 1)
      end

      #  ------------------------- New chat -------------------------
      # Testing that the additional context is injected in a new chat again
      add_new_chat

      # Ask a question
      send_message_and_wait_for_stream_finished!

      # Check agent response
      within_testid('chat-history') do
        expect(page).to have_css('.duo-chat-message-complete', count: 2)
        expect(page).to have_css('.duo-chat-message-complete', text: 'Duo:')

        # Check how many included reference buttons are rendered
        expect(page).to have_css('[data-testid="chat-context-selections-title"]', count: 1)

        # Expand included reference
        expand_included_references_of_user_message_at(1) do
          within_testid('chat-context-tokens-wrapper') do
            # Check if page context item is added by PageContextProvider
            expect(page).to have_selector('[aria-label="Current page"]')
            # Check if AGENTS.md context item is added by RuleContextProvider
            expect(page).to have_selector('[aria-label="AGENTS.md"]')
            # Check if chat-rules.md context item is added by RuleContextProvider
            expect(page).to have_selector('[aria-label="chat-rules.md"]')
          end
        end
      end
    end
  end
end

RSpec.shared_examples 'user can use summarize button in issue' do
  include_context 'with duo workflow service'

  it 'allows user to summarize issue and selects the Planner agent', :duo_workflow_service do
    visit subject

    within(".work-item-notes") do
      click_button('View summary')
    end

    within_testid('chat-subheader') do
      planner_agent = Ai::FoundationalChatAgentsDefinitions::ITEMS.find { |a| a[:reference] == 'duo_planner' }
      expect(page).to have_content(planner_agent[:name])
    end

    within_testid('chat-history') do
      expect(page).to have_css('.duo-chat-message')
      expect(page).to have_content('Summarize the comments on this issue.')
    end
  end
end

RSpec.shared_examples 'user can troubleshoot job failure' do
  include_context 'with duo workflow service'

  it 'allows user to troubleshoot job failure', :duo_workflow_service do
    visit subject

    within_testid('rca-bar-component') do
      click_button('Troubleshoot')
    end

    # Check user prompt and agent response
    within_testid('chat-history') do
      expect(page).to have_css('.duo-chat-message', count: 2)
      expect(page).to have_content('Troubleshoot this broken pipeline.')
      expect(page).to have_content('mock response')
    end
  end
end

RSpec.shared_examples 'user can use explain code' do
  include_context 'with duo workflow service'

  it 'allows user to use explain code feature', :duo_workflow_service do
    visit subject

    select_element('code[data-testid="content"]')

    click_button('What does the selected code mean?')

    # Check user prompt and agent response
    within_testid('chat-history') do
      expect(page).to have_css('.duo-chat-message', count: 2)
      expect(page).to have_content('Explain this code.')
      expect(page).to have_content('mock response')
    end
  end
end

RSpec.shared_examples 'user can navigate AI panel using navigation rail' do
  context 'when navigating AI panel tabs', :duo_workflow_service do
    include_context 'with duo workflow service'

    it 'navigates forward through all tabs successfully' do
      visit subject

      # 1. Start at chat (initial state)
      click_button "Active GitLab Duo Chat"
      wait_for_requests

      within_testid('chat-component') do
        expect(page).to have_content('GitLab Duo Agent Platform')
      end

      # Send a message to create a thread in history
      question = 'test-question-for-history'
      find_by_testid('chat-prompt-input').fill_in(with: question)
      send_keys :enter
      wait_for_requests

      within_testid('chat-component') do
        expect(page).to have_content('mock')
      end

      # 2. Navigate to history
      find_by_testid('ai-history-toggle').click
      wait_for_requests

      within_testid('chat-history') do
        expect(page).to have_selector('[data-testid="chat-threads-thread-box"]', wait: 5)
      end

      # 3. Navigate to sessions
      find_by_testid('ai-sessions-toggle').click
      wait_for_requests

      expect(page).to have_content('Sessions')

      # 4. Navigate back to chat
      find_by_testid('ai-chat-toggle').click
      wait_for_requests

      within_testid('chat-component') do
        expect(page).to have_content('mock')
      end
    end

    it 'preserves chat messages when navigating away and back' do
      visit subject
      click_button "Active GitLab Duo Chat"
      wait_for_requests

      # Send a message
      question = 'test-navigation-persistence'
      find_by_testid('chat-prompt-input').fill_in(with: question)
      send_keys :enter
      wait_for_requests

      within_testid('chat-component') do
        expect(page).to have_content(question)
        expect(page).to have_content('mock')
      end

      # Navigate to history
      find_by_testid('ai-history-toggle').click
      wait_for_requests

      # Navigate back to chat
      find_by_testid('ai-chat-toggle').click
      wait_for_requests

      # Verify messages still present
      within_testid('chat-component') do
        expect(page).to have_content(question)
        expect(page).to have_content('mock')
      end
    end

    it 'hydrates thread correctly when selected from history' do
      visit subject
      click_button "Active GitLab Duo Chat"
      wait_for_requests

      # Create first thread
      question1 = 'first-thread-question'
      find_by_testid('chat-prompt-input').fill_in(with: question1)
      send_keys :enter
      wait_for_requests

      # Wait for response
      within_testid('chat-component') do
        expect(page).to have_content('mock')
      end

      # Start new chat by selecting an agent from the dropdown.
      # The new-chat button renders as a GlCollapsibleListbox when multiple
      # agents are available. Click the toggle to open the dropdown, then
      # select the default "GitLab Duo" agent to start a fresh thread.
      within_testid('add-new-agent-toggle') do
        find('button').click
      end
      # The listbox uses positioning-strategy="fixed", so its panel is
      # rendered outside the toggle's DOM subtree (appended to <body>).
      # Search for the option at the page level rather than within the toggle.
      find('[role="option"]', text: 'GitLab Duo').click
      wait_for_requests

      # Create second thread
      question2 = 'second-thread-question'
      find_by_testid('chat-prompt-input').fill_in(with: question2)
      send_keys :enter
      wait_for_requests

      # Wait for response
      within_testid('chat-component') do
        expect(page).to have_content('mock')
      end

      # Navigate to history
      find_by_testid('ai-history-toggle').click
      wait_for_requests

      # Select the first-created thread from history.
      # History is ordered most-recent-first, so pick the thread containing question1.
      within_testid('chat-history') do
        thread_items = all('[data-testid="chat-threads-thread-box"]')
        expect(thread_items.length).to be >= 2
        thread_items.find { |item| item.text.include?(question1) }.click
      end

      wait_for_requests

      # Verify first thread content loaded correctly
      within_testid('chat-component') do
        expect(page).to have_content(question1)
        expect(page).not_to have_content(question2)
      end
    end

    it 'closes panel when clicking active tab again' do
      visit subject

      # Open chat
      find_by_testid('ai-chat-toggle').click
      wait_for_requests
      expect(page).to have_css('.ai-panel', wait: 5)

      # Click active tab again - should close
      find_by_testid('ai-chat-toggle').click
      wait_for_requests
      expect(page).not_to have_css('.ai-panel')
    end

    it 'handles rapid navigation without race conditions' do
      visit subject

      # Rapidly click through tabs
      5.times do
        find_by_testid('ai-chat-toggle').click
        find_by_testid('ai-history-toggle').click
        find_by_testid('ai-sessions-toggle').click
      end

      wait_for_requests

      # Should settle on last clicked tab
      expect(page).to have_content('Sessions')
    end

    it 'closes agent selector dropdown after selecting an agent' do
      visit subject

      # Start a new chat to open the panel. The regression only
      # reproduces when switching agents while the panel is mounted.
      add_new_chat

      # Now switch to a different agent via the dropdown
      click_button "Add new chat"
      expect(page).to have_content('Choose an agent')

      find('[role="option"]', text: 'Data Analyst').click
      wait_for_requests

      # Verify the dropdown closed after selection
      expect(page).not_to have_content('Choose an agent')

      # Verify the selected agent is reflected in the chat header
      within_testid('chat-subheader') do
        expect(page).to have_content('Data Analyst')
      end
    end
  end
end

RSpec.shared_examples 'user sees agentic chat blocked state' do
  it 'shows the Duo disabled empty state with a link to Duo settings' do
    visit subject

    click_button 'GitLab Duo Agent Platform'

    within_testid('chat-component') do
      expect(page).to have_content('Turn on GitLab Duo Agent Platform')
      expect(page).to have_link('Go to Duo settings', href: duo_settings_path)
    end
  end

  it 'keeps the panel in the previous state' do
    visit subject

    click_button 'GitLab Duo Agent Platform'

    page.refresh

    expect(page).to have_css('#ai-panel-portal')

    find_by_testid('duo-disabled-toggle').click

    page.refresh

    expect(page).not_to have_css('#ai-panel-portal')
  end
end
