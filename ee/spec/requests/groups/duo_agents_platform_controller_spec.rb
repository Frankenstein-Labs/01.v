# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups::DuoAgentsPlatform', :saas_gitlab_com_subscriptions, feature_category: :workflow_catalog do
  let_it_be(:developer) { create(:user, :with_namespace) }
  let_it_be(:reporter) { create(:user, :with_namespace) }
  let_it_be(:guest) { create(:user, :with_namespace) }
  let(:user) { developer }

  let_it_be_with_reload(:group) do
    create(:group_with_plan, plan: :ultimate_trial_plan, trial: true,
      trial_starts_on: Date.current, trial_ends_on: 30.days.from_now,
      developers: developer, reporters: reporter, guests: guest)
  end

  before do
    stub_saas_features(gitlab_com_subscriptions: true, ai_catalog: true)
    stub_licensed_features(ai_catalog: true, ai_features: true)
    create(:gitlab_subscription_add_on_purchase, :active_trial, :duo_core, namespace: group)
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

  describe 'GET /:group/-/automate' do
    context 'when user is not signed in' do
      before do
        sign_out(user)
      end

      it 'returns 404' do
        get group_automate_agents_path(group)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when group is not a root group' do
      let(:subgroup) { create(:group, parent: group) }

      it 'returns 404' do
        get group_automate_agents_path(subgroup)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user has access to duo_workflow' do
      it 'renders successfully' do
        get group_automate_flows_path(group)

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'pushes feature flags to frontend' do
        get group_automate_flows_path(group)

        expect(response.body).to include('aiCatalogThirdPartyFlows')
      end
    end

    context 'when the user is a guest' do
      let(:user) { guest }

      it 'renders the agents page' do
        get group_automate_agents_path(group)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when the AI catalog is not available' do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :ai_catalog).and_return(false)
      end

      it 'renders the agents page because ai_catalog_public_explore is enabled' do
        get group_automate_agents_path(group)

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when ai_catalog_public_explore is disabled' do
        before do
          stub_feature_flags(ai_catalog_public_explore: false)
        end

        it 'returns a 404' do
          get group_automate_agents_path(group)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when duo_features_enabled is false' do
      before do
        stub_feature_flags(ai_catalog_public_explore: false)
        group.namespace_settings.update!(duo_features_enabled: false)
      end

      it 'returns a 404' do
        get group_automate_agents_path(group)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the user is entitled but their identity is not verified' do
      before do
        stub_feature_flags(dap_require_identity_verification: true)
        allow_any_instance_of(User).to receive(:identity_verified?).and_return(false) # rubocop:disable RSpec/AnyInstanceOf -- the request reloads current_user, so a per-object stub would not apply
      end

      it 'renders the page so the verification banner can be shown' do
        get group_automate_agents_path(group)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when vueroute is agents' do
      it 'returns successfully' do
        get group_automate_agents_path(group)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when vueroute is flows' do
      it 'returns successfully' do
        get group_automate_flows_path(group)

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when user is a maintainer of a project in the group' do
        let_it_be(:maintainer) { create(:user) }
        let_it_be(:maintainer_group, freeze: false) { create(:group) }
        let_it_be(:project) { create(:project, group: maintainer_group, maintainers: maintainer) }

        let(:group) { maintainer_group }
        let(:user) { maintainer }

        before do
          group.namespace_settings.update!(
            duo_features_enabled: true,
            duo_foundational_flows_enabled: true,
            duo_remote_flows_enabled: true
          )
        end

        it 'renders successfully' do
          get group_automate_flows_path(group)

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'when the AI catalog is not available' do
          before do
            stub_feature_flags(ai_catalog_public_explore: false)
            allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :ai_catalog).and_return(false)
          end

          it 'returns a 404' do
            get group_automate_flows_path(group)

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      context 'when user can read foundational flows' do
        before do
          allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :ai_catalog_flows).and_return(false)
          group.namespace_settings.update!(duo_foundational_flows_enabled: true)
        end

        it 'returns successfully' do
          get group_automate_flows_path(group)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when user does not have access to read flows or foundational flows' do
        let(:user) { reporter }

        it 'returns a 404' do
          get group_automate_flows_path(group)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when vueroute is mcp-servers' do
      context 'when user can read mcp servers' do
        it 'returns successfully' do
          get group_automate_mcp_servers_path(group)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when user cannot read mcp servers' do
        before do
          group.ai_settings.update!(duo_workflow_mcp_enabled: false)
        end

        it 'returns 404' do
          get group_automate_mcp_servers_path(group)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
