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
        @secret_name ||= "update_secret"
      end

      before(:context) do
        project.add_member(maintainer, Resource::Members::AccessLevel::MAINTAINER)
        project.add_member(reporter, Resource::Members::AccessLevel::REPORTER)

        Flow::Login.while_signed_in(as: owner) do
          project.visit!

          Page::Project::Menu.perform(&:go_to_general_settings)
          Page::Project::Settings::Main.perform do |settings|
            settings.expand_visibility_project_features_permissions do |permissions_page|
              scopes = %w[read write]
              permissions_page.add_role_permission(role_name: 'Maintainer', scopes: scopes)
            end
          end

          Page::Project::Menu.perform(&:go_to_secrets_manager)
          EE::Page::Project::Secure::SecretsManager.perform do |secrets_page|
            secrets_page.click_new_secret
            secrets_page.create_secret(
              name: secret_name,
              value: 'testvalue',
              description: "Test updating a secret",
              environment: '*',
              branch: 'main'
            )
          end
        end
      end

      context 'when updating a project secret' do
        it 'successfully updates a secret when Maintainer has update permissions' do
          Flow::Login.while_signed_in(as: maintainer) do
            project.visit!

            Page::Project::Menu.perform(&:go_to_secrets_manager)
            EE::Page::Project::Secure::SecretsManager.perform do |secrets_page|
              secrets_page.click_secret_details(secret_name)
              expect(secrets_page).to have_edit_button
              secrets_page.click_edit_secret_button
              updated_description = "Updated description by Maintainer"
              secrets_page.update_secret(description: updated_description)
              expect(secrets_page).to have_secret_details(secret_name, updated_description)
            end
          end
        end

        it 'returns 404 when Reporter has no update permissions' do
          Flow::Login.while_signed_in(as: reporter) do
            visit("#{project.web_url}/-/secrets")

            expect(page).to have_text('404: Page not found')
          end
        end
      end
    end
  end
end
