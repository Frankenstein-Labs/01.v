# frozen_string_literal: true

module Mutations
  module Ai
    module Catalog
      module Item
        class Star < BaseMutation
          graphql_name 'AiCatalogItemStar'

          authorize :read_ai_catalog_item

          argument :id,
            ::Types::GlobalIDType[::Ai::Catalog::Item],
            required: true,
            description: 'Global ID of the catalog item to star or unstar.'

          argument :starred,
            GraphQL::Types::Boolean,
            required: true,
            description: 'Indicates whether to star or unstar the catalog item.'

          field :star_count,
            GraphQL::Types::Int,
            null: false,
            description: 'Number of stars for the catalog item.'

          def resolve(id:, starred:)
            item = authorized_find!(id: id)

            result = ::Ai::Catalog::Items::StarService.new(item, current_user, { starred: starred }).execute

            {
              star_count: result.payload[:star_count],
              errors: result.errors
            }
          end
        end
      end
    end
  end
end
