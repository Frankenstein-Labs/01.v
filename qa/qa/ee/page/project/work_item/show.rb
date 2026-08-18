# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module WorkItem
          module Show
            extend QA::Page::PageConcern

            def self.prepended(base)
              super

              base.class_eval do
                prepend Page::Component::DapEmptyState

                view 'ee/app/assets/javascripts/work_items/components/work_item_weight.vue' do
                  element 'work-item-weight'
                end

                view 'app/assets/javascripts/work_items/components/shared/work_item_sidebar_widget.vue' do
                  element 'edit-button'
                end

                view 'ee/app/assets/javascripts/work_items/components/work_item_iteration.vue' do
                  element 'work-item-iteration'
                  element 'work-item-iteration-link'
                end
              end
            end

            def weight_label_value
              find_element('work-item-weight')
            end

            def assign_iteration(_, period_display, iteration_group)
              wait_iteration_block_finish_loading do
                click_element('edit-button')
                wait_for_requests
                find_element("listbox-item-gid://gitlab/Iteration/#{iteration_group.id}").click
              end

              wait_until(reload: false) do
                has_element?('work-item-iteration-link', text: period_display, wait: 0)
              end
            end

            def has_iteration?(period_display)
              wait_iteration_block_finish_loading do
                has_element?('work-item-iteration-link', text: period_display)
              end
            end

            def click_iteration(period_display)
              click_element('work-item-iteration-link', text: period_display)
            end

            def wait_for_attachment_replication(image_url, max_wait: Runtime::Geo.max_file_replication_time)
              QA::Runtime::Logger.debug(%(#{self.class.name} - wait_for_attachment_replication))
              wait_until_geo_max_replication_time(max_wait: max_wait) do
                asset_exists?(image_url)
              end
            end

            private

            def wait_iteration_block_finish_loading
              within_element('work-item-iteration') do
                wait_until(reload: false, max_duration: 10, sleep_interval: 1) do
                  finished_loading_block?
                  yield
                end
              end
            end
          end
        end
      end
    end
  end
end
