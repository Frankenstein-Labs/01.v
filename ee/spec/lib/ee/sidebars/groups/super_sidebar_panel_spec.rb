# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Groups::SuperSidebarPanel, feature_category: :navigation do
  let(:user) { build_stubbed(:user) }
  let(:group) { build(:group, owners: user) }

  let(:context) do
    Sidebars::Groups::Context.new(
      current_user: user,
      container: group,
      is_super_sidebar: true,
      # Turn features off that do not add/remove menu items
      show_promotions: false,
      show_discover_group_security: false
    )
  end

  subject(:panel) { described_class.new(context) }

  # We want to enable _all_ possible menu items for these specs
  before do
    # Give the user access to everything and enable every feature
    allow(Ability).to receive(:allowed?).and_return(true)
    # Needed to show Container Registry items
    allow(::Gitlab.config.registry).to receive(:enabled).and_return(true)
    # Needed to show Billing
    allow(::Gitlab::CurrentSettings).to receive(:should_check_namespace_plan?).and_return(true)
    # Needed to show LDAP Group Sync
    allow(::Gitlab::Auth::Ldap::Config).to receive(:group_sync_enabled?).and_return(true)
    # Needed for GitLab Duo menu item
    stub_licensed_features(code_suggestions: true)
    add_on = create(:gitlab_subscription_add_on)
    create(:gitlab_subscription_add_on_purchase, quantity: 50, namespace: group, add_on: add_on)
    # Enable licensed features, Domain Verification, Secure settings, and Duo Agent Platform
    allow(group).to receive_messages(licensed_feature_available?: true, domain_verification_available?: true,
      duo_features_enabled: true, secure_settings_available?: true, policy_store_experiment_active?: true)
    # Needed for Roles and permissions
    stub_saas_features(gitlab_com_subscriptions: true)
    # Needed for virtual registry
    stub_config(dependency_proxy: { enabled: true })
    # Needed for Contribution analytics
    stub_feature_flags(contributions_analytics_dashboard: false, hide_gitlab_credits_page: false)
  end

  describe '#renderable_menus' do
    it 'includes DuoAgentsMenu' do
      menu_classes = panel.instance_variable_get(:@menus).map(&:class)
      expect(menu_classes).to include(Sidebars::Groups::SuperSidebarMenus::DuoAgentsMenu)
    end

    it 'positions DuoAgentsMenu after PlanMenu' do
      menus = panel.instance_variable_get(:@menus).map(&:class)
      plan_index = menus.index(Sidebars::Groups::SuperSidebarMenus::PlanMenu)
      duo_agents_index = menus.index(Sidebars::Groups::SuperSidebarMenus::DuoAgentsMenu)

      expect(plan_index).to be < duo_agents_index
    end

    context 'when group is subgroup' do
      let(:group) { build(:group, :nested) }

      it 'does not include DuoAgentsMenu' do
        menu_classes = panel.instance_variable_get(:@menus).map(&:class)
        expect(menu_classes).not_to include(Sidebars::Groups::SuperSidebarMenus::DuoAgentsMenu)
      end
    end
  end

  it_behaves_like 'a panel with uniquely identifiable menu items'
  it_behaves_like 'a panel with all menu_items categorized'
  it_behaves_like 'a panel without placeholders'
  it_behaves_like 'a panel instantiable by the anonymous user'
end
