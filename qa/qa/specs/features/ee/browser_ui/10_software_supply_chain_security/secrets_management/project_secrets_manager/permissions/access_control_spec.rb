# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :secrets_manager,
    :orchestrated,
    feature_category: :secrets_management
  ) do
    include_context 'secrets manager base'
    describe 'Access secret permissions' do
      context 'when testing access control for secret permissions management' do
        let(:maintainer) { create(:user) }
        let(:reporter) { create(:user) }

        it 'maintainer can view permissions' do
          # Test that maintainer access secret permissions management, but not edit them.
          project.add_member(maintainer, Resource::Members::AccessLevel::MAINTAINER)

          Support::Waiter.wait_until(max_duration: 10, sleep_interval: 1) do
            project.reload!
            project.find_member(maintainer.username).present?
          end

          Flow::Login.while_signed_in(as: maintainer) do
            project.visit!

            Page::Project::Menu.perform(&:go_to_general_settings)
            Page::Project::Settings::Main.perform do |settings|
              settings.expand_visibility_project_features_permissions do |permissions_page|
                # Maintainer should see secret permissions management section, but not able to edit them
                expect(permissions_page).to have_secrets_manager_permissions_section
                expect(permissions_page).not_to have_add_permission_button
              end
            end
          end
        end

        it 'reporter cannot access secret permissions' do
          # Test that reporter cannot access secret permissions management
          project.add_member(reporter, Resource::Members::AccessLevel::REPORTER)

          Support::Waiter.wait_until(max_duration: 10, sleep_interval: 1) do
            project.reload!
            project.find_member(reporter.username).present?
          end

          Flow::Login.while_signed_in(as: reporter) do
            project.visit!

            Page::Project::Show.perform do |show|
              expect(show).not_to have_settings_sidebar
            end
            visit("#{project.web_url}/edit#js-shared-permissions")
            expect(page).to have_text('404: Page not found')
          end
        end
      end

      context 'when a non-owner access the secret permissions' do
        let(:non_project_owner) { create(:user) }
        let(:other_project) do
          create(:project, :with_readme, name: 'other-project-for-testing',
            api_client: Runtime::User::Store.admin_api_client)
        end

        it 'cannot access secret permissions page' do
          other_project.add_member(non_project_owner, Resource::Members::AccessLevel::OWNER)

          Flow::Login.while_signed_in(as: non_project_owner) do
            project.visit!

            Page::Project::Show.perform do |show|
              expect(show).not_to have_settings_sidebar
            end
            visit("#{project.web_url}/edit#js-shared-permissions")
            expect(page).to have_text('404: Page not found')
          end
        end
      end
    end
  end
end
