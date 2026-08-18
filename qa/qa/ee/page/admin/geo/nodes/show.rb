# frozen_string_literal: true

module QA
  module EE
    module Page
      module Admin
        module Geo
          module Nodes
            class Show < QA::Page::Base
              view 'ee/app/assets/javascripts/geo_sites/components/app.vue' do
                element 'add-site-button'
              end

              def new_node!
                click_element('add-site-button')
              end
            end
          end
        end
      end
    end
  end
end
