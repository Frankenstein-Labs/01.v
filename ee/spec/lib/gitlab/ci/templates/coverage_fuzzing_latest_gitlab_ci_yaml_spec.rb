# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Coverage-Fuzzing.latest.gitlab-ci.yml', feature_category: :dynamic_application_security_testing do
  include Ci::PipelineMessageHelpers

  subject(:template) do
    <<~YAML
      stages:
      - fuzz

      include:
        - template: 'Security/Coverage-Fuzzing.latest.gitlab-ci.yml'

      my_fuzz_target:
        extends: .fuzz_base
        script:
          - ./gitlab-cov-fuzz run --regression=$REGRESSION -- my_target
    YAML
  end

  describe 'the created pipeline' do
    let_it_be(:project) { create(:project, :custom_repo, files: { 'README.txt' => '' }) }

    let(:default_branch) { 'master' }
    let(:user) { project.first_owner }
    let(:service) { Ci::CreatePipelineService.new(project, user, ref: 'master') }
    let(:pipeline) { service.execute(:push).payload }
    let(:build_names) { pipeline.builds.pluck(:name) }

    before do
      stub_ci_pipeline_yaml_file(template)
      allow_next_instance_of(Ci::BuildScheduleWorker) do |worker|
        allow(worker).to receive(:perform).and_return(true)
      end
      allow(project).to receive(:default_branch).and_return(default_branch)
    end

    context 'when project has Ultimate license' do
      let(:license) { build(:license, plan: License::ULTIMATE_PLAN) }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      context 'without extending job default' do
        subject(:template) { Gitlab::Template::GitlabCiYmlTemplate.find('Coverage-Fuzzing.latest').content }

        it 'includes no job' do
          expect(build_names).to be_empty
          expect(pipeline.errors.full_messages).to match_array([sanitize_message(Ci::Pipeline.rules_failure_message)])
        end
      end

      it_behaves_like 'acts as branch pipeline', %w[my_fuzz_target]

      # Can't reuse the shared example as this template has not been
      # updated to use AST_ENABLE_MR_PIPELINES
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
          expect(build_names).to match_array(%w[my_fuzz_target])
        end
      end

      context 'when COVFUZZ_DISABLED=1' do
        before do
          create(:ci_variable, project: project, key: 'COVFUZZ_DISABLED', value: '1')
        end

        it 'includes no jobs' do
          expect(build_names).to be_empty
          expect(pipeline.errors.full_messages).to match_array([sanitize_message(Ci::Pipeline.rules_failure_message)])
        end
      end

      context 'when COVFUZZ_DISABLED="true"' do
        before do
          create(:ci_variable, project: project, key: 'COVFUZZ_DISABLED', value: 'true')
        end

        it 'includes no jobs' do
          expect(build_names).to be_empty
          expect(pipeline.errors.full_messages).to match_array([sanitize_message(Ci::Pipeline.rules_failure_message)])
        end
      end

      context 'when COVFUZZ_DISABLED="false"' do
        before do
          create(:ci_variable, project: project, key: 'COVFUZZ_DISABLED', value: 'false')
        end

        it 'include jobs' do
          expect(build_names).not_to be_empty
        end
      end
    end
  end
end
