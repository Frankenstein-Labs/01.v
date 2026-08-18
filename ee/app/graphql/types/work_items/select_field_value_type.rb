# frozen_string_literal: true

module Types
  module WorkItems
    class SelectFieldValueType < Types::BaseObject # rubocop:disable Graphql/AuthorizeTypes -- already authorized in parent entity
      graphql_name 'WorkItemSelectFieldValue'

      implements Types::WorkItems::CustomFieldValueInterface

      def self.authorization_scopes
        super + [:ai_workflows]
      end

      field :selected_options, [Types::Issuables::CustomFieldSelectOptionType], null: true, hash_key: :value,
        description: 'Selected options of the custom field.',
        scopes: [:api, :read_api, :ai_workflows]
    end
  end
end
