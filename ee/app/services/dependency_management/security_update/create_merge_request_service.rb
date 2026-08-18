# frozen_string_literal: true

module DependencyManagement
  module SecurityUpdate
    class CreateMergeRequestService < BaseService
      include Gitlab::Utils::StrongMemoize
      include Gitlab::ExclusiveLeaseHelpers
      include Gitlab::InternalEventsTracking

      MAX_OUTPUT_ARTIFACT_SIZE = 5.megabytes
      MAX_FILE_ACTIONS = 50
      WORKLOAD_JOB_NAME = 'workload'
      LEASE_TIMEOUT = 1.minute

      private_constant :MAX_OUTPUT_ARTIFACT_SIZE, :MAX_FILE_ACTIONS, :WORKLOAD_JOB_NAME

      # @param project [Project]
      # @param pipeline [Ci::Pipeline] the completed workload pipeline
      # @param vulnerability [Vulnerability]
      def initialize(project:, pipeline:, vulnerability:)
        super(project: project)

        @pipeline = pipeline
        @vulnerability = vulnerability
      end

      def execute
        return error_response(message: 'Feature not available') unless feature_available?
        return error_response(message: 'Pipeline has not completed successfully') unless pipeline_succeeded?
        return error_response(message: 'Service account not available') unless service_account

        output = fetch_and_parse_output
        return output if fetch_or_parse_failed?(output)

        return error_response(message: 'No dependency changes found in output') if output.dependencies.empty?
        return error_response(message: 'No updated files found in output') if output.updated_files.empty?

        # A maintainer already closed an MR for this vulnerability and we're not proposing a
        # newer version, so don't recreate it.
        if remediation_dismissed?(output)
          reschedule_remaining_remediations
          return skipped_response
        end

        commit_result = create_branch_and_commit(output)
        return commit_result if commit_result.error?

        mr_result = in_lock(lease_key, ttl: LEASE_TIMEOUT, retries: 2, sleep_sec: 1.second) do
          create_or_update_merge_request(output)
        end
        return mr_result if mr_result.error?

        merge_request = mr_result.payload[:merge_request]

        link_vulnerability_to_merge_request(merge_request)

        # The MR now reflects this resolution, so hold off re-resolving it for a while.
        RefreshCooldown.start(merge_request) if merge_request&.persisted?

        success_response(payload: { merge_request: merge_request })
      rescue Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError
        error_response(message: 'Could not obtain lock for merge request creation')
      rescue StandardError => e
        log_error(e)
        error_response(message: 'Unexpected error creating merge request')
      end

      private

      attr_reader :pipeline, :vulnerability

      def feature_available?
        project.licensed_feature_available?(:dependency_scanning)
      end

      def pipeline_succeeded?
        pipeline.complete? && pipeline.success?
      end

      def service_account
        result = DependencyManagement::ProvisionServiceAccountService
          .new(project: project)
          .execute

        return unless result.success?

        result.payload[:user]
      end
      strong_memoize_attr :service_account

      def workload_job
        pipeline.find_job_with_archive_artifacts(WORKLOAD_JOB_NAME)
      end
      strong_memoize_attr :workload_job

      def fetch_and_parse_output
        return error_response(message: 'job producing output.json artifact not found') unless workload_job

        raw_json = Gitlab::Ci::ArtifactFileReader
          .new(workload_job, max_archive_size: MAX_OUTPUT_ARTIFACT_SIZE)
          .read('output.json', max_size: MAX_OUTPUT_ARTIFACT_SIZE)

        return error_response(message: 'output.json artifact not found') unless raw_json

        OutputParser.parse(raw_json)
      rescue Gitlab::Ci::ArtifactFileReader::Error => e
        error_response(message: "Failed to read output.json artifact: #{e.message}")
      rescue OutputParser::ParseError => e
        error_response(message: "Failed to parse output.json: #{e.message}")
      end

      def fetch_or_parse_failed?(output)
        output.respond_to?(:error?) && output.error?
      end

      # The branch created by the pipeline containing the dependency updates.
      # Used as the MR source branch (the branch to be merged).
      def update_branch
        workload_job&.variables&.find { |v| v.key == 'DEPENDENCY_MANAGEMENT_SOURCE_REF' }&.value
      end
      strong_memoize_attr :update_branch

      # The project's default branch where dependency updates will be merged into.
      # Used as the MR target branch.
      def default_branch
        project.default_branch_or_main
      end

      def create_branch_and_commit(output)
        return error_response(message: 'Source ref is not set on pipeline') unless update_branch

        ensure_branch_exists

        existing_paths = project.repository.blobs_at(
          output.updated_files.map { |f| [update_branch, f.path] },
          blob_size_limit: 0 # existence check only, no content needed
        ).map(&:path).to_set

        actions = output.updated_files.map do |file|
          {
            action: existing_paths.include?(file.path) ? 'update' : 'create',
            file_path: file.path,
            content: file.content,
            encoding: file.encoding
          }
        end

        return error_response(message: "Too many file changes (#{actions.size})") if actions.size > MAX_FILE_ACTIONS

        result = ::Files::MultiService.new(project, service_account, {
          commit_message: build_commit_message(output),
          branch_name: update_branch,
          start_branch: update_branch,
          actions: actions,
          author_name: service_account.name,
          author_email: service_account.commit_email_or_default
        }).execute

        if result[:status] == :success
          success_response
        else
          error_response(message: "Failed to commit changes: #{result[:message]}")
        end
      rescue Gitlab::Git::PreReceiveError => e
        error_response(
          message: "Git pre-receive hook rejected the push: #{Gitlab::Utils::ErrorMessage.to_user_facing(e.message)}"
        )
      rescue Gitlab::Git::CommandError => e
        log_error(e)
        error_response(message: "Git error while committing: #{e.message}")
      end

      def ensure_branch_exists
        return if project.repository.branch_exists?(update_branch)

        result = ::Branches::CreateService.new(project, service_account)
          .execute(update_branch, default_branch)

        return if result[:status] == :success

        raise Gitlab::Git::CommandError, "Failed to create branch '#{update_branch}': #{result[:message]}"
      end

      def build_commit_message(output)
        dep_lines = output.dependencies.map do |dep|
          "#{dep.name}: #{dep.previous_version} → #{dep.version}"
        end

        <<~MSG.strip
          Update #{output.dependencies.map(&:name).join(', ')}

          #{dep_lines.join("\n")}

          This commit was automatically generated by GitLab Dependency Management
          to remediate a security vulnerability.

          Vulnerability: #{vulnerability.title}
          Severity: #{vulnerability.severity}
        MSG
      end

      def create_or_update_merge_request(output)
        # Re-check after acquiring lock - another worker may have already created the MR
        existing_mr = find_existing_merge_request
        return update_existing_merge_request(existing_mr, output) if existing_mr

        create_new_merge_request(output)
      end

      def lease_key
        "dependency_management:create_merge_request:#{project.id}:#{update_branch}"
      end

      def find_existing_merge_request
        project.merge_requests
          .opened
          .find_by(source_branch: update_branch) # rubocop:disable CodeReuse/ActiveRecord -- single lookup
      end

      def create_new_merge_request(output)
        merge_request = ::MergeRequests::CreateService.new(
          project: project,
          current_user: service_account,
          params: {
            source_branch: update_branch,
            target_branch: default_branch,
            title: build_mr_title(output),
            description: render_mr_description(output)
          }
        ).execute

        unless merge_request.persisted?
          return error_response(
            message: "Failed to create merge request: #{merge_request.errors.full_messages.to_sentence}"
          )
        end

        track_internal_event(
          'create_dependency_management_auto_remediation_mr',
          project: project,
          additional_properties: {
            purl_type: purl_type,
            merge_request_id: merge_request.id
          }
        )

        merge_request.assignees << service_account
        assign_reviewer(merge_request)

        success_response(payload: { merge_request: merge_request })
      end

      def assign_reviewer(merge_request)
        reviewer = project.maintainers.active.human.order_random.first

        unless reviewer
          Gitlab::AppLogger.warn(
            message: 'DependencyManagement: no active maintainer found to assign as reviewer',
            merge_request_iid: merge_request.iid,
            project_id: project.id
          )

          return
        end

        merge_request.reviewers << reviewer
      end

      # The title carries the proposed version, and RemediationDismissalChecker parses it
      # back out of closed MRs to compare against later proposals. A refresh that resolves
      # a newer version has to move the title with the diff or that comparison reads a
      # version we never actually proposed.
      def update_existing_merge_request(merge_request, output)
        updated_mr = ::MergeRequests::UpdateService.new(
          project: project,
          current_user: service_account,
          params: {
            title: build_mr_title(output),
            description: render_mr_description(output)
          }
        ).execute(merge_request)

        if updated_mr.errors.empty?
          success_response(payload: { merge_request: updated_mr })
        else
          error_response(
            message: "Failed to update merge request: #{updated_mr.errors.full_messages.to_sentence}"
          )
        end
      end

      def build_mr_title(output)
        MergeRequestTitle.build(output.dependencies)
      end

      def render_mr_description(output)
        ApplicationController.render(
          template: 'dependency_management/security_update/merge_request_description',
          formats: :md,
          locals: {
            dependencies: output.dependencies,
            updated_files: output.updated_files,
            vulnerability: vulnerability,
            vulnerability_url: vulnerability_url
          }
        )
      end

      def vulnerability_url
        Gitlab::Routing.url_helpers.project_security_vulnerability_url(project, vulnerability)
      end

      # purl_type is identical across all sbom_occurrences for a given vulnerability
      # (enforced during ingestion in Sbom::CreateOccurrencesVulnerabilitiesService),
      # so picking any one occurrence is safe.
      def purl_type
        vulnerability.sbom_occurrences.first&.purl_type
      end
      strong_memoize_attr :purl_type

      def link_vulnerability_to_merge_request(merge_request)
        return unless merge_request&.persisted?

        link = Vulnerabilities::MergeRequestLink.new(
          vulnerability: vulnerability,
          finding: vulnerability.finding,
          merge_request: merge_request
        )

        unless link.save
          Gitlab::AppLogger.warn(
            message: 'DependencyManagement: failed to link vulnerability to merge request',
            vulnerability_id: vulnerability.id,
            merge_request_iid: merge_request.iid,
            project_id: project.id,
            errors: link.errors.full_messages
          )
          return
        end

        Vulnerabilities::Reads::UpsertService.new(
          vulnerability,
          { has_merge_request: true },
          projects: project
        ).execute
      rescue StandardError => e
        log_error(e)
      end

      def remediation_dismissed?(output)
        # An open MR is handled by the update path, not treated as a dismissal.
        return false if find_existing_merge_request

        RemediationDismissalChecker
          .new(project: project, vulnerability: vulnerability)
          .dismissed?(output)
      end

      def reschedule_remaining_remediations
        ::DependencyManagement::SecurityUpdate::RescheduleWorker.perform_async(project.id)
      end

      def skipped_response
        Gitlab::AppLogger.info(
          message: 'DependencyManagement: skipping recreation of a user-dismissed remediation',
          project_id: project.id,
          vulnerability_id: vulnerability.id,
          source_branch: update_branch
        )

        success_response(payload: { skipped: true })
      end
    end
  end
end
