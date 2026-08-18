# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :secrets_manager,
    :orchestrated,
    feature_category: :secrets_management
  ) do
    include_context 'secrets manager base'

    describe 'Ci pipeline fails when project secret is not available' do
      let(:executor) { "qa-runner-#{Faker::Alphanumeric.alphanumeric(number: 8)}" }
      let(:nonexistent_secret_name) { 'NonexistentTest' }
      let!(:runner) { create(:project_runner, project: project, name: executor, tags: [executor]) }

      let(:add_ci_file) do
        create(:commit, project: project, commit_message: 'Add .gitlab-ci.yml', actions: [
          {
            action: 'create',
            file_path: '.gitlab-ci.yml',
            content: <<~YAML
              default:
                tags: [#{executor}]

              secrets_manager_job:
                secrets:
                  NONEXISTENT_SECRET:
                    gitlab_secrets_manager:
                      name: #{nonexistent_secret_name}
                script:
                  - echo "Testing OpenBao in CI"
                  - cat $NONEXISTENT_SECRET
                  - echo "This should not run"
            YAML
          }
        ])
      end

      before do
        add_ci_file
        trigger_pipeline
        wait_for_pipeline
      end

      after do
        runner.remove_via_api!
      end

      context 'when accessing secrets in CI pipeline' do
        it 'fails to access secret in CI pipeline job' do
          job = create(:job, project: project, id: project.job_by_name('secrets_manager_job')[:id])

          aggregate_failures do
            trace = job.trace
            expect(trace).to have_content('Resolving secrets')
            expect(trace).to have_content("Resolving secret \"NONEXISTENT_SECRET\"")
            expect(trace).to have_content('ERROR: Job failed (system failure)')
            expect(trace).not_to have_content('This should not run'),
              "Script should not execute when secret resolution fails"
          end
        end
      end

      private

      def trigger_pipeline
        create(:pipeline, project: project)
      end

      def wait_for_pipeline
        Support::Waiter.wait_until(max_duration: 180, sleep_interval: 5) do
          pipelines = project.pipelines
          pipelines.present? && %w[success failed].include?(pipelines.first[:status])
        end

        project.pipelines.first
      end
    end
  end
end
