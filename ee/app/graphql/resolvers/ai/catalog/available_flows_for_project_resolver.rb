# frozen_string_literal: true

module Resolvers
  module Ai
    module Catalog
      class AvailableFlowsForProjectResolver < BaseResolver
        include Gitlab::Graphql::Authorize::AuthorizeResource

        description 'Find AI Catalog flows available to enable for a project.'

        type ::Types::Ai::Catalog::ItemConsumerType.connection_type, null: false

        argument :project_id,
          ::Types::GlobalIDType[::Project],
          required: true,
          description: 'Project ID to retrieve available AI Catalog flows for.'

        def resolve(project_id:)
          project = authorized_find!(id: project_id)

          root_group = project.root_ancestor
          return none unless root_group.is_a?(Group)

          root_group.configured_ai_catalog_items.with_item_type(::Ai::Catalog::Item::FLOW_TYPE).with_items
        end

        private

        def find_object(id:)
          ::GitlabSchema.find_by_gid(id)
        end

        def authorized_resource?(project)
          Ability.allowed?(current_user, :admin_ai_catalog_item_consumer, project)
        end

        def none
          ::Ai::Catalog::ItemConsumer.none
        end
      end
    end
  end
end
