# frozen_string_literal: true

module Types
  module Geo
    # rubocop:disable Graphql/AuthorizeTypes -- because it is included
    class AiVectorizableFileUploadRegistryType < BaseObject
      graphql_name 'AiVectorizableFileUploadRegistry'

      include ::Types::Geo::RegistryType

      description 'Represents the Geo replication and verification state of an `ai_vectorizable_file_upload`'

      field :ai_vectorizable_file_upload_id, GraphQL::Types::ID, null: false,
        description: 'ID of the AI Vectorizable File Upload.'
    end
    # rubocop:enable Graphql/AuthorizeTypes
  end
end
