# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::NoPipeline, feature_category: :pipeline_composition do
  let_it_be(:project) { create(:project, :small_repo) }
  let_it_be(:user) { create(:user) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let(:push_options) do
    Ci::PipelineCreation::PushOptions.new({})
  end

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      current_user: user,
      push_options: push_options,
      origin_ref: project.default_branch_or_main)
  end

  let(:step) { described_class.new(pipeline, command) }

  describe '#no_pipeline?' do
    context 'when pipeline is created' do
      it 'does not break the chain' do
        expect(step.break?).to be false
      end
    end

    context 'when pipeline should not be created' do
      let(:push_options) do
        Ci::PipelineCreation::PushOptions.new({ 'ci' => { 'no_pipeline' => true } })
      end

      it 'breaks the chain' do
        expect(step.break?).to be true
      end

      context 'when execution policies are not allowing no_pipeline' do
        before do
          command.pipeline_policy_context = instance_double(
            Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext,
            no_pipeline_allowed?: false
          )
        end

        it 'does not break the chain' do
          expect(step.break?).to be false
        end
      end

      context 'when pipeline execution policies are allowing no_pipeline' do
        before do
          command.pipeline_policy_context = instance_double(
            Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext,
            no_pipeline_allowed?: true
          )
        end

        it 'breaks the chain' do
          expect(step.break?).to be true
        end
      end

      context 'when no pipeline execution policies defined' do
        it 'breaks the chain' do
          expect(step.break?).to be true
        end
      end
    end
  end
end
