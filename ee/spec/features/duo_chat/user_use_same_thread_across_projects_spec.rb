# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Chat > User uses the same thread across projects', :js, :saas, feature_category: :duo_chat do
  include AgenticChatHelpers

  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan) }
  let_it_be(:project_a) { create(:project, :repository, group: group) }
  let_it_be(:project_b) { create(:project, :repository, group: group) }
  let_it_be(:project_c) { create(:project, :repository, group: group) }

  before_all do
    group.add_developer(user)
  end

  before do
    sign_in(user)
  end

  include_context 'with duo features enabled and agentic chat available for group on SaaS'

  context 'when using duo agentic chat', :duo_workflow_service do
    include_context 'with duo workflow service'

    it 'injects additional context per project' do
      create_rules_in_project_repository(project_a, %w[AGENTS.md .gitlab/duo/chat-rules.md])
      create_rules_in_project_repository(project_b, %w[AGENTS.md])

      # Visit project-A and create a new chat thread
      visit project_path(project_a)
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
          # Check items inside of the included reference
          within_testid('chat-context-tokens-wrapper') do
            # Check if three items included
            expect(page).to have_css('.gl-token-content', count: 3)
            # Check if page context, AGENTS.md and chat-rules.md items were added by PageContextProvider
            expect(page).to have_selector('[aria-label="Current page"]')
            expect(page).to have_selector('[aria-label="AGENTS.md"]')
            expect(page).to have_selector('[aria-label="chat-rules.md"]')
          end
        end
      end

      # Visit project-B and continue the conversation
      visit project_path(project_b)

      # Ask a question
      send_message_and_wait_for_stream_finished!

      # Check agent response
      within_testid('chat-history') do
        expect(page).to have_css('.duo-chat-message-complete', count: 4)
        expect(page).to have_css('.duo-chat-message-complete', text: 'Duo:', count: 2)

        # Check how many included reference buttons are rendered
        expect(page).to have_css('[data-testid="chat-context-selections-title"]', count: 2)

        # Expand included reference
        expand_included_references_of_user_message_at(2) do
          # Check items inside of the included reference
          within_testid('chat-context-tokens-wrapper') do
            # Check if three items included
            expect(page).to have_css('.gl-token-content', count: 3)
            # Check if page context and AGENTS.md items were added by PageContextProvider
            expect(page).to have_selector('[aria-label="Current page"]')
            expect(page).to have_selector('[aria-label="AGENTS.md"]')
            # Check if the ignore item was added for the previous chat-rules.md
            expect(page).to have_selector('[aria-label="Ignore previous chat-rules.md"]')
          end
        end
      end

      # Visit project-C and continue the conversation
      visit project_path(project_c)

      # Ask a question
      send_message_and_wait_for_stream_finished!

      # Check agent response
      within_testid('chat-history') do
        expect(page).to have_css('.duo-chat-message-complete', count: 6)
        expect(page).to have_css('.duo-chat-message-complete', text: 'Duo:', count: 3)

        # Check how many included reference buttons are rendered
        expect(page).to have_css('[data-testid="chat-context-selections-title"]', count: 3)

        # Expand included reference
        expand_included_references_of_user_message_at(3) do
          # Check items inside of the included reference
          within_testid('chat-context-tokens-wrapper') do
            # Check if two items included
            expect(page).to have_css('.gl-token-content', count: 2)
            # Check if page context item was added by PageContextProvider
            expect(page).to have_selector('[aria-label="Current page"]')
            # Check if the ignore item was added for the previous AGENTS.md
            expect(page).to have_selector('[aria-label="Ignore previous AGENTS.md"]')
          end
        end
      end
    end
  end
end
