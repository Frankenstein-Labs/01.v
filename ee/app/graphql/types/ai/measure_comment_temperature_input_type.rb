# frozen_string_literal: true

module Types
  module Ai
    class MeasureCommentTemperatureInputType < BaseMethodInputType
      graphql_name 'AiMeasureCommentTemperatureInput'

      argument :content, GraphQL::Types::String,
        required: true,
        description: 'Content of the message.'
    end
  end
end
