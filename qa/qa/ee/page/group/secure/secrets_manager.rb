# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Secure
          class SecretsManager < QA::EE::Page::Project::Secure::SecretsManager
            view 'ee/app/assets/javascripts/ci/secrets/components/secrets_empty_state.vue' do
              element 'empty-state-new-secret-button'
            end

            view 'ee/app/assets/javascripts/ci/secrets/components/secrets_table/secrets_table.vue' do
              element 'new-secret-button'
              element 'secret-details-link'
              element 'secret-created-at'
            end

            view 'ee/app/assets/javascripts/ci/secrets/components/secret_form/secret_form.vue' do
              element 'secret-name-field-group'
              element 'secret-value-field-group'
              element 'secret-description-field-group'
              element 'secret-rotation-field-group'
              element 'submit-form-button'
              element 'cancel-button'
            end

            view 'ee/app/assets/javascripts/ci/secrets/components/secret_delete_modal.vue' do
              element 'delete-secret-modal'
            end

            view 'ee/app/assets/javascripts/ci/secrets/components/secret_details/secret_details_wrapper.vue' do
              element 'secret-edit-button'
            end

            # Group secrets have no branch scope (project-only), so skip select_branch.
            def create_secret(name:, value:, description:, environment: '*', expiration: nil, rotation_days: nil)
              fill_secret_name(name)
              fill_secret_value(value)
              fill_secret_description(description)
              select_environment(environment)
              set_expiration_date(expiration) if expiration
              set_rotation_period(rotation_days) if rotation_days

              click_element('submit-form-button')
            end
          end
        end
      end
    end
  end
end
