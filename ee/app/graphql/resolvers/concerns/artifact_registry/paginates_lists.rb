# frozen_string_literal: true

module ArtifactRegistry
  module PaginatesLists
    extend ActiveSupport::Concern

    def artifact_registry_pagination(first: nil, last: nil, before: nil, after: nil)
      raise ::Gitlab::Graphql::Errors::ArgumentError, '`last` requires `before`' if last && before.blank?

      {
        limit: artifact_registry_outbound_limit(first: first, last: last),
        cursor: before.presence || after.presence
      }.compact
    end

    def artifact_registry_connection(page)
      ::Gitlab::Graphql::ExternallyPaginatedArray.new(
        page.prev_cursor,
        page.next_cursor,
        *page.nodes,
        has_next_page: page.next_cursor.present?,
        has_previous_page: page.prev_cursor.present?
      )
    end

    private

    def artifact_registry_outbound_limit(first:, last:)
      [first, last, artifact_registry_max_page_size].compact.min
    end

    def artifact_registry_max_page_size
      (field.respond_to?(:max_page_size) && field.max_page_size) || GitlabSchema.default_max_page_size # rubocop:disable Graphql/Descriptions -- false positive on the resolver's `field` accessor
    end
  end
end
