# frozen_string_literal: true

module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :secrets_manager,
    :orchestrated,
    feature_category: :secrets_management
  ) do
    include_context 'secrets manager base'

    describe 'Project Secret CI Access' do
      let(:executor) { "qa-runner-#{Faker::Alphanumeric.alphanumeric(number: 8)}" }
      let(:secret_name) { 'Test' }
      let(:secret_value) { 'my-secret-value-for-ci' }
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
                  TEST_SECRET:
                    gitlab_secrets_manager:
                      name: #{secret_name}
                script:
                  - echo "Testing OpenBao in CI"
                  - cat $TEST_SECRET
                  - wc -c $TEST_SECRET
            YAML
          }
        ])
      end

      let(:add_secret) do
        Page::Main::Menu.perform(&:sign_out)
        Flow::Login.sign_in(as: owner)
        project.visit!

        Page::Project::Menu.perform(&:go_to_secrets_manager)
        EE::Page::Project::Secure::SecretsManager.perform do |secrets_page|
          secrets_page.click_new_secret
          secrets_page.create_secret(
            name: secret_name,
            value: secret_value,
            description: "Secret for CI pipeline test",
            environment: '*',
            branch: 'main'
          )
        end
      end

      before do
        add_secret
        add_ci_file
        trigger_pipeline
        wait_for_pipeline
      end

      after do
        runner.remove_via_api!
      end

      context 'when accessing secrets in CI pipeline' do
        let(:expected_byte_count) { secret_value.bytesize }

        it 'successfully accesses secret in CI pipeline job' do
          job = create(:job, project: project, id: project.job_by_name('secrets_manager_job')[:id])

          aggregate_failures do
            trace = job.trace
            expect(trace).to have_content('Testing OpenBao in CI')
            expect(trace).to have_content('Job succeeded')
            expect(trace).to have_content(expected_byte_count)
            expect(trace).not_to include(secret_value), "Secret value should not appear in job logs"
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
