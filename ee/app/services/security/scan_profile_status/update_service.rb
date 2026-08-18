# frozen_string_literal: true

module Security
  module ScanProfileStatus
    class UpdateService
      BUILD_TO_STATUS = {
        'success' => :success,
        'failed' => :failed,
        'canceled' => :failed,
        'skipped' => :failed
      }.freeze

      # Higher value = worse status = higher priority when deduplicating
      STATUS_PRIORITY = {
        success: 0,
        failed: 1
      }.freeze

      def initialize(pipeline)
        @pipeline = pipeline
        @project = pipeline&.project
      end

      def execute
        return unless project&.licensed_feature_available?(:security_scan_profiles)

        build_data_by_profile = dedupe_builds_by_profile(profile_triggered_builds)
        return if build_data_by_profile.empty?

        existing_statuses = ScanProfileProjectStatus
          .by_project(project.id)
          .index_by(&:security_scan_profile_id)

        upsert_records = build_data_by_profile.map do |profile_id, (status, build)|
          build_upsert_attributes(profile_id, status, build, existing_statuses[profile_id])
        end

        ScanProfileProjectStatus.upsert_all(
          upsert_records,
          unique_by: [:project_id, :security_scan_profile_id]
        )
      end

      private

      attr_reader :pipeline, :project

      def dedupe_builds_by_profile(builds)
        builds.each_with_object({}) do |build, build_data_by_profile|
          profile_id = resolve_profile_id(build)
          next unless profile_id

          status = BUILD_TO_STATUS[build.status] || :failed
          current_status, _ = build_data_by_profile[profile_id]
          next if current_status && STATUS_PRIORITY[current_status] > STATUS_PRIORITY[status]

          build_data_by_profile[profile_id] = [status, build]
        end
      end

      def profile_triggered_builds
        pipeline.builds
          .with_build_source(:security_scan_profiles)
          .with_statuses(Ci::HasStatus::COMPLETED_STATUSES)
          .latest
      end

      def resolve_profile_id(build)
        redis_profile_id = begin
          ::Gitlab::Ci::Pipeline::SecurityScanProfiles::ScanProfileMappingStore.profile_id_for_build(build)
        rescue ::Redis::BaseError => e
          Gitlab::ErrorTracking.track_exception(e, extra: { build_id: build.id, pipeline_id: pipeline.id })
          nil
        end

        redis_profile_id || resolve_profile_id_from_build(build)
      end

      def resolve_profile_id_from_build(build)
        scan_type = detect_scan_type(build)
        return unless scan_type

        profiles = profiles_by_scan_type[scan_type.to_s] || []

        if profiles.size > 1
          Gitlab::AppLogger.warn(
            message: 'Multiple scan profiles found for scan type, skipping fallback resolution',
            scan_type: scan_type,
            project_id: project.id,
            profile_count: profiles.size
          )
          return
        end

        profiles.first&.id
      end

      def profiles_by_scan_type
        @profiles_by_scan_type ||= project.security_scan_profiles.not_deleted.scanner.group_by(&:scan_type)
      end

      def detect_scan_type(build)
        report_keys = build_reports(build).map(&:to_sym)
        profile_types = Enums::Security.scan_profile_types.keys

        matched = (report_keys & profile_types).first
        return matched if matched

        return :dependency_scanning if report_keys.include?(:cyclonedx) &&
          build.name.include?('dependency_scanning')

        nil
      end

      def build_reports(build)
        build.options.dig(:artifacts, :reports)&.keys || []
      end

      def build_upsert_attributes(profile_id, status, build, existing)
        failure_count = calculate_failure_count(existing, status)
        success_count = calculate_success_count(existing, status)
        resolved_status = resolve_status(status, failure_count)

        {
          project_id: project.id,
          security_scan_profile_id: profile_id,
          status: ScanProfileProjectStatus.statuses[resolved_status],
          consecutive_failure_count: failure_count,
          consecutive_success_count: success_count,
          last_scan_at: build.started_at || build.created_at,
          build_id: build.id,
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      def calculate_failure_count(existing, status)
        return 0 unless status == :failed

        (existing&.consecutive_failure_count || 0) + 1
      end

      def calculate_success_count(existing, status)
        return 0 unless status == :success

        (existing&.consecutive_success_count || 0) + 1
      end

      def resolve_status(status, failure_count)
        return :warning if status == :failed && failure_count < ScanProfileProjectStatus::FAILED_THRESHOLD

        status
      end
    end
  end
end
