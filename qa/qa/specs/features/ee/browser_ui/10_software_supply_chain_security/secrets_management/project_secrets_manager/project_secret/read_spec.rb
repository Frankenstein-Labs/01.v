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
      def reporter
        @reporter ||= create(:user)
      end

      def user_in_a_group
        @user_in_a_group ||= create(:user)
      end

      def group
        @group ||= create(:group)
      end

      def secret_name
        @secret_name ||= "reading_secret"
      end

      before(:context) do
        project.add_member(reporter, Resource::Members::AccessLevel::REPORTER)
        project.invite_group(group, Resource::Members::AccessLevel::DEVELOPER)
        group.add_member(user_in_a_group)

        Flow::Login.while_signed_in(as: owner) do
          project.visit!

          Page::Project::Menu.perform(&:go_to_general_settings)
          Page::Project::Settings::Main.perform do |settings|
            settings.expand_visibility_project_features_permissions do |permissions_page|
              permissions_page.add_group_permission(group_path: group.full_path, scopes: %w[read])
            end
          end

          Page::Project::Menu.perform(&:go_to_secrets_manager)
          EE::Page::Project::Secure::SecretsManager.perform do |secrets_page|
            secrets_page.click_new_secret
            secrets_page.create_secret(
              name: secret_name,
              value: 'testvalue',
              description: "Test reading a secret",
              environment: '*',
              branch: 'main'
            )
          end
        end
      end

      context 'when reading a project secret' do
        it 'successfully reads a secret when a User from group has read permissions' do
          Flow::Login.while_signed_in(as: user_in_a_group) do
            project.visit!

            Page::Project::Menu.perform(&:go_to_secrets_manager)
            EE::Page::Project::Secure::SecretsManager.perform do |secrets_page|
              expect(secrets_page).to have_secret_in_table(secret_name)
            end
          end
        end

        it 'returns 404 when Reporter has no read permissions' do
          Flow::Login.while_signed_in(as: reporter) do
            visit("#{project.web_url}/-/secrets")

            expect(page).to have_text('404: Page not found')
          end
        end
      end
    end
  end
end
