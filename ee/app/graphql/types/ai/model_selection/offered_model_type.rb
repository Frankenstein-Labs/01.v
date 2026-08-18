# frozen_string_literal: true

module Types
  module Ai
    module ModelSelection
      # rubocop: disable Graphql/AuthorizeTypes -- authorization in resolver/mutation
      class OfferedModelType < ::Types::BaseObject
        graphql_name 'AiModelSelectionOfferedModel'
        description 'Model offered for Model Selection'

        field :ref, String, null: false, description: 'Identifier for the offered model.'

        field :name, String, null: false, description: 'Humanized name for the offered model, e.g "Chat GPT 4o".'

        field :model_provider, String, null: true,
          experiment: { milestone: '18.6' },
          description: 'Provider for the model, e.g "OpenAI".'

        field :model_description, String, null: true, # rubocop:disable GraphQL/ExtractType -- this is an offered model attribute, no need for new type
          experiment: { milestone: '18.7' },
          description: 'Brief description of the model, e.g "Fast, cost-effective responses".'

        field :cost_indicator, String, null: true,
          experiment: { milestone: '18.7' },
          description: 'Presentational cost indicator for model usage, e.g "$", "$$", "$$$".'
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
