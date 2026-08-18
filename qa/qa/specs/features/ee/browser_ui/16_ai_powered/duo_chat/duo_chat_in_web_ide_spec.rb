# frozen_string_literal: true

module QA
  # https://docs.gitlab.com/ee/development/ai_features/duo_chat.html
  RSpec.describe 'Ai-powered', feature_category: :duo_chat do
    describe "Duo Chat in Web IDE" do
      include_context 'Web IDE test prep'
      shared_examples 'Duo Chat' do
        it 'gets a valid response back' do
          Page::Project::WebIDE::VSCode.perform do |ide|
            ide.open_duo_chat
            ide.within_vscode_duo_chat do
              QA::EE::Page::Component::DuoChat.perform do |duo_chat|
                duo_chat.clear_chat_history
                expect(duo_chat).to be_empty_state
                duo_chat.send_duo_chat_prompt('hi')

                Support::Waiter.wait_until(message: 'Wait for Duo Chat response and feedback message') do
                  raise "Error found in Duo Chat: '#{duo_chat.error_text}'" if duo_chat.has_error?

                  duo_chat.number_of_messages > 1 && duo_chat.has_feedback_message?
                end

                QA::Runtime::Logger.debug("Latest Duo Chat response #{duo_chat.latest_response}")
                expect(duo_chat.latest_response).not_to be_blank, 'Expected a response from Duo Chat'
              end
            end
          end
        end
      end

      let(:project) { create(:project, :with_readme, name: 'webide-duo-chat-project') }
      let(:token) { Runtime::User::Store.default_api_client.personal_access_token }

      before do
        load_web_ide
      end

      context "when asking 'hi'" do
        context 'on GitLab.com', :external_ai_provider,
          only: { pipeline: %i[staging staging-canary canary production] },
          quarantine: {
            type: :bug,
            issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/536335'
          } do
          include_examples 'Duo Chat'
        end

        context 'on Self-managed', :orchestrated, :ai_gateway, quarantine: {
          type: :investigating,
          issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24043'
        } do
          let(:api_client) { Runtime::User::Store.admin_api_client }
          let(:user) { Runtime::User::Store.admin_user }

          include_examples 'Duo Chat'
        end
      end
    end
  end
end
