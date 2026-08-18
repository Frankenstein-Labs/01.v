# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      class ThirdPartyFlowType < ::Types::BaseObject
        graphql_name 'AiCatalogThirdPartyFlow'
        description 'An AI catalog third party flow'
        authorize :read_ai_catalog_item

        implements ::Types::Ai::Catalog::ItemInterface
      end
    end
  end
end
