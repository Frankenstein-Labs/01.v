# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        class Roadmap < QA::Page::Base
          view 'ee/app/assets/javascripts/roadmap/components/epic_item_details.vue' do
            element 'epic-details-cell'
          end

          view 'ee/app/assets/javascripts/roadmap/components/epic_item.vue' do
            element 'epic-timeline-cell'
          end

          view 'ee/app/assets/javascripts/roadmap/components/roadmap_shell.vue' do
            element 'roadmap-shell'
          end

          def has_epic?(epic)
            wait_for_requests

            within_element('roadmap-shell') do
              find("[data-testid='epic-details-cell']", text: epic.title) &&
                find("[data-testid='epic-timeline-cell'] a", text: epic.title)
            end
          end
        end
      end
    end
  end
end
