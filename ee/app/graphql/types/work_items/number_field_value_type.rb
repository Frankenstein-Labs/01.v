# frozen_string_literal: true

module Types
  module WorkItems
    class NumberFieldValueType < Types::BaseObject # rubocop:disable Graphql/AuthorizeTypes -- already authorized in parent entity
      graphql_name 'WorkItemNumberFieldValue'

      implements Types::WorkItems::CustomFieldValueInterface

      def self.authorization_scopes
        super + [:ai_workflows]
      end

      field :value, GraphQL::Types::Float, null: true, description: 'Number value of the custom field.',
        scopes: [:api, :read_api, :ai_workflows]
    end
  end
end
