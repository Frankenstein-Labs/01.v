# frozen_string_literal: true

module Types
  module ArtifactRegistry
    class RepositoryType < BaseObject
      graphql_name 'ArtifactRegistryRepository'
      description 'Repository in Artifact Registry.'

      authorize :read_artifact_registry

      # A repository is only reachable through the organization connection field, which authorizes
      # against the organization, and it owns no group or project to scope a token against.
      authorize_granular_token skip_reason: :parent_authorizes

      field :name, GraphQL::Types::String,
        null: false,
        experiment: { milestone: '19.3' },
        description: 'Name of the repository, unique within its namespace.'

      field :format, ::Types::ArtifactRegistry::RepositoryFormatEnum,
        null: false,
        experiment: { milestone: '19.3' },
        description: 'Package format the repository holds.'

      field :kind, ::Types::ArtifactRegistry::RepositoryKindEnum,
        null: false,
        experiment: { milestone: '19.3' },
        description: 'How the repository sources its artifacts.'

      field :visibility, ::Types::ArtifactRegistry::RepositoryVisibilityEnum,
        null: false,
        experiment: { milestone: '19.3' },
        description: 'Who can read the repository.'

      field :downloads_count, GraphQL::Types::BigInt,
        null: false,
        experiment: { milestone: '19.3' },
        description: 'Number of artifact downloads from the repository. Buffered, so it can lag.'

      field :size_bytes, GraphQL::Types::BigInt,
        null: false,
        experiment: { milestone: '19.3' },
        description: 'Storage the repository occupies, in bytes. Buffered, so it can lag.'

      field :last_updated_at, ::Types::TimeType,
        null: true,
        experiment: { milestone: '19.3' },
        description: 'Time the repository content last changed. Null when the content never changed.'

      field :description, GraphQL::Types::String,
        null: true,
        experiment: { milestone: '19.3' },
        description: 'Human-readable description of the repository. Null when unset.'

      # Hosted repositories carry no settable settings (S17 Phase 1), and the remote and
      # virtual shapes are not contracted until the Go-service S13 phase lands, so the
      # polymorphic object has no fixed shape to type yet. It stays JSON for the experiment
      # stage; a typed union/interface replaces it before GA. See
      # https://gitlab.com/gitlab-org/gitlab/-/issues/609504.
      # Non-null: the client defaults it to an empty object, so it is always present.
      field :settings, GraphQL::Types::JSON, # rubocop:disable Graphql/JSONType -- polymorphic settings; typed shape deferred to the S13 contract (see comment)
        null: false,
        experiment: { milestone: '19.3' },
        description: 'Kind-specific configuration, discriminated by format and kind. Empty for hosted repositories.'
    end
  end
end
