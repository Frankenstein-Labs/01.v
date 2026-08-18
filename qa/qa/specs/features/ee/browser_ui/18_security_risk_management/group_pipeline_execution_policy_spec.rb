# frozen_string_literal: true

module QA
  RSpec.describe 'Security Risk Management', feature_category: :security_policy_management do
    describe 'Group Pipeline Execution Policy' do
      let(:executor) { "qa-runner-#{Faker::Alphanumeric.alphanumeric(number: 8)}" }
      let(:group) { create(:group) }
      let(:policy_name) { 'Greyhound' }
      let(:template_project) do
        create(:project, name: 'template-project-pipeline-exec-policy',
          group: group, initialize_with_readme: true)
      end

      let(:template_project_ci_path) { "policy-ci-#{Faker::Alphanumeric.alphanumeric(number: 4)}.yml" }

      let(:project) do
        create(:project, name: 'project-test-pipeline-exec-policy', group: group, initialize_with_readme: true)
      end

      let(:merge_request) do
        create(:merge_request,
          project: project,
          description: Faker::Lorem.sentence,
          target_new_branch: false,
          file_name: Faker::File.unique.file_name,
          file_content: Faker::Lorem.sentence)
      end

      let!(:runner) { create(:group_runner, group: group, name: executor, tags: [executor]) }

      let!(:pipeline_exec_policy_ci_file) do
        create(:commit, project: template_project, commit_message: 'Add policy-ci.yml', actions: [
          { action: 'create', file_path: template_project_ci_path, content: pipeline_execution_policy_yaml }
        ])
      end

      let!(:project_ci_file) do
        create(:commit, project: project, commit_message: 'Add project .gitlab-ci.yml', actions: [
          { action: 'create', file_path: '.gitlab-ci.yml', content: project_ci_yaml }
        ])
      end

      let(:expected_job_log) { "This job is due to pipeline execution policy for #{group.path}" }

      before do
        Flow::Login.sign_in
      end

      after do
        runner.remove_via_api!
      end

      it 'executes jobs as per inject strategy',
        quarantine: {
          issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/28696',
          type: :flaky
        } do
        create_pipeline_execution_policy
        merge_pipeline_execution_policy

        merge_request.visit!
        Flow::Pipeline.wait_for_pipeline_creation_via_api(project: project)
        Flow::Pipeline.wait_for_latest_pipeline_to_have_status(project: project, status: 'success')

        Flow::Pipeline.visit_latest_pipeline
        aggregate_failures do
          Page::Project::Pipeline::Show.perform do |pipeline|
            expect(pipeline).to have_job('pipeline_exec_policy_build_job')
            expect(pipeline).to have_job('pipeline_exec_policy_pre_job')
            expect(pipeline).to have_job('pipeline_exec_policy_post_job')
            expect(pipeline).to have_job('project_job')
          end
        end

        verify_expected_job_log(job_name: 'pipeline_exec_policy_build_job', expected_text: expected_job_log)
        verify_expected_job_log(job_name: 'pipeline_exec_policy_pre_job', expected_text: expected_job_log)
        verify_expected_job_log(job_name: 'pipeline_exec_policy_post_job', expected_text: expected_job_log)
        verify_expected_job_log(job_name: 'project_job', expected_text: 'This is the project job. Colour grey')
      end

      it 'executes jobs as per override strategy',
        quarantine: {
          issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/28696',
          type: :flaky
        } do
        create_pipeline_execution_policy(override: true)
        merge_pipeline_execution_policy

        merge_request.visit!
        Flow::Pipeline.wait_for_pipeline_creation_via_api(project: project)
        Flow::Pipeline.wait_for_latest_pipeline_to_have_status(project: project, status: 'success')

        Flow::Pipeline.visit_latest_pipeline
        aggregate_failures do
          Page::Project::Pipeline::Show.perform do |pipeline|
            expect(pipeline).to have_job('pipeline_exec_policy_build_job')
            expect(pipeline).to have_job('pipeline_exec_policy_pre_job')
            expect(pipeline).to have_job('pipeline_exec_policy_post_job')
            expect(pipeline).not_to have_job('project_job')
          end
        end

        verify_expected_job_log(job_name: 'pipeline_exec_policy_build_job', expected_text: expected_job_log)
        verify_expected_job_log(job_name: 'pipeline_exec_policy_pre_job', expected_text: expected_job_log)
        verify_expected_job_log(job_name: 'pipeline_exec_policy_post_job', expected_text: expected_job_log)
      end

      private

      def create_pipeline_execution_policy(override: false)
        group.visit!
        Page::Group::Menu.perform(&:go_to_policies)

        EE::Page::Group::Policies::SecurityPolicies.perform do |new_policy_page|
          new_policy_page.click_new_policy
          new_policy_page.click_pipeline_execution_policy
          new_policy_page.set_policy_name(policy_name)
          new_policy_page.set_policy_description('To test pipeline execution policy')
          new_policy_page.select_strategy(override) if override
          new_policy_page.select_project(template_project.id)
          new_policy_page.set_ci_file_path(template_project_ci_path)
          new_policy_page.save_policy
        end
      end

      def merge_pipeline_execution_policy
        Page::MergeRequest::Show.perform do |mr_page|
          mr_page.wait_until(max_duration: 80, sleep_interval: 2, reload: true,
            message: 'Wait for policy MR page') do
            mr_page.has_merge_button?
          end

          Support::Retrier.retry_on_exception(sleep_interval: 2, reload_page: mr_page,
            message: "Retrying policy merge") do
            mr_page.merge!
          end
        end
      end

      def verify_expected_job_log(job_name:, expected_text:)
        project.visit_job(job_name)
        Page::Project::Job::Show.perform do |show|
          show.loaded?
          expect(show.output).to have_content(expected_text),
            "Didn't find '#{expected_text}' within #{job_name}'s log:\n#{show.output}."
        end
      end

      def pipeline_execution_policy_yaml
        <<~YAML
          default:
            tags: ["#{executor}"]

          pipeline_exec_policy_build_job:
            stage: build
            script:
              - echo "#{expected_job_log}"

          pipeline_exec_policy_pre_job:
            stage: .pipeline-policy-pre
            script:
              - echo "#{expected_job_log}"

          pipeline_exec_policy_post_job:
            stage: .pipeline-policy-post
            script:
              - echo "#{expected_job_log}"
        YAML
      end

      def project_ci_yaml
        <<~YAML
          stages:
            - build

          project_job:
            stage: build
            tags: ["#{executor}"]
            script:
              - echo "This is the project job. Colour grey"
        YAML
      end
    end
  end
end
