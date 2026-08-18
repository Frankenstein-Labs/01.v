# frozen_string_literal: true

module QA
  RSpec.describe 'Verify', feature_category: :continuous_integration do
    describe 'Pipeline for merged result' do
      let!(:project) { create(:project, name: 'pipeline-for-merged-results') }
      let!(:executor) { "qa-runner-#{Faker::Alphanumeric.alphanumeric(number: 8)}" }
      let!(:runner) do
        create(:project_runner, project: project, name: executor, tags: [executor])
      end

      let!(:ci_file) do
        create(:commit, project: project, commit_message: 'Add .gitlab-ci.yml', actions: [
          {
            action: 'create',
            file_path: '.gitlab-ci.yml',
            content: <<~YAML
              test:
                tags: [#{executor}]
                script:
                  - sleep 300
                  - echo 'OK'
                only:
                  - merge_requests
            YAML
          }
        ])
      end

      let(:merge_request) do
        create(:merge_request,
          project: project,
          description: Faker::Lorem.sentence,
          target_new_branch: false,
          file_name: Faker::File.unique.file_name,
          file_content: Faker::Lorem.sentence)
      end

      before do
        Flow::Login.sign_in
        project.visit!
        Flow::MergeRequest.enable_merged_results_pipelines
      end

      after do
        runner&.remove_via_api!
      end

      it(
        'merge request can be merged immediately',
        quarantine: {
          issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/12631',
          type: 'flaky'
        }
      ) do
        merge_request.visit!

        Page::MergeRequest::Show.perform do |show|
          expect { show }.to eventually_have_content('Merged results pipeline running').within(
            sleep_interval: 5, reload_page: show
          ), 'Expected pipeline to be a merged results pipeline.'

          show.merge_immediately!

          expect(show).to be_merged, "Expected content 'The changes were merged' but it did not appear."
        end
      end
    end
  end
end
