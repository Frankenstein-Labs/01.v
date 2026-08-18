# frozen_string_literal: true

module QA
  RSpec.describe 'Security Risk Management', feature_category: :security_policy_management,
    only: { pipeline: %i[staging staging-canary] } do
    describe 'approval policy' do
      let!(:project) do
        create(:project, :with_readme,
          name: 'project-with-fake-dependency-scan', description: 'Project to test license finding')
      end

      let!(:runner) do
        create(:project_runner, project: project, name: "runner-for-#{project.name}")
      end

      let!(:scan_result_policy_project) do
        QA::EE::Resource::SecurityScanPolicyProject.fabricate_via_api! do |commit|
          commit.full_path = project.full_path
        end
      end

      let!(:policy_project) do
        create(:project,
          group: project.group, add_name_uuid: false,
          name: Pathname.new(scan_result_policy_project.api_response[:full_path]).basename.to_s)
      end

      let(:scan_result_policy_name) { 'greyhound' }
      let(:policy_yaml_path) { "qa/ee/fixtures/approval_policy_yaml/approval_policy_license_finding_policy.yml" }
      let(:dependency_scan_fixtures) { Pathname.new(EE::Runtime::Path.fixture('dependency_scanning_fixtures')) }

      let(:commit_branch) { "new_branch_#{SecureRandom.hex(8)}" }
      let!(:approver) { Runtime::User::Store.additional_test_user }

      let(:scan_result_policy_commit) do
        QA::EE::Resource::ScanResultPolicyCommit.fabricate_via_api! do |commit|
          commit.policy_name = scan_result_policy_name
          commit.full_path = project.full_path
          commit.mode = :APPEND
          commit.policy_yaml = begin
            yaml_obj = YAML.load_file(policy_yaml_path)
            yaml_obj["actions"].first["user_approvers_ids"][0] = approver.id
            yaml_obj
          end
        end
      end

      let!(:ci_file) do
        {
          file_path: '.gitlab-ci.yml',
          content: <<~YAML
            dependency_scanning:
              stage: test
              script:
              - echo "Fake scan"
              artifacts:
                paths:
                  - "gl-sbom-*.cdx.json"
                reports:
                  cyclonedx: "gl-sbom-*.cdx.json"
                  dependency_scanning: gl-dependency-scanning-report.json
          YAML
        }
      end

      let!(:repository_commit) do
        build(:commit,
          project: project,
          start_branch: project.default_branch,
          branch: commit_branch,
          commit_message: 'Add dependency scan files and .gitlab-ci.yml') do |commit|
            commit.add_directory(dependency_scan_fixtures)
            commit.add_files([ci_file])
          end.fabricate_via_api!
      end

      before do
        project.add_member(approver)
        scan_result_policy_commit # fabricate approval policy commit

        Flow::Login.sign_in
        project.visit!
      end

      after do
        runner.remove_via_api!
        project.remove_via_api!
      end

      it 'requires approval when license findings violate approval policy',
        quarantine: {
          issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24937',
          type: :investigating
        } do
        expect(scan_result_policy_commit.api_response).to have_key(:branch)
        expect(scan_result_policy_commit.api_response[:branch]).not_to be_nil

        create_scan_result_policy
        # Create MR after creating the approval policy
        merge_request = create_test_mr

        Flow::Pipeline.wait_for_latest_pipeline(status: 'passed', wait: 90)
        merge_request.visit!

        Page::MergeRequest::Show.perform do |mr|
          expect(mr).not_to be_mergeable
          expect(mr.approvals_required_from).to include(scan_result_policy_name)
        end
      end

      def create_test_mr
        create(:merge_request,
          :no_preparation,
          project: project,
          target_new_branch: false,
          source_branch: commit_branch)
      end

      def create_scan_result_policy
        branch_name = scan_result_policy_commit.api_response[:branch]
        create(:merge_request,
          :no_preparation,
          project: policy_project,
          target_new_branch: false,
          source_branch: branch_name).merge_via_api!
      end
    end
  end
end
