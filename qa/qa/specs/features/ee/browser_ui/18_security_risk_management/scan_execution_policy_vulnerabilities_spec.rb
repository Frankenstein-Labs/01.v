# frozen_string_literal: true

module QA
  RSpec.describe 'Security Risk Management', except: { subdomain: 'pre' },
    feature_category: :security_policy_management do
    describe 'Group Level Scan Execution Policy' do
      let(:group) { create(:group, path: "scan-execution-policy-group-#{SecureRandom.hex(4)}") }

      let!(:project) do
        create(:project, :with_readme, group: group, name: 'project-with-scan-execution-policy')
      end

      let!(:runner) do
        create(:project_runner, project: project, name: "runner-for-#{project.name}")
      end

      let!(:scan_execution_policy_project) do
        EE::Resource::SecurityScanPolicyProject.fabricate_via_api! do |commit|
          commit.full_path = project.group.full_path # Configuring group scan execution policy
        end
      end

      let!(:policy_project) do
        create(:project,
          group: project.group,
          add_name_uuid: false,
          name: Pathname.new(scan_execution_policy_project.api_response[:full_path]).basename.to_s)
      end

      let(:scan_execution_policy_name) { 'greyhound' }
      let(:policy_yaml_path) do
        Pathname.new(EE::Runtime::Path.fixture('scan_execution_policy_yaml/scan_execution_policy_schedule.yml'))
      end

      let(:job_name) { 'secret-detection-0' }

      let(:commit_branch) { "new_branch_#{SecureRandom.hex(8)}" }

      let(:scan_execution_policy_commit) do
        EE::Resource::ScanResultPolicyCommit.fabricate_via_api! do |commit|
          commit.policy_name = scan_execution_policy_name
          commit.full_path = project.group.full_path # Configuring group scan execution policy
          commit.mode = :APPEND
          commit.policy_yaml = YAML.load_file(policy_yaml_path)
        end
      end

      before do
        Flow::Login.sign_in
        project.visit!
        scan_execution_policy_commit # fabricate scan execution policy commit
      end

      after do
        runner.remove_via_api!
      end

      it 'takes effect when pipeline is run on the main branch',
        quarantine: {
          issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24046',
          type: :investigating
        } do
        expect(scan_execution_policy_commit.api_response).to have_key(:branch)
        expect(scan_execution_policy_commit.api_response[:branch]).not_to be_nil

        create_scan_execution_policy

        create_commit('main')
        # Check that secret-detection job is triggered whenever there is a pipeline is triggered on main
        expect { pipeline_has_a_job? }.to eventually_be_truthy.within(max_duration: 60, reload_page: page),
          "Expected #{job_name} to appear but it is not present"
      end

      it 'does not take effect when pipeline is run on non default branch' do
        expect(scan_execution_policy_commit.api_response).to have_key(:branch)
        expect(scan_execution_policy_commit.api_response[:branch]).not_to be_nil

        create_scan_execution_policy

        create_commit(commit_branch) # commit_branch variable is also used in create_test_mr function

        create_test_mr
        Flow::Pipeline.wait_for_pipeline_to_have_status_by_source_branch(
          project: project, source_branch: commit_branch, status: 'success'
        )
        # Check that secret-detection job is NOT present in MR pipeline (non-default branch)
        expect(pipeline_has_a_job?).to be_falsey
      end

      private

      def create_scan_execution_policy
        branch_name = scan_execution_policy_commit.api_response[:branch]
        create(:merge_request,
          :no_preparation,
          project: policy_project,
          target_new_branch: false,
          source_branch: branch_name).merge_via_api!
      end

      def pipeline_has_a_job?
        Flow::Pipeline.visit_latest_pipeline

        Page::Project::Pipeline::Show.perform do |pipeline|
          pipeline.has_job?(job_name)
        end
      end

      def ci_file
        {
          action: 'create',
          file_path: '.gitlab-ci.yml',
          content: <<~YAML
            test:
              script: echo "Test job"
          YAML
        }
      end

      def test_file
        {
          action: 'create',
          file_path: 'abc.py',
          content: <<~TXT
            import os
            os.getenv('QA_RUN_TYPE')
          TXT
        }
      end

      def create_commit(branch_name)
        create(:commit,
          project: project,
          start_branch: project.default_branch,
          branch: branch_name,
          commit_message: "Commit files to #{branch_name} branch",
          actions: [ci_file, test_file])
      end

      def create_test_mr
        create(:merge_request,
          :no_preparation,
          project: project,
          target_new_branch: false,
          source_branch: commit_branch)
      end
    end
  end
end
