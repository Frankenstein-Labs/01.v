# frozen_string_literal: true

module Mutations
  module Ai
    module Catalog
      module ItemConsumer
        class Delete < BaseMutation
          graphql_name 'AiCatalogItemConsumerDelete'

          field :success, GraphQL::Types::Boolean,
            null: false,
            description: 'Returns true if catalog item consumer was successfully deleted.'

          argument :id, ::Types::GlobalIDType[::Ai::Catalog::ItemConsumer],
            required: true,
            description: 'Global ID of the catalog item consumer to delete.'

          authorize :admin_ai_catalog_item_consumer

          def resolve(id:)
            item_consumer = authorized_find!(id: id)

            result = ::Ai::Catalog::ItemConsumers::DestroyService.new(item_consumer, current_user).execute

            {
              success: result.success?,
              errors: Array(result.errors)
            }
          end
        end
      end
    end
  end
end
