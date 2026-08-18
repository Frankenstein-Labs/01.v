# frozen_string_literal: true

module QA
  RSpec.describe 'Verify', :orchestrated, :requires_admin, :geo, feature_category: :continuous_integration do
    describe 'When CI job log is archived and Geo is enabled' do
      let(:executor) { "qa-runner-#{SecureRandom.hex(6)}" }
      let(:pipeline_job_name) { 'test-archival' }
      let(:project) { create(:project, name: 'geo-project-with-archived-traces') }
      let!(:runner) { create(:project_runner, project: project, name: executor, tags: [executor]) }

      let!(:commit) do
        create(:commit, project: project, commit_message: 'Add .gitlab-ci.yml', actions: [
          {
            action: 'create',
            file_path: '.gitlab-ci.yml',
            content: <<~YAML
              test-archival:
                tags:
                  - #{executor}
                script: echo "OK"
            YAML
          }
        ])
      end

      before do
        Flow::Login.sign_in
      end

      after do
        runner.remove_via_api!
      end

      it 'continues to display the archived trace' do
        job = create(:job, id: project.job_by_name(pipeline_job_name)[:id], project: project, name: pipeline_job_name)

        job.visit!

        Support::Waiter.wait_until(max_duration: 150) do
          job.artifacts.any?
        end

        Page::Project::Job::Show.perform do |job|
          job.refresh
          expect(job).to have_job_log
        end
      end
    end
  end
end
