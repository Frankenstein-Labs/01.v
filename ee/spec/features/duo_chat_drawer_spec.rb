# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Chat drawer', :js, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }

  before do
    allow_next_instance_of(::Gitlab::Llm::DuoChat) do |instance|
      allow(instance).to receive_messages(
        credits_available?: true,
        usage_billing_forbidden?: false,
        agentic_mode_available?: false,
        classic_chat_available?: true
      )
    end
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
  end

  context 'for saas', :saas do
    let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }

    before_all do
      group.add_developer(user)
    end

    before do
      sign_in(user)
    end

    describe 'Feature enabled and available' do
      include_context 'with ai features enabled for group'

      before do
        visit group_path(group)
      end

      shared_examples 'GitLab Duo drawer' do
        it 'opens the drawer to chat with GitLab Duo' do
          wait_for_requests

          within_testid('chat-component') do
            expect(page).to have_text('GitLab Duo Chat')
          end
        end
      end

      context "when opening the drawer from the breadcrumbs or side panel" do
        before do
          find_by_testid('ai-chat-toggle').click
        end

        it_behaves_like 'GitLab Duo drawer'
      end
    end
  end

  context 'for self-managed', :with_cloud_connector do
    let_it_be_with_reload(:group) { create(:group) }

    before do
      sign_in(user)
    end

    describe 'Feature enabled and available' do
      include_context 'with duo features enabled and ai chat available for self-managed'

      before do
        visit group_path(group)
      end

      shared_examples 'GitLab Duo drawer' do
        it 'opens the drawer to chat with GitLab Duo' do
          wait_for_requests

          within_testid('chat-component') do
            expect(page).to have_text('GitLab Duo Chat')
          end
        end
      end

      context "when opening the drawer from the breadcrumbs or side panel" do
        before do
          find_by_testid('ai-chat-toggle').click
        end

        it_behaves_like 'GitLab Duo drawer'
      end
    end
  end
end
