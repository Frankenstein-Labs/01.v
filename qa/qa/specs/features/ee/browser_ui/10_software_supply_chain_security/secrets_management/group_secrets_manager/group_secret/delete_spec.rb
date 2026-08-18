# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :secrets_manager,
    :orchestrated,
    :requires_admin,
    feature_category: :secrets_management
  ) do
    include_context 'group secrets manager base'
    describe 'Group Secret' do
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
        group.add_member(maintainer, Resource::Members::AccessLevel::MAINTAINER)
        group.add_member(reporter, Resource::Members::AccessLevel::REPORTER)

        Flow::Login.while_signed_in(as: owner) do
          group.visit!

          Page::Group::Menu.perform(&:go_to_general_settings)
          Page::Group::Settings::General.perform do |settings|
            settings.add_role_permission(role_name: 'Maintainer', scopes: %w[read])
            settings.add_user_permission(username: reporter.username, scopes: %w[read delete])
          end

          Page::Group::Menu.perform(&:go_to_secrets_manager)
          EE::Page::Group::Secure::SecretsManager.perform do |secrets_page|
            secrets_page.click_new_secret
            secrets_page.create_secret(
              name: secret_name,
              value: 'testvalue',
              description: "Test deleting a secret",
              environment: '*'
            )
          end
        end
      end

      context 'when deleting a group secret', order: :defined do
        it 'fails to delete a secret when Maintainer has no delete permissions' do
          Flow::Login.while_signed_in(as: maintainer) do
            group.visit!

            Page::Group::Menu.perform(&:go_to_secrets_manager)
            EE::Page::Group::Secure::SecretsManager.perform do |secrets_page|
              expect(secrets_page).to have_delete_button(secret_name)
              secrets_page.delete_secret(name: secret_name, expect_error: true)
              expect(secrets_page).to have_permissions_error
            end
          end
        end

        it 'successfully deletes a secret when a User has delete permissions' do
          Flow::Login.while_signed_in(as: reporter) do
            group.visit!

            Page::Group::Menu.perform(&:go_to_secrets_manager)
            EE::Page::Group::Secure::SecretsManager.perform do |secrets_page|
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
