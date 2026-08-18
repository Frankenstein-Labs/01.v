# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Projects::SuperSidebarPanel, feature_category: :navigation do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, :small_repo, group: group) }

  # required by the Google Artifact Registry items
  let_it_be(:artifact_registry_integration) do
    create(:google_cloud_platform_artifact_registry_integration, project: project)
  end

  # required by the Google Artifact Registry items
  let_it_be(:wlif_integration) do
    create(:google_cloud_platform_workload_identity_federation_integration, project: project)
  end

  # required by the Harbor Registry item
  let_it_be(:harbor_integration) { create(:harbor_integration, project: project) }
  let(:context) do
    Sidebars::Projects::Context.new(
      current_user: user,
      container: project,
      current_ref: project.repository.root_ref,
      is_super_sidebar: true,
      # Turn features on that impact the list of items rendered
      can_view_pipeline_editor: true,
      learn_gitlab_enabled: true,
      show_get_started_menu: false,
      show_discover_project_security: true,
      # Turn features off that do not add/remove items
      show_cluster_hint: false,
      show_promotions: false
    )
  end

  subject(:panel) { described_class.new(context) }

  before_all do
    group.add_owner(user)
  end

  # We want to enable _all_ possible menu items for these specs
  before do
    # Give the user access to everything and enable every feature
    allow(Ability).to receive(:allowed?).and_return(true)
    # Iterations are only available in non-personal projects
    allow(project).to receive_messages(
      licensed_feature_available?: true, personal?: false, product_analytics_enabled?: true
    )
    # Needed to show Container Registry items
    allow(::Gitlab.config.registry).to receive(:enabled).and_return(true)
    # Needed to show Google Artifactory Registry items
    stub_saas_features(google_cloud_support: true)
    allow(::ServiceDesk).to receive(:supported?).and_return(true)
    project.update!(service_desk_enabled: true)
    stub_feature_flags(hide_incident_management_features: false)
    stub_feature_flags(hide_error_tracking_features: false)
    stub_feature_flags(observability_sass_features: true)
    allow(Observability::GroupO11ySetting).to receive(:observability_setting_for)
      .and_return(instance_double(Observability::GroupO11ySetting, persisted?: true))
    # Needed for Duo Agent Platform menu items
    allow(project).to receive(:duo_features_enabled).and_return(true)
  end

  describe '#renderable_menus' do
    it 'includes DuoAgentsMenu in EE' do
      menus = panel.instance_variable_get(:@menus).map(&:class)
      expect(menus).to include(Sidebars::Projects::SuperSidebarMenus::DuoAgentsMenu)
    end

    it 'positions DuoAgentsMenu after PlanMenu' do
      menus = panel.instance_variable_get(:@menus).map(&:class)
      plan_index = menus.index(Sidebars::Projects::SuperSidebarMenus::PlanMenu)
      duo_agents_index = menus.index(Sidebars::Projects::SuperSidebarMenus::DuoAgentsMenu)

      expect(plan_index).to be < duo_agents_index
    end
  end

  it_behaves_like 'a panel with uniquely identifiable menu items'
  it_behaves_like 'a panel with all menu_items categorized'
  it_behaves_like 'a panel without placeholders'
  it_behaves_like 'a panel instantiable by the anonymous user'
end
