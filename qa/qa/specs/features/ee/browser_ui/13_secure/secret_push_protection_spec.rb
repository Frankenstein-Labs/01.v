# frozen_string_literal: true

module QA
  RSpec.describe 'Secure', :requires_admin, feature_category: :secret_detection do
    describe 'Secret Push Protection' do
      let!(:project) do
        create(:project, :with_readme, name: 'secret-push-project', description: 'Secret Push Protection Project')
      end

      let(:test_token) { Runtime::User::Store.test_user.create_personal_access_token!(use_for_api_client: false) }
      let(:test_token_text) { test_token.token }

      before do
        test_token.revoke!
        enable_secret_protection unless Runtime::Env.running_on_dot_com?
        enable_project_secret_protection
      end

      it 'blocks commit when enabled when token is detected' do
        Git::Repository.perform do |repository|
          repository.uri = project.repository_http_location.uri
          repository.use_default_credentials
          repository.default_branch = project.default_branch
          repository.clone
          repository.use_default_identity
          repository.commit_file("new-file", test_token_text, "Add token file")
          result = repository.push_changes(raise_on_failure: false, max_attempts: 1)

          expect(result).to match(expected_error_pattern)
        end
      end

      context 'when secret added in the Web IDE' do
        include_context 'Web IDE test prep'

        before do
          create(:commit,
            project: project,
            branch: project.default_branch,
            commit_message: 'Commit new file',
            actions: [
              {
                action: 'create',
                file_path: file_name
              }
            ])
        end

        let(:file_name) { 'new_file.text' }

        it 'blocks commit when enabled and token is detected' do
          Flow::Login.sign_in
          project.visit!

          # Open Web IDE
          load_web_ide

          # Create a new file with the test token
          Page::Project::WebIDE::VSCode.perform do |ide|
            ide.wait_for_ide_to_load
            ide.add_text_to_a_file(file_name, "Secret token: #{test_token_text}")

            expect(ide.commit_blocked_by_secret_detection(file_name)).to be true
          end
        end
      end

      def enable_secret_protection
        Flow::Login.while_signed_in_as_admin do
          Page::Main::Menu.perform(&:go_to_admin_area)
          Page::Admin::Menu.perform(&:go_to_security_and_compliance_settings)
          EE::Page::Admin::Settings::Securityandcompliance.perform do |settings|
            settings.set_secret_push_protection_mode('available')
          end
        end
      end

      def enable_project_secret_protection
        Flow::Login.while_signed_in do
          project.visit!
          Page::Project::Menu.perform(&:go_to_security_configuration)
          Page::Project::Secure::ConfigurationForm.perform do |config_form|
            expect(config_form).to have_false_secret_detection_status

            config_form.enable_secret_detection

            expect(config_form).to have_true_secret_detection_status
          end
        end
      end

      def error_messages
        {
          blocked: 'PUSH BLOCKED: Secrets detected in code changes',
          found: 'Secret push protection found the following secrets in commit',
          token: 'GitLab [Pp]ersonal [Aa]ccess [Tt]oken',
          resolution: 'To push your changes you must remove the identified secrets.'
        }
      end

      def expected_error_pattern
        messages = error_messages
        %r{.*#{messages[:blocked]}[\s\S]*#{messages[:found]}[\s\S]*#{messages[:token]}[\s\S]*#{messages[:resolution]}}
      end
    end
  end
end
