# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Monitor
          module Incidents
            module Show
              extend QA::Page::PageConcern

              def self.prepended(base)
                super

                base.class_eval do
                  prepend Page::Component::DapEmptyState

                  view 'ee/app/assets/javascripts/linked_resources/components/resource_links_block.vue' do
                    element 'resource-links-list'
                  end

                  view 'ee/app/assets/javascripts/linked_resources/components/resource_links_list.vue' do
                    element 'resource-link-item'
                  end
                end
              end

              def has_linked_resource?(title)
                within_element('resource-links-list') do
                  has_element?('resource-link-item', text: title)
                end
              end

              def linked_resources_count
                within_element('resource-links-list') do
                  all_elements('resource-link-item', minimum: 1).count
                end
              end
            end
          end
        end
      end
    end
  end
end
