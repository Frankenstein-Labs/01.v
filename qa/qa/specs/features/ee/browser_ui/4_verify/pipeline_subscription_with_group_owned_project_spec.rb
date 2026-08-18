# frozen_string_literal: true

module QA
  RSpec.describe 'Verify', feature_category: :continuous_integration do
    describe 'Pipeline subscription with a group owned project' do
      let(:executor) { "qa-runner-#{SecureRandom.hex(3)}" }
      let(:tag_name) { "awesome-tag-#{SecureRandom.hex(3)}" }
      let(:group) { create(:group, name: "group-for-pipeline-subscriptions-#{SecureRandom.hex(3)}") }

      let(:upstream_project) do
        create(:project,
          name: 'upstream-project-for-subscription',
          description: 'Project with CI subscription',
          group: group)
      end

      let(:downstream_project) do
        create(:project,
          name: 'downstream-project-for-subscription',
          description: 'Project with CI subscription',
          group: group)
      end

      let!(:runner) { create(:group_runner, group: group, name: executor, tags: [executor]) }

      before do
        [downstream_project, upstream_project].each do |project|
          add_ci_file(project)
        end

        Flow::Pipeline.wait_for_pipeline_creation_via_api(project: downstream_project)

        Flow::Login.sign_in
        downstream_project.visit!

        EE::Resource::PipelineSubscriptions.fabricate_via_browser_ui! do |subscription|
          subscription.project_path = upstream_project.path_with_namespace
        end
      end

      after do
        runner.remove_via_api!
      end

      context 'when upstream project new tag pipeline finishes' do
        it 'triggers pipeline in downstream project' do
          downstream_project.visit!

          Runtime::Logger.info "Creating tag #{tag_name} for #{upstream_project.name}."
          create(:tag, project: upstream_project, ref: upstream_project.default_branch, name: tag_name)
          Flow::Pipeline.wait_for_pipeline_creation_via_api(project: downstream_project, size: 2)

          expect(upstream_project).to have_pipeline_with_ref(tag_name),
            "No pipeline with ref #{tag_name} was created for #{upstream_project.name}."

          expect do
            downstream_project.latest_pipeline[:status]
          end.to eventually_eq('success').within(max_duration: 300), 'Downstream pipeline did not succeed as expected.'
        end
      end

      private

      def add_ci_file(project)
        create(:commit, project: project, commit_message: 'Add .gitlab-ci.yml', actions: [
          {
            action: 'create',
            file_path: '.gitlab-ci.yml',
            content: <<~YAML
              job:
                tags:
                  - #{executor}
                script:
                  - echo DONE!
            YAML
          }
        ])
      end
    end
  end
end
