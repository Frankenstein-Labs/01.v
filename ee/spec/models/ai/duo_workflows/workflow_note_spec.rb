# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::WorkflowNote, feature_category: :duo_agent_platform do
  subject(:workflow_note) { build(:duo_workflows_workflow_note) }

  it { is_expected.to belong_to(:workflow) }
  it { is_expected.to belong_to(:note) }
  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:namespace) }

  it { is_expected.to validate_presence_of(:workflow) }
  it { is_expected.to validate_presence_of(:note) }
  it { is_expected.to validate_presence_of(:link_type) }

  it 'defines the link_type enum' do
    is_expected.to define_enum_for(:link_type)
      .with_values(created: 1, triggered: 2)
      .with_prefix(:link_type)
  end

  describe 'uniqueness' do
    it 'is enforced per workflow, note, and link type by the database', :aggregate_failures do
      existing = create(:duo_workflows_workflow_note)

      duplicate = build(:duo_workflows_workflow_note,
        workflow: existing.workflow, note: existing.note, link_type: existing.link_type)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe '.triggered_for_notes' do
    let_it_be(:project) { create(:project) }
    let_it_be(:catalog_item_version) { create(:ai_catalog_item_version) }
    let_it_be(:workflow) do
      create(:duo_workflows_workflow, project: project, ai_catalog_item_version: catalog_item_version)
    end

    let_it_be(:note_a) { create(:note, project: project) }
    let_it_be(:note_b) { create(:note, project: project) }
    let_it_be(:triggered_a) do
      create(:duo_workflows_workflow_note, workflow: workflow, note: note_a, link_type: :triggered)
    end

    let_it_be(:triggered_b) do
      create(:duo_workflows_workflow_note, workflow: workflow, note: note_b, link_type: :triggered)
    end

    before_all do
      note_c = create(:note, project: project)
      create(:duo_workflows_workflow_note, workflow: workflow, note: note_c, link_type: :created)
    end

    it 'returns only triggered links matching the given note IDs, excluding other link types and IDs' do
      # triggered_b exists but is excluded by the note_id filter; created_c is excluded by link_type
      expect(described_class.triggered_for_notes([note_a.id])).to contain_exactly(triggered_a)
    end

    it 'preloads associations used to resolve the agent name and authorize the workflow' do
      result = described_class.triggered_for_notes([note_a.id, note_b.id]).load

      expect do
        result.map { |link| ::Ai::DuoWorkflows::WorkflowPresenter.new(link.workflow).agent_name }
        result.map { |link| link.workflow.user }
      end.not_to exceed_query_limit(0)
    end
  end

  describe '.ensure_link' do
    let_it_be(:project) { create(:project) }
    let_it_be(:workflow) { create(:duo_workflows_workflow, project: project) }
    let_it_be(:note) { create(:note, project: project) }

    subject(:errors) do
      described_class.ensure_link(workflow: workflow, artifact: note, link_type: :created)
    end

    it 'creates a link carrying the workflow project and namespace and reports no errors' do
      expect { errors }.to change { described_class.count }.by(1)
      expect(errors).to be_empty

      expect(described_class.last).to have_attributes(
        workflow: workflow,
        note: note,
        project_id: workflow.project_id,
        namespace_id: workflow.namespace_id,
        link_type: 'created'
      )
    end

    context 'when the link is invalid' do
      before do
        # Both project_id and namespace_id present violates the project-xor-namespace rule.
        allow(workflow).to receive(:namespace_id).and_return(project.project_namespace_id)
      end

      it 'reports errors and creates nothing' do
        expect { errors }.not_to change { described_class.count }
        expect(errors.full_messages).to include('either project_id or namespace_id must be present')
      end
    end

    context 'when a matching link already exists' do
      let_it_be(:existing_link) do
        create(:duo_workflows_workflow_note, workflow: workflow, note: note, link_type: :created)
      end

      it 'reports no errors and creates no duplicate' do
        expect { errors }.not_to change { described_class.count }
        expect(errors).to be_empty
      end
    end
  end

  describe '#project_xor_namespace_present' do
    it 'is valid with only a project' do
      workflow_note.assign_attributes(project: build_stubbed(:project), namespace: nil)

      expect(workflow_note).to be_valid
    end

    it 'is valid with only a namespace' do
      workflow_note.assign_attributes(project: nil, namespace: build_stubbed(:group))

      expect(workflow_note).to be_valid
    end

    it 'is invalid without a project or namespace', :aggregate_failures do
      workflow_note.assign_attributes(project: nil, namespace: nil)

      expect(workflow_note).to be_invalid
      expect(workflow_note.errors[:base]).to include('either project_id or namespace_id must be present')
    end

    it 'is invalid with both a project and a namespace', :aggregate_failures do
      workflow_note.assign_attributes(project: build_stubbed(:project), namespace: build_stubbed(:group))

      expect(workflow_note).to be_invalid
      expect(workflow_note.errors[:base]).to include('either project_id or namespace_id must be present')
    end
  end
end
