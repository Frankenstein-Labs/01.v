# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::WorkflowMergeRequest, feature_category: :duo_agent_platform do
  subject(:workflow_merge_request) { build(:duo_workflows_workflow_merge_request) }

  it { is_expected.to belong_to(:workflow) }
  it { is_expected.to belong_to(:merge_request) }
  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:namespace) }

  it { is_expected.to validate_presence_of(:workflow) }
  it { is_expected.to validate_presence_of(:merge_request) }
  it { is_expected.to validate_presence_of(:link_type) }

  it 'defines the link_type enum' do
    is_expected.to define_enum_for(:link_type)
      .with_values(source: 0, created: 1)
      .with_prefix(:link_type)
  end

  describe 'uniqueness' do
    it 'is enforced per workflow, merge request, and link type by the database', :aggregate_failures do
      existing = create(:duo_workflows_workflow_merge_request)

      duplicate = build(:duo_workflows_workflow_merge_request,
        workflow: existing.workflow, merge_request: existing.merge_request, link_type: existing.link_type)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe '.ensure_link' do
    let_it_be(:project) { create(:project) }
    let_it_be(:workflow) { create(:duo_workflows_workflow, project: project) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }

    subject(:errors) do
      described_class.ensure_link(workflow: workflow, artifact: merge_request, link_type: :source)
    end

    it 'creates a link carrying the workflow project and namespace and reports no errors' do
      expect { errors }.to change { described_class.count }.by(1)
      expect(errors).to be_empty

      expect(described_class.last).to have_attributes(
        workflow: workflow,
        merge_request: merge_request,
        project_id: workflow.project_id,
        namespace_id: workflow.namespace_id,
        link_type: 'source'
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
        create(:duo_workflows_workflow_merge_request, workflow: workflow, merge_request: merge_request,
          link_type: :source)
      end

      it 'reports no errors and creates no duplicate' do
        expect { errors }.not_to change { described_class.count }
        expect(errors).to be_empty
      end
    end
  end

  describe '#project_xor_namespace_present' do
    it 'is valid with only a project' do
      workflow_merge_request.assign_attributes(project: build_stubbed(:project), namespace: nil)

      expect(workflow_merge_request).to be_valid
    end

    it 'is valid with only a namespace' do
      workflow_merge_request.assign_attributes(project: nil, namespace: build_stubbed(:group))

      expect(workflow_merge_request).to be_valid
    end

    it 'is invalid without a project or namespace', :aggregate_failures do
      workflow_merge_request.assign_attributes(project: nil, namespace: nil)

      expect(workflow_merge_request).to be_invalid
      expect(workflow_merge_request.errors[:base]).to include('either project_id or namespace_id must be present')
    end

    it 'is invalid with both a project and a namespace', :aggregate_failures do
      workflow_merge_request.assign_attributes(project: build_stubbed(:project), namespace: build_stubbed(:group))

      expect(workflow_merge_request).to be_invalid
      expect(workflow_merge_request.errors[:base]).to include('either project_id or namespace_id must be present')
    end
  end
end
