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
        @secret_name ||= "update_secret"
      end

      before(:context) do
        group.add_member(maintainer, Resource::Members::AccessLevel::MAINTAINER)
        group.add_member(reporter, Resource::Members::AccessLevel::REPORTER)

        Flow::Login.while_signed_in(as: owner) do
          group.visit!

          Page::Group::Menu.perform(&:go_to_general_settings)
          Page::Group::Settings::General.perform do |settings|
            settings.add_role_permission(role_name: 'Maintainer', scopes: %w[read write])
          end

          Page::Group::Menu.perform(&:go_to_secrets_manager)
          EE::Page::Group::Secure::SecretsManager.perform do |secrets_page|
            secrets_page.click_new_secret
            secrets_page.create_secret(
              name: secret_name,
              value: 'testvalue',
              description: "Test updating a secret",
              environment: '*'
            )
          end
        end
      end

      context 'when updating a group secret' do
        it 'successfully updates a secret when Maintainer has update permissions' do
          Flow::Login.while_signed_in(as: maintainer) do
            group.visit!

            Page::Group::Menu.perform(&:go_to_secrets_manager)
            EE::Page::Group::Secure::SecretsManager.perform do |secrets_page|
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
            visit("#{group.web_url}/-/secrets")

            expect(page).to have_text('404: Page not found')
          end
        end
      end
    end
  end
end
