# frozen_string_literal: true

module QA
  RSpec.describe 'Software Supply Chain Security',
    feature_category: :compliance_management,
    quarantine: {
      issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/work_items/43614',
      type: :flaky
    } do
    shared_examples 'audit event' do |expected_events|
      it 'logs audit events for UI operations' do
        QA::Support::Retrier.retry_on_exception do
          Page::Project::Menu.perform(&:go_to_audit_events)
        end
        expected_events.each do |expected_event|
          expect(page).to have_text(expected_event)
        end
      end
    end

    describe 'Project' do
      let(:project) { create(:project, :with_readme, name: 'awesome-project') }
      let(:user) { Runtime::User::Store.additional_test_user }

      before do
        sign_in
      end

      context "for add project" do
        before do
          Resource::Project.fabricate_via_browser_ui! do |project|
            project.name = 'audit-add-project-via-ui'
            project.initialize_with_readme = true
            project.description = nil
          end.visit!
        end

        it_behaves_like 'audit event', ["Added project"]
      end

      context "for add user access as guest" do
        before do
          project.visit!

          Page::Project::Menu.perform(&:go_to_members)
          Page::Project::Members.perform do |members|
            members.add_member(user.username, 'Guest')
          end
        end

        it_behaves_like 'audit event', ["Added user access as Default role: Guest"]
      end

      context "for add deploy key" do
        before do
          key = Runtime::Key::RSA.new
          deploy_key_title = 'deploy key title'
          deploy_key_value = key.public_key

          Resource::DeployKey.fabricate_via_browser_ui! do |resource|
            resource.project = project
            resource.title = deploy_key_title
            resource.key = deploy_key_value
          end
        end

        it_behaves_like 'audit event', ["Added deploy key"]
      end

      context "for change visibility" do
        before do
          project.visit!

          Page::Project::Menu.perform(&:go_to_general_settings)
          Page::Project::Settings::Main.perform do |settings|
            # Change visibility from public to internal
            settings.expand_visibility_project_features_permissions do |page|
              page.set_project_visibility "Private"
            end
          end
        end

        it_behaves_like 'audit event', ["Changed visibility level from Public to Private"]
      end

      context "for export file download", :skip_live_env do
        before do
          create(:project, :with_readme, name: 'project_for_export').visit!

          Page::Project::Menu.perform(&:go_to_general_settings)
          Page::Project::Settings::Main.perform do |settings|
            settings.expand_advanced_settings(&:click_export_project_link)
            QA::Support::Waiter.wait_until(message: 'Wait for download export to start') do
              settings.download_export_started?
            end

            # The project download export link is only rendered after some async jobs are completed
            QA::Support::Retrier.retry_until(max_duration: 60, message: 'Failed to verify download export link') do
              Page::Project::Menu.perform(&:go_to_general_settings)
              settings.expand_advanced_settings do |advanced_settings|
                advanced_settings.scroll_to_element('export-project-content')
                QA::Support::WaitForRequests.wait_for_requests
                advanced_settings.has_download_export_link?(wait: 6)
              end
            end
          end

          Page::Project::Settings::Main.perform do |settings|
            settings.expand_advanced_settings(&:click_download_export_link)
          end
        end

        it_behaves_like 'audit event', ["Export file download started"]
      end

      context "for project archive and unarchive" do
        before do
          project.visit!

          # Archive project
          Page::Project::Menu.perform(&:go_to_general_settings)
          Page::Project::Settings::Main.perform(&:expand_advanced_settings)
          Page::Project::Settings::Advanced.perform(&:archive_project)
          Support::Waiter.wait_until { page.has_text?(/This project is (archived|read-only)/) }

          # Unarchive project
          Page::Project::Menu.perform(&:go_to_general_settings)
          Page::Project::Settings::Main.perform(&:expand_advanced_settings)
          Page::Project::Settings::Advanced.perform(&:unarchive_project)
        end

        it_behaves_like 'audit event', ["Project archived", "Project unarchived"]
      end

      def sign_in
        Flow::Login.sign_in unless Page::Main::Menu.perform { |p| p.has_personal_area?(wait: 0) }
      end
    end
  end
end
