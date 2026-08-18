# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      class AgentType < ::Types::BaseObject
        graphql_name 'AiCatalogAgent'
        description 'An AI catalog agent'
        authorize :read_ai_catalog_item

        implements ::Types::Ai::Catalog::ItemInterface

        field :foundational_agent_reference, GraphQL::Types::String,
          null: true,
          experiment: { milestone: '19.2' },
          description: 'Foundational agent reference.'
      end
    end
  end
end
