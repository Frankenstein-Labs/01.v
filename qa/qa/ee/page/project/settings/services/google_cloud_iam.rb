# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Settings
          module Services
            class GoogleCloudIam < QA::Page::Base
              view 'ee/app/assets/javascripts/integrations/edit/components/sections/google_cloud_iam.vue' do
                element 'google-cloud-iam-component'
              end

              view 'app/assets/javascripts/integrations/edit/components/dynamic_field.vue' do
                # rubocop:disable QA/ElementWithPattern -- required for qa:selectors job to pass
                element 'service-workload_identity_federation_project_id-field', ':data-testid="`${fieldId}-field`"'
                element 'service-workload_identity_federation_project_number-field', ':data-testid="`${fieldId}-field`"'
                element 'service-workload_identity_pool_id-field', ':data-testid="`${fieldId}-field`"'
                element 'service-workload_identity_pool_provider_id-field', ':data-testid="`${fieldId}-field`"'
                # rubocop:enable QA/ElementWithPattern
              end

              attr_accessor :project_id,
                :project_number,
                :pool_id,
                :provider_id

              def fill_in_manual_setup_form
                set_project_id
                set_project_number
                set_pool_id
                set_provider_id
                click_element('save-changes-button')
              end

              def active?
                has_element?('status-success-icon')
              end

              private

              def set_project_id
                fill_element('service-workload_identity_federation_project_id-field', project_id)
              end

              def set_project_number
                fill_element('service-workload_identity_federation_project_number-field', project_number)
              end

              def set_pool_id
                fill_element('service-workload_identity_pool_id-field', pool_id)
              end

              def set_provider_id
                fill_element('service-workload_identity_pool_provider_id-field', provider_id)
              end
            end
          end
        end
      end
    end
  end
end
