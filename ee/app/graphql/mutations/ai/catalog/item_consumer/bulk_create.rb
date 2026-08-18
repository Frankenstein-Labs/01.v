# frozen_string_literal: true

module Mutations
  module Ai
    module Catalog
      module ItemConsumer
        class BulkCreate < BaseMutation
          graphql_name 'AiCatalogItemConsumerBulkCreate'

          include TriggerConditionsConverter

          argument :item_id, ::Types::GlobalIDType[::Ai::Catalog::Item],
            required: true,
            description: 'Global ID of the catalog item to enable.'

          MAX_PROJECTS = 100

          argument :project_ids, [::Types::GlobalIDType[::Project]],
            required: true,
            validates: { length: { maximum: MAX_PROJECTS } },
            description: "Global IDs of the projects to enable the catalog item in (maximum #{MAX_PROJECTS})."

          argument :trigger_types, [GraphQL::Types::String],
            required: false,
            description: 'List of event types to create AI Catalog triggers for.'

          argument :trigger_filter, GraphQL::Types::JSON, # rubocop:disable Graphql/JSONType -- filter schema is not model backed, disabled for the same reason in Mutations::Ai::Catalog::ItemConsumer::Create
            required: false,
            deprecated: { reason: 'Use `triggerConditions`', milestone: '19.3' },
            description: 'Filter conditions for the auto-created AI Catalog triggers, keyed by event type.'

          argument :trigger_conditions, ::Types::Ai::Catalog::TriggerConditionsInputType,
            required: false,
            experiment: { milestone: '19.3' },
            description: 'Filter conditions for the auto-created AI Catalog triggers, keyed by event type.'

          argument :pinned_version, ::Types::Ai::Catalog::PinnedVersionType,
            required: false,
            description: 'Version to pin the item to, in the format `n.n.n`. ' \
              'Must be a released version. Defaults to the latest released version. ' \
              "Ignored when enabling within the item's managing project, " \
              'which always tracks the latest released version.'

          validates mutually_exclusive: [:trigger_filter, :trigger_conditions]

          authorize :read_ai_catalog_item

          def resolve(
            item_id:, project_ids:, trigger_types: nil, trigger_filter: nil, trigger_conditions: nil,
            pinned_version: nil)
            raise_resource_not_available_error! unless bulk_create_enabled?

            trigger_filter = convert_trigger_conditions_to_h(trigger_conditions) if trigger_conditions.present?

            item = authorized_find!(id: item_id)

            result = ::Ai::Catalog::ItemConsumers::EnqueueBulkCreateService
              .new(current_user:, item:, project_ids:, trigger_types:, trigger_filter:, pinned_version:).execute

            { errors: result.errors }
          end

          private

          def bulk_create_enabled?
            Feature.enabled?(:ai_catalog_bulk_item_consumer_create, current_user)
          end
        end
      end
    end
  end
end
