# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Groups::Menus::SecurityComplianceMenu, feature_category: :navigation do
  let_it_be(:owner) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be_with_refind(:group) do
    create(:group, :private).tap do |g|
      g.add_owner(owner)
      g.add_guest(guest)
    end
  end

  let(:user) { owner }
  let(:show_group_discover_security) { false }
  let(:context) { Sidebars::Groups::Context.new(current_user: user, container: group, show_discover_group_security: show_group_discover_security) }
  let(:menu) { described_class.new(context) }
  let(:menu_items) { menu.renderable_items.map(&:title) }

  describe '#link' do
    subject(:link) { menu.link }

    context 'when menu has menu items' do
      it 'returns first visible menu item link' do
        expect(link).to eq menu.renderable_items.first.link
      end
    end

    context 'when menu does no have any menu item' do
      let(:user) { nil }

      it 'returns show group security page' do
        expect(link).to eq "/groups/#{group.full_path}/-/security/discover"
      end
    end
  end

  describe '#title' do
    subject(:title) { menu.title }

    specify do
      is_expected.to eq 'Security and compliance'
    end

    context 'when menu does not have any menu items' do
      let(:user) { nil }

      specify do
        is_expected.to eq 'Security'
      end
    end
  end

  describe '#render?' do
    subject(:render) { menu.render? }

    it 'returns true if there are menu items' do
      is_expected.to be true
    end

    context 'when there are no menu items' do
      let(:user) { nil }

      it 'returns false if there are no menu items' do
        is_expected.to be false
      end

      context 'when show group discover security option is enabled' do
        let(:show_group_discover_security) { true }

        it { is_expected.to be true }
      end
    end
  end

  describe 'Menu Items' do
    subject(:items) { described_class.new(context).renderable_items.index { |e| e.item_id == item_id } }

    shared_examples 'menu access rights' do
      it { is_expected.not_to be_nil }

      describe 'when the user does not have access' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'Security Dashboard' do
      let(:item_id) { :security_dashboard }

      context 'when security_dashboard feature is enabled' do
        before do
          stub_licensed_features(security_dashboard: true)
        end

        it { is_expected.not_to be_nil }

        context 'when the user is authorized to read_vulnerability' do
          it 'lists Security dashboard in the menu list' do
            expect(menu_items).to include("Security dashboard")
          end
        end

        context 'when the user is not authorized to read_vulnerability' do
          let(:user) { guest }

          it 'does not list Security dashboard in the menu list' do
            expect(menu_items).not_to include("Security dashboard")
          end
        end
      end

      context 'when security_dashboard feature is not enabled' do
        it { is_expected.to be_nil }
      end
    end

    describe 'Vulnerability Report' do
      let(:item_id) { :vulnerability_report }

      context 'when security_dashboard feature is enabled' do
        before do
          stub_licensed_features(security_dashboard: true)
        end

        it { is_expected.not_to be_nil }

        context 'when the user is authorized to read_vulnerability' do
          it 'lists Vulnerability report in the menu list' do
            expect(menu_items).to include("Vulnerability report")
          end
        end

        context 'when the user is not authorized to read_vulnerability' do
          let(:user) { guest }

          it 'does not list Vulnerability report in the menu list' do
            expect(menu_items).not_to include("Vulnerability report")
          end
        end
      end

      context 'when security_dashboard feature is not enabled' do
        it { is_expected.to be_nil }
      end
    end

    describe 'Compliance center' do
      let(:item_id) { :compliance }

      context 'when group_level_compliance_dashboard feature is enabled' do
        before do
          stub_licensed_features(group_level_compliance_dashboard: true)
        end

        it_behaves_like 'menu access rights'

        context 'when user is assigned a custom role with `read_compliance_dashboard` ability' do
          let_it_be(:user) { create(:user) }

          let_it_be(:member_role) do
            create(:member_role, :guest, :read_compliance_dashboard, namespace: group)
          end

          let_it_be(:member) do
            create(:group_member, :guest, user: user, source: group, member_role: member_role)
          end

          before do
            stub_licensed_features(group_level_compliance_dashboard: true, custom_roles: true)
          end

          it_behaves_like 'menu access rights'

          context 'when custom roles feature is disabled' do
            before do
              stub_licensed_features(group_level_compliance_dashboard: true, custom_roles: false)
            end

            it { is_expected.to be_nil }
          end
        end

        context 'when user is assigned a custom role with `admin_compliance_framework` ability' do
          let_it_be(:user) { create(:user) }

          let_it_be(:member_role) do
            create(:member_role, :guest, :admin_compliance_framework, namespace: group)
          end

          let_it_be(:member) do
            create(:group_member, :guest, user: user, source: group, member_role: member_role)
          end

          before do
            stub_licensed_features(group_level_compliance_dashboard: true, custom_roles: true)
          end

          it_behaves_like 'menu access rights'

          context 'when custom roles feature is disabled' do
            before do
              stub_licensed_features(group_level_compliance_dashboard: true, custom_roles: false)
            end

            it { is_expected.to be_nil }
          end
        end
      end

      context 'when group_level_compliance_dashboard feature is not enabled' do
        it { is_expected.to be_nil }
      end
    end

    describe 'Credentials', :saas do
      let(:item_id) { :credentials }

      context 'when credentials_inventory feature is not licensed' do
        it { is_expected.to be_nil }
      end

      context 'when credentials_inventory feature is licensed' do
        before do
          stub_licensed_features(credentials_inventory: true)
        end

        it_behaves_like 'menu access rights'
      end
    end

    describe 'Security Policies' do
      let(:item_id) { :scan_policies }

      context 'when scan_policies feature is enabled' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        context 'when group security policies feature is disabled' do
          it_behaves_like 'menu access rights'
        end

        context 'when scan_policies feature is not enabled' do
          before do
            stub_licensed_features(security_orchestration_policies: false)
          end

          it { is_expected.to be_nil }
        end
      end
    end

    describe 'Policy Store' do
      let(:item_id) { :policy_store }

      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'when the security_policies_v2 feature flag is disabled' do
        before do
          stub_feature_flags(security_policies_v2: false)
          stub_application_setting(policy_store_experiment_enabled: true)
          group.namespace_settings.update!(policy_store_experiment_enabled: true)
        end

        it { is_expected.to be_nil }
      end

      context 'when the experiment is active for the group' do
        before do
          stub_application_setting(policy_store_experiment_enabled: true)
          group.namespace_settings.update!(policy_store_experiment_enabled: true)
        end

        it_behaves_like 'menu access rights'

        it 'renders the Policy store menu item' do
          item = described_class.new(context).renderable_items.find { |e| e.item_id == :policy_store }

          expect(item.title).to eq('Policy store')
        end
      end

      context 'when the experiment is disabled at the instance level' do
        before do
          stub_application_setting(policy_store_experiment_enabled: false)
          group.namespace_settings.update!(policy_store_experiment_enabled: true)
        end

        it { is_expected.to be_nil }
      end

      context 'when the experiment is disabled at the group level' do
        before do
          stub_application_setting(policy_store_experiment_enabled: true)
          group.namespace_settings.update!(policy_store_experiment_enabled: false)
        end

        it { is_expected.to be_nil }
      end
    end

    describe 'Dependency Firewall', :saas_dependency_firewall do
      let(:item_id) { :dependency_firewall }

      before do
        stub_licensed_features(dependency_firewall: true, security_orchestration_policies: true)
        group.namespace_settings.update!(dependency_firewall_enabled: true)
      end

      it_behaves_like 'menu access rights'

      context 'when the dependency_firewall_phase1 feature flag is disabled' do
        before do
          stub_feature_flags(dependency_firewall_phase1: false)
        end

        it { is_expected.to be_nil }
      end

      context 'when the dependency firewall is not licensed' do
        before do
          stub_licensed_features(dependency_firewall: false, security_orchestration_policies: true)
        end

        it { is_expected.to be_nil }
      end

      context 'when the dependency firewall is disabled for the root namespace' do
        before do
          group.namespace_settings.update!(dependency_firewall_enabled: false)
        end

        it { is_expected.to be_nil }
      end

      context 'when the user cannot read security orchestration policies' do
        let(:user) { guest }

        it { is_expected.to be_nil }
      end
    end

    describe 'Audit events' do
      let(:item_id) { :audit_events }

      context 'when audit_events feature is enabled' do
        before do
          stub_licensed_features(audit_events: true)
        end

        it_behaves_like 'menu access rights'
      end

      context 'when audit_events feature is not enabled' do
        before do
          stub_licensed_features(audit_events: false)
        end

        it { is_expected.to be_nil }
      end
    end

    describe 'Security configuration' do
      let(:item_id) { :configuration }

      context 'when security_attributes feature is available' do
        before do
          stub_licensed_features(security_attributes: true)
        end

        it { is_expected.not_to be_nil }

        context 'when user is authorized to admin_security_attributes' do
          it 'lists Security configuration in the menu list' do
            expect(menu_items).to include("Security configuration")
          end
        end

        context 'when user is not authorized to admin_security_attributes' do
          let(:user) { guest }

          it 'does not list Security configuration in the menu list' do
            expect(menu_items).not_to include("Security configuration")
          end
        end
      end

      context 'when security_attributes feature is not available' do
        before do
          stub_licensed_features(security_attributes: false)
        end

        it { is_expected.to be_nil }
      end

      context 'when security_scan_profiles feature is available' do
        before do
          stub_licensed_features(security_scan_profiles: true)
        end

        it 'shows Security configuration in the menu' do
          expect(menu_items).to include("Security configuration")
        end

        context 'when user does not have read_security_scan_profiles permission' do
          let(:user) { guest }

          it 'does not show Security configuration' do
            expect(menu_items).not_to include("Security configuration")
          end
        end
      end

      context 'when security_scan_profiles feature is not available' do
        before do
          stub_licensed_features(security_scan_profiles: false)
        end

        it { is_expected.to be_nil }
      end
    end

    describe 'Dependency List' do
      let(:item_id) { :dependency_list }

      before do
        stub_licensed_features(security_dashboard: false)
      end

      it { is_expected.to be_nil }

      context 'when `security_dashboard` & `dependency_scanning` feature is enabled' do
        before do
          stub_licensed_features(security_dashboard: true, dependency_scanning: true)
        end

        it { is_expected.not_to be_nil }
      end
    end

    describe 'Secrets manager' do
      let(:item_id) { :secrets_manager }
      let_it_be_with_reload(:secrets_manager) { build(:group_secrets_manager, group: group) }

      before_all do
        secrets_manager.activate!
      end

      before do
        # SM availability requires (FF AND enrollment); the entitlement-aware
        # policy also requires an entitled namespace. Enroll + entitle by default
        # so positive-path tests are reachable. Negative-path tests override the
        # FF, license, or enrollment as needed.
        enroll_instance_in_secrets_manager
      end

      context 'when all conditions are met' do
        before do
          stub_licensed_features(native_secrets_management: true)
        end

        it { is_expected.not_to be_nil }
      end

      context 'with the New badge' do
        let(:secrets_manager_menu_item) do
          described_class.new(context).renderable_items.find { |e| e.item_id == item_id }
        end

        it_behaves_like 'secrets manager nav item with a New badge'
      end

      context 'when not enrolled' do
        # The paid experience makes the top-level group reachable without an enrollment
        # record so the owner can enroll from the trial empty state; the legacy behavior
        # (link hidden until enrolled) still holds when that flag is off.
        before do
          stub_feature_flags(secrets_manager_paid_experience: false)
          stub_licensed_features(native_secrets_management: true)
          stub_application_setting(secrets_manager_instance_enrolled: false)
        end

        it { is_expected.to be_nil }
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(group_secrets_manager: false)
          stub_licensed_features(native_secrets_management: true)
        end

        it { is_expected.to be_nil }
      end

      context 'when native_secrets_management feature is not licensed' do
        before do
          stub_licensed_features(native_secrets_management: false)
        end

        it { is_expected.to be_nil }
      end

      context 'when user does not have read_secret permission' do
        let(:user) { guest }

        before do
          stub_licensed_features(native_secrets_management: true)
        end

        it { is_expected.to be_nil }
      end

      context 'when the paid experience is disabled' do
        # Exercises the legacy "provisioned and active" gate (the flag defaults to enabled in tests).
        before do
          stub_feature_flags(secrets_manager_paid_experience: false)
          stub_licensed_features(native_secrets_management: true)
        end

        context 'when secrets manager is not provisioned' do
          let_it_be(:group_without_sm) { create(:group).tap { |g| g.add_owner(owner) } }
          let(:context) { Sidebars::Groups::Context.new(current_user: user, container: group_without_sm) }

          it { is_expected.to be_nil }
        end

        context 'when secrets manager is not active' do
          let_it_be(:group_provisioning) { create(:group).tap { |g| g.add_owner(owner) } }
          let_it_be(:provisioning_sm) { create(:group_secrets_manager, group: group_provisioning) }
          let(:context) { Sidebars::Groups::Context.new(current_user: user, container: group_provisioning) }

          it { is_expected.to be_nil }
        end
      end

      context 'when the paid experience is enabled' do
        let(:secrets_manager_menu_item) do
          described_class.new(context).renderable_items.find { |e| e.item_id == item_id }
        end

        before do
          stub_licensed_features(native_secrets_management: true)
        end

        %i[trial_eligible trial paid offline_paid blocked].each do |state|
          context "when the entitlement state is #{state}" do
            before do
              stub_secrets_manager_entitlement(state: state)
            end

            it 'shows an enabled link' do
              expect(secrets_manager_menu_item).not_to be_nil
            end
          end
        end

        context 'when the entitlement state is ineligible' do
          before do
            stub_secrets_manager_entitlement(state: :ineligible)
          end

          it { is_expected.to be_nil }
        end

        context 'when secrets manager is not provisioned but the namespace is entitled' do
          let_it_be(:group_without_sm) { create(:group).tap { |g| g.add_owner(owner) } }
          let(:context) { Sidebars::Groups::Context.new(current_user: user, container: group_without_sm) }

          before do
            stub_secrets_manager_entitlement(state: :trial)
          end

          it 'shows an enabled link before provisioning' do
            expect(secrets_manager_menu_item).not_to be_nil
          end
        end
      end
    end
  end

  describe 'Feature Library metadata', :saas do
    let(:expected_tiers) do
      {
        security_dashboard: :ultimate,
        vulnerability_report: :ultimate,
        dependency_list: :ultimate,
        compliance: :premium,
        credentials: :ultimate,
        scan_policies: :ultimate,
        audit_events: :premium
      }
    end

    before do
      stub_licensed_features(
        security_dashboard: true,
        dependency_scanning: true,
        group_level_compliance_dashboard: true,
        credentials_inventory: true,
        security_orchestration_policies: true,
        audit_events: true
      )
    end

    subject(:serialized) { menu.renderable_items.map(&:serialize_for_super_sidebar) }

    it 'gives every item a description and a unique library_icon', :aggregate_failures do
      expect(serialized).not_to be_empty
      expect(serialized).to all(include(:description, :library_icon))
      icons = serialized.map { |item| item[:library_icon] }
      expect(icons).to match_array(icons.uniq)
    end

    it 'tags licensed items with the correct tier', :aggregate_failures do
      tiers = serialized.index_by { |item| item[:id] }.transform_values { |item| item[:tier] }

      expect(tiers).to include(expected_tiers)
    end
  end
end
