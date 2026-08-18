# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::WorkflowsWorkload, feature_category: :duo_agent_platform do
  subject(:workflows_workload) { create(:duo_workflows_workload) }

  it { is_expected.to belong_to(:workflow) }
  it { is_expected.to belong_to(:workload) }
  it { is_expected.to belong_to(:project) }

  it { is_expected.to validate_presence_of(:workflow) }
  it { is_expected.to validate_presence_of(:workload) }
  it { is_expected.to validate_presence_of(:project) }

  context 'with loose foreign key on duo_workflows_workloads.workload_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let!(:parent) { create(:ci_workload) }
      let!(:model) { create(:duo_workflows_workload, workload: parent) }
    end
  end
end
