# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Query'], feature_category: :api do
  include_context 'with FOSS query type fields'

  specify do
    expected_ee_fields = [
      :add_on_purchases,
      :artifact_registry_role_assignments,
      :ai_catalog_agent_flow_config,
      :ai_catalog_available_flows_for_project,
      :ai_catalog_built_in_tools,
      :ai_catalog_configured_items,
      :ai_catalog_item_consumer,
      :ai_catalog_item,
      :ai_catalog_item_versions,
      :ai_catalog_items,
      :ai_catalog_custom_and_foundational_items,
      :ai_catalog_mcp_server,
      :ai_catalog_mcp_servers,
      :ai_catalog_mcp_tools,
      :ai_flows_metadata,
      :ai_foundational_chat_agent,
      :ai_foundational_chat_agents,
      :ai_messages,
      :ai_conversation_threads,
      :ai_chat_available_models,
      :ai_chat_context_presets,
      :ai_chat_included_projects,
      :ai_usage_data,
      :ai_domain_settings,
      :ai_tool_rules,
      :admin_duo_availability_namespaces,
      :blob_search,
      :ci_catalog_bundled_resources,
      :ci_catalog_resources,
      :ci_catalog_resource,
      :ci_minutes_usage,
      :ci_minutes_project_monthly_usage,
      :ci_dedicated_hosted_runner_filters,
      :ci_dedicated_hosted_runner_usage,
      :ci_queueing_history,
      :current_license,
      :custom_dashboard,
      :custom_dashboards,
      :custom_system_dashboard,
      :devops_adoption_enabled_namespaces,
      :duo_default_namespace_candidates,
      :duo_workflow_branches,
      :duo_workflow_events,
      :duo_workflow_workflows,
      :epic_board_list,
      :geo_node,
      :instance_security_dashboard,
      :iteration,
      :license_history_entries,
      :member_role_permissions,
      :admin_member_role_permissions,
      :ml_model,
      :ml_experiment,
      :organization,
      :runner_usage_by_project,
      :runner_usage,
      :subscription_future_entries,
      :vulnerabilities,
      :vulnerabilities_count_by_day,
      :vulnerability,
      :workspace,
      :workspaces,
      :instance_external_audit_event_destinations,
      :instance_google_cloud_logging_configurations,
      :audit_events_instance_amazon_s3_configurations,
      :member_role,
      :member_roles,
      :admin_member_role,
      :admin_member_roles,
      :self_managed_add_on_eligible_users,
      :standard_role,
      :standard_roles,
      :google_cloud_artifact_registry_repository_artifact,
      :audit_events_instance_streaming_destinations,
      :self_managed_users_queued_for_role_promotion,
      :ai_self_hosted_models,
      :cloud_connector_status,
      :project_secrets_manager,
      :project_secrets,
      :project_secret,
      :project_secrets_count,
      :project_secrets_needing_rotation,
      :secret_permissions,
      :project_secrets_permissions,
      :group_secrets_manager,
      :group_secrets_permissions,
      :group_secrets,
      :group_secret,
      :group_secrets_count,
      :group_secrets_needing_rotation,
      :ai_feature_settings,
      :ai_slash_commands,
      :compliance_framework_templates,
      :compliance_requirement_controls,
      :duo_settings,
      :custom_field,
      :ldap_admin_role_links,
      :ai_model_selection_namespace_settings,
      :dependency,
      :spdx_licenses,
      :project_compliance_violation,
      :virtual_registries_container_registry,
      :virtual_registries_packages_maven_registry,
      :namespace_security_projects,
      :virtual_registries_packages_maven_upstream,
      :virtual_registries_container_upstream,
      :work_item_allowed_statuses,
      :work_item_type_icon_definitions,
      :subscription_usage,
      :trial_usage,
      :openbao_health,
      :namespace_secrets_manager_enrollment,
      :instance_secrets_manager_enrollment,
      :pipeline_execution_schedule_policy_test_run,
      :security_scan_profile,
      :security_configuration,
      :package_metadata_advisory,
      :package_metadata_advisories,
      :gitlab_credits_available,
      :gitlab_credits_unavailable_reason
    ]

    all_expected_fields = expected_foss_fields + expected_ee_fields

    expect(described_class).to have_graphql_fields(*all_expected_fields)
  end

  describe 'epicBoardList field' do
    subject { described_class.fields['epicBoardList'] }

    it 'finds an epic board list by its gid' do
      is_expected.to have_graphql_arguments(:id, :epic_filters)
      is_expected.to have_graphql_type(Types::Boards::EpicListType)
      is_expected.to have_graphql_resolver(Resolvers::Boards::EpicListResolver)
    end
  end

  describe 'aiCatalogBuiltInTools field' do
    subject(:field) { described_class.fields['aiCatalogBuiltInTools'] }

    it 'has custom max_page_size' do
      expect(field.max_page_size).to eq(1000)
    end
  end

  describe '.authorization_scopes' do
    it 'includes :ai_workflows' do
      expect(described_class.authorization_scopes).to include(:ai_workflows)
    end
  end

  describe 'field scopes' do
    {
      'vulnerabilities' => %i[api read_api ai_workflows],
      'vulnerability' => %i[api read_api ai_workflows]
    }.each do |field, scopes|
      it "includes the correct scopes for #{field}" do
        expect(described_class.fields[field].instance_variable_get(:@scopes)).to include(*scopes)
      end
    end
  end

  describe 'virtualRegistriesContainerRegistry field' do
    subject { described_class.fields['virtualRegistriesContainerRegistry'] }

    it 'finds a container virtual registry by its gid' do
      is_expected.to have_graphql_arguments(:id)
      is_expected.to have_graphql_type(::Types::VirtualRegistries::Container::RegistryDetailsType)
    end
  end

  describe 'virtualRegistriesPackagesMavenRegistry field' do
    subject { described_class.fields['virtualRegistriesPackagesMavenRegistry'] }

    it 'finds a maven virtual registry by its gid' do
      is_expected.to have_graphql_arguments(:id)
      is_expected.to have_graphql_type(::Types::VirtualRegistries::Packages::Maven::RegistryDetailsType)
    end
  end

  describe 'virtualRegistriesPackagesMavenUpstream field' do
    subject { described_class.fields['virtualRegistriesPackagesMavenUpstream'] }

    it 'finds a maven upstream registry by its gid' do
      is_expected.to have_graphql_arguments(:id)
      is_expected.to have_graphql_type(::Types::VirtualRegistries::Packages::Maven::UpstreamDetailsType)
    end
  end

  describe 'virtualRegistriesContainerUpstream field' do
    subject { described_class.fields['virtualRegistriesContainerUpstream'] }

    it 'finds a container upstream by its gid' do
      is_expected.to have_graphql_arguments(:id)
      is_expected.to have_graphql_type(::Types::VirtualRegistries::Container::UpstreamDetailsType)
    end
  end
end
