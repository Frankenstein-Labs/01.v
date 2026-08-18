# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Automate Agent Sessions', :js, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project, :repository) }
  let(:agent_sessions_path) { project_automate_agent_sessions_path(project) }
  let_it_be(:user) { create(:user) }

  before_all do
    project.add_developer(user)
    project.project_setting.update!(duo_remote_flows_enabled: true, duo_features_enabled: true)
  end

  before do
    sign_in(user)

    stub_licensed_features(ai_workflows: true)
    allow(::Ai::DuoWorkflow).to receive(:enabled?).and_return(true)
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)

    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(user, :read_duo_workflow, anything).and_return(true)
    allow(Ability).to receive(:allowed?).with(user, :duo_workflow, anything).and_return(true)

    # Mock the usage quota service to avoid external HTTP requests
    allow_next_instance_of(::Ai::UsageQuotaService) do |service|
      allow(service).to receive(:execute).and_return(ServiceResponse.success)
    end
  end

  describe 'visiting the agent sessions page' do
    context 'when sessions exist' do
      let_it_be(:workflow1) do
        create(:duo_workflows_workflow,
          project: project,
          user: user,
          goal: 'Fix pipeline issues',
          workflow_definition: 'issue_to_mr',
          environment: :web)
      end

      let_it_be(:workflow2) do
        create(:duo_workflows_workflow,
          project: project,
          user: user,
          goal: 'Review code changes',
          workflow_definition: 'code_review',
          environment: :web)
      end

      before do
        visit agent_sessions_path
      end

      it 'displays the sessions list' do
        expect(page).to have_content(workflow1.title)
        expect(page).to have_content(workflow2.title)
      end
    end

    context 'when no sessions exist' do
      before do
        Ai::DuoWorkflows::Workflow.where(project: project).delete_all
        visit agent_sessions_path
      end

      it 'shows empty state' do
        expect(page).to have_content('No agent sessions yet', wait: 10)
      end
    end
  end

  describe 'access control' do
    let(:agent_sessions_path) { project_automate_agent_sessions_path(project) }

    shared_examples 'returns 404 page' do
      it 'returns 404' do
        visit agent_sessions_path

        expect(page).to have_content('Page not found')
      end
    end

    context 'when duo remote flows are disabled' do
      before do
        project.project_setting.update!(duo_remote_flows_enabled: false)
      end

      include_examples 'returns 404 page'
    end

    context 'when duo features are disabled' do
      before do
        project.project_setting.update!(duo_features_enabled: false)
      end

      include_examples 'returns 404 page'
    end

    context 'when user does not have access to project' do
      let(:other_user) { create(:user) }

      before do
        sign_out(user)
        sign_in(other_user)
      end

      include_examples 'returns 404 page'
    end
  end
end
