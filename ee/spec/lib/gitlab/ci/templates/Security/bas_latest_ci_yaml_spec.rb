# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Security/BAS.latest.gitlab-ci.yml', feature_category: :continuous_integration do
  include Ci::PipelineMessageHelpers

  describe 'the created pipeline' do
    let(:build_names) { pipeline.builds.pluck(:name) }
    let(:template) do
      <<~YAML
        stages:
          - dast

        include:
          - template: Security/BAS.latest.gitlab-ci.yml
      YAML
    end

    let(:default_branch) { project.default_branch_or_main }
    let(:pipeline_branch) { default_branch }
    let(:project) { create(:project, :custom_repo, files: { 'README.txt' => '' }) }
    let(:service) { Ci::CreatePipelineService.new(project, user, ref: pipeline_branch) }
    let(:user) { project.first_owner }

    subject(:pipeline) { service.execute(:push).payload }

    before do
      stub_ci_pipeline_yaml_file(template)

      allow_next_instance_of(Ci::BuildScheduleWorker) do |instance|
        allow(instance).to receive(:perform).and_return(true)
      end

      allow(project).to receive(:default_branch).and_return(default_branch)
      create_current_license(plan: License::ULTIMATE_PLAN)
      stub_licensed_features(dast: true)
    end

    it_behaves_like 'acts as branch pipeline', %w[dast dast_with_bas]

    %w[true 1].each do |dast_bas_disabled|
      context "when DAST_BAS_DISABLED=#{dast_bas_disabled}" do
        before do
          create(:ci_variable, key: 'DAST_BAS_DISABLED', value: dast_bas_disabled, project: project)
        end

        it_behaves_like 'acts as branch pipeline', %w[dast]

        # Can't reuse the shared example as this template has not been
        # updated to use AST_ENABLE_MR_PIPELINES (since it's deprecated)
        context 'when MR pipeline' do
          let(:service) { MergeRequests::CreatePipelineService.new(project: project, current_user: user) }
          let(:feature_branch) { 'feature' }
          let(:pipeline) { service.execute(merge_request).payload }

          let(:merge_request) do
            create(:merge_request,
              source_project: project,
              source_branch: feature_branch,
              target_project: project,
              target_branch: default_branch)
          end

          before do
            project.repository.create_file(
              project.creator,
              'README.md',
              "README on branch feature",
              message: 'Add README.md',
              branch_name: feature_branch)
          end

          it 'creates a pipeline with the expected jobs' do
            expect(pipeline).to be_merge_request_event
            expect(pipeline.errors.full_messages).to be_empty
            expect(build_names).to match_array(%w[dast])
          end
        end
      end
    end

    context 'when CI_OPEN_MERGE_REQUESTS is set' do
      before do
        create(:ci_variable, key: 'CI_OPEN_MERGE_REQUESTS', value: 'gitlab-org/gitlab!333', project: project)
      end

      it 'skips branch pipelines when an open MR exists' do
        expect(build_names).to be_empty
        expect(pipeline.errors.full_messages).to match_array([sanitize_message(Ci::Pipeline.rules_failure_message)])
      end
    end
  end
end
