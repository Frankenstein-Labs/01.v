# frozen_string_literal: true

module Security
  module ScanProfiles
    class ProjectAttachService
      include Gitlab::Utils::StrongMemoize

      AUDIT_EVENT_NAME = 'security_scan_profile_attached_to_project'
      MAX_PROJECTS = 500

      def self.execute(...)
        new(...).execute
      end

      def initialize(profile:, current_user:, projects: [])
        @profile = profile
        @projects = projects
        @current_user = current_user
        @errors = []
      end

      def execute
        return { errors: errors } unless valid_projects?

        inserted_ids = insert_under_limit
        handle_errors(inserted_ids)
        initialize_profile_statuses(inserted_ids)
        create_audit_events(inserted_ids)
        schedule_analyzer_status_update_worker(inserted_ids)

        { errors: errors }
      rescue StandardError => e
        Gitlab::ErrorTracking.track_and_raise_for_dev_exception(e)
        error_result('An error has occurred during profile attachment')
      end

      private

      attr_reader :profile, :projects, :current_user, :errors

      def valid_projects?
        errors << 'At least one project must be provided' if projects.empty?
        errors << "Cannot attach profile to more than #{MAX_PROJECTS} items at once." if projects.size > MAX_PROJECTS
        errors.empty?
      end

      def insert_under_limit
        sql = <<~SQL
          INSERT INTO security_scan_profiles_projects (project_id, security_scan_profile_id, created_at, updated_at)
          SELECT candidate_project_id, :profile_id, NOW(), NOW()
          FROM UNNEST(ARRAY[:project_ids]) AS candidate_project_id
          WHERE (
            SELECT COUNT(*) FROM security_scan_profiles_projects spp
            WHERE spp.project_id = candidate_project_id
            AND EXISTS (
              SELECT 1 FROM security_scan_profiles sp
              WHERE sp.id = spp.security_scan_profile_id
              AND sp.deleted_at IS NULL
            )
          ) < :max_limit
          ON CONFLICT (project_id, security_scan_profile_id) DO NOTHING
          RETURNING project_id;
        SQL

        sanitized_sql = ActiveRecord::Base.sanitize_sql_array([sql, {
          project_ids: projects.map(&:id),
          profile_id: profile.id,
          max_limit: Security::ScanProfileProject::MAX_PROFILES_PER_PROJECT
        }])

        # rubocop:disable Database/AvoidUsingPluckWithoutLimit: -- False positive. This is not a relation.
        Security::ScanProfileProject.connection.execute(sanitized_sql)
          .pluck('project_id') # rubocop:disable CodeReuse/ActiveRecord -- reading query result
        # rubocop:enable Database/AvoidUsingPluckWithoutLimit:
      end

      def handle_errors(inserted_ids)
        requested_ids = projects.map(&:id)
        return if inserted_ids.size == requested_ids.size

        potential_error_ids = requested_ids - inserted_ids
        already_attached_ids = Security::ScanProfileProject
          .by_project_id(potential_error_ids)
          .for_scan_profile(profile.id)
          .limit(potential_error_ids.size)
          .pluck(:project_id) # rubocop:disable CodeReuse/ActiveRecord -- specific use case

        maxed_out_ids_set = (potential_error_ids - already_attached_ids).to_set
        maxed_out_projects = projects.select { |p| maxed_out_ids_set.include?(p.id) }
        return if maxed_out_projects.empty?

        # Preload routes to avoid N+1 queries when accessing project.full_path
        ActiveRecord::Associations::Preloader.new(records: maxed_out_projects, associations: [:route]).call

        maxed_out_projects.each do |project|
          errors << "Project '#{project.name}' (#{project.full_path}) has reached the maximum limit of scan profiles."
        end
      end

      def initialize_profile_statuses(inserted_ids)
        return if inserted_ids.empty?

        records = inserted_ids.map do |project_id|
          {
            project_id: project_id,
            security_scan_profile_id: profile.id,
            status: Security::ScanProfileProjectStatus.statuses[:success],
            consecutive_failure_count: 0,
            consecutive_success_count: 0,
            created_at: now,
            updated_at: now
          }
        end

        Security::ScanProfileProjectStatus.upsert_all(
          records,
          unique_by: [:project_id, :security_scan_profile_id]
        )
      end

      def schedule_analyzer_status_update_worker(inserted_ids)
        return unless inserted_ids.present?

        Security::AnalyzersStatus::ScheduleSettingChangedUpdateWorker.perform_async(inserted_ids, profile.scan_type)
      end

      def create_audit_events(attached_project_ids)
        return if current_user.blank? || attached_project_ids.empty?

        attached_ids_set = attached_project_ids.to_set
        attached_projects = projects.select { |p| attached_ids_set.include?(p.id) }
        return if attached_projects.empty?

        # Preload routes to avoid N+1 queries when accessing project.full_path
        ActiveRecord::Associations::Preloader.new(records: attached_projects, associations: [:route]).call

        ::Gitlab::Audit::Auditor.audit(audit_context) do
          attached_projects.each do |project|
            event = build_audit_event(project)
            ::Gitlab::Audit::EventQueue.push(event)
          end
        end
      end

      def audit_context
        {
          author: current_user,
          scope: profile.namespace,
          target: profile,
          name: AUDIT_EVENT_NAME
        }
      end

      def build_audit_event(project)
        AuditEvents::BuildService.new(
          author: current_user,
          scope: project,
          target: profile,
          created_at: now,
          message: "Attached security scan profile '#{profile.name}' to project '#{project.full_path}'",
          additional_details: {
            event_name: AUDIT_EVENT_NAME,
            profile_id: profile.id,
            profile_name: profile.name,
            scan_type: profile.scan_type,
            project_id: project.id,
            project_path: project.full_path
          }
        ).execute
      end

      def now
        Time.zone.now
      end
      strong_memoize_attr :now

      def error_result(message)
        {
          errors: [message]
        }
      end
    end
  end
end
