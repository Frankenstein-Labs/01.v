# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :secrets_manager,
    :orchestrated,
    feature_category: :secrets_management
  ) do
    include_context 'secrets manager base'
    describe 'Project Secret' do
      def maintainer
        @maintainer ||= create(:user)
      end

      def reporter
        @reporter ||= create(:user)
      end

      def secret_name
        @secret_name ||= "deleting_secret"
      end

      before(:context) do
        project.add_member(maintainer, Resource::Members::AccessLevel::MAINTAINER)
        project.add_member(reporter, Resource::Members::AccessLevel::REPORTER)

        Flow::Login.while_signed_in(as: owner) do
          project.visit!

          Page::Project::Menu.perform(&:go_to_general_settings)
          Page::Project::Settings::Main.perform do |settings|
            settings.expand_visibility_project_features_permissions do |permissions_page|
              scopes = %w[read]
              permissions_page.add_role_permission(role_name: 'Maintainer', scopes: scopes)

              scopes = %w[read delete]
              permissions_page.add_user_permission(username: reporter.username, scopes: scopes)
            end
          end

          Page::Project::Menu.perform(&:go_to_secrets_manager)
          EE::Page::Project::Secure::SecretsManager.perform do |secrets_page|
            secrets_page.click_new_secret
            secrets_page.create_secret(
              name: secret_name,
              value: 'testvalue',
              description: "Test deleting a secret",
              environment: '*',
              branch: 'main'
            )
          end
        end
      end

      context 'when deleting a project secret', order: :defined do
        it 'fails to delete a secret when Maintainer has no delete permissions' do
          Flow::Login.while_signed_in(as: maintainer) do
            project.visit!

            Page::Project::Menu.perform(&:go_to_secrets_manager)
            EE::Page::Project::Secure::SecretsManager.perform do |secrets_page|
              expect(secrets_page).to have_delete_button(secret_name)
              secrets_page.delete_secret(name: secret_name, expect_error: true)
              expect(secrets_page).to have_permissions_error
            end
          end
        end

        it 'successfully deletes a secret when a User has delete permissions' do
          Flow::Login.while_signed_in(as: reporter) do
            project.visit!

            Page::Project::Menu.perform(&:go_to_secrets_manager)
            EE::Page::Project::Secure::SecretsManager.perform do |secrets_page|
              expect(secrets_page).to have_delete_button(secret_name)
              secrets_page.delete_secret(name: secret_name)
              expect(secrets_page).to have_no_secret(secret_name)
            end
          end
        end
      end
    end
  end
end
