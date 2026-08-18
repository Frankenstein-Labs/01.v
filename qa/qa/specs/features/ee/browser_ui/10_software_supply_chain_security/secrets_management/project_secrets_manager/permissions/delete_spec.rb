# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :secrets_manager,
    :orchestrated,
    feature_category: :secrets_management
  ) do
    include_context 'secrets manager base'
    describe 'Delete on project secret permissions' do
      let(:reporter) { create(:user) }

      context 'when owner deletes a permission' do
        it 'successfully deletes permissions' do
          project.add_member(reporter, Resource::Members::AccessLevel::REPORTER)

          Support::Waiter.wait_until(max_duration: 10, sleep_interval: 1) do
            project.reload!
            project.find_member(reporter.username).present?
          end

          Flow::Login.while_signed_in(as: owner) do
            project.visit!

            Page::Project::Menu.perform(&:go_to_general_settings)
            Page::Project::Settings::Main.perform do |settings|
              settings.expand_visibility_project_features_permissions do |permissions_page|
                scopes = %w[read]
                permissions_page.add_user_permission(username: reporter.username, scopes: scopes)
                permissions_page.delete_user_permission(username: reporter.username)
                expect(permissions_page).not_to have_user_permission(username: reporter.username, scopes: scopes)
              end
            end
          end
        end
      end
    end
  end
end
