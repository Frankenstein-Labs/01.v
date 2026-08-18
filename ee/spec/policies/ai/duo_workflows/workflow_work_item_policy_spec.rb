# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::WorkflowWorkItemPolicy, feature_category: :duo_agent_platform do
  subject(:policy) { described_class.new(current_user, link) }

  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:workflow) { create(:duo_workflows_workflow, project: project) }
  let_it_be(:link) { create(:duo_workflows_workflow_work_item, workflow: workflow) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let(:current_user) { developer }

  before do
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
  end

  # The policy delegates to the linked workflow, so `read_duo_workflow` on the
  # join record resolves through WorkflowPolicy.
  describe 'read_duo_workflow' do
    context 'when the user can read the linked workflow' do
      before do
        workflow.update!(user: current_user)
        allow(current_user).to receive(:allowed_to_use?).and_return(true)
      end

      it { expect_allowed(:read_duo_workflow) }
    end

    context 'when the user cannot read the linked workflow' do
      it { expect_disallowed(:read_duo_workflow) }
    end
  end
end
