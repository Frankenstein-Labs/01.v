# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::PopulateMetadata, feature_category: :pipeline_composition do
  include Ci::PipelineExecutionPolicyHelpers

  let_it_be(:project) { create(:project, :small_repo) }
  let_it_be(:user) { create(:user) }

  let(:pipeline) do
    build(:ci_pipeline, project: project, ref: 'master', user: user)
  end

  let(:policy_pipeline_1) do
    build_mock_policy_pipeline({ 'build' => ['docker'] }).tap do |pipeline|
      pipeline.pipeline_metadata = build(:ci_pipeline_metadata, name: 'Policy 1 name')
    end
  end

  let(:policy_pipeline_2) do
    build_mock_policy_pipeline({ 'test' => ['rspec'] }).tap do |pipeline|
      pipeline.pipeline_metadata = build(:ci_pipeline_metadata, name: 'Policy 2 name')
    end
  end

  let(:execution_policy_pipelines) { [] }
  let(:policy_configs) { execution_policy_pipelines.map(&:policy_config) }

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      current_user: user,
      origin_ref: pipeline.ref
    )
  end

  let(:dependencies) do
    [
      Gitlab::Ci::Pipeline::Chain::Config::Content.new(pipeline, command),
      Gitlab::Ci::Pipeline::Chain::Config::Process.new(pipeline, command),
      Gitlab::Ci::Pipeline::Chain::EvaluateWorkflowRules.new(pipeline, command),
      Gitlab::Ci::Pipeline::Chain::SeedBlock.new(pipeline, command),
      Gitlab::Ci::Pipeline::Chain::Seed.new(pipeline, command),
      Gitlab::Ci::Pipeline::Chain::Populate.new(pipeline, command)
    ]
  end

  let(:step) { described_class.new(pipeline, command) }

  let(:config) do
    { rspec: { script: 'rspec' } }
  end

  def run_chain
    dependencies.map(&:perform!)
    step.perform!
  end

  before do
    stub_ci_pipeline_yaml_file(YAML.dump(config))
    allow(command.pipeline_policy_context.pipeline_execution_context)
      .to receive_messages(policies: policy_configs, policy_pipelines: execution_policy_pipelines)
  end

  shared_examples 'not saving pipeline metadata' do
    it 'does not save pipeline metadata' do
      run_chain

      expect(pipeline.pipeline_metadata).to be_nil
    end
  end

  context 'with pipeline name' do
    let(:config) do
      { workflow: { name: ' Project pipeline name  ' }, rspec: { script: 'rspec' } }
    end

    it 'assigns project pipeline name' do
      run_chain

      expect(pipeline.pipeline_metadata.name).to eq('Project pipeline name')
      expect(pipeline.pipeline_metadata.project).to eq(pipeline.project)
      expect(pipeline.pipeline_metadata).not_to be_persisted
    end

    context 'with pipeline execution policies' do
      let(:execution_policy_pipelines) do
        [
          build(:pipeline_execution_policy_pipeline,
            policy_config: build(:pipeline_execution_policy_config, :override_project_ci),
            pipeline: policy_pipeline_1),
          build(:pipeline_execution_policy_pipeline,
            policy_config: build(:pipeline_execution_policy_config, :override_project_ci),
            pipeline: policy_pipeline_2)
        ]
      end

      it 'assigns policy pipeline name from the first policy (lowest in the hierarchy)' do
        run_chain

        expect(pipeline.pipeline_metadata.name).to eq('Policy 1 name')
        expect(pipeline.pipeline_metadata.project).to eq(pipeline.project)
        expect(pipeline.pipeline_metadata).not_to be_persisted
      end

      context 'when policies are not overriding' do
        let(:execution_policy_pipelines) do
          [
            build(:pipeline_execution_policy_pipeline,
              policy_config: build(:pipeline_execution_policy_config, :inject_policy),
              pipeline: policy_pipeline_1),
            build(:pipeline_execution_policy_pipeline,
              policy_config: build(:pipeline_execution_policy_config, :inject_policy),
              pipeline: policy_pipeline_2)
          ]
        end

        it 'assigns the project pipeline name' do
          run_chain

          expect(pipeline.pipeline_metadata.name).to eq('Project pipeline name')
        end
      end

      context 'with mixed strategies' do
        let(:execution_policy_pipelines) do
          [
            build(:pipeline_execution_policy_pipeline,
              policy_config: build(:pipeline_execution_policy_config, :override_project_ci),
              pipeline: policy_pipeline_1),
            build(:pipeline_execution_policy_pipeline,
              policy_config: build(:pipeline_execution_policy_config, :inject_policy),
              pipeline: policy_pipeline_2)
          ]
        end

        it 'assigns the overriding policy name' do
          run_chain

          expect(pipeline.pipeline_metadata.name).to eq('Policy 1 name')
        end
      end
    end
  end

  describe 'security_policy_protected_branch_bypassed' do
    context 'with a recorded approval policy bypass' do
      before do
        command.security_policy_protected_branch_bypassed = true
      end

      it 'assigns the bypass decision to the pipeline metadata' do
        run_chain

        expect(pipeline.pipeline_metadata.security_policy_protected_branch_bypassed).to be true
        expect(pipeline.pipeline_metadata.project).to eq(pipeline.project)
        expect(pipeline.pipeline_metadata).not_to be_persisted
      end

      context 'with a pipeline name' do
        let(:config) do
          { workflow: { name: 'Pipeline name' }, rspec: { script: 'rspec' } }
        end

        it 'assigns the name and the bypass decision to the same metadata record' do
          run_chain

          expect(pipeline.pipeline_metadata.name).to eq('Pipeline name')
          expect(pipeline.pipeline_metadata.security_policy_protected_branch_bypassed).to be true
          expect(pipeline.pipeline_metadata).not_to be_persisted
        end
      end
    end

    context 'without a recorded approval policy bypass' do
      it_behaves_like 'not saving pipeline metadata'
    end
  end
end
