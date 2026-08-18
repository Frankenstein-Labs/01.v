# frozen_string_literal: true

module Ai
  module Catalog
    module Flows
      class ExecuteWorkItemCreatedWorkflowTriggersWorker
        include Ai::CloudEventsFlowTriggerWorker

        concurrency_limit -> { 100 }
        idempotent!

        class << self
          def cloud_event_class
            WorkItems::CreatedEvent
          end

          def event_type
            :work_item
          end

          def action
            'created'
          end
        end

        private

        def find_resource_and_container(cloud_event)
          work_item = WorkItem.find_by_id(cloud_event.event_data[:work_item_id])

          unless work_item
            logger.info(structured_payload(message: 'Work item not found.',
              work_item_id: cloud_event.event_data[:work_item_id]))
            return
          end

          [work_item, work_item.project]
        end
      end
    end
  end
end
