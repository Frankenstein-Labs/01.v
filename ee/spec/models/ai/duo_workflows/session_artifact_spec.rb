# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::SessionArtifact, feature_category: :compliance_management do
  describe 'associations' do
    it { is_expected.to belong_to(:workflow).class_name('Ai::DuoWorkflows::Workflow') }
    it { is_expected.to belong_to(:project).optional }
    it { is_expected.to belong_to(:namespace).required }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:duo_workflow_session_artifact) }

    it { is_expected.to validate_presence_of(:workflow_id) }
    it { is_expected.to validate_uniqueness_of(:workflow_id) }
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:workflow_definition) }
    it { is_expected.to validate_length_of(:workflow_definition).is_at_most(255) }
    it { is_expected.to validate_length_of(:model_used).is_at_most(255) }

    context 'when the artifact is project-scoped' do
      it 'is valid with both project_id and namespace_id' do
        workflow = create(:duo_workflows_workflow)
        artifact = build(:duo_workflow_session_artifact, workflow: workflow, user: workflow.user,
          project: workflow.project, namespace: workflow.project.project_namespace)

        expect(artifact.project_id).to be_present
        expect(artifact.namespace_id).to be_present
        expect(artifact).to be_valid
      end
    end

    context 'when the artifact is namespace-scoped' do
      it 'is valid without project_id' do
        namespace = create(:group)
        workflow = create(:duo_workflows_workflow, project: nil, namespace: namespace)
        artifact = build(:duo_workflow_session_artifact, workflow: workflow, user: workflow.user,
          project: nil, namespace: namespace)

        expect(artifact.namespace_id).to be_present
        expect(artifact.project_id).to be_nil
        expect(artifact).to be_valid
      end
    end

    context 'when namespace_id is nil' do
      it 'is invalid' do
        artifact = build(:duo_workflow_session_artifact, namespace: nil)

        expect(artifact).not_to be_valid
        expect(artifact.errors[:namespace]).to be_present
      end
    end
  end

  describe '.sync_from_workflow!' do
    let_it_be_with_reload(:workflow) { create(:duo_workflows_workflow) }

    it 'creates a session artifact from a workflow' do
      expect { described_class.sync_from_workflow!(workflow) }
        .to change { described_class.count }.by(1)

      artifact = described_class.find_by(workflow_id: workflow.id)
      expect(artifact.user_id).to eq(workflow.user_id)
      expect(artifact.project_id).to eq(workflow.project_id)
      expect(artifact.status).to eq(workflow.status_before_type_cast)
      expect(artifact.workflow_definition).to eq(workflow.workflow_definition)
      expect(artifact.workflow_created_at).to be_within(1.second).of(workflow.created_at)
      expect(artifact.workflow_updated_at).to be_within(1.second).of(workflow.updated_at)
    end

    it 'populates namespace_id with the project namespace for a project workflow' do
      described_class.sync_from_workflow!(workflow)

      artifact = described_class.find_by(workflow_id: workflow.id)
      expect(artifact.namespace_id).to eq(workflow.project.project_namespace_id)
    end

    context 'with a namespace-scoped workflow' do
      let_it_be(:group) { create(:group) }
      let_it_be(:namespace_workflow, freeze: false) do
        create(:duo_workflows_workflow, project: nil, namespace: group)
      end

      it 'populates namespace_id with the workflow namespace', :aggregate_failures do
        described_class.sync_from_workflow!(namespace_workflow)

        artifact = described_class.find_by(workflow_id: namespace_workflow.id)
        expect(artifact.namespace_id).to eq(group.id)
        expect(artifact.project_id).to be_nil
      end
    end

    it 'upserts on subsequent calls' do
      described_class.sync_from_workflow!(workflow)

      expect { described_class.sync_from_workflow!(workflow) }
        .not_to change { described_class.count }
    end

    it 'updates the artifact when workflow changes' do
      described_class.sync_from_workflow!(workflow)
      workflow.update!(workflow_definition: 'chat')
      described_class.sync_from_workflow!(workflow)

      expect(described_class.find_by(workflow_id: workflow.id).workflow_definition).to eq('chat')
    end
  end

  describe 'scopes' do
    let_it_be(:group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:subgroup_project) { create(:project, group: subgroup) }

    let_it_be(:workflow_in_project) { create(:duo_workflows_workflow, project: project) }
    let_it_be(:workflow_in_subgroup) { create(:duo_workflows_workflow, project: subgroup_project) }

    let_it_be(:artifact_in_project) do
      create(:duo_workflow_session_artifact,
        workflow: workflow_in_project,
        workflow_definition: 'software_development',
        workflow_created_at: 3.days.ago,
        workflow_updated_at: 2.hours.ago)
    end

    let_it_be(:artifact_in_subgroup) do
      create(:duo_workflow_session_artifact,
        workflow: workflow_in_subgroup,
        workflow_definition: 'chat',
        workflow_created_at: 1.day.ago,
        workflow_updated_at: 1.hour.ago)
    end

    describe '.with_keyset_order' do
      it 'orders by workflow_updated_at DESC, then workflow_id DESC' do
        results = described_class
          .where(id: [artifact_in_project.id, artifact_in_subgroup.id])
          .with_keyset_order

        expect(results.first).to eq(artifact_in_subgroup)
        expect(results.second).to eq(artifact_in_project)
      end
    end

    describe '.with_project' do
      let_it_be_with_reload(:workflow) { create(:duo_workflows_workflow, project: project) }
      let_it_be(:artifact) { create(:duo_workflow_session_artifact, workflow: workflow) }

      it 'eager loads the project association' do
        result = described_class.where(id: artifact.id).with_project.first

        expect(result.association(:project)).to be_loaded
      end
    end
  end

  describe '#web_path' do
    context 'when the artifact belongs to a project' do
      let_it_be_with_reload(:workflow) { create(:duo_workflows_workflow) }
      let_it_be(:artifact) { create(:duo_workflow_session_artifact, workflow: workflow) }

      it 'returns a URL containing the workflow id' do
        expect(artifact.web_path).to include(workflow.id.to_s)
      end

      it 'includes the automate agent sessions path' do
        expect(artifact.web_path).to include('automate/agent-sessions')
      end
    end

    context 'when the artifact is namespace-level (no project)' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:namespace_workflow) { create(:duo_workflows_workflow, project: nil, namespace: namespace) }
      let_it_be(:artifact) do
        create(:duo_workflow_session_artifact, :with_namespace,
          workflow: namespace_workflow, namespace: namespace)
      end

      it 'returns nil' do
        expect(artifact.web_path).to be_nil
      end
    end
  end

  describe '#download_path' do
    context 'when the artifact belongs to a project' do
      let_it_be(:workflow) { create(:duo_workflows_workflow) }
      let_it_be(:artifact) { create(:duo_workflow_session_artifact, workflow: workflow) }

      it 'returns the project download path containing the workflow id' do
        expect(artifact.download_path).to eq(
          Gitlab::Routing.url_helpers.download_project_security_agent_artifact_path(workflow.project, workflow.id)
        )
      end
    end

    context 'when the artifact is namespace-level (no project)' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:namespace_workflow) { create(:duo_workflows_workflow, project: nil, namespace: namespace) }
      let_it_be(:artifact) do
        create(:duo_workflow_session_artifact, :with_namespace,
          workflow: namespace_workflow, namespace: namespace)
      end

      it 'returns nil' do
        expect(artifact.download_path).to be_nil
      end
    end
  end
end
