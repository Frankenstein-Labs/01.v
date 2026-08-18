# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Workloads::Workload, feature_category: :continuous_integration do
  describe 'associations' do
    it { is_expected.to have_many(:workflows_workloads).class_name('Ai::DuoWorkflows::WorkflowsWorkload') }
    it { is_expected.to have_many(:workflows).through(:workflows_workloads) }
  end

  describe '#latest_workflow' do
    let_it_be(:project) { create(:project) }
    let_it_be(:workload) { create(:ci_workload, project: project) }

    subject(:latest_workflow) { workload.latest_workflow }

    context 'when the workload has no workflows' do
      it { is_expected.to be_nil }
    end

    context 'when the workload has multiple workflows' do
      let_it_be(:older_workflow) { create(:duo_workflows_workflow, project: project) }
      let_it_be(:newer_workflow) { create(:duo_workflows_workflow, project: project) }

      before_all do
        create(:duo_workflows_workload, workflow: older_workflow, workload: workload, project: project)
        create(:duo_workflows_workload, workflow: newer_workflow, workload: workload, project: project)
      end

      it 'returns the workflow with the highest id' do
        expect(latest_workflow).to eq(newer_workflow)
      end
    end
  end
end
