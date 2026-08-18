# frozen_string_literal: true

module QA
  module EE
    module Page
      module Admin
        module Geo
          module Nodes
            class New < QA::Page::Base
              view 'ee/app/assets/javascripts/geo_site_form/components/geo_site_form_core.vue' do
                element 'site-name-field'
                element 'site-url-field'
              end

              view 'ee/app/assets/javascripts/geo_site_form/components/geo_site_form.vue' do
                element 'add-site-button'
              end

              def set_site_name(name)
                fill_element 'site-name-field', name
              end

              def set_site_address(address)
                fill_element 'site-url-field', address
              end

              def add_site!
                click_element 'add-site-button'
              end
            end
          end
        end
      end
    end
  end
end
