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
      def developer
        @developer ||= create(:user)
      end

      def reporter
        @reporter ||= create(:user)
      end

      def secret_name
        @secret_name ||= "reading_secret"
      end

      before(:context) do
        group.add_member(developer, Resource::Members::AccessLevel::DEVELOPER)
        group.add_member(reporter, Resource::Members::AccessLevel::REPORTER)

        Flow::Login.while_signed_in(as: owner) do
          group.visit!

          Page::Group::Menu.perform(&:go_to_general_settings)
          Page::Group::Settings::General.perform do |settings|
            settings.add_role_permission(role_name: 'Developer', scopes: %w[read])
          end

          Page::Group::Menu.perform(&:go_to_secrets_manager)
          EE::Page::Group::Secure::SecretsManager.perform do |secrets_page|
            secrets_page.click_new_secret
            secrets_page.create_secret(
              name: secret_name,
              value: 'testvalue',
              description: "Test reading a secret",
              environment: '*'
            )
          end
        end
      end

      context 'when reading a group secret' do
        it 'successfully reads a secret when Developer has read permissions' do
          Flow::Login.while_signed_in(as: developer) do
            group.visit!

            Page::Group::Menu.perform(&:go_to_secrets_manager)
            EE::Page::Group::Secure::SecretsManager.perform do |secrets_page|
              expect(secrets_page).to have_secret_in_table(secret_name)
            end
          end
        end

        it 'returns 404 when Reporter has no read permissions' do
          Flow::Login.while_signed_in(as: reporter) do
            visit("#{group.web_url}/-/secrets")

            expect(page).to have_text('404: Page not found')
          end
        end
      end
    end
  end
end
