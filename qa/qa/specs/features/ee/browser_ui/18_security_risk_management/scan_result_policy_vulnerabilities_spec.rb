# frozen_string_literal: true

module QA
  RSpec.describe 'Security Risk Management',
    feature_category: :security_policy_management,
    quarantine: {
      issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/work_items/43776',
      type: :flaky
    } do
    describe 'Approval policy' do
      let!(:project) do
        create(:project,
          :with_readme,
          name: 'project-with-scan-result-policy',
          description: 'Project to test approval policy with secure')
      end

      let(:tag_name) { "secure_report_#{project.name}" }
      let!(:runner) do
        create(:project_runner, project: project, name: "runner-for-#{project.name}", tags: [tag_name])
      end

      let!(:scan_result_policy_project) do
        Support::Retrier.retry_on_exception(sleep_interval: 2, message: "Security policy project fabrication failed") do
          EE::Resource::SecurityScanPolicyProject.fabricate_via_api! do |commit|
            commit.full_path = project.full_path
          end
        end
      end

      let!(:policy_project) do
        create(:project,
          add_name_uuid: false,
          group: project.group,
          name: Pathname.new(scan_result_policy_project.api_response[:full_path]).basename.to_s)
      end

      let(:scan_result_policy_name) { 'greyhound' }
      let(:policy_yaml_path) { "qa/ee/fixtures/approval_policy_yaml/approval_policy.yml" }
      let(:premade_report_name) { "gl-container-scanning-report.json" }
      let(:premade_report_path) { "qa/ee/fixtures/secure_premade_reports/gl-container-scanning-report.json" }
      let(:commit_branch) { "new_branch_#{SecureRandom.hex(8)}" }

      let(:scan_result_policy_commit) do
        EE::Resource::ScanResultPolicyCommit.fabricate_via_api! do |commit|
          commit.policy_name = scan_result_policy_name
          commit.full_path = project.full_path
          commit.mode = :APPEND
          commit.policy_yaml = begin
            yaml_obj = YAML.load_file(policy_yaml_path)
            yaml_obj["actions"].first["user_approvers_ids"][0] = Runtime::User::Store.test_user.id
            yaml_obj
          end
        end
      end

      let(:target_branch_report_commit) do
        create_commit(branch_name: project.default_branch, actions: [
          ci_file(report_name: premade_report_name, action: 'create'),
          report_file(report_name: premade_report_name, report_path: premade_report_path, severity: 'High',
            action: 'create')
        ])
      end

      before do
        # Retry is needed due to delays with project authorization updates
        # Long term solution to accessing the status of a project authorization update
        # has been proposed in https://gitlab.com/gitlab-org/gitlab/-/issues/393369
        QA::Support::Retrier.retry_on_exception(sleep_interval: 2,
          message: "Retrying approval policy commit") do
          scan_result_policy_commit # fabricate approval policy commit
        end

        Flow::Login.sign_in

        # Create a target branch report for the approval policy to match against
        target_branch_report_commit

        project.visit!
      end

      after do
        runner.remove_via_api!
      end

      it 'requires approval when a pipeline report has findings matching the approval policy' do
        # Make sure approval policy commit was successful before running examples
        expect(scan_result_policy_commit.api_response).to have_key(:branch)
        expect(scan_result_policy_commit.api_response[:branch]).not_to be_nil

        create_scan_result_policy
        # Create a branch and a commit to trigger a pipeline to generate container scanning findings
        create_commit(branch_name: commit_branch, actions: [
          report_file(report_name: premade_report_name, report_path: premade_report_path,
            severity: 'Critical', action: 'update')
        ])

        merge_request = create_test_mr
        Flow::Pipeline.wait_for_pipeline_to_have_status_by_source_branch(
          project: project, source_branch: commit_branch, status: 'success'
        )

        wait_for_merge_request_to_be_blocked_by_policy(merge_request)

        Page::MergeRequest::Show.perform do |mr|
          expect(mr.approvals_required_from).to include(scan_result_policy_name)
          expect(mr.approved?).to be(false)
          expect(mr).to be_auto_mergeable
        end
      end

      it 'does not block merge when approval policy does not apply for pipeline security findings' do
        # Make sure approval policy commit was successful before running examples
        expect(scan_result_policy_commit.api_response).to have_key(:branch)
        expect(scan_result_policy_commit.api_response[:branch]).not_to be_nil

        create_scan_result_policy

        # Create a branch and a commit to trigger a pipeline to generate container scanning findings
        create_commit(branch_name: commit_branch, actions: [
          report_file(report_name: premade_report_name, report_path: premade_report_path,
            severity: 'Medium', action: 'update')
        ])

        merge_request = create_test_mr
        Flow::Pipeline.wait_for_pipeline_to_have_status_by_source_branch(
          project: project, source_branch: commit_branch, status: 'success'
        )
        wait_for_policy_rule_to_be_applied(merge_request)

        wait_for_merge_request_to_be_mergeable(merge_request)

        Page::MergeRequest::Show.perform do |mr|
          expect(mr).to be_mergeable
          expect(page.has_text?('Approval is optional')).to be true
        end
      end

      def ci_file(report_name:, action:)
        {
          action: action,
          file_path: '.gitlab-ci.yml',
          content: <<~YAML
            include:
              template: Container-Scanning.gitlab-ci.yml
              template: SAST.gitlab-ci.yml

            container_scanning:
              tags: [#{tag_name}]
              only: null # Template defaults to feature branches only
              variables:
                GIT_STRATEGY: fetch # Template defaults to none, which stops fetching the premade report
              script:
                - echo "Skipped"
              artifacts:
                reports:
                  container_scanning: #{report_name}
          YAML
        }
      end

      def create_scan_result_policy
        branch_name = scan_result_policy_commit.api_response[:branch]
        create(:merge_request,
          :no_preparation,
          project: policy_project,
          target_new_branch: false,
          source_branch: branch_name).merge_via_api!
      end

      def create_test_mr
        create(:merge_request,
          :no_preparation,
          project: project,
          target_new_branch: false,
          source_branch: commit_branch)
      end

      def wait_for_merge_request_to_be_blocked_by_policy(merge_request)
        merge_request.visit!

        QA::Support::Waiter.wait_until(max_duration: 120, sleep_interval: 2, reload_page: merge_request,
          message: "Waiting for MR to be blocked by approval policy") do
          Page::MergeRequest::Show.perform do |mr|
            mr.close_dap_panel_if_exists
            next false unless mr.approval_status_loaded?

            mr.approvals_required_from.include?(scan_result_policy_name) &&
              !mr.approved? &&
              mr.auto_mergeable?
          rescue EE::Page::MergeRequest::Show::ApprovalConditionsError
            false
          end
        end
      end

      def wait_for_merge_request_to_be_mergeable(merge_request)
        merge_request.visit!

        QA::Support::Waiter.wait_until(max_duration: 90, sleep_interval: 2, reload_page: merge_request,
          message: "Waiting for MR to become mergeable") do
          Page::MergeRequest::Show.perform do |mr|
            mr.close_dap_panel_if_exists
            mr.approval_status_loaded? &&
              mr.mergeable? &&
              page.has_text?('Approval is optional', wait: 1)
          end
        end
      end

      def wait_for_policy_rule_to_be_applied(merge_request)
        QA::Support::Waiter.wait_until(max_duration: 90, sleep_interval: 2,
          message: "Waiting for policy rule to be applied to MR") do
          merge_request.fetch_approval_rules.any? do |rule|
            rule_name = rule[:name] || rule['name']
            rule_type = rule[:rule_type] || rule['rule_type']

            rule_name == scan_result_policy_name && rule_type == 'report_approver'
          end
        end
      end

      def report_file(report_name:, report_path:, severity:, action:)
        {
          action: action,
          file_path: report_name.to_s,
          content: container_scanning_report_content(report_path, severity)
        }
      end

      def container_scanning_report_content(report_path, severity)
        if severity != "Critical"
          File.read(report_path.to_s).gsub("Critical", severity)
        else
          File.read(report_path.to_s)
        end
      end

      def create_commit(branch_name:, actions:)
        create(:commit,
          project: project,
          start_branch: project.default_branch,
          branch: branch_name,
          commit_message: 'Add premade container scanning report',
          actions: actions)
      end
    end
  end
end
