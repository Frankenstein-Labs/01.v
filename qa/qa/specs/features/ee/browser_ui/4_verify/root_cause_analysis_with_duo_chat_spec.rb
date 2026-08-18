# frozen_string_literal: true

module QA
  RSpec.describe 'Verify', :requires_admin, :external_ai_provider, feature_category: :continuous_integration,
    only: { pipeline: %i[staging staging-canary] } do
    describe 'Root Cause Analysis' do
      let(:executor) { "qa-runner-#{SecureRandom.hex(4)}" }
      let(:pipeline_job_name) { 'test-root-cause-analysis' }
      let(:project) { create(:project, name: 'project-for-root-cause-analysis') }
      let(:root_cause_pattern) { /Root cause of failure|Root cause/i }
      let(:solution_pattern) { /Example Fix|Solution|How to Fix/i }
      let(:root_cause_analysis_patterns) { [root_cause_pattern, solution_pattern] }
      let(:expected_command) { '/troubleshoot' }

      let!(:runner) { create(:project_runner, project: project, name: executor, tags: [executor]) }

      let!(:commit) do
        create(:commit, project: project, commit_message: 'Add .gitlab-ci.yml', actions: [
          {
            action: 'create',
            file_path: '.gitlab-ci.yml',
            content: <<~YAML
              #{pipeline_job_name}:
                tags:
                  - #{executor}
                script: brew doctor
            YAML
          }
        ])
      end

      let(:job) do
        create(:job, id: project.job_by_name(pipeline_job_name)[:id], project: project, name: pipeline_job_name)
      end

      before do
        Flow::Login.sign_in
        project.visit!
        clear_chat

        Support::Waiter.wait_until(message: 'Wait for MR pipeline to be created') do
          project.pipelines.present?
        end
      end

      after do
        runner.remove_via_api!
      end

      context 'when user clicks Troubleshoot on failed CI job' do
        it 'gets failure analysis in Duo Chat', :aggregate_failures do
          job.visit!

          Page::Project::Job::Show.perform do |job|
            # This job must fail in order for the test to use Root Cause Analysis feature.
            # 'Failed' status also indicates the job has finished and can now be analyzed.
            Support::Waiter.wait_until(max_duration: 150) do
              job.has_status?('Failed')
            end

            job.click_duo_troubleshoot_button

            EE::Page::Component::DuoChat.perform do |duo_chat|
              duo_chat.wait_for_response

              # Currently has a known duo-chat bug
              # Not checking this for now until bug is resolved
              # Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/469530
              #
              # expect { duo_chat.has_response?(expected_command) }
              #   .to eventually_be_truthy.within(max_duration: 60),
              #       "Expected \"#{expected_command}\" within Duo Chat response."

              expect do
                response = duo_chat.response
                root_cause_analysis_patterns.all? { |pattern| response.match?(pattern) }
              end.to eventually_be_truthy.within(max_duration: 90),
                "Expected root cause and solution patterns within Duo Chat response."
            end
          end
        end
      end

      private

      def clear_chat
        EE::Page::Component::DuoChat.perform do |duo_chat|
          duo_chat.open_duo_chat
          duo_chat.clear_chat_history
          duo_chat.close
        end
      end
    end
  end
end
