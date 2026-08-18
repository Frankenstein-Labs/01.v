# frozen_string_literal: true

module Ai
  module Catalog
    module FlowFactoryHelpers
      def create_flow_configuration_for_project(project, service_account, event_types)
        group = project.root_ancestor

        flow = create(:ai_catalog_item, :flow, project: project)

        parent_consumer = create(
          :ai_catalog_item_consumer,
          group: group,
          item: flow,
          service_account: service_account
        )

        project_consumer = create(
          :ai_catalog_item_consumer,
          project: project,
          item: flow,
          service_account: nil,
          parent_item_consumer: parent_consumer
        )

        if event_types.any?
          create(
            :ai_flow_trigger,
            :for_catalog_consumer,
            ai_catalog_item_consumer: project_consumer,
            project: project,
            event_types: event_types
          )
        end

        flow
      end
    end
  end
end
