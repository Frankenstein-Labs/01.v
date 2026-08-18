# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Groups::SettingsHelper, feature_category: :groups_and_projects do
  include I18nHelper

  include_context 'with mocked Foundational Chat Agents'

  let(:namespace_settings) do
    build(:namespace_settings, unique_project_download_limit: 1,
      unique_project_download_limit_interval_in_seconds: 2,
      unique_project_download_limit_allowlist: %w[username1 username2],
      unique_project_download_limit_alertlist: [3, 4],
      auto_ban_user_on_excessive_projects_download: true)
  end

  let(:ai_settings) do
    build(:namespace_ai_settings, duo_workflow_mcp_enabled: true)
  end

  let(:foundational_agents_status_records) do
    [build(:namespace_foundational_agent_statuses, reference: foundational_chat_agent_1_ref)]
  end

  let(:group) do
    build(
      :group,
      namespace_settings: namespace_settings,
      ai_settings: ai_settings, id: 7,
      foundational_agents_status_records: foundational_agents_status_records
    )
  end

  let(:subgroup1) { build_stubbed(:group, parent: group) }
  let(:subgroup2) { build_stubbed(:group, parent: group) }

  let(:current_user) { build(:user) }

  before do
    helper.instance_variable_set(:@group, group)
    allow(helper).to receive(:current_user).and_return(current_user)
    allow(helper).to receive(:instance_variable_get).with(:@current_user).and_return(current_user)
    allow(::GitlabSubscriptions::AddOnPurchase)
      .to receive_message_chain(:for_self_managed, :for_duo_pro_or_duo_enterprise, :active, :first)
  end

  describe '.unique_project_download_limit_settings_data', feature_category: :insider_threat do
    subject { helper.unique_project_download_limit_settings_data }

    it 'returns the expected data' do
      is_expected.to eq({ group_full_path: group.full_path,
                          max_number_of_repository_downloads: 1,
                          max_number_of_repository_downloads_within_time_period: 2,
                          git_rate_limit_users_allowlist: %w[username1 username2],
                          git_rate_limit_users_alertlist: [3, 4],
                          auto_ban_user_on_excessive_projects_download: 'true' })
    end
  end

  describe '#foundational_agents_data' do
    subject(:statuses) do
      Gitlab::Json.safe_parse(helper.send(:foundational_agents_data)[:foundational_agents_statuses])
    end

    let(:mocked_foundational_chat_agents) do
      [
        foundational_duo_chat_agent,
        { id: 2, reference: 'duo_planner', version: 'v1', name: 'Planner', description: 'Planner agent' },
        { id: 3, reference: 'security_analyst_agent', version: 'v1', name: 'Security Analyst',
          description: 'Security agent', ultimate_only: true }
      ]
    end

    before do
      allow(group).to receive_messages(
        root?: true,
        foundational_agents_statuses: [
          { reference: 'duo_planner', name: 'Planner', enabled: nil },
          { reference: 'security_analyst_agent', name: 'Security Analyst', enabled: nil }
        ]
      )
    end

    context 'when group has ai_features license (Ultimate)' do
      before do
        allow(group).to receive(:licensed_feature_available?).with(:ai_features).and_return(true)
      end

      it 'includes ultimate-only agents' do
        references = statuses.pluck('reference')

        expect(references).to include('security_analyst_agent')
        expect(references).to include('duo_planner')
      end
    end

    context 'when group does not have ai_features license (Free/Premium)' do
      before do
        allow(group).to receive(:licensed_feature_available?).with(:ai_features).and_return(false)
      end

      it 'excludes ultimate-only agents' do
        references = statuses.pluck('reference')

        expect(references).not_to include('security_analyst_agent')
      end

      it 'includes non-ultimate agents' do
        references = statuses.pluck('reference')

        expect(references).to include('duo_planner')
      end
    end

    context 'with the Orbit agent' do
      before do
        allow(group).to receive(:licensed_feature_available?).with(:ai_features).and_return(true)
        allow(group).to receive_messages(
          root?: true,
          foundational_agents_statuses: [
            { reference: 'duo_planner', name: 'Planner', enabled: nil },
            { reference: 'orbit_agent', name: 'Orbit', enabled: nil }
          ]
        )
      end

      context 'when the Knowledge Graph is not enabled for the user' do
        before do
          allow(::Analytics::KnowledgeGraph).to receive(:enabled_for?).with(current_user).and_return(false)
        end

        it 'excludes the orbit_agent' do
          references = statuses.pluck('reference')

          expect(references).to include('duo_planner')
          expect(references).not_to include('orbit_agent')
        end
      end

      context 'when the Knowledge Graph is enabled for the user' do
        before do
          allow(::Analytics::KnowledgeGraph).to receive(:enabled_for?).with(current_user).and_return(true)
        end

        it 'includes the orbit_agent' do
          references = statuses.pluck('reference')

          expect(references).to include('duo_planner', 'orbit_agent')
        end
      end
    end
  end

  describe '#available_foundational_flows_json' do
    let(:root) { true }
    let(:saas) { true }
    let(:ai_features) { true }
    let(:ai_beta) { true }
    let(:flows) { Gitlab::Json.safe_parse(helper.send(:available_foundational_flows_json)) }

    subject(:references) { flows.pluck('reference') }

    before do
      stub_saas_features(gitlab_com_subscriptions: saas)

      allow(group).to receive(:root?).and_return(root)
      allow(group).to receive(:licensed_feature_available?).with(:ai_features).and_return(ai_features)

      stub_application_setting(instance_level_ai_beta_features_enabled: ai_beta)
      allow(namespace_settings).to receive(:experiment_features_enabled).and_return(ai_beta)
    end

    context 'when group is not root' do
      let(:root) { false }

      it { is_expected.to be_empty }
    end

    context 'when group is root' do
      context 'and has ai_features license (Ultimate)' do
        it 'includes ultimate-only flows' do
          expect(references).to include('resolve_sast_vulnerability/v1')
        end
      end

      context 'and does not have ai_features license (Free/Premium)' do
        let(:ai_features) { false }

        it 'excludes ultimate-only flows' do
          expect(references).not_to include('resolve_sast_vulnerability/v1')
          expect(references).not_to include('sast_fp_detection/v1')
          expect(references).not_to include('secrets_fp_detection/v1')
        end

        it 'includes non-ultimate flows' do
          expect(references).to include('code_review/v1')
          expect(references).to include('developer/v1')
        end
      end

      context 'on SaaS with experiment features enabled' do
        it 'includes beta flows' do
          expect(references).to include('recommend_reviewers/v1')
        end
      end

      context 'on SaaS without experiment features' do
        let(:ai_beta) { false }

        it 'excludes beta flows' do
          expect(references).not_to include('recommend_reviewers/v1')
        end
      end

      context 'on self-managed with instance beta features enabled' do
        let(:saas) { false }

        it 'includes beta flows' do
          expect(references).to include('recommend_reviewers/v1')
        end
      end

      context 'on self-managed without instance beta features' do
        let(:saas) { false }
        let(:ai_beta) { false }

        it 'excludes beta flows' do
          expect(references).not_to include('recommend_reviewers/v1')
        end
      end
    end
  end

  describe '#group_ai_general_settings_helper_data' do
    subject(:group_ai_general_settings_helper_data) { helper.group_ai_general_settings_helper_data }

    before do
      allow(helper).to receive(:group_ai_settings_helper_data).and_return({ base_data: 'data' })
    end

    it 'returns the expected data' do
      expect(group_ai_general_settings_helper_data).to include(
        on_general_settings_page: 'true',
        redirect_path: edit_group_path(group),
        base_data: 'data'
      )
    end
  end

  describe '#group_ai_configuration_settings_helper_data' do
    subject(:group_ai_configuration_settings_helper_data) { helper.group_ai_configuration_settings_helper_data }

    before do
      allow(helper).to receive(:group_ai_settings_helper_data).and_return({ base_data: 'data' })
    end

    it 'returns the expected data' do
      expect(group_ai_configuration_settings_helper_data).to include(
        on_general_settings_page: 'false',
        redirect_path: group_settings_gitlab_duo_path(group),
        base_data: 'data'
      )
    end
  end

  describe 'group_ai_settings_helper_data' do
    subject(:settings) { helper.group_ai_settings_helper_data }

    let(:add_on_purchase) { nil }
    let(:root_ancestor) { group }
    let(:test_workflows) do
      [
        {
          foundational_flow_reference: 'test_flow/v1',
          display_name: s_('FoundationalFlow|Test Flow'),
          description: s_('FoundationalFlow|Test Description'),
          feature_maturity: 'ga'
        },
        {
          foundational_flow_reference: 'beta_flow/v1',
          display_name: s_('FoundationalFlow|Beta Flow'),
          description: s_('FoundationalFlow|Beta Flow Description'),
          feature_maturity: 'beta'
        }
      ]
    end

    let(:test_description_html) { helper.markdown('Test Description', project: nil) }
    let(:beta_description_html) { helper.markdown('Beta Flow Description', project: nil) }

    let(:subgroup1) { build_stubbed(:group, parent: group) }
    let(:subgroup2) { build_stubbed(:group, parent: group) }

    let(:namespace_access_rules_mock) do
      {
        subgroup1.id => [
          build_stubbed(
            :ai_namespace_feature_access_rules,
            through_namespace: subgroup1,
            root_namespace: group,
            accessible_entity: 'duo_classic'
          ),
          build_stubbed(
            :ai_namespace_feature_access_rules,
            through_namespace: subgroup1,
            root_namespace: group,
            accessible_entity: 'duo_agent_platform'
          )
        ],
        subgroup2.id => [
          build_stubbed(
            :ai_namespace_feature_access_rules,
            through_namespace: subgroup2,
            root_namespace: group,
            accessible_entity: 'duo_classic'
          )
        ]
      }
    end

    let(:namespace_access_rules_result) do
      [
        {
          through_namespace: {
            id: subgroup1.id,
            name: subgroup1.name,
            full_path: subgroup1.full_path
          },
          features: %w[duo_classic duo_agent_platform]
        }, {
          through_namespace: {
            id: subgroup2.id,
            name: subgroup2.name,
            full_path: subgroup2.full_path
          },
          features: %w[duo_classic]
        }
      ]
    end

    before do
      allow(current_user).to receive(:can?).with(:admin_duo_workflow, group).and_return(true)
      stub_saas_features(gitlab_com_subscriptions: true)
      stub_licensed_features(ai_features: true, ai_catalog: true)

      allow(Ai::NamespaceFeatureAccessRule).to receive(:by_root_namespace_group_by_through_namespace)
        .and_return namespace_access_rules_mock

      allow(::Ai::Catalog::FoundationalFlow).to receive(:fixed_items).and_return(test_workflows)

      allow(group.root_ancestor).to receive(:has_active_add_on_purchase?).with([:duo_enterprise]).and_return(false)
      allow(group.root_ancestor).to receive(:consented_to?).with(:code_review_flow_dap_routing).and_return(false)

      # Clear the internal cache to avoid different behavior when using finder methods.
      ::Ai::Catalog::FoundationalFlow.send(:storage).clear

      if ::Ai::Catalog::FoundationalFlow.instance_variable_defined?(:@raw_items)
        ::Ai::Catalog::FoundationalFlow.remove_instance_variable(:@raw_items)
      end
    end

    after do
      # Clear the internal cache to make sure mocked definitions don't leak to other tests.
      ::Ai::Catalog::FoundationalFlow.send(:storage).clear

      if ::Ai::Catalog::FoundationalFlow.instance_variable_defined?(:@raw_items)
        ::Ai::Catalog::FoundationalFlow.remove_instance_variable(:@raw_items)
      end
    end

    it 'returns the expected data' do
      is_expected.to eq(
        {
          duo_availability_cascading_settings: "{\"locked_by_application_setting\":false,\"locked_by_ancestor\":false}",
          duo_availability: group.namespace_settings.duo_availability.to_s,
          duo_remote_flows_cascading_settings: "{\"locked_by_application_setting\":false,\"locked_by_ancestor\":false}",
          duo_remote_flows_availability: group.namespace_settings.duo_remote_flows_availability.to_s,
          duo_foundational_flows_cascading_settings:
            "{\"locked_by_application_setting\":false,\"locked_by_ancestor\":false}",
          duo_foundational_flows_availability: group.namespace_settings.duo_foundational_flows_availability.to_s,
          duo_custom_agents_cascading_settings:
            "{\"locked_by_application_setting\":false,\"locked_by_ancestor\":false}",
          duo_custom_agents_availability: group.namespace_settings.duo_custom_agents_availability.to_s,
          duo_custom_flows_cascading_settings:
            "{\"locked_by_application_setting\":false,\"locked_by_ancestor\":false}",
          duo_custom_flows_availability: group.namespace_settings.duo_custom_flows_availability.to_s,
          duo_external_agents_cascading_settings:
            "{\"locked_by_application_setting\":false,\"locked_by_ancestor\":false}",
          duo_external_agents_availability: group.namespace_settings.duo_external_agents_availability.to_s,
          tool_approval_for_session_cascading_settings:
            "{\"locked_by_application_setting\":false,\"locked_by_ancestor\":false}",
          tool_approval_for_session_availability: group.namespace_settings.tool_approval_for_session_availability.to_s,
          ai_audit_events_storage_cascading_settings:
            "{\"locked_by_application_setting\":false,\"locked_by_ancestor\":false}",
          duo_core_features_enabled: group.namespace_settings.duo_core_features_enabled.to_s,
          prompt_injection_protection_available: "true",
          prompt_injection_protection_level: "log_only",
          are_duo_settings_locked: group.namespace_settings.duo_features_enabled_locked?.to_s,
          duo_availability_admin_locked: group.namespace_settings.admin_locked_duo_features_enabled?.to_s,
          experiment_features_enabled: group.namespace_settings.experiment_features_enabled.to_s,
          prompt_cache_enabled: group.namespace_settings.model_prompt_cache_enabled.to_s,
          are_experiment_settings_allowed: (group.experiment_settings_allowed? && gitlab_com_subscription?).to_s,
          are_prompt_cache_settings_allowed: (group.prompt_cache_settings_allowed? && gitlab_com_subscription?).to_s,
          update_id: group.id,
          root_namespace_id: group.root_ancestor.id,
          group_full_path: group.full_path,
          duo_workflow_available: "true",
          duo_workflow_mcp_available: "true",
          duo_agent_platform_enabled: "true",
          duo_workflow_mcp_enabled: "true",
          ai_usage_data_collection_available: "true",
          ai_usage_data_collection_enabled: "false",
          ai_catalog_restricted_to_group_hierarchy: "false",
          ai_catalog_restricted_to_group_hierarchy_available: "true",
          ai_audit_events_storage_enabled: "false",
          allow_all_unix_sockets: "false",
          allow_project_extension: "true",
          include_recommended_allowed: "false",
          enforce_on_local_clients: "false",
          foundational_agents_default_enabled: "true",
          foundational_agents_statuses: Gitlab::Json.generate([
            { reference: 'agent_1', name: 'Agent 1', description: 'First agent', enabled: true },
            { reference: 'agent_2', name: 'Agent 2', description: 'Second agent', enabled: nil }
          ]),
          show_foundational_agents_availability: "true",
          show_foundational_agents_per_agent_availability: "true",
          show_duo_agent_platform_enablement_setting: "true",
          is_saas: 'true',
          ai_minimum_access_level_to_execute: nil,
          ai_minimum_access_level_to_execute_async: Gitlab::Access::DEVELOPER,
          ai_settings_minimum_access_level_manage: nil,
          ai_settings_minimum_access_level_enable_on_projects: nil,
          available_foundational_flows: Gitlab::Json.generate([{
            name: 'Test Flow',
            description: 'Test Description',
            descriptionHtml: test_description_html,
            reference: 'test_flow/v1'
          }]),
          selected_foundational_flow_references: '[]',
          duo_template_project: nil,
          show_duo_template_project: 'true',
          duo_enterprise_active: 'false',
          code_review_flow_consent_given: 'false',
          namespace_access_rules: Gitlab::Json.dump(namespace_access_rules_result),
          new_group_path: "/groups/new?parent_id=#{group.id}#create-group-pane"
        }
      )
    end

    context 'when locale is not en' do
      let(:stubbed_translations) do
        {
          'FoundationalFlow|Test Flow' => 'Test Flow in German',
          'FoundationalFlow|Test Description' => 'Test Description in German'
        }
      end

      it 'returns foundational flows with translated names and descriptions' do
        with_stubbed_translations(:de, stubbed_translations) do
          expect(settings[:available_foundational_flows]).to eq(
            Gitlab::Json.generate([
              {
                name: 'Test Flow in German',
                description: 'Test Description in German',
                descriptionHtml: helper.markdown('Test Description in German', project: nil),
                reference: 'test_flow/v1'
              }
            ])
          )
        end
      end
    end

    context 'when SaaS group has enabled experimental/beta AI features' do
      before do
        namespace_settings.experiment_features_enabled = true
      end

      it 'also contains beta/experimental foundational flow data' do
        expect(settings[:available_foundational_flows]).to eq(
          Gitlab::Json.generate([
            {
              name: 'Test Flow',
              description: 'Test Description',
              descriptionHtml: test_description_html,
              reference: 'test_flow/v1'
            },
            {
              name: 'Beta Flow',
              description: 'Beta Flow Description',
              descriptionHtml: beta_description_html,
              reference: 'beta_flow/v1'
            }
          ])
        )
      end
    end

    context 'when not SaaS' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'only contains GA foundational flow data' do
        expect(settings[:available_foundational_flows]).to eq(
          Gitlab::Json.generate([
            {
              name: 'Test Flow',
              description: 'Test Description',
              descriptionHtml: test_description_html,
              reference: 'test_flow/v1'
            }
          ])
        )
      end

      it 'returns ai_usage_data_collection_available as false' do
        expect(settings[:ai_usage_data_collection_available]).to eq('false')
      end

      context 'when instance has enabled experimental/beta AI features' do
        before do
          stub_application_setting(instance_level_ai_beta_features_enabled: true)
        end

        it 'also contains beta/experimental foundational flow data' do
          expect(settings[:available_foundational_flows]).to eq(
            Gitlab::Json.generate([
              {
                name: 'Test Flow',
                description: 'Test Description',
                descriptionHtml: test_description_html,
                reference: 'test_flow/v1'
              },
              {
                name: 'Beta Flow',
                description: 'Beta Flow Description',
                descriptionHtml: beta_description_html,
                reference: 'beta_flow/v1'
              }
            ])
          )
        end
      end
    end

    context 'without an ai_settings record' do
      let(:group) { build(:group, namespace_settings: namespace_settings, id: 7) }

      it 'returns the expected data' do
        is_expected.to include(
          is_saas: 'true',
          duo_workflow_mcp_enabled: 'false',
          ai_usage_data_collection_available: 'true',
          ai_usage_data_collection_enabled: 'false',
          ai_catalog_restricted_to_group_hierarchy: 'false',
          ai_catalog_restricted_to_group_hierarchy_available: 'true',
          foundational_agents_default_enabled: 'true',
          duo_agent_platform_enabled: 'true',
          ai_minimum_access_level_to_execute: nil,
          ai_minimum_access_level_to_execute_async: Gitlab::Access::DEVELOPER,
          ai_settings_minimum_access_level_manage: nil,
          ai_settings_minimum_access_level_enable_on_projects: nil,
          allow_all_unix_sockets: "false",
          allow_project_extension: "true",
          include_recommended_allowed: "false",
          enforce_on_local_clients: "false"
        )
      end
    end

    context 'when ai_catalog_restricted_to_group_hierarchy is true' do
      let(:ai_settings) do
        build(:namespace_ai_settings, ai_catalog_restricted_to_group_hierarchy: true)
      end

      it 'returns ai_catalog_restricted_to_group_hierarchy as "true"' do
        is_expected.to include(ai_catalog_restricted_to_group_hierarchy: 'true')
      end
    end

    context 'when the group is a subgroup' do
      before do
        allow(group).to receive(:root?).and_return(false)
      end

      it 'returns ai_catalog_restricted_to_group_hierarchy_available as "false"' do
        is_expected.to include(ai_catalog_restricted_to_group_hierarchy_available: 'false')
      end
    end

    context 'when ai_settings minimum access levels have been set' do
      let(:ai_settings) do
        build(:namespace_ai_settings,
          minimum_access_level_execute: ::Gitlab::Access::DEVELOPER,
          minimum_access_level_execute_async: ::Gitlab::Access::GUEST,
          minimum_access_level_manage: ::Gitlab::Access::MAINTAINER,
          minimum_access_level_enable_on_projects: ::Gitlab::Access::OWNER)
      end

      it 'returns the expected data' do
        is_expected.to include(
          ai_minimum_access_level_to_execute: Gitlab::Access::DEVELOPER,
          ai_minimum_access_level_to_execute_async: Gitlab::Access::GUEST,
          ai_settings_minimum_access_level_manage: Gitlab::Access::MAINTAINER,
          ai_settings_minimum_access_level_enable_on_projects: Gitlab::Access::OWNER
        )
      end
    end

    context 'when group is on free tier (no ai_catalog license)' do
      before do
        stub_licensed_features(ai_catalog: false)
      end

      it 'returns duo_workflow_mcp_available as false' do
        is_expected.to include(
          duo_workflow_available: "true",
          duo_workflow_mcp_available: "false"
        )
      end
    end

    context 'with a group that is not a root namespace' do
      before do
        allow(group).to receive(:root?).and_return(false)
        group.ai_settings = build(:namespace_ai_settings, duo_workflow_mcp_enabled: false)
      end

      it 'returns the expected data' do
        is_expected.to include(
          {
            duo_workflow_available: "false",
            duo_workflow_mcp_available: "false",
            duo_workflow_mcp_enabled: "false",
            ai_usage_data_collection_available: "false",
            available_foundational_flows: '[]',
            selected_foundational_flow_references: '[]',
            duo_template_project: nil,
            show_duo_template_project: 'false'
          }
        )
      end
    end

    describe 'show_foundational_agents_availability' do
      context 'when group is not root' do
        before do
          allow(group).to receive(:root?).and_return(false)
        end

        it 'is false' do
          is_expected.to include({ show_foundational_agents_availability: "false" })
        end
      end

      context 'when group is not saas' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it 'is false' do
          is_expected.to include({ show_foundational_agents_availability: "false" })
        end
      end
    end

    describe "show_foudnational-agents_per_agent_availability" do
      context 'when group is not root' do
        before do
          allow(group).to receive(:root?).and_return(false)
        end

        it 'is false' do
          is_expected.to include({ show_foundational_agents_per_agent_availability: "false" })
        end
      end

      context 'when group is not saas' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it 'is false' do
          is_expected.to include({ show_foundational_agents_per_agent_availability: "false" })
        end
      end
    end

    describe 'show_duo_agent_platform_enablement_setting' do
      context 'when group is not root' do
        before do
          allow(group).to receive(:root?).and_return(false)
        end

        it 'is false' do
          is_expected.to include({ show_duo_agent_platform_enablement_setting: "false" })
        end
      end

      context 'when group is not saas' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it 'is false' do
          is_expected.to include({ show_duo_agent_platform_enablement_setting: "false" })
        end
      end
    end

    describe 'duo_template_project' do
      context 'when group has no template project' do
        it 'is nil' do
          is_expected.to include({ duo_template_project: nil })
        end
      end

      context 'when group is not root' do
        before do
          allow(group).to receive(:root?).and_return(false)
        end

        it 'is nil' do
          is_expected.to include({ duo_template_project: nil })
        end
      end

      context 'when group has a template project set' do
        let(:template_project) { build_stubbed(:project, name: 'Template') }

        let(:namespace_template_setting) do
          build_stubbed(:namespace_template_setting, duo_template_project: template_project)
        end

        before do
          allow(group).to receive_messages(root?: true, namespace_template_setting: namespace_template_setting)
        end

        it 'returns the serialised project data as JSON' do
          result = ::Gitlab::Json.safe_parse(settings[:duo_template_project])

          expect(result).to include(
            'id' => template_project.id,
            'name' => template_project.name,
            'full_path' => template_project.full_path
          )
        end
      end
    end

    describe 'show_duo_template_project' do
      context 'when group is root with a valid id' do
        it { is_expected.to include({ show_duo_template_project: 'true' }) }
      end

      context 'when group is not root' do
        before do
          allow(group).to receive(:root?).and_return(false)
        end

        it { is_expected.to include({ show_duo_template_project: 'false' }) }
      end

      context 'when group is root but has no id' do
        before do
          allow(group).to receive(:root?).and_return(true)
          allow(group.root_ancestor).to receive(:id).and_return(nil)
        end

        it { is_expected.to include({ show_duo_template_project: 'false' }) }
      end
    end

    describe 'duo_enterprise_active' do
      using RSpec::Parameterized::TableSyntax

      where(:has_add_on, :expected) do
        true  | 'true'
        false | 'false'
      end

      with_them do
        before do
          allow(group.root_ancestor)
            .to receive(:has_active_add_on_purchase?)
            .with([:duo_enterprise])
            .and_return(has_add_on)
        end

        it { is_expected.to include(duo_enterprise_active: expected) }
      end
    end

    describe 'code_review_flow_consent_given' do
      using RSpec::Parameterized::TableSyntax

      where(:consented, :expected) do
        true  | 'true'
        false | 'false'
      end

      with_them do
        before do
          allow(group.root_ancestor)
            .to receive(:consented_to?)
            .with(:code_review_flow_dap_routing)
            .and_return(consented)
        end

        it { is_expected.to include(code_review_flow_consent_given: expected) }
      end
    end

    context 'with GitLab.com' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'return is_saas as true' do
        is_expected.to include(is_saas: 'false')
      end
    end
  end

  describe 'group_amazon_q_settings_view_model_data' do
    subject(:group_amazon_q_settings_view_model_data) { helper.group_amazon_q_settings_view_model_data }

    before do
      group.amazon_q_integration = build(:amazon_q_integration, instance: false, auto_review_enabled: true)
    end

    it 'returns the expected data' do
      is_expected.to eq(
        {
          group_id: group.id.to_s,
          init_availability: group.namespace_settings.duo_availability.to_s,
          init_auto_review_enabled: true,
          duo_availability_cascading_settings: { locked_by_application_setting: false, locked_by_ancestor: false },
          are_duo_settings_locked: group.namespace_settings.duo_features_enabled_locked?,
          duo_availability_admin_locked: group.namespace_settings.admin_locked_duo_features_enabled?
        }
      )
    end
  end

  describe 'group_amazon_q_settings_view_model_json' do
    subject(:group_amazon_q_settings_view_model_json) { helper.group_amazon_q_settings_view_model_json }

    it 'returns the expected data' do
      is_expected.to eq(
        {
          groupId: "7",
          initAvailability: "default_on",
          initAutoReviewEnabled: false,
          areDuoSettingsLocked: false,
          duoAvailabilityAdminLocked: false,
          duoAvailabilityCascadingSettings: { lockedByApplicationSetting: false, lockedByAncestor: false }
        }.to_json
      )
    end
  end

  describe 'show_group_ai_settings_general?' do
    let(:duo_settings_available?) { true }

    # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need persisted objects
    let(:root_ancestor) { create(:group) }
    let(:group) { create(:group, parent: root_ancestor) }
    # rubocop:enable RSpec/FactoryBot/AvoidCreate

    before do
      allow(GitlabSubscriptions::Duo)
        .to receive(:duo_settings_available?)
        .with(root_ancestor)
        .and_return(duo_settings_available?)
    end

    it { expect(helper).to be_show_group_ai_settings_general }

    context 'when group has no trial or add-on' do
      let(:duo_settings_available?) { false }

      it { expect(helper).not_to be_show_group_ai_settings_general }
    end
  end

  describe 'show_group_ai_settings_page?' do
    using RSpec::Parameterized::TableSyntax
    subject { helper.show_group_ai_settings_page? }

    where(:licensed_ai_features_available, :show_gitlab_duo_settings_app, :expected_result) do
      false | false | false
      false | true  | false
      true  | false | false
      true  | true  | true
    end

    with_them do
      before do
        allow(group).to receive(:licensed_ai_features_available?).and_return(licensed_ai_features_available)
        allow(helper).to receive(:show_gitlab_duo_settings_app?).with(group).and_return(show_gitlab_duo_settings_app)
      end

      it 'returns the expected result' do
        expect(helper.show_group_ai_settings_page?).to eq(expected_result)
      end
    end
  end

  describe '#show_virtual_registries_setting?' do
    it 'delegates to VirtualRegistries.any_registry_available_for_settings?' do
      allow(::VirtualRegistries).to receive(:any_registry_available_for_settings?)
        .with(group, current_user).and_return(true)

      expect(helper.show_virtual_registries_setting?(group)).to be true
    end

    it 'returns false when any_registry_available_for_settings? returns false' do
      allow(::VirtualRegistries).to receive(:any_registry_available_for_settings?)
        .with(group, current_user).and_return(false)

      expect(helper.show_virtual_registries_setting?(group)).to be false
    end
  end

  describe '#usage_billing_dashboard_data', :saas do
    let(:gitlab_com_subscriptions) { true }
    let(:plan_name_for_upgrading) { ::Plan::FREE }
    let(:plans_data) { [Hashie::Mash.new(id: 1, code: ::Plan::PREMIUM)] }

    subject { helper.usage_billing_dashboard_data(group, plans_data) }

    before do
      stub_saas_features(gitlab_com_subscriptions: gitlab_com_subscriptions)
      allow(group).to receive(:plan_name_for_upgrading).and_return(plan_name_for_upgrading)
    end

    it 'returns the expected data structure' do
      is_expected.to include(
        user_usage_path: include('__USERNAME__'),
        namespace_path: group.full_path,
        upgrade_button_path: include("gl_namespace_id=#{group.id}"),
        is_saas: 'true',
        is_free: 'true',
        is_paid_base_plan: 'false'
      )
    end

    context 'when plan is not FREE' do
      let(:plan_name_for_upgrading) { ::Plan::PREMIUM }

      it { is_expected.to include(is_free: 'false') }
    end

    context 'when group is on a paid plan' do
      let(:group) do
        build_stubbed(:group, gitlab_subscription: build_stubbed(:gitlab_subscription, plan_code: Plan::ULTIMATE))
      end

      it { is_expected.to include(is_paid_base_plan: 'true') }
    end

    context 'when group has an active gitlab_credits add-on purchase' do
      before do
        allow(group).to receive(:has_active_add_on_purchase?).with(:gitlab_credits).and_return(true)
      end

      it { is_expected.to include(is_free: 'false') }
    end

    it 'includes purchase_credits_path' do
      is_expected.to include(
        purchase_credits_path: include("gl_namespace_id=#{group.id}", 'plan_type=gitlab_credits')
      )
    end

    it { is_expected.to include(credits_generalization_ui: 'true') }

    context 'when credits_generalization_ui feature flag is disabled' do
      before do
        stub_feature_flags(credits_generalization_ui: false)
      end

      it { is_expected.to include(credits_generalization_ui: 'false') }
    end
  end

  describe '#seat_control_warning?' do
    subject { helper.seat_control_warning?(group) }

    context 'when SAML provider is enabled' do
      before do
        build_stubbed(:saml_provider, group: group)
      end

      it { is_expected.to be true }
    end

    context 'when SAML provider is not enabled' do
      it { is_expected.to be false }
    end

    context 'when bso_minimal_access_fallback feature flag is disabled' do
      before do
        stub_feature_flags(bso_minimal_access_fallback: false)
        build_stubbed(:saml_provider, group: group)
      end

      it { is_expected.to be false }
    end
  end

  describe '#seat_control_saml_scim_warning' do
    it 'returns a BSO warning message' do
      result = helper.seat_control_saml_scim_warning

      expect(result).to include(
        'With restricted access turned on and if no seats are available, new users provisioned through ' \
          'SAML/SCIM are assigned the non-billable Minimal Access role.'
      )
      expect(result).to include('user/group/saml_sso/_index.md')
      expect(result).to include('user/group/saml_sso/scim_setup.md')
    end
  end
end
