# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects::DuoAgentsPlatform', :saas_gitlab_com_subscriptions, type: :request,
  feature_category: :workflow_catalog do
  let_it_be(:developer) { create(:user, :with_namespace) }
  let_it_be(:maintainer) { create(:user, :with_namespace) }
  let_it_be(:reporter) { create(:user, :with_namespace) }
  let_it_be(:guest) { create(:user, :with_namespace) }
  let(:user) { developer }

  let_it_be_with_reload(:group) do
    create(:group_with_plan, plan: :ultimate_trial_plan, trial: true,
      trial_starts_on: Date.current, trial_ends_on: 30.days.from_now,
      developers: developer, maintainers: maintainer, reporters: reporter, guests: guest)
  end

  let_it_be_with_reload(:project) { create(:project, group: group) }

  before do
    stub_saas_features(gitlab_com_subscriptions: true, ai_catalog: true)
    stub_licensed_features(ai_catalog: true, ai_features: true)
    create(:gitlab_subscription_add_on_purchase, :active_trial, :duo_core, namespace: group)
    project.project_setting.update!(duo_remote_flows_enabled: true, duo_features_enabled: true)
    group.namespace_settings.update!(
      duo_features_enabled: true, experiment_features_enabled: true, duo_core_features_enabled: true
    )
    group.ai_settings.update!(duo_agent_platform_enabled: true, duo_workflow_mcp_enabled: true)
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
    allow_next_instance_of(Gitlab::Llm::DuoChat) do |instance|
      allow(instance).to receive_messages(credits_available?: true, usage_billing_forbidden?: false)
    end
    sign_in(user)
  end

  describe 'GET /:namespace/:project/-/automate' do
    context 'when duo workflow is enabled' do
      context 'and the user has access to duo_workflow' do
        it 'renders successfully' do
          get project_automate_agent_sessions_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'pushes feature flags to frontend' do
          get project_automate_agent_sessions_path(project)

          expect(response.body).to include('aiCatalogThirdPartyFlows')
        end

        context 'when accessing a specific agent session' do
          let_it_be(:other_project) { create(:project, group: group) }
          let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: developer) }
          let_it_be(:other_workflow) { create(:duo_workflows_workflow, project: other_project, user: developer) }

          it 'renders successfully when the session belongs to the project' do
            get project_automate_path(project, vueroute: "agent-sessions/#{workflow.id}")

            expect(response).to have_gitlab_http_status(:ok)
          end

          it 'returns 404 when the session belongs to a different project' do
            get project_automate_path(project, vueroute: "agent-sessions/#{other_workflow.id}")

            expect(response).to have_gitlab_http_status(:not_found)
          end

          it 'returns 404 when the session does not exist' do
            get project_automate_path(project, vueroute: "agent-sessions/#{non_existing_record_id}")

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      context 'and the user is a guest' do
        let(:user) { guest }

        it 'renders the agents page' do
          get project_automate_agents_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'and the AI catalog is not available' do
        before do
          allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :ai_catalog).and_return(false)
        end

        it 'renders the agent sessions page because ai_catalog_public_explore is enabled' do
          get project_automate_agent_sessions_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'and ai_catalog_public_explore is disabled' do
          before do
            stub_feature_flags(ai_catalog_public_explore: false)
          end

          it 'returns a 404' do
            get project_automate_agent_sessions_path(project)

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      context 'when the user is entitled but their identity is not verified' do
        before do
          stub_feature_flags(dap_require_identity_verification: true)
          allow_any_instance_of(User).to receive(:identity_verified?).and_return(false) # rubocop:disable RSpec/AnyInstanceOf -- the request reloads current_user, so a per-object stub would not apply
        end

        it 'renders the page so the verification banner can be shown' do
          get project_automate_agent_sessions_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'when duo_features_enabled setting is disabled' do
      before do
        project.project_setting.update!(duo_features_enabled: false)
      end

      it 'returns 404' do
        get project_automate_agent_sessions_path(project)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when duo_remote_flows_enabled setting is disabled' do
      before do
        project.project_setting.update!(duo_remote_flows_enabled: false)
      end

      it 'returns 404' do
        get project_automate_agent_sessions_path(project)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when vueroute is agents' do
      it 'returns successfully' do
        get project_automate_agents_path(project)

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when the user is not signed in and the project is public' do
        let_it_be(:project) { create(:project, :public) }

        before do
          sign_out(user)
        end

        it 'returns a 404' do
          get project_automate_agents_path(project)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when vueroute is flow-triggers' do
      context 'when user can manage ai flow triggers' do
        let(:user) { maintainer }

        it 'renders successfully' do
          get project_automate_flow_triggers_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when user cannot manage ai flow triggers' do
        it 'returns 404' do
          get project_automate_flow_triggers_path(project)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when vueroute is flows' do
      context 'when user can read flows' do
        it 'returns successfully' do
          get project_automate_flows_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when user can read foundational flows' do
        before do
          allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :ai_catalog_flows).and_return(false)
          project.project_setting.update!(duo_foundational_flows_enabled: true)
        end

        it 'returns successfully' do
          get project_automate_flows_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when user cannot read flows or foundational flows' do
        let(:user) { reporter }

        it 'returns 404' do
          get project_automate_flows_path(project)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when vueroute is onboarding' do
      before do
        stub_feature_flags(duo_agent_onboarding: true)

        allow_next_instance_of(Repository) do |repo|
          allow(repo).to receive_messages(exists?: true, blob_at: nil)
        end

        allow_next_instance_of(Gitlab::CodeOwners::Loader) do |loader|
          allow(loader).to receive(:members).and_return([])
        end
      end

      context 'when user has duo_workflow access' do
        it 'returns successfully' do
          get project_automate_onboarding_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'pushes the onboarding setup path and initializer state', :aggregate_failures do
          get project_automate_onboarding_path(project)

          expect(response.body).to include('onboarding_setup_path')
          expect(response.body).to include('onboarding_initializers')
          expect(response.body).to include('init_project_context')
          expect(response.body).to include('init_execution_env')
          expect(response.body).to include('init_mr_review_instructions')
          expect(response.body).to include('init_codeowners')
          expect(response.body).to include('init_chat_rules')
        end

        it 'pushes the readiness state and the manage-project ability', :aggregate_failures do
          get project_automate_onboarding_path(project)

          expect(response.body).to include('onboarding_readiness')
          expect(response.body).to include('dap_available')
          expect(response.body).to include('environment_healthy')
          expect(response.body).to include('group_settings_path')
          expect(response.body).to include('onboarding_capabilities')
          expect(response.body).to include('can_admin_project')
        end

        context 'when an onboarding workflow is tracked for an initializer' do
          let!(:persisted_workflow) { create(:duo_workflows_workflow, :running, project: project) }

          before do
            allow_next_instance_of(Ai::Catalog::Onboarding::WorkflowTracker) do |tracker|
              allow(tracker).to receive(:workflow_for).and_return(nil)
              allow(tracker).to receive(:workflow_for).with('init_project_context').and_return(persisted_workflow)
            end
          end

          it 'reflects the tracked workflow status and id in the gon payload', :aggregate_failures do
            get project_automate_onboarding_path(project)

            expect(response.body).to include('"status":"running"')
            expect(response.body).to include("\"workflow_id\":#{persisted_workflow.id}")
          end
        end
      end

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(duo_agent_onboarding: false)
        end

        it 'returns 404' do
          get project_automate_onboarding_path(project)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when user lacks duo_workflow access' do
        let(:user) { reporter }

        it 'returns 404' do
          get project_automate_onboarding_path(project)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when vueroute is mcp-servers' do
      context 'when user can read mcp servers' do
        it 'returns successfully' do
          get project_automate_mcp_servers_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when user cannot read mcp servers' do
        before do
          group.ai_settings.update!(duo_workflow_mcp_enabled: false)
        end

        it 'returns 404' do
          get project_automate_mcp_servers_path(project)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when flow-triggers are requested' do
      context 'when user is not signed in' do
        before do
          sign_out(user)
        end

        it 'redirects to sign in' do
          get project_automate_flow_triggers_path(project)

          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context 'when user does not have access to project' do
        let(:other_user) { create(:user) }

        before do
          sign_in(other_user)
        end

        it 'returns 404' do
          get project_automate_flow_triggers_path(project)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end

  describe 'POST /:namespace/:project/-/automate/onboarding/setup' do
    let(:run_result) { ServiceResponse.success(payload: { workflow_id: 42 }) }

    before do
      stub_feature_flags(duo_agent_onboarding: true)

      allow_next_instance_of(Ai::Catalog::Onboarding::RunService) do |svc|
        allow(svc).to receive(:execute).and_return(run_result)
      end
    end

    def post_setup(params = { event_type: 'init_project_context' })
      post project_automate_onboarding_setup_path(project), params: params
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(duo_agent_onboarding: false)
      end

      it 'returns 404' do
        post_setup

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the user lacks duo_workflow access' do
      let(:user) { reporter }

      it 'returns 403' do
        post_setup

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when the run succeeds' do
      it 'returns 201 with the workflow id', :aggregate_failures do
        post_setup

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['workflow_id']).to eq(42)
      end

      it 'passes the initializer key to the run service' do
        expect(Ai::Catalog::Onboarding::RunService).to receive(:new).with(
          project: project, current_user: user, params: { event_type: 'improve_ci' }
        ).and_return(instance_double(Ai::Catalog::Onboarding::RunService, execute: run_result))

        post_setup(event_type: 'improve_ci')
      end
    end

    context 'when the run fails' do
      let(:run_result) { ServiceResponse.error(message: 'nope') }

      it 'returns 422 with the error message', :aggregate_failures do
        post_setup

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(json_response['message']).to eq('nope')
      end
    end
  end

  describe 'feature category assignment' do
    it 'returns workflow_catalog for the agents route' do
      controller = Projects::DuoAgentsPlatformController.new
      allow(controller).to receive(:params).and_return(ActionController::Parameters.new(vueroute: 'agents'))

      expect(controller.feature_category).to eq('workflow_catalog')
    end

    it 'returns workflow_catalog for the flows route' do
      controller = Projects::DuoAgentsPlatformController.new
      allow(controller).to receive(:params).and_return(ActionController::Parameters.new(vueroute: 'flows'))

      expect(controller.feature_category).to eq('workflow_catalog')
    end

    it 'returns duo_agent_platform for the triggers route' do
      controller = Projects::DuoAgentsPlatformController.new
      allow(controller).to receive(:params).and_return(ActionController::Parameters.new(vueroute: 'triggers'))

      expect(controller.feature_category).to eq('duo_agent_platform')
    end

    it 'returns duo_agent_platform for the agent-sessions route' do
      controller = Projects::DuoAgentsPlatformController.new
      allow(controller).to receive(:params).and_return(ActionController::Parameters.new(vueroute: 'agent-sessions'))

      expect(controller.feature_category).to eq('duo_agent_platform')
    end

    it 'returns workflow_catalog when no vueroute is set' do
      controller = Projects::DuoAgentsPlatformController.new
      allow(controller).to receive(:params).and_return(ActionController::Parameters.new({}))

      expect(controller.feature_category).to eq('workflow_catalog')
    end
  end
end
