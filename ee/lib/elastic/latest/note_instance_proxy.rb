# frozen_string_literal: true

module Elastic
  module Latest
    class NoteInstanceProxy < ApplicationInstanceProxy
      SCHEMA_VERSION = 25_24

      # We're migrating the `confidential` Note column to `internal` and therefore write to both attributes.
      # https://gitlab.com/groups/gitlab-org/-/epics/9634
      DEFAULT_INDEX_ATTRIBUTES = %i[
        id note project_id noteable_type noteable_id created_at updated_at confidential internal
      ].freeze

      delegate :noteable, to: :target

      def as_indexed_json(_options = {})
        # `noteable` can be sometimes be nil (eg. when a commit has been
        # deleted) or somehow it was left orphaned in the database. In such
        # cases we want to delete it from the index since there is no value in
        # having orphaned notes be searchable.
        raise Elastic::Latest::DocumentShouldBeDeletedFromIndexError.new(target.class.name, target.id) if noteable.nil?

        data = {}

        # We don't use as_json(only: ...) because it calls all virtual and serialized attributes
        # https://gitlab.com/gitlab-org/gitlab/issues/349
        DEFAULT_INDEX_ATTRIBUTES.each do |attr|
          data[attr] = safely_read_attribute_for_elasticsearch(attr)
        end

        data.merge!(build_issue_data)
        data.merge!(build_traversal_ids)
        data.merge!(build_project_data)
        data.merge!(build_visibility_data)
        data.merge!(build_project_feature_access_level_data)
        data.merge!(build_schema_version)
        data.merge!(generic_attributes)

        data.deep_stringify_keys
      end

      def generic_attributes
        super.except('join_field')
      end

      private

      def build_visibility_data
        {
          visibility_level: target.project&.visibility_level || Gitlab::VisibilityLevel::PRIVATE
        }
      end

      def build_project_feature_access_level_data
        # other note types (DesignManagement::Design, AlertManagement::Alert, Epic, Vulnerability )
        # are indexed but not currently searchable so we will not add permission
        # data for them until the search capability is implemented
        case noteable
        when Snippet
          { snippets_access_level: safely_read_project_feature_for_elasticsearch(:snippets) }
        when Commit
          { repository_access_level: safely_read_project_feature_for_elasticsearch(:repository) }
        when Issue, MergeRequest
          access_level_attribute = ProjectFeature.access_level_attribute(noteable)

          { access_level_attribute.to_s => safely_read_project_feature_for_elasticsearch(noteable) }
        else
          {}
        end
      end

      def build_project_data
        return {} unless target.project

        {
          hashed_root_namespace_id: target.project.namespace&.hashed_root_namespace_id,
          archived: target.project.self_or_ancestors_archived?
        }
      end

      def build_issue_data
        return {} unless noteable.is_a?(Issue)

        {
          issue: {
            assignee_id: noteable.assignee_ids,
            author_id: noteable.author_id,
            confidential: noteable.confidential
          }
        }
      end

      def build_traversal_ids
        namespace = noteable.try(:namespace) ||
          noteable.try(:project)&.try(:namespace) ||
          noteable.try(:target_project)&.try(:namespace)

        return {} if namespace.nil?

        {
          traversal_ids: namespace.elastic_namespace_ancestry
        }
      end

      def build_schema_version
        {
          schema_version: schema_version
        }
      end

      def schema_version
        SCHEMA_VERSION
      end
    end
  end
end
