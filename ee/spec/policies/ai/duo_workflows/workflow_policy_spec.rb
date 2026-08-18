# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::WorkflowPolicy, feature_category: :duo_agent_platform do
  using RSpec::Parameterized::TableSyntax

  subject(:policy) { described_class.new(current_user, workflow) }

  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group) }
  let_it_be_with_reload(:workflow) { create(:duo_workflows_workflow, project: project, environment: :ide) }
  let_it_be(:guest) { create(:user, guest_of: workflow.project) }
  let_it_be(:developer) { create(:user, developer_of: workflow.project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: workflow.project) }

  let(:current_user) { developer }

  describe "read_duo_workflow and update_duo_workflow" do
    where(:duo_features_enabled, :current_user, :stage_check_available, :user_is_allowed_to_use, :allowed) do
      true   | ref(:developer)  | true  | false | false
      true   | ref(:developer)  | false | false | false
      true   | ref(:maintainer) | false | false | false
      true   | ref(:maintainer) | true  | false | false
      true   | ref(:guest)      | true  | false | false
      false  | ref(:developer)  | true  | false | false
      true   | ref(:maintainer) | true  | true  | true
      true   | ref(:guest)      | true  | true  | false
      true   | ref(:developer)  | true  | true  | true
    end

    with_them do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project,
          :duo_workflow).and_return(stage_check_available)
        allow(current_user).to receive(:allowed_to_use?).and_return(user_is_allowed_to_use)
        project.project_setting.update!(duo_features_enabled: duo_features_enabled)
        workflow.update!(user: current_user)
      end

      it 'checks read and update workflow policy' do
        is_expected.to(allowed ? be_allowed(:read_duo_workflow) : be_disallowed(:read_duo_workflow))
        is_expected.to(allowed ? be_allowed(:update_duo_workflow) : be_disallowed(:update_duo_workflow))
      end
    end

    context "when user is not workflow owner but has project access and workflow is non-chat web environment" do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
        project.project_setting.update!(duo_features_enabled: true)
        workflow.update!(user: maintainer, environment: :web)
        allow(current_user).to receive(:allowed_to_use?).and_return(true)
      end

      it { is_expected.to be_allowed(:read_duo_workflow) }
      it { is_expected.to be_disallowed(:update_duo_workflow) }
    end

    context "when user is not workflow owner but has project access and workflow is non-chat ambient environment" do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
        project.project_setting.update!(duo_features_enabled: true)
        workflow.update!(user: maintainer, environment: :ambient)
        allow(current_user).to receive(:allowed_to_use?).and_return(true)
      end

      it { is_expected.to be_allowed(:read_duo_workflow) }
      it { is_expected.to be_disallowed(:update_duo_workflow) }
    end

    context "when user is not workflow owner" do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
        project.project_setting.update!(duo_features_enabled: true)
        workflow.update!(user: maintainer, environment: :ide)
        allow(current_user).to receive(:allowed_to_use?).and_return(true)
      end

      it { is_expected.to be_disallowed(:read_duo_workflow) }
      it { is_expected.to be_disallowed(:update_duo_workflow) }

      context "when current user is a service account" do
        let(:current_user) do
          create(:user, :service_account, developer_of: workflow.project, composite_identity_enforced: true)
        end

        before do
          allow(current_user).to receive(:allowed_to_use?).and_return(true)
        end

        it { is_expected.to be_allowed(:read_duo_workflow) }
        it { is_expected.to be_allowed(:update_duo_workflow) }
        it { expect_disallowed(:resume_duo_workflow) }

        context 'when workflow is in input_required state' do
          before do
            pipeline = create(:ci_pipeline, :success, project: project)
            workload = create(:ci_workload, pipeline: pipeline, project: project)
            workflow.workflows_workloads.create!(workload: workload, project: project)
            workflow.update!(status: status_enum(:input_required))
          end

          it { expect_allowed(:resume_duo_workflow) }
        end
      end
    end
  end

  describe "read_duo_workflow and update_duo_workflow for project-level agentic chat" do
    let_it_be_with_reload(:workflow) { create(:duo_workflows_workflow, :agentic_chat, project: project) }

    before do
      allow(policy).to receive(:can?).and_call_original
      allow(policy).to receive(:can?).with(:access_duo_agentic_chat, project).and_return(can_use_agentic_chat)
      allow(policy).to receive(:can?).with(:duo_workflow, project).and_return(true)
    end

    context "when agentic chat is allowed" do
      let(:can_use_agentic_chat) { true }

      context "when current user is workflow owner" do
        before do
          workflow.update!(user: current_user)
        end

        it 'allows read and update workflow policy' do
          is_expected.to be_allowed(:read_duo_workflow)
          is_expected.to be_allowed(:update_duo_workflow)
        end

        it { expect_disallowed(:resume_duo_workflow) }

        context 'when workflow is in input_required state' do
          before do
            workflow.update!(status: status_enum(:input_required))
          end

          it { expect_disallowed(:resume_duo_workflow) }
        end
      end

      context "when current user is not workflow owner" do
        before do
          workflow.update!(user: create(:user))
        end

        it 'disallows read, update and resume workflow policy' do
          is_expected.to be_disallowed(:read_duo_workflow)
          is_expected.to be_disallowed(:update_duo_workflow)
          expect_disallowed(:resume_duo_workflow)
        end
      end
    end

    context "when agentic chat is disallowed" do
      let(:can_use_agentic_chat) { false }

      before do
        workflow.update!(user: current_user)
      end

      it 'disallows read and update workflow policy' do
        is_expected.to be_disallowed(:read_duo_workflow)
        is_expected.to be_disallowed(:update_duo_workflow)
      end
    end
  end

  describe "read_duo_workflow and update_duo_workflow for namespace-level agentic chat" do
    let_it_be_with_reload(:workflow) { create(:duo_workflows_workflow, :agentic_chat, namespace: group) }

    before do
      allow(policy).to receive(:can?).and_call_original
      allow(policy).to receive(:can?).with(:access_duo_agentic_chat, group).and_return(can_use_agentic_chat)
      # Namespace-level workflows have no project, so can_use_duo_workflows_in_project is always false
      allow(policy).to receive(:can?).with(:duo_workflow, nil).and_return(false)
    end

    context "when agentic chat is allowed" do
      let(:can_use_agentic_chat) { true }

      context "when current user is workflow owner" do
        before do
          workflow.update!(user: current_user)
        end

        it 'allows read and update workflow policy' do
          is_expected.to be_allowed(:read_duo_workflow)
          is_expected.to be_allowed(:update_duo_workflow)
        end

        it { expect_disallowed(:resume_duo_workflow) }

        context 'when workflow is in input_required state' do
          before do
            workflow.update!(status: status_enum(:input_required))
          end

          it { expect_disallowed(:resume_duo_workflow) }
        end
      end

      context "when current user is not workflow owner" do
        before do
          workflow.update!(user: create(:user))
        end

        it 'disallows read, update and resume workflow policy' do
          is_expected.to be_disallowed(:read_duo_workflow)
          is_expected.to be_disallowed(:update_duo_workflow)
          expect_disallowed(:resume_duo_workflow)
        end
      end
    end

    context "when agentic chat is disallowed" do
      let(:can_use_agentic_chat) { false }

      before do
        workflow.update!(user: current_user)
      end

      it 'disallows read and update workflow policy' do
        is_expected.to be_disallowed(:read_duo_workflow)
        is_expected.to be_disallowed(:update_duo_workflow)
      end
    end
  end

  describe 'resume_duo_workflow' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      allow(current_user).to receive(:allowed_to_use?).and_return(true)
      project.project_setting.update!(duo_features_enabled: true)
      workflow.update!(user: current_user)
    end

    context 'when workflow is not in input_required state' do
      it { expect_disallowed(:resume_duo_workflow) }
    end

    context 'when workflow is in input_required state' do
      before do
        workflow.update!(status: status_enum(:input_required))
      end

      context 'when there are no workloads' do
        it { expect_disallowed(:resume_duo_workflow) }
      end

      context 'when last workload pipeline has a non-completed status' do
        before do
          pipeline = create(:ci_pipeline, project: project)
          workload = create(:ci_workload, pipeline: pipeline, project: project)
          workflow.workflows_workloads.create!(workload: workload, project: project)
        end

        it { expect_disallowed(:resume_duo_workflow) }
      end

      context 'when last workload pipeline has a completed status' do
        before do
          pipeline = create(:ci_pipeline, :success, project: project)
          workload = create(:ci_workload, pipeline: pipeline, project: project)
          workflow.workflows_workloads.create!(workload: workload, project: project)
        end

        it { expect_allowed(:resume_duo_workflow) }

        context 'when user is not the workflow owner' do
          before do
            workflow.update!(user: maintainer)
          end

          it { expect_disallowed(:resume_duo_workflow) }
        end

        context 'when duo workflows are not available for the project' do
          before do
            allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(false)
          end

          it { expect_disallowed(:resume_duo_workflow) }
        end
      end
    end
  end

  describe "execute_duo_workflow_in_ci" do
    where(:duo_features_enabled, :duo_remote_flows_enabled, :current_user,
      :stage_check, :allowed) do
      true  | false | ref(:developer)  | true  | false
      true  | true  | ref(:developer)  | false | false
      true  | true  | ref(:developer)  | true  | true
      true  | true  | ref(:guest)      | true  | false
      false | true  | ref(:developer)  | true  | false
    end

    with_them do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(stage_check)
        allow(current_user).to receive(:allowed_to_use?).and_return(true)
        project.project_setting.update!(duo_features_enabled: duo_features_enabled,
          duo_remote_flows_enabled: duo_remote_flows_enabled)
        workflow.update!(user: current_user)
      end

      it 'checks execute_duo_workflow_in_ci policy' do
        is_expected.to(allowed ? be_allowed(:execute_duo_workflow_in_ci) : be_disallowed(:execute_duo_workflow_in_ci))
      end
    end
  end

  describe 'delete_duo_workflow' do
    context 'when workflow is a chat workflow' do
      let_it_be(:chat_workflow) { create(:duo_workflows_workflow, :agentic_chat, project: project) }

      let(:workflow) { chat_workflow }

      context 'when user owns the workflow' do
        let(:current_user) { chat_workflow.user }

        it { is_expected.to be_allowed(:delete_duo_workflow) }
      end

      context 'when user does not own the workflow' do
        let(:current_user) { create(:user) }

        it { is_expected.to be_disallowed(:delete_duo_workflow) }
      end

      context 'when current user is a service account' do
        let(:current_user) { create(:user, :service_account) }

        context 'when service account does not have composite identity enforced' do
          it { is_expected.to be_disallowed(:delete_duo_workflow) }
        end

        context 'when service account has composite identity enforced' do
          before do
            current_user.composite_identity_enforced!
          end

          it { is_expected.to be_allowed(:delete_duo_workflow) }
        end
      end
    end

    context 'when workflow is not a chat workflow' do
      let(:current_user) { workflow.user }

      it { is_expected.to be_disallowed(:delete_duo_workflow) }
    end
  end

  describe ':read_duo_workflow for compliance reviewers' do
    let_it_be(:reviewer) { create(:user) }
    let(:current_user) { reviewer }

    before_all do
      project.add_owner(reviewer)
    end

    before do
      stub_licensed_features(
        custom_roles: true,
        project_level_compliance_dashboard: true,
        group_level_compliance_dashboard: true
      )
    end

    context 'when workflow is a non-chat workflow' do
      let_it_be(:other_owner) { create(:user) }

      before_all do
        workflow.update!(user: other_owner)
      end

      it { is_expected.to be_allowed(:read_duo_workflow) }
      it { is_expected.to be_allowed(:read_agent_artifacts) }
      it { is_expected.to be_disallowed(:update_duo_workflow) }
    end

    context 'when workflow is a foundational agent workflow' do
      let_it_be(:foundational_workflow) do
        create(:duo_workflows_workflow, project: project,
          workflow_definition: 'security_analyst_agent/v1')
      end

      subject(:policy) { described_class.new(reviewer, foundational_workflow) }

      it { is_expected.to be_allowed(:read_duo_workflow) }
      it { is_expected.to be_allowed(:read_agent_artifacts) }
      it { is_expected.to be_disallowed(:update_duo_workflow) }
    end

    context 'when workflow is a chat session' do
      let_it_be(:chat_workflow) do
        create(:duo_workflows_workflow, :agentic_chat, project: project)
      end

      subject(:policy) { described_class.new(reviewer, chat_workflow) }

      it { is_expected.to be_disallowed(:read_duo_workflow) }
      it { is_expected.to be_disallowed(:read_agent_artifacts) }
    end

    context 'when user has :read_agent_artifacts via a project membership only' do
      let_it_be(:project_reviewer) { create(:user) }
      let_it_be(:project_role) { create(:member_role, :guest, :read_agent_artifacts, namespace: group) }
      let_it_be(:project_membership) do
        create(:project_member, :guest, member_role: project_role, user: project_reviewer, project: project)
      end

      subject(:policy) { described_class.new(project_reviewer, workflow) }

      it { is_expected.to be_allowed(:read_agent_artifacts) }
      it { is_expected.to be_allowed(:read_duo_workflow) }

      it 'does not grant :read_agent_artifacts on the parent group' do
        expect(project_reviewer.can?(:read_agent_artifacts, group)).to be(false)
      end
    end

    context 'when user has no compliance role' do
      let_it_be(:non_compliance_user) { create(:user, developer_of: project) }
      let(:current_user) { non_compliance_user }

      it { is_expected.to be_disallowed(:read_agent_artifacts) }
      it { is_expected.to be_disallowed(:read_duo_workflow) }
    end

    context 'when user has :read_agent_artifacts on a different group' do
      let_it_be(:other_reviewer) { create(:user) }
      let_it_be(:other_group) { create(:group) }
      let_it_be(:other_role) { create(:member_role, :guest, :read_agent_artifacts, namespace: other_group) }
      let_it_be(:other_membership) do
        create(:group_member, :guest, member_role: other_role, user: other_reviewer, group: other_group)
      end

      subject(:policy) { described_class.new(other_reviewer, workflow) }

      it { is_expected.to be_disallowed(:read_agent_artifacts) }
      it { is_expected.to be_disallowed(:read_duo_workflow) }
    end
  end

  describe 'namespace-scoped non-chat sessions' do
    let_it_be_with_reload(:workflow) do
      create(:duo_workflows_workflow, namespace: group, project: nil, environment: :ide)
    end

    let_it_be(:group_developer) { create(:user, developer_of: group) }

    let(:current_user) { group_developer }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :duo_workflow).and_return(true)
      allow(current_user).to receive(:allowed_to_use?).and_return(true)
      workflow.update!(user: current_user)
    end

    it 'lets the owner read and update the session', :aggregate_failures do
      is_expected.to be_allowed(:read_duo_workflow)
      is_expected.to be_allowed(:update_duo_workflow)
    end

    it 'does not let a different group member read or update the session' do
      other_policy = described_class.new(create(:user, developer_of: group), workflow)

      expect(other_policy).to be_disallowed(:read_duo_workflow)
      expect(other_policy).to be_disallowed(:update_duo_workflow)
    end

    it 'keeps remote execution denied, since there is no project to run it in' do
      is_expected.to be_disallowed(:execute_duo_workflow_in_ci)
    end
  end

  describe 'autonomous SA as workflow owner' do
    let_it_be(:autonomous_sa) { create(:user, :service_account, developer_of: project) }
    let(:current_user) { autonomous_sa }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      allow(autonomous_sa).to receive(:allowed_to_use?).and_return(true)
      project.project_setting.update!(duo_features_enabled: true)
      workflow.update!(
        user: autonomous_sa,
        trigger_source: :system,
        environment: :web
      )
    end

    it 'recognizes the SA as workflow owner when it is the workflow user' do
      is_expected.to be_allowed(:read_duo_workflow)
      is_expected.to be_allowed(:update_duo_workflow)
    end
  end

  def status_enum(status)
    Ai::DuoWorkflows::Workflow.state_machines[:status].states[status].value
  end
end
