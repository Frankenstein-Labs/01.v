# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::Populate, feature_category: :pipeline_composition do
  include Ci::PipelineMessageHelpers

  let_it_be(:project) { create(:project, :small_repo) }
  let_it_be(:user) { create(:user) }

  let(:pipeline) do
    build(:ci_empty_pipeline, project: project, ref: 'master', user: user)
  end

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      current_user: user,
      origin_ref: 'master',
      pipeline_policy_context: instance_double(
        Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext,
        pipeline_execution_context: instance_double(
          Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext,
          valid_stage?: true,
          applying_config_override?: false,
          has_execution_policy_pipelines?: true,
          job_options: {},
          creating_policy_pipeline?: true,
          creating_any_policy_pipeline?: true,
          force_pipeline_creation_on_empty_pipeline?: force_pipeline_creation
        ),
        job_options: {}
      ),
      seeds_block: nil
    )
  end

  let(:force_pipeline_creation) { true }

  let(:dependencies) do
    [
      Gitlab::Ci::Pipeline::Chain::Config::Content.new(pipeline, command),
      Gitlab::Ci::Pipeline::Chain::Config::Process.new(pipeline, command),
      Gitlab::Ci::Pipeline::Chain::EvaluateWorkflowRules.new(pipeline, command),
      Gitlab::Ci::Pipeline::Chain::SeedBlock.new(pipeline, command),
      Gitlab::Ci::Pipeline::Chain::Seed.new(pipeline, command)
    ]
  end

  let(:step) do
    result = described_class.new(pipeline, command)

    dependencies.each do |dependency|
      dependency.perform!

      # Sanity check. All the dependencies are required for the step object to be valid
      raise "Dependency #{dependency.class} failed with #{pipeline.errors.full_messages}" if dependency.break?
    end

    result
  end

  let(:config) do
    { rspec: {
      script: 'ls',
      only: ['something']
    } }
  end

  before do
    stub_ci_pipeline_yaml_file(config.to_yaml)

    allow(command.pipeline_policy_context.pipeline_execution_context).to(
      receive(:enforce_stages!) { |config:| config }
    )
  end

  context 'when pipeline is empty and there are policy pipelines' do
    it 'does not break the chain' do
      step.perform!

      expect(step.break?).to be false
    end

    it 'does not append an error' do
      step.perform!

      expect(pipeline.errors).to be_empty
    end

    it 'sets pipeline_creation_forced_to_continue flag on command' do
      step.perform!

      expect(command.pipeline_creation_forced_to_continue).to be(true)
    end

    context 'when execution is not forced' do
      let(:force_pipeline_creation) { false }

      it 'breaks the chain' do
        step.perform!

        expect(step.break?).to be true
      end

      it 'appends an error about no stages/jobs' do
        step.perform!

        expect(pipeline.errors.to_a)
          .to include sanitize_message(::Ci::Pipeline.rules_failure_message)
      end

      it 'does not set pipeline_creation_forced_to_continue flag on command' do
        step.perform!

        expect(command.pipeline_creation_forced_to_continue).to be_nil
      end
    end
  end
end
