# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Settings
          module Integrations
            extend QA::Page::PageConcern

            def self.prepended(base)
              super

              base.class_eval do
                include Page::Component::SecureReport

                # rubocop:disable QA/ElementWithPattern -- required for qa:selectors job to pass
                view 'app/assets/javascripts/integrations/index/components/integrations_table.vue' do
                  element 'google_cloud_platform_workload_identity_federation-link',
                    %q(:data-testid="`${item.name}-link`")
                  element 'google_cloud_platform_artifact_registry-link', %q(:data-testid="`${item.name}-link`")
                end
                # rubocop:enable QA/ElementWithPattern
              end
            end

            def click_google_cloud_iam_link
              click_element('google_cloud_platform_workload_identity_federation-link')
            end

            def click_google_artifact_registry_link
              click_element('google_cloud_platform_artifact_registry-link')
            end
          end
        end
      end
    end
  end
end
