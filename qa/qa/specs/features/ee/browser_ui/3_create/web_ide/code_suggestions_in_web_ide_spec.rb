# frozen_string_literal: true

module QA
  # This test requires several feature flags, user settings, and instance configuration.
  # See https://docs.gitlab.com/ee/development/ai_features/code_suggestions/#code-suggestions-development-setup
  RSpec.describe 'Create', feature_category: :code_suggestions do
    describe 'Code Suggestions in Web IDE' do
      include_context "Web IDE test prep"

      let(:api_client) { Runtime::User::Store.default_api_client }
      let(:project) { create(:project, :with_readme, name: 'webide-code-suggestions-project', api_client: api_client) }
      let(:file_name) { 'new_file.rb' }
      let(:prompt_data) { 'def reverse_string' }

      before do
        create(:commit, project: project, api_client: api_client, actions: [
          { action: 'create', file_path: file_name, content: '# test' }
        ])
        load_web_ide(file_name: file_name)
      end

      shared_examples 'a code generation suggestion' do
        it 'returns a code generation suggestion which can be accepted' do
          Page::Project::WebIDE::VSCode.perform do |ide|
            ide.add_prompt_into_a_file(file_name, prompt_data)
            previous_content_length = ide.editor_content_length

            # code generation will put suggestion on the next line
            ide.wait_for_code_suggestion
            expect(ide.editor_content_length).to be > previous_content_length, "Expected a suggestion"

            ide.accept_code_suggestion
            expect(ide.editor_content_length).to be > previous_content_length, "Expected accepted suggestion in file"
          end
        end
      end

      shared_examples 'a code completion suggestion' do
        # We should avoid the use of . in the prompt since the remote Selenium WebDriver
        # also uses send_keys to upload files if it finds the text matches a potential file name,
        # which can cause unintended behavior in the test.
        #
        # The remote WebDriver is used in orchestrated tests that make use of Selenoid video recording.
        # https://www.selenium.dev/documentation/webdriver/elements/file_upload/
        let(:prompt_data) { "def set_name(whitespace_name)\n    @name = " }

        it 'returns a code completion suggestion which can be accepted' do
          Page::Project::WebIDE::VSCode.perform do |ide|
            ide.add_prompt_into_a_file(file_name, prompt_data)
            previous_content_length = ide.editor_content_length

            # code completion will put suggestion on the same line
            ide.wait_for_code_suggestion
            expect(ide.editor_content_length).to be > previous_content_length, 'Expected a suggestion'

            ide.accept_code_suggestion
            expect(ide.editor_content_length).to be > previous_content_length, 'Expected accepted suggestion in file'
          end
        end
      end

      shared_examples 'unauthorized' do
        it 'returns no suggestion' do
          Page::Project::WebIDE::VSCode.perform do |ide|
            ide.add_prompt_into_a_file(file_name, prompt_data, wait_for_code_suggestions: false)
            previous_content_length = ide.editor_content_length

            expect(ide).to have_code_suggestions_disabled

            expect(ide.editor_content_length).to eq(previous_content_length), "Expected no suggestion"
          end
        end
      end

      context 'on GitLab.com', :smoke, :external_ai_provider,
        only: { pipeline: %i[staging staging-canary canary production] },
        quarantine: {
          issue: 'https://gitlab.com/gitlab-org/gitlab-vscode-extension/-/issues/1948',
          type: :bug
        } do
        it_behaves_like 'a code generation suggestion'

        it_behaves_like 'a code completion suggestion'
      end

      context 'on Self-managed', :orchestrated do
        let(:api_client) { Runtime::User::Store.admin_api_client }
        let(:user) { Runtime::User::Store.admin_user }

        context 'with a valid license' do
          context 'with a Duo Enterprise add-on' do
            context 'when seat is assigned', :ai_gateway do
              it_behaves_like 'a code completion suggestion'
            end

            context 'when seat is not assigned', :ai_gateway_no_seat_assigned, quarantine: {
              issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24037',
              type: :flaky
            } do
              # Code suggestions is included with Duo Core
              it_behaves_like 'a code completion suggestion'
            end
          end

          context 'with no Duo Enterprise add-on', :ai_gateway_no_add_on, quarantine: {
            issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24037',
            type: :flaky
          } do
            # Code suggestions is included with Duo Core
            it_behaves_like 'a code completion suggestion'
          end
        end

        context 'with no license', :ai_gateway_no_license do
          it_behaves_like 'unauthorized'
        end
      end
    end
  end
end
