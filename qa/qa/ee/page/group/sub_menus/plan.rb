# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module SubMenus
          module Plan
            extend QA::Page::PageConcern

            def go_to_epics
              return unless has_element?('nav-item-link', submenu_item: 'Work items')

              open_plan_submenu("Work items")
            end

            def go_to_roadmap
              open_plan_submenu("Roadmap")
            end

            def go_to_group_iterations
              open_plan_submenu('Iterations')
            end
          end
        end
      end
    end
  end
end
