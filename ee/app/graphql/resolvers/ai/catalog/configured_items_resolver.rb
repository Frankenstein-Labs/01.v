# frozen_string_literal: true

module Resolvers
  module Ai
    module Catalog
      class ConfiguredItemsResolver < BaseResolver
        description 'Find AI Catalog items configured for use.'

        type ::Types::Ai::Catalog::ItemConsumerType.connection_type, null: false

        argument :group_id,
          ::Types::GlobalIDType[::Group],
          prepare: ->(global_id, _ctx) { global_id&.model_id },
          required: false,
          description: 'Group ID to retrieve configured AI Catalog items for.'

        argument :include_inherited,
          GraphQL::Types::Boolean,
          required: false,
          default_value: false,
          description: 'Include configured AI Catalog items inherited from parent groups.'

        argument :include_foundational_consumers,
          GraphQL::Types::Boolean,
          required: false,
          default_value: false,
          description: 'Include configured foundational AI Catalog items.',
          experiment: { milestone: '18.10' }

        argument :item_id,
          ::Types::GlobalIDType[::Ai::Catalog::Item],
          prepare: ->(global_id, _ctx) { global_id&.model_id },
          required: false,
          description: 'Item ID to retrieve configured AI Catalog items for.'

        argument :project_id,
          ::Types::GlobalIDType[::Project],
          prepare: ->(global_id, _ctx) { global_id&.model_id },
          required: false,
          description: 'Project ID to retrieve configured AI Catalog items for.'

        argument :configurable_for_project_id,
          ::Types::GlobalIDType[::Project],
          prepare: ->(global_id, _ctx) { global_id&.model_id },
          required: false,
          description: 'Project ID to filter AI Catalog item consumers. When provided with group_id, returns only ' \
            'consumers whose associated items are configurable within the project (i.e., group-enabled ' \
            'items that are public or owned by the project). Excludes consumers for items that are ' \
            'private to other projects.'

        argument :foundational_flow_reference,
          GraphQL::Types::String,
          required: false,
          description: 'Filter by foundational flow reference.'

        argument :item_type, ::Types::Ai::Catalog::ItemTypeEnum,
          required: false,
          description: 'Type of items to retrieve.'

        argument :item_types, [::Types::Ai::Catalog::ItemTypeEnum],
          required: false,
          description: 'Types of items to retrieve.'

        validates at_least_one_of: [:group_id, :project_id]

        def resolve(**args)
          ::Ai::Catalog::ItemConsumersFinder.new(current_user, params: args).execute.with_items
        end
      end
    end
  end
end
