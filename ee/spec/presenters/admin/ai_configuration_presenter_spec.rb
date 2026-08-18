# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::AiConfigurationPresenter, feature_category: :ai_abstraction_layer do
  let_it_be(:default_organization) { build(:organization) }

  before do
    allow(::Organizations::Organization).to receive(:default_organization).and_return(default_organization)
    stub_current_organization(default_organization)
  end

  describe '#settings' do
    subject(:settings) { described_class.new(current_user).settings }

    let(:current_user) { build(:admin) }
    let(:application_setting_attributes) do
      {
        disabled_direct_code_suggestions?: true,
        duo_availability: 'default_off',
        duo_remote_flows_availability: true,
        duo_foundational_flows_availability: false,
        duo_workflows_default_image_registry: nil,
        duo_chat_expiration_column: 'last_updated_at',
        duo_chat_expiration_days: '30',
        enabled_expanded_logging: true,
        gitlab_dedicated_instance?: false,
        instance_level_ai_beta_features_enabled: true,
        model_prompt_cache_enabled?: true,
        duo_template_project: nil
      }
    end

    let(:ai_settings) do
      Ai::Setting.new.tap do |settings|
        allow(settings).to receive_messages(
          duo_core_features_enabled?: true,
          duo_agent_platform_enabled: true,
          ai_audit_events_streaming_enabled: false,
          foundational_agents_default_enabled: true
        )
      end
    end

    let(:beta_self_hosted_models_enabled) { true }
    let(:active_duo_add_ons_exist?) { true }
    let(:namespace_access_rules) do
      {
        1 => [
          instance_double(
            ::Ai::FeatureAccessRule,
            through_namespace: instance_double(
              Namespace,
              id: 1,
              name: 'Group A',
              full_path: 'group-a'
            ),
            accessible_entity: 'duo_classic'
          )
        ],
        2 => [
          instance_double(
            ::Ai::FeatureAccessRule,
            through_namespace: instance_double(
              Namespace,
              id: 2,
              name: 'Group B',
              full_path: 'group-b'
            ),
            accessible_entity: 'duo_agent_platform'
          )
        ]
      }
    end

    let(:transformed_namespace_access_rules) do
      [
        {
          through_namespace: {
            id: 1,
            name: 'Group A',
            full_path: 'group-a'
          },
          features: ["duo_classic"]
        }, {
          through_namespace: {
            id: 2,
            name: 'Group B',
            full_path: 'group-b'
          },
          features: ['duo_agent_platform']
        }
      ]
    end

    before do
      stub_ee_application_setting(**application_setting_attributes)

      allow(GitlabSubscriptions::AddOnPurchase)
        .to receive(:active_duo_add_ons_exist?)
        .with(:instance)
        .and_return(active_duo_add_ons_exist?)

      allow(Ai::Setting).to receive(:for_organization_read_only).and_return(ai_settings)

      allow(Ai::TestingTermsAcceptance)
        .to receive(:has_accepted?)
        .and_return(beta_self_hosted_models_enabled)

      allow(Ability).to receive(:allowed?).with(current_user, :manage_self_hosted_models_settings).and_return(true)
      allow(Ability).to receive(:allowed?).with(current_user, :update_dap_self_hosted_model).and_return(true)
      allow(Ability).to receive(:allowed?).with(current_user, :update_ai_gateway_timeout).and_return(true)

      allow(Ai::FeatureAccessRule).to receive(:duo_root_namespace_access_rules).and_return namespace_access_rules

      stub_licensed_features(ai_features: true)
    end

    specify do
      expect(settings).to include(
        ai_audit_events_streaming_enabled: 'false',
        duo_agent_platform_enabled: 'true',
        duo_cli_enabled: 'true',
        expose_duo_agent_platform_service_url: 'true',
        are_experiment_settings_allowed: 'true',
        are_prompt_cache_settings_allowed: 'true',
        beta_self_hosted_models_enabled: 'true',
        can_manage_self_hosted_models: 'true',
        duo_instance_model_selection_path: '/admin/gitlab_duo/model_selection',
        can_configure_ai_logging: 'true',
        can_manage_aigw_timeout: 'true',
        disabled_direct_connection_method: 'true',
        duo_availability: 'default_off',
        duo_remote_flows_availability: 'true',
        duo_foundational_flows_availability: 'false',
        duo_workflows_default_image_registry: '',
        duo_chat_expiration_column: 'last_updated_at',
        duo_chat_expiration_days: '30',
        duo_core_features_enabled: 'true',
        duo_pro_visible: 'true',
        enabled_expanded_logging: 'true',
        experiment_features_enabled: 'true',
        on_general_settings_page: 'false',
        prompt_cache_enabled: 'true',
        redirect_path: '/admin/gitlab_duo',
        toggle_beta_models_path: '/admin/ai/duo_self_hosted/toggle_beta_models',
        foundational_agents_default_enabled: 'true',
        show_foundational_agents_availability: 'true',
        show_foundational_agents_per_agent_availability: 'true',
        show_duo_agent_platform_enablement_setting: 'true',
        namespace_access_rules: Gitlab::Json.dump(transformed_namespace_access_rules),
        new_group_path: '/groups/new',
        ai_minimum_access_level_to_execute: '',
        ai_minimum_access_level_to_execute_async: Gitlab::Access::DEVELOPER.to_s,
        include_recommended_allowed: 'false',
        allow_all_unix_sockets: 'false',
        allow_project_extension: 'true',
        enforce_on_local_clients: 'false',
        duo_template_project: '',
        show_duo_template_project: 'true'
      )
    end

    context 'with foundational_agents_default_enabled false' do
      before do
        allow(ai_settings).to receive_messages(foundational_agents_default_enabled: false)
      end

      it { expect(settings).to include(foundational_agents_default_enabled: 'false') }
    end

    context 'without active Duo add-on' do
      let(:active_duo_add_ons_exist?) { false }

      it { expect(settings).to include(are_experiment_settings_allowed: 'false') }
      it { expect(settings).to include(duo_pro_visible: 'false') }
    end

    context 'with beta self-hosted models enabled' do
      let(:beta_self_hosted_models_enabled) { 'false' }

      it { expect(settings).to include(beta_self_hosted_models_enabled: 'false') }
    end

    context 'when user cannot manage self-hosted models' do
      before do
        allow(Ability).to receive(:allowed?).with(current_user, :manage_self_hosted_models_settings).and_return(false)
        allow(Ability).to receive(:allowed?).with(current_user, :update_ai_gateway_timeout).and_return(false)
      end

      it { expect(settings).to include(can_manage_self_hosted_models: 'false') }
      it { expect(settings).to include(can_manage_aigw_timeout: 'false') }
    end

    context 'when user cannot manage self-hosted models but can update AIGW timeout' do
      before do
        allow(Ability).to receive(:allowed?).with(current_user, :manage_self_hosted_models_settings).and_return(false)
        allow(Ability).to receive(:allowed?).with(current_user, :update_ai_gateway_timeout).and_return(true)
      end

      it { expect(settings).to include(can_manage_self_hosted_models: 'false') }
      it { expect(settings).to include(can_manage_aigw_timeout: 'true') }
    end

    describe 'show_gitlab_managed_model_alert' do
      let(:self_hosted) { false }
      let(:online_license) { true }

      before do
        allow(Ai::Setting).to receive(:self_hosted?).and_return(self_hosted)

        current_license = License.current
        allow(License).to receive(:current).and_return(current_license)
        allow(current_license).to receive(:online_cloud_license?).and_return(online_license)
      end

      context 'when eligible and no self-hosted model exists' do
        it { expect(settings).to include(show_gitlab_managed_model_alert: 'true') }
      end

      context 'when the license is not an online cloud license' do
        let(:online_license) { false }

        it { expect(settings).to include(show_gitlab_managed_model_alert: 'false') }
      end

      context 'when there is no license' do
        before do
          allow(License).to receive(:current).and_return(nil)
        end

        it { expect(settings).to include(show_gitlab_managed_model_alert: 'false') }
      end

      context 'when a self-hosted model exists' do
        let(:self_hosted) { true }

        it { expect(settings).to include(show_gitlab_managed_model_alert: 'false') }
      end

      context 'when user cannot manage self-hosted models' do
        before do
          allow(Ability).to receive(:allowed?)
            .with(current_user, :manage_self_hosted_models_settings).and_return(false)
        end

        it { expect(settings).to include(show_gitlab_managed_model_alert: 'false') }
      end
    end

    context 'when user cannot update DAP self-hosted models' do
      before do
        allow(Ability).to receive(:allowed?).with(current_user, :update_dap_self_hosted_model).and_return(false)
      end

      it { expect(settings).to include(expose_duo_agent_platform_service_url: 'false') }
    end

    context 'with enabled direct code suggestions' do
      let(:application_setting_attributes) { super().merge(disabled_direct_code_suggestions?: false) }

      it { expect(settings).to include(disabled_direct_connection_method: 'false') }
    end

    context 'with other Duo availability' do
      let(:application_setting_attributes) { super().merge(duo_availability: 'always_off') }

      it { expect(settings).to include(duo_availability: 'always_off') }
    end

    context 'with other Duo chat expiration column' do
      let(:application_setting_attributes) { super().merge(duo_chat_expiration_column: 'last_created_at') }

      it { expect(settings).to include(duo_chat_expiration_column: 'last_created_at') }
    end

    context 'with other Duo chat expiration days' do
      let(:application_setting_attributes) { super().merge(duo_chat_expiration_days: '10') }

      it { expect(settings).to include(duo_chat_expiration_days: '10') }
    end

    context 'without Duo Core features disabled' do
      before do
        allow(ai_settings).to receive_messages(duo_core_features_enabled?: false)
      end

      it { expect(settings).to include(duo_core_features_enabled: 'false') }
    end

    context 'with AI audit event streaming enabled' do
      before do
        allow(ai_settings).to receive_messages(ai_audit_events_streaming_enabled: true)
      end

      it { expect(settings).to include(ai_audit_events_streaming_enabled: 'true') }
    end

    context 'when on SaaS' do
      before do
        allow(Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(true)
      end

      it { expect(settings).to include(can_configure_ai_logging: 'false') }
      it { expect(settings).not_to have_key(:duo_template_project) }
      it { expect(settings).to include(show_duo_template_project: 'false') }
    end

    context 'with a duo_template_project set' do
      let(:template_project) { build_stubbed(:project, name: 'Template') }
      let(:application_setting_attributes) { super().merge(duo_template_project: template_project) }

      it 'returns the serialized project as JSON' do
        result = Gitlab::Json.safe_parse(settings[:duo_template_project])

        expect(result).to include(
          'id' => template_project.id,
          'name' => template_project.name,
          'full_path' => template_project.full_path
        )
      end
    end

    context 'when on GitLab Dedicated' do
      let(:application_setting_attributes) { super().merge(gitlab_dedicated_instance?: true) }

      it { expect(settings).to include(can_configure_ai_logging: 'false') }
    end

    context 'when AI features are not available' do
      before do
        allow(License).to receive(:ai_features_available?).and_return(false)
      end

      it { expect(settings).to include(can_configure_ai_logging: 'false') }
    end

    context 'without expanded logging' do
      let(:application_setting_attributes) { super().merge(enabled_expanded_logging: false) }

      it { expect(settings).to include(enabled_expanded_logging: 'false') }
    end

    context 'without experiment features enabled' do
      let(:application_setting_attributes) { super().merge(instance_level_ai_beta_features_enabled: false) }

      it { expect(settings).to include(experiment_features_enabled: 'false') }
    end

    context 'without prompt cache' do
      let(:application_setting_attributes) { super().merge(model_prompt_cache_enabled?: false) }

      it { expect(settings).to include(prompt_cache_enabled: 'false') }
    end

    context 'with different AI minimum access levels' do
      before do
        allow(ai_settings).to receive_messages(
          ai_minimum_access_level_execute_with_fallback: Gitlab::Access::MAINTAINER,
          ai_minimum_access_level_execute_async_with_fallback: Gitlab::Access::OWNER
        )
      end

      it { expect(settings).to include(ai_minimum_access_level_to_execute: Gitlab::Access::MAINTAINER.to_s) }
      it { expect(settings).to include(ai_minimum_access_level_to_execute_async: Gitlab::Access::OWNER.to_s) }
    end

    context 'with duo_workflows_default_image_registry set' do
      let(:application_setting_attributes) do
        super().merge(duo_workflows_default_image_registry: 'registry.example.com')
      end

      it { expect(settings).to include(duo_workflows_default_image_registry: 'registry.example.com') }
    end

    describe 'foundational_agent_statuses' do
      include_context 'with mocked Foundational Chat Agents'

      it 'returns all foundational agents except duo chat with default enabled status' do
        statuses = Gitlab::Json.safe_parse(settings.fetch(:foundational_agents_statuses))

        expect(statuses).to match_array([
          { "description" => "First agent", "enabled" => nil, "name" => "Agent 1", "reference" => "agent_1" },
          { "description" => "Second agent", "enabled" => nil, "name" => "Agent 2", "reference" => "agent_2" }
        ])
      end

      context 'when an ultimate_only agent is present' do
        let(:ultimate_only_agent) do
          { id: 99, reference: 'ultimate_agent', version: 'v1', name: 'Ultimate Agent',
            description: 'Ultimate only', ultimate_only: true }
        end

        let(:mocked_foundational_chat_agents) do
          [foundational_duo_chat_agent, foundational_chat_agent_1, ultimate_only_agent]
        end

        context 'when the instance does not have an Ultimate license (e.g. credits-only)' do
          before do
            stub_licensed_features(ai_features: false)
          end

          it 'excludes ultimate_only agents from the statuses' do
            statuses = Gitlab::Json.safe_parse(settings.fetch(:foundational_agents_statuses))
            references = statuses.pluck("reference")

            expect(references).to include('agent_1')
            expect(references).not_to include('ultimate_agent')
          end
        end

        context 'when the instance has only a Premium license' do
          before do
            stub_licensed_features(ai_catalog: true, ai_features: false)
          end

          it 'excludes ultimate_only agents from the statuses' do
            statuses = Gitlab::Json.safe_parse(settings.fetch(:foundational_agents_statuses))
            references = statuses.pluck("reference")

            expect(references).to include('agent_1')
            expect(references).not_to include('ultimate_agent')
          end
        end

        context 'when the instance has an Ultimate license' do
          before do
            stub_licensed_features(ai_features: true)
          end

          it 'includes ultimate_only agents in the statuses' do
            statuses = Gitlab::Json.safe_parse(settings.fetch(:foundational_agents_statuses))
            references = statuses.pluck("reference")

            expect(references).to include('agent_1', 'ultimate_agent')
          end
        end
      end

      context 'with the Orbit agent' do
        let(:orbit_agent) do
          { id: 100, reference: 'orbit_agent', version: 'v1', name: 'Orbit',
            description: 'AI-powered intelligence analyst with Knowledge Graph access.' }
        end

        let(:mocked_foundational_chat_agents) do
          [foundational_duo_chat_agent, foundational_chat_agent_1, orbit_agent]
        end

        def references
          Gitlab::Json.safe_parse(settings.fetch(:foundational_agents_statuses)).pluck('reference')
        end

        context 'when the Knowledge Graph is not configured (e.g. Dedicated)' do
          before do
            allow(::Analytics::KnowledgeGraph).to receive(:enabled_for?).with(current_user).and_return(false)
          end

          context 'when the instance has an Ultimate license (ai_features)' do
            before do
              stub_licensed_features(ai_features: true)
            end

            it 'excludes the orbit_agent from the statuses' do
              expect(references).to include('agent_1')
              expect(references).not_to include('orbit_agent')
            end
          end

          context 'when the instance does not have an ai_features license' do
            before do
              stub_licensed_features(ai_features: false)
            end

            it 'excludes the orbit_agent from the statuses' do
              expect(references).to include('agent_1')
              expect(references).not_to include('orbit_agent')
            end
          end
        end

        context 'when the Knowledge Graph is enabled for the user' do
          before do
            allow(::Analytics::KnowledgeGraph).to receive(:enabled_for?).with(current_user).and_return(true)
          end

          context 'when the instance has an Ultimate license (ai_features)' do
            before do
              stub_licensed_features(ai_features: true)
            end

            it 'includes the orbit_agent in the statuses' do
              expect(references).to include('agent_1', 'orbit_agent')
            end
          end

          context 'when the instance does not have an ai_features license' do
            before do
              stub_licensed_features(ai_features: false)
            end

            it 'includes the orbit_agent in the statuses' do
              expect(references).to include('agent_1', 'orbit_agent')
            end
          end
        end
      end
    end
  end
end
