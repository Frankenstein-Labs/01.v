# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Chat > User navigates Duo Chat history', :js, :saas, :with_current_organization, feature_category: :duo_chat do
  let_it_be(:user) { create(:user, organizations: [current_organization]) }
  let_it_be(:group) { create(:group_with_plan, :public, plan: :ultimate_plan, organization: current_organization) }
  let_it_be(:project) { create(:project, :public, group: group, organization: current_organization) }
  let_it_be(:thread) do
    create(:ai_conversation_thread, user: user, organization: current_organization).tap do |thread|
      create(:ai_conversation_message, content: 'Chat Message', role: :user, thread: thread,
        organization: current_organization)
      create(:ai_conversation_message, content: 'Response', role: :assistant, thread: thread,
        organization: current_organization)
    end
  end

  # Create Duo Enterprise add-on and assign the user to it
  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: group)
  end

  let_it_be(:user_add_on_assignment) do
    create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user)
  end

  def open_duo_chat
    find('button.js-tanuki-bot-chat-toggle').click
    wait_for_requests
  end

  def close_popover
    return unless has_testid?('close-button', wait: 1) # rubocop:disable RSpec/AvoidConditionalStatements -- popover only shown in classic mode

    find_by_testid('close-button').click
  end

  before_all do
    group.add_developer(user)
  end

  before do
    stub_feature_flags(no_duo_classic_for_duo_core_users: false)
    allow(user).to receive(:allowed_to_use?).and_return(true)
    allow(user).to receive(:can?).and_call_original
    allow_next_instance_of(::Gitlab::Llm::DuoChat) do |instance|
      allow(instance).to receive_messages(credits_available?: true, usage_billing_forbidden?: false,
        classic_chat_available?: true)
    end

    sign_in(user)

    visit project_path(project)
    open_duo_chat
    close_popover
  end

  context 'when Chat History button is clicked' do
    it 'opens chat history list' do
      find_by_testid("ai-history-toggle").click
      wait_for_requests

      expect(page).to have_css('[data-testid="chat-threads-thread-box"]')
    end
  end
end
