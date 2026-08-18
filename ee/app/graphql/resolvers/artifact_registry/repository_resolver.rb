# frozen_string_literal: true

module Resolvers
  module ArtifactRegistry
    class RepositoryResolver < BaseResolver
      type ::Types::ArtifactRegistry::RepositoryType, null: true

      argument :name, GraphQL::Types::String,
        required: true,
        description: 'Name of the repository to read, unique within its namespace.'

      private

      # Resolves one repository by the organization's slug and the requested
      # name. The client returns nil on a read-404, which surfaces here as a
      # null field for edit prefill.
      def resolve_artifact_registry(name:)
        artifact_registry_client.repository(slug: artifact_registry_slug, name: name)
      end
    end
  end
end
