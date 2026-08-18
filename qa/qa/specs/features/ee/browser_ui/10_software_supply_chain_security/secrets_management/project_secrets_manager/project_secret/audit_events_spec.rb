# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :secrets_manager,
    :orchestrated,
    :requires_admin,
    feature_category: :secrets_management
  ) do
    include_context 'secrets manager base'

    describe 'Project Secret audit events' do
      let(:secret_name) { "audit_secret_#{Faker::Alphanumeric.alphanumeric(number: 8)}" }

      it 'records create, update (value and description-only), and delete audit events' do
        Flow::Login.while_signed_in(as: owner) do
          project.visit!

          Page::Project::Menu.perform(&:go_to_secrets_manager)
          EE::Page::Project::Secure::SecretsManager.perform do |secrets_page|
            secrets_page.click_new_secret
            secrets_page.create_secret(
              name: secret_name,
              value: 'testvalue',
              description: 'Created for audit test',
              environment: '*',
              branch: 'main'
            )
            expect(secrets_page).to have_secret_in_table(secret_name)

            # A value change writes the data path; a description-only change writes only the
            # metadata path. Both must produce an update audit event, so exercise each.
            secrets_page.go_back_to_secrets_list
            secrets_page.click_secret_details(secret_name)
            expect(secrets_page).to have_edit_button
            secrets_page.click_edit_secret_button
            secrets_page.update_secret(value: 'updatedvalue')

            secrets_page.go_back_to_secrets_list
            secrets_page.click_secret_details(secret_name)
            expect(secrets_page).to have_edit_button
            secrets_page.click_edit_secret_button
            secrets_page.update_secret(description: 'Updated for audit test')
            expect(secrets_page).to have_secret_details(secret_name, 'Updated for audit test')

            secrets_page.go_back_to_secrets_list
            secrets_page.delete_secret(name: secret_name)
            expect(secrets_page).to have_no_secret(secret_name)
          end

          # Audit events arrive asynchronously from OpenBao's audit stream, so reload until they
          # appear. Both updates must be audited exactly once, so expect two "Updated" events
          # alongside the single create and delete.
          # retry_on_exception tolerates transient audit-page navigation/render errors.
          QA::Support::Retrier.retry_until(
            max_duration: 120,
            sleep_interval: 5,
            retry_on_exception: true,
            message: 'Waiting for project secret audit events to appear'
          ) do
            Page::Project::Menu.perform(&:go_to_audit_events)
            page.has_text?('Created project secret') &&
              page.text.scan('Updated project secret').size == 2 &&
              page.has_text?('Deleted project secret')
          end
        end
      end
    end
  end
end
