# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module SubMenus
          module Secure
            extend QA::Page::PageConcern

            def self.included(base)
              super

              base.class_eval do
                include Page::SubMenus::Secure
              end
            end

            def go_to_compliance_center
              open_secure_submenu('Compliance center')
            end

            def go_to_secrets_manager
              open_secure_submenu('Secrets manager')
            end
          end
        end
      end
    end
  end
end
