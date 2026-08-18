# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::LinkArtifactService, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project) }
  let_it_be(:workflow) { create(:duo_workflows_workflow, project: project) }
  let_it_be(:work_item) { create(:work_item, project: project) }

  let(:artifact) { work_item }
  let(:link_type) { :source }

  subject(:execute) do
    described_class.new(workflow: workflow, artifact: artifact, link_type: link_type).execute
  end

  describe '#execute' do
    it 'creates the matching join record and succeeds' do
      expect { execute }.to change { Ai::DuoWorkflows::WorkflowWorkItem.count }.by(1)

      expect(execute).to be_success
      expect(
        Ai::DuoWorkflows::WorkflowWorkItem.where(workflow: workflow, work_item: work_item, link_type: :source)
      ).to exist
    end

    context 'when the artifact is a merge request' do
      let_it_be(:merge_request) { create(:merge_request, source_project: project) }

      let(:artifact) { merge_request }

      it 'creates the matching merge request join record' do
        expect { execute }.to change { Ai::DuoWorkflows::WorkflowMergeRequest.count }.by(1)

        expect(execute).to be_success
        expect(
          Ai::DuoWorkflows::WorkflowMergeRequest.where(
            workflow: workflow, merge_request: merge_request, project_id: project.id, link_type: :source
          )
        ).to exist
      end
    end

    context 'when the artifact is a note' do
      let_it_be(:note) { create(:note, project: project) }

      let(:artifact) { note }
      let(:link_type) { :created }

      it 'creates the matching note join record' do
        expect { execute }.to change { Ai::DuoWorkflows::WorkflowNote.count }.by(1)

        expect(execute).to be_success
        expect(
          Ai::DuoWorkflows::WorkflowNote.where(
            workflow: workflow, note: note, project_id: project.id, link_type: :created
          )
        ).to exist
      end
    end

    context 'when the artifact is a pipeline' do
      let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

      let(:artifact) { pipeline }

      it 'creates the matching pipeline join record' do
        expect { execute }.to change { Ai::DuoWorkflows::WorkflowPipeline.count }.by(1)

        expect(execute).to be_success
        expect(
          Ai::DuoWorkflows::WorkflowPipeline.where(
            workflow: workflow, pipeline: pipeline, project_id: project.id, link_type: :source
          )
        ).to exist
      end
    end

    context 'when the artifact type is not supported' do
      let(:artifact) { project }

      it 'returns an error and creates nothing' do
        expect { execute }.not_to change { Ai::DuoWorkflows::WorkflowWorkItem.count }

        expect(execute).to be_error
        expect(execute.message).to include('Unsupported artifact type')
      end
    end

    context 'when a matching link already exists' do
      let_it_be(:existing_link) do
        create(:duo_workflows_workflow_work_item, workflow: workflow, work_item: work_item, link_type: :source)
      end

      it 'is idempotent, succeeding without creating a duplicate' do
        expect { execute }.not_to change { Ai::DuoWorkflows::WorkflowWorkItem.count }

        expect(execute).to be_success
      end
    end

    context 'when the same artifact is already linked under a different link_type' do
      let_it_be(:created_link) do
        create(:duo_workflows_workflow_work_item, workflow: workflow, work_item: work_item, link_type: :created)
      end

      it 'creates a separate link for the new link_type' do
        expect { execute }.to change { Ai::DuoWorkflows::WorkflowWorkItem.count }.by(1)

        expect(execute).to be_success
        expect(
          Ai::DuoWorkflows::WorkflowWorkItem.where(workflow: workflow, work_item: work_item, link_type: :source)
        ).to exist
      end
    end

    context 'when the link is invalid' do
      before do
        # Force both project_id and namespace_id to be present, violating the
        # project-xor-namespace rule so the record fails validation on save.
        allow(workflow).to receive(:namespace_id).and_return(project.project_namespace_id)
      end

      it 'returns an unprocessable_entity error and creates nothing' do
        expect { execute }.not_to change { Ai::DuoWorkflows::WorkflowWorkItem.count }

        expect(execute).to be_error
        expect(execute.http_status).to eq(:unprocessable_entity)
      end
    end
  end
end
