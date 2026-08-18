# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Settings
          module Services
            class GoogleArtifactRegistry < QA::Page::Base
              view 'app/assets/javascripts/integrations/edit/components/dynamic_field.vue' do
                # rubocop:disable QA/ElementWithPattern -- required for qa:selectors job to pass
                element 'service-artifact_registry_project_id-field', ':data-testid="`${fieldId}-field`"'
                element 'service-artifact_registry_repositories-field', ':data-testid="`${fieldId}-field`"'
                element 'service-artifact_registry_location-field', ':data-testid="`${fieldId}-field`"'
                # rubocop:enable QA/ElementWithPattern
              end

              attr_accessor :project_id,
                :repository_name,
                :repository_location

              def fill_in_repository_configuration
                set_project_id
                set_repository_name
                set_repository_location
                click_element('save-changes-button')
              end

              def active?
                has_element?('status-success-icon')
              end

              def test_settings
                click_element('test-button')
              end

              private

              def set_project_id
                fill_element('service-artifact_registry_project_id-field', project_id)
              end

              def set_repository_name
                fill_element('service-artifact_registry_repositories-field', repository_name)
              end

              def set_repository_location
                fill_element('service-artifact_registry_location-field', repository_location)
              end
            end
          end
        end
      end
    end
  end
end
