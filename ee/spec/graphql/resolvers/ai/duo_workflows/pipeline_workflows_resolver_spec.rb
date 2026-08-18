# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::DuoWorkflows::PipelineWorkflowsResolver, feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, developers: user) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:other_pipeline) { create(:ci_pipeline, project: project) }

  let_it_be(:workflow) do
    create(:duo_workflows_workflow, user: user, project: project, environment: :web).tap do |w|
      create(:duo_workflows_workflow_pipeline, workflow: w, pipeline: pipeline)
    end
  end

  let_it_be(:other_pipeline_workflow) do
    create(:duo_workflows_workflow, user: user, project: project, environment: :web).tap do |w|
      create(:duo_workflows_workflow_pipeline, workflow: w, pipeline: other_pipeline)
    end
  end

  before do
    stub_licensed_features(ai_workflows: true)
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
    allow(user).to receive(:allowed_to_use?).and_return(true)
  end

  def resolve_workflows(pipeline)
    resolve(described_class, obj: pipeline, ctx: { current_user: user })
  end

  describe '#resolve' do
    it 'returns the workflows linked to the pipeline' do
      expect(batch_sync { resolve_workflows(pipeline) }).to contain_exactly(workflow)
    end

    it 'hands each workflow the project instance the pipeline already holds' do
      workflows = batch_sync { resolve_workflows(pipeline) }

      expect(workflows.to_a.first.project).to be(pipeline.project)
    end

    it 'loads the workflows for several pipelines in one batch', :aggregate_failures do
      recorder = ActiveRecord::QueryRecorder.new do
        batch_sync { [resolve_workflows(pipeline), resolve_workflows(other_pipeline)] }
      end

      expect(recorder.occurrences_starting_with('SELECT "duo_workflows_workflow_pipelines"').values.sum).to eq(1)
      expect(recorder.occurrences_starting_with('SELECT "duo_workflows_workflows"').values.sum).to eq(1)
    end

    context 'when no workflows are linked' do
      let_it_be(:unlinked_pipeline) { create(:ci_pipeline, project: project) }

      it 'returns an empty collection' do
        expect(batch_sync { resolve_workflows(unlinked_pipeline) }).to be_empty
      end
    end

    context 'when ai_workflows is not licensed' do
      before do
        stub_licensed_features(ai_workflows: false)
      end

      it 'returns nil' do
        expect(batch_sync { resolve_workflows(pipeline) }).to be_nil
      end
    end
  end
end
