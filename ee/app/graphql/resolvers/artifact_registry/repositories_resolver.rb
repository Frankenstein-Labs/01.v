# frozen_string_literal: true

module Resolvers
  module ArtifactRegistry
    class RepositoriesResolver < BaseResolver
      include ::ArtifactRegistry::PaginatesLists

      type ::Types::ArtifactRegistry::RepositoryType.connection_type, null: true

      DEFAULT_SORT = ::Types::ArtifactRegistry::RepositorySortEnum.values.fetch('LAST_UPDATED_AT_DESC').value

      argument :format, ::Types::ArtifactRegistry::RepositoryFormatEnum,
        required: false,
        experiment: { milestone: '19.3' },
        description: 'Return only repositories holding the given package format.'

      argument :kind, ::Types::ArtifactRegistry::RepositoryKindEnum,
        required: false,
        experiment: { milestone: '19.3' },
        description: 'Return only repositories sourcing their artifacts the given way.'

      # Artifact Registry sorts by `name` ascending without a pair, so the resolver always sends one.
      argument :sort, ::Types::ArtifactRegistry::RepositorySortEnum,
        required: false,
        default_value: DEFAULT_SORT,
        replace_null_with_default: true,
        experiment: { milestone: '19.3' },
        description: 'Sort repositories by the criteria.'

      private

      def resolve_artifact_registry(sort:, format: nil, kind: nil, first: nil, last: nil, before: nil, after: nil)
        page = artifact_registry_client.repositories(
          slug: artifact_registry_slug,
          **{ format: format, kind: kind }.compact,
          **sort,
          **artifact_registry_pagination(first: first, last: last, before: before, after: after)
        )

        # A namespace the caller cannot see, or that is absent, resolves the field null rather
        # than erroring, which is the outcome the view renders as not found.
        return unless page

        artifact_registry_connection(page)
      end
    end
  end
end
