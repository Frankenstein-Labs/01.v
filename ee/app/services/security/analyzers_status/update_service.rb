# frozen_string_literal: true

module Security
  module AnalyzersStatus
    class UpdateService
      include ::Security::AnalyzersStatus::AggregatedTypesHandler

      SCAN_TO_ANALYZER_STATUS = {
        'succeeded' => :success,
        'job_failed' => :failed,
        'report_error' => :failed,
        'preparation_failed' => :failed
      }.freeze

      SCAN_PROFILE_TYPE_TO_ANALYZER_TYPES = {
        'sast' => %w[sast sast_advanced]
      }.freeze

      # Because :sast_iac and :sast_advanced reports belong to a report with a name of 'sast',
      # we have to do extra checking to determine which reports have been included
      # When using advanced sast, sast should also show in the report names.
      # kics-iac-sast is being treated as IaC and not as SAST.
      SAST_BUILD_NAME_PREFIX_OVERRIDES = {
        'gitlab-advanced-sast' => { add: [:sast_advanced], remove: [] }.freeze,
        'kics-iac-sast' => { add: [:sast_iac], remove: [:sast] }.freeze
      }.freeze

      PIPELINE_EXCLUDED_TYPES = %w[secret_detection secret_detection_secret_push_protection
        container_scanning container_scanning_for_registry dependency_scanning_post_processing].freeze

      STALE_THRESHOLD = 3

      def initialize(pipeline)
        @pipeline = pipeline
        @project = pipeline&.project
      end

      def execute
        return unless executable?

        status_diff = DiffService.new(project, analyzers_statuses).execute
        upsert_analyzers_statuses
        update_ancestors(status_diff)

      rescue StandardError => error
        Gitlab::ErrorTracking.track_exception(error, project_id: project.id, pipeline_id: pipeline.id)
      end

      private

      attr_reader :pipeline, :project

      def executable?
        pipeline.present? && project.present?
      end

      def analyzers_statuses
        @analyzers_statuses ||= begin
          scan_based = scan_based_analyzers_statuses
          absent = absent_statuses(scan_based)
          aggregated_statuses = aggregated_statuses(scan_based.merge(absent))

          scan_based.merge(absent).merge(aggregated_statuses)
        end
      end

      def absent_statuses(scan_based_statuses)
        excluded = excluded_types(scan_based_statuses)
        AnalyzerProjectStatus
          .by_projects(project)
          .without_types(excluded)
          .select(:analyzer_type, :status, :consecutive_absence_count, :build_id, :last_call)
          .to_h { |record| [record.analyzer_type.to_sym, absent_status_hash(record)] }
      end

      def absent_status_hash(record)
        new_count = record.consecutive_absence_count + 1
        new_status = new_count >= STALE_THRESHOLD ? :stale : record.status.to_sym

        build_analyzer_status_hash(project, record.analyzer_type.to_sym, new_status, status_hash: {
          consecutive_absence_count: new_count,
          build_id: record.build_id,
          last_call: record.last_call
        })
      end

      def excluded_types(scan_based_statuses)
        PIPELINE_EXCLUDED_TYPES +
          (scan_based_statuses.present? ? scan_based_statuses.keys : []) +
          profile_covered_scan_types # Keep attached profiles types out of not_configured_statuses even without a job
      end

      def normalize_aggregated_types(existing_group_types)
        TYPE_MAPPINGS.each do |type, config|
          if existing_group_types.include?(type)
            existing_group_types.delete(type)
            existing_group_types.push(config[:pipeline_type])
          end
        end

        existing_group_types
      end

      def aggregated_statuses(analyzers_statuses)
        TYPE_MAPPINGS.values.each_with_object({}) do |config, memo|
          pipeline_type = config[:pipeline_type]
          next unless analyzers_statuses[pipeline_type]

          aggregated_status =
            build_aggregated_type_status(project, pipeline_type, analyzers_statuses[pipeline_type])
          memo[aggregated_status[:analyzer_type]] = aggregated_status if aggregated_status
        end
      end

      def upsert_analyzers_statuses
        return unless analyzers_statuses.present?

        AnalyzerProjectStatus.upsert_all(analyzers_statuses.values, unique_by: [:project_id, :analyzer_type])
        InventoryFilters::AnalyzerStatusUpdateService.execute([project], analyzers_statuses.values)
      end

      def update_ancestors(status_diff)
        Security::AnalyzerNamespaceStatuses::AncestorsUpdateService.execute(status_diff)
      end

      def profile_covered_scan_types
        Security::ScanProfile.scan_type_names_for_project(project)
          .flat_map { |type| SCAN_PROFILE_TYPE_TO_ANALYZER_TYPES.fetch(type, [type]) }
      end

      def pipeline_scans
        @pipeline_scans ||= pipeline.security_scans
          .latest
          .without_statuses(%i[purged created preparing])
          .including_build
          .ordered_by_created_at_and_id
      end

      def scan_based_analyzers_statuses
        pipeline_scans.each_with_object({}) do |scan, memo|
          scan_analyzer_groups = analyzer_groups_from_scan(scan)
          status = SCAN_TO_ANALYZER_STATUS[scan.status]
          next unless status

          scan_analyzer_groups.each do |scan_analyzer_group|
            if status_priority(status) > status_priority(memo[scan_analyzer_group]&.[](:status))
              memo[scan_analyzer_group] =
                build_analyzer_status_hash(project, scan_analyzer_group, status, build: scan.build)
            end
          end
        end
      end

      def analyzer_groups_from_scan(scan)
        scan_type = scan.scan_type.to_sym
        return [] unless Enums::Security.extended_analyzer_types.key?(scan_type)

        existing_group_types = [scan_type]
        if scan.scan_type == 'sast'
          existing_group_types = apply_sast_subtype_overrides(scan.build&.name, existing_group_types)
        end

        normalize_aggregated_types(existing_group_types)
      end

      def apply_sast_subtype_overrides(build_name, group_types)
        # Support both direct job names and policy-or-profile-enforced job names with suffixes
        # e.g., 'gitlab-advanced-sast', 'gitlab-advanced-sast-cpp',
        # 'gitlab-advanced-sast-0', 'gitlab-advanced-sast:policy-123456-0'
        prefix, override = SAST_BUILD_NAME_PREFIX_OVERRIDES.find { |prefix, _| build_name.to_s.start_with?(prefix) }
        return group_types unless prefix

        (group_types - override[:remove]) | override[:add]
      end
    end
  end
end
