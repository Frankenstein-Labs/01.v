# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::Skip, feature_category: :pipeline_composition do
  let_it_be(:project) { create(:project, :small_repo) }
  let_it_be(:user) { create(:user) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      current_user: user,
      ignore_skip_ci: false,
      save_incompleted: true,
      origin_ref: project.default_branch_or_main)
  end

  let(:step) { described_class.new(pipeline, command) }

  describe '#skipped?' do
    context 'when pipeline has not been skipped' do
      it 'does not break the chain' do
        expect(step.break?).to be false
      end
    end

    context 'when pipeline should be skipped' do
      before do
        allow(pipeline).to receive(:git_commit_message).and_return('commit message [ci skip]')
      end

      it 'breaks the chain' do
        expect(step.break?).to be true
      end

      context 'when execution policies are not allowing skip' do
        before do
          command.pipeline_policy_context = instance_double(
            Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext,
            skip_ci_allowed?: false
          )
        end

        it 'does not break the chain' do
          expect(step.break?).to be false
        end
      end

      context 'when pipeline execution policies are allowing skip' do
        before do
          command.pipeline_policy_context = instance_double(
            Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext,
            skip_ci_allowed?: true
          )
        end

        it 'breaks the chain' do
          expect(step.break?).to be true
        end
      end
    end
  end
end
