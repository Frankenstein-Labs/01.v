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
      let(:maintainer) { create(:user) }
      let(:reporter) { create(:user) }

      context 'when creating a group secret' do
        before do
          group.add_member(maintainer, Resource::Members::AccessLevel::MAINTAINER)
          group.add_member(reporter, Resource::Members::AccessLevel::REPORTER)
        end

        it 'successfully creates a secret when Maintainer has create permissions' do
          Flow::Login.while_signed_in(as: owner) do
            group.visit!

            Page::Group::Menu.perform(&:go_to_general_settings)
            Page::Group::Settings::General.perform do |settings|
              settings.add_role_permission(role_name: 'Maintainer', scopes: %w[read write])
            end
          end

          Flow::Login.while_signed_in(as: maintainer) do
            group.visit!

            Page::Group::Menu.perform(&:go_to_secrets_manager)
            EE::Page::Group::Secure::SecretsManager.perform do |secrets_page|
              secret_name = "test_maintainer_secret"

              expect(secrets_page).to have_new_secret_button
              secrets_page.click_new_secret
              secrets_page.create_secret(
                name: secret_name,
                value: 'testvalue',
                description: "Secret by test_maintainer_secret",
                environment: '*'
              )

              expect(secrets_page).to have_secret_in_table(secret_name)
            end
          end
        end

        it 'returns 404 when Reporter has no create permissions' do
          Flow::Login.while_signed_in(as: reporter) do
            visit("#{group.web_url}/-/secrets")

            expect(page).to have_text('404: Page not found')
          end
        end
      end
    end
  end
end
