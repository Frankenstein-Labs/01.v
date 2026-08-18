# frozen_string_literal: true

module Elastic
  module Latest
    class MergeRequestInstanceProxy < ApplicationInstanceProxy
      SCHEMA_VERSION = 24_49

      def as_indexed_json(_options = {})
        # We don't use as_json(only: ...) because it calls all virtual and serialized attributtes
        # https://gitlab.com/gitlab-org/gitlab/issues/349
        data = {}

        [
          :id,
          :iid,
          :target_branch,
          :source_branch,
          :title,
          :description,
          :created_at,
          :updated_at,
          :state,
          :merge_status,
          :source_project_id,
          :target_project_id,
          :project_id, # Redundant field aliased to target_project_id makes it easier to share searching code
          :author_id
        ].each do |attr|
          data[attr.to_s] = safely_read_attribute_for_elasticsearch(attr)
        end

        data['visibility_level'] = target.project.visibility_level
        data['merge_requests_access_level'] = safely_read_project_feature_for_elasticsearch(:merge_requests)
        data['hashed_root_namespace_id'] = target_project.namespace.hashed_root_namespace_id

        data['hidden'] = target.hidden?
        data['archived'] = target.project.self_or_ancestors_archived?

        # Schema version. The format is YYVV (year/version).
        # YY is the two-digit year, VV is the version number (01-99) within that year.
        # Please update if you're changing the schema of the document
        data['schema_version'] = SCHEMA_VERSION
        data['label_ids'] = target.label_ids.map(&:to_s)
        data['traversal_ids'] = target.project.elastic_namespace_ancestry

        data['assignee_ids'] = target.assignee_ids.map(&:to_s)

        data.merge(generic_attributes)
      end

      def generic_attributes
        super.except('join_field')
      end
    end
  end
end
