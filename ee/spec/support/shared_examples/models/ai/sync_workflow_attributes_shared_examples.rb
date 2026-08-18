# frozen_string_literal: true

RSpec.shared_examples 'sync workflow attributes' do
  context 'with project-level workflow' do
    let(:project) { create(:project) }
    let(:workflow) { create(:duo_workflows_workflow, project: project) }

    it 'syncs project_id from workflow' do
      subject.workflow = workflow
      subject.project_id = subject.namespace_id = nil

      subject.save!

      expect(subject.project).to eq(workflow.project)
    end
  end

  context 'with namespace-level workflow' do
    let(:group) { create(:group) }
    let(:workflow) { create(:duo_workflows_workflow, namespace: group) }

    it 'syncs namespace_id from workflow' do
      subject.workflow = workflow
      subject.project = subject.namespace = nil

      subject.save!

      expect(subject.namespace).to eq(workflow.namespace)
    end
  end
end
