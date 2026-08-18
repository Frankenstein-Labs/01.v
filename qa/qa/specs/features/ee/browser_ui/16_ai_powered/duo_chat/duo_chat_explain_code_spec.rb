# frozen_string_literal: true

module QA
  RSpec.describe 'Ai-powered', feature_category: :duo_chat do
    describe 'Duo Chat', :external_ai_provider,
      only: { pipeline: %w[staging-canary staging canary production] } do
      let(:project) { create(:project, :with_readme, name: 'duo-chat-explain-code') }

      before do
        Flow::Login.sign_in

        create(:commit, project: project, actions: [
          { action: 'create', file_path: 'test.rb', content: 'class' }
        ])
      end

      it 'explains highlighted code in repository' do
        project.visit!

        QA::EE::Page::Component::DuoChat.perform do |duo_chat|
          duo_chat.open_duo_chat
          duo_chat.clear_chat_history
          duo_chat.close
        end

        Page::Project::Show.perform do |project|
          project.click_file('test.rb')
        end

        Page::File::Show.perform do |file|
          file.double_click_code_token('class')
          file.explain_code
        end

        expect(page).to have_text('GitLab Duo Chat')

        QA::EE::Page::Component::DuoChat.perform do |duo_chat|
          Support::Waiter.wait_until(message: 'Wait for Duo Chat response') do
            duo_chat.number_of_messages > 1
          end

          expect(duo_chat).to have_text('Explain this code'), 'Expected "Explain this code" request sent to Duo Chat.'
          expect { duo_chat.response }.to eventually_include('code').within(max_duration: 30),
            'Expected "code" within Duo Chat response.'
        end
      end
    end
  end
end
