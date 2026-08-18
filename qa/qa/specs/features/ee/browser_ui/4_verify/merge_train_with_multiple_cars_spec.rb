# frozen_string_literal: true

module QA
  RSpec.describe 'Verify', feature_category: :continuous_integration, quarantine: {
    issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24053',
    type: :flaky
  } do
    describe 'Merge train with multiple cars' do
      let!(:project) { create(:project, name: 'merge-train-with-multiple-cars') }
      let(:executor) { "qa-runner-#{random_string}" }
      let(:total_train_cars) { 2 }

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
                  - sleep 15
                  - echo 'OK'
                only:
                  - merge_requests
            YAML
          }
        ])
      end

      before do
        Flow::Login.sign_in
        project.visit!
        Flow::MergeRequest.enable_merge_trains
      end

      after do
        runner.remove_via_api!
      end

      it 'successfully merges all merge requests' do
        merge_requests = Array.new(total_train_cars) { create_merge_request }

        # Add all MRs to the same train first
        merge_requests.each_with_index do |merge_request, index|
          merge_request.visit!
          Page::MergeRequest::Show.perform do |show|
            show.merge_via_merge_train
            expect { show }.to eventually_have_content(queue_message(index)),
              "Didn't find text #{queue_message(index)} within MR widget."

            expect { show }.to eventually_have_content('Added to the merge train'),
              "Didn't find text 'Added to the merge train' within MR widget."
          end
        end

        # The train will take some time to finish.
        # Once the train finishes, all MRs in the train are expected to be merged.
        merge_requests.each do |merge_request|
          expect do
            merge_request_state(merge_request)
          end.to eventually_eq('merged').within(max_duration: 90, sleep_interval: 1),
            "Expected MR iid #{merge_request.iid} to be merged but is still #{merge_request_state(merge_request)}"
        end
      end

      private

      def random_string
        SecureRandom.hex(8)
      end

      def create_merge_request
        create(
          :merge_request,
          title: random_string,
          project: project,
          description: random_string,
          target_new_branch: false,
          file_name: random_string,
          file_content: random_string
        )
      end

      def queue_message(index)
        return "This merge request is ##{index + 1} of #{index + 1} in queue." if index > 0

        'A new merge train has started and this merge request is the first of the queue.'
      end

      def merge_request_state(merge_request)
        merge_request.reload!
        merge_request.state
      end
    end
  end
end
