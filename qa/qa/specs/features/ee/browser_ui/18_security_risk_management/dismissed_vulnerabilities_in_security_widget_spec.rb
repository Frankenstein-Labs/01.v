# frozen_string_literal: true

module QA
  RSpec.describe('Security Risk Management', feature_category: :vulnerability_management) do
    describe 'MR security widget' do
      let(:secret_detection_report) { "gl-secret-detection-report.json" }
      let(:secret_detection_report_mr) { "gl-secret-detection-report-mr.json" }

      let!(:project) do
        create(:project,
          name: "project-with-vulnerabilities-#{SecureRandom.hex(4)}",
          description: 'To test dismissed vulnerabilities in MR widget')
      end

      let!(:artefacts_directory) do
        Pathname.new(EE::Runtime::Path.fixture('dismissed_security_findings_mr_widget'))
      end

      let!(:runner) do
        create(:project_runner, project: project, name: "runner-for-#{project.name}-#{SecureRandom.hex(4)}",
          tags: ['secure_report'])
      end

      let!(:repository) do
        build(:commit, project: project, commit_message: 'Add report files') do |commit|
          commit.add_directory(artefacts_directory)
        end.fabricate_via_api!
      end

      let!(:ci_yaml_commit) do
        create(:commit, project: project, commit_message: 'Add .gitlab-ci.yml', actions: [
          ci_file(secret_detection_report).merge(action: 'create')
        ])
      end

      let(:source_mr_repository) do
        create(:commit,
          project: project,
          branch: "test-dismissed-vulnerabilities-#{SecureRandom.hex(4)}",
          start_branch: project.default_branch,
          commit_message: 'new secret detection findings report in yml file',
          actions: [ci_file(secret_detection_report_mr).merge(action: 'update')])
      end

      let!(:merge_request) do
        create(:merge_request,
          project: project,
          source: source_mr_repository,
          source_branch: source_mr_repository.branch,
          target_branch: project.default_branch)
      end

      before do
        Flow::Login.sign_in
        project.visit!
      end

      after do
        runner.remove_via_api!
      end

      it 'checks that dismissed vulnerabilities do not show up' do
        # Wait on the default branch pipeline specifically. The merge request pipeline is created first, so
        # waiting on the "latest" pipeline can resolve to it and race ahead of the report we depend on.
        Flow::Pipeline.wait_for_pipeline_to_have_status_by_source_branch(
          project: project, source_branch: project.default_branch, status: 'success')

        Page::Project::Menu.perform(&:go_to_vulnerability_report)

        EE::Page::Project::Secure::VulnerabilityReport.perform do |vulnerability_report|
          vulnerability_report.wait_for_vuln_report_to_load
          vulnerability_report.select_all_vulnerabilities
          vulnerability_report.change_state('dismissed', 'not_applicable')
        end

        merge_request.visit!
        wait_for_mr_pipeline_success

        Page::MergeRequest::Show.perform do |merge_request|
          expect(merge_request).to have_vulnerability_report(timeout: 120)
          expect(merge_request).to have_vulnerability_count(2)
        end
      end

      private

      def wait_for_mr_pipeline_success
        merge_request
        Support::Retrier.retry_until(max_duration: 120, message: "Waiting for MR pipeline to complete",
          sleep_interval: 5) do
          pipeline = project.pipelines.find { |item| item[:source] == "merge_request_event" }
          pipeline&.dig(:status) == "success"
        end
      end

      def ci_file(report_name)
        {
          file_path: '.gitlab-ci.yml',
          content: <<~YAML
            workflow:
              rules:
                - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
                - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

            include:
              template: Jobs/Secret-Detection.latest.gitlab-ci.yml

            secret_detection:
              tags: [secure_report]
              script:
                - echo "Skipped"
              artifacts:
                reports:
                  secret_detection: #{report_name}
              allow_failure: false
          YAML
        }
      end
    end
  end
end
