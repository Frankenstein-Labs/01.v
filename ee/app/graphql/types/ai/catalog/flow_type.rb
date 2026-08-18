# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      class FlowType < ::Types::BaseObject
        graphql_name 'AiCatalogFlow'
        description 'An AI catalog flow'
        authorize :read_ai_catalog_item

        implements ::Types::Ai::Catalog::ItemInterface
      end
    end
  end
end
