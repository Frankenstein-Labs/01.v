# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module SubMenus
          module Secure
            extend QA::Page::PageConcern

            def self.prepended(base)
              super

              base.class_eval do
                prepend Page::SubMenus::Secure
              end
            end

            def go_to_license_compliance
              open_secure_submenu('License compliance')
            end

            def go_to_on_demand_scans
              open_secure_submenu('On-demand scans')
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
