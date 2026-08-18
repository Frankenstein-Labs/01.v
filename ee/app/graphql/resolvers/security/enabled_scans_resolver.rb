# frozen_string_literal: true

module Resolvers
  module Security
    class EnabledScansResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type ::Types::Security::EnabledScansType, null: false
      authorize :read_security_resource

      def resolve(...)
        enabled_scans = ::Security::Scan.scan_types.transform_values { false }
        scans_in_pipeline.each { |scan_type| enabled_scans[scan_type] = true }
        enabled_scans.merge({ ready: ready })
      end

      private

      def ready
        ::Security::Scan.results_ready?(object)
      end

      def scans_in_pipeline
        model.by_pipeline_ids(pipeline_ids).distinct_scan_types
      end

      def pipeline_ids
        object.self_and_project_descendants.pluck_primary_key
      end

      def model
        ::Security::Scan
      end
    end
  end
end
