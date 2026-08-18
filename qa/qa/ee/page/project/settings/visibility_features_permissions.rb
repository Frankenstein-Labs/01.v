# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Settings
          module VisibilityFeaturesPermissions
            extend QA::Page::PageConcern

            def self.prepended(base)
              super

              base.class_eval do
                include Page::Component::SecretsManagerSettings
                include Page::Component::SecretsManagerPermissions
              end
            end
          end
        end
      end
    end
  end
end
