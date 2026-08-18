# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::PipelineExecutionPolicies::EvaluatePolicies, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, :small_repo) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let(:source) { 'push' }
  let(:pipeline) { build(:ci_pipeline, source: source, project: project, ref: 'master', user: user) }

  let(:creating_policy_pipeline) { nil }
  let(:pipeline_policy_context) do
    instance_double(Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext,
      pipeline_execution_context: instance_double(
        Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext,
        creating_policy_pipeline?: creating_policy_pipeline
      )
    )
  end

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      source: pipeline.source,
      project: project,
      current_user: user,
      origin_ref: pipeline.ref,
      pipeline_policy_context: pipeline_policy_context
    )
  end

  let(:step) { described_class.new(pipeline, command) }

  describe '#perform!' do
    it 'builds policy pipelines using pipeline_policy_context' do
      expect(pipeline_policy_context.pipeline_execution_context)
        .to receive(:build_policy_pipelines!).with(pipeline.partition_id)

      step.perform!
    end

    context 'when error is raised' do
      before do
        allow(pipeline_policy_context.pipeline_execution_context)
          .to receive(:build_policy_pipelines!).and_yield('some error')

        step.perform!
      end

      it 'breaks the processing chain' do
        expect(step.break?).to be true
      end

      it 'does not save the pipeline' do
        expect(pipeline).not_to be_persisted
      end

      it 'returns a specific error' do
        expect(pipeline.errors[:base]).to include(a_string_including('Pipeline execution policy error: some error'))
      end
    end
  end
end
