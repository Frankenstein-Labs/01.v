# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Projects::Menus::SecurityComplianceMenu, feature_category: :navigation do
  let_it_be(:project) { create(:project) }

  let(:user) { project.first_owner }
  let(:show_promotions) { true }
  let(:show_discover_project_security) { true }
  let(:context) { Sidebars::Projects::Context.new(current_user: user, container: project, show_promotions: show_promotions, show_discover_project_security: show_discover_project_security) }

  subject(:items) { described_class.new(context).renderable_items.find { |i| i.item_id == item_id } }

  describe '#link' do
    subject(:menu) { described_class.new(context) }

    let(:show_promotions) { false }
    let(:show_discover_project_security) { false }

    using RSpec::Parameterized::TableSyntax

    where(:show_discover_project_security, :security_dashboard_feature, :dependency_scanning_feature, :audit_events_feature, :expected_link) do
      true  | true  | true  | true  | '/-/security/discover'
      false | true  | true  | true  | '/-/security/dashboard'
      false | false | true  | true  | '/-/dependencies'
      false | false | false | true  | '/-/audit_events'
      false | false | false | false | '/-/security/configuration'
    end

    with_them do
      it 'returns the expected link' do
        stub_licensed_features(security_dashboard: security_dashboard_feature, audit_events: audit_events_feature, dependency_scanning: dependency_scanning_feature)

        expect(menu.link).to include(expected_link)
      end
    end

    context 'when no security menu item and show promotions' do
      let(:user) { nil }

      it 'returns nil', :aggregate_failures do
        expect(menu.renderable_items).to be_empty
        expect(menu.link).to be_nil
      end
    end
  end

  describe 'Menu items' do
    describe 'with read_vulnerablity custom role permission' do
      subject(:renderable_items) { described_class.new(context).renderable_items.map(&:item_id) }

      before do
        stub_licensed_features(
          security_dashboard: true, audit_events: true, dependency_scanning: true, custom_roles: true, license_scanning: true
        )

        role = create(:member_role, :guest, :read_vulnerability, namespace: project.group)
        create(:group_member, :guest, user: guest, source: project.group, member_role: role)
      end

      let(:guest) { create(:user) }
      let(:context) { Sidebars::Projects::Context.new(current_user: guest, container: project, show_promotions: false, show_discover_project_security: false) }

      context 'with a public project' do
        let_it_be(:project) { create(:project, :public, :in_group) }

        it { expect(renderable_items).to match_array([:dashboard, :vulnerability_report]) }
      end

      context 'with a private project' do
        let_it_be(:project) { create(:project, :private, :in_group) }

        it { expect(renderable_items).to match_array([:dashboard, :vulnerability_report]) }
      end
    end

    describe 'Configuration' do
      let(:item_id) { :configuration }

      describe '#sidebar_security_configuration_paths' do
        let(:expected_security_configuration_paths) do
          %w[
            projects/security/configuration#show
            projects/security/sast_configuration#show
            projects/security/api_fuzzing_configuration#show
            projects/security/dast_configuration#show
            projects/security/dast_profiles#show
            projects/security/dast_site_profiles#new
            projects/security/dast_site_profiles#edit
            projects/security/dast_scanner_profiles#new
            projects/security/dast_scanner_profiles#edit
            projects/security/corpus_management#show
            projects/security/secret_detection_configuration#show
          ]
        end

        it 'includes all the security configuration paths' do
          expect(subject.active_routes[:path]).to match_array expected_security_configuration_paths
        end
      end
    end

    describe 'Discover Security and compliance' do
      let(:item_id) { :discover_project_security }

      context 'when show_discover_project_security is true' do
        it { is_expected.not_to be_nil }
      end

      context 'when show_discover_project_security is not true' do
        let(:show_discover_project_security) { false }

        it { is_expected.to be_nil }
      end
    end

    describe 'Security Dashboard' do
      let(:item_id) { :dashboard }

      before do
        stub_licensed_features(security_dashboard: true)
      end

      context 'when user can access security dashboard' do
        it { is_expected.not_to be_nil }
      end

      context 'when user cannot access security dashboard' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'Vulnerability Report' do
      let(:item_id) { :vulnerability_report }

      before do
        stub_licensed_features(security_dashboard: true)
      end

      context 'when user can access vulnerabilities report' do
        it { is_expected.not_to be_nil }
      end

      context 'when user cannot access vulnerabilities report' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'On Demand Scans' do
      let(:item_id) { :on_demand_scans }

      before do
        stub_licensed_features(security_on_demand_scans: true)
      end

      context 'when user can access vulnerabilities report' do
        it { is_expected.not_to be_nil }
      end

      context 'when user cannot access vulnerabilities report' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end

      context 'when FIPS mode is enabled' do
        let(:user) { project.first_owner }

        before do
          allow(::Gitlab::FIPS).to receive(:enabled?).and_return(true)
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :read_on_demand_dast_scan, project).and_return(true)
        end

        it { is_expected.not_to be_nil }
      end
    end

    describe 'Dependency List' do
      let(:item_id) { :dependency_list }

      before do
        stub_licensed_features(dependency_scanning: true)
      end

      context 'when user can access dependency list' do
        it { is_expected.not_to be_nil }
      end

      context 'when user cannot access dependency list' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'Policies' do
      let(:item_id) { :scan_policies }

      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'when user can access policies tab' do
        it { is_expected.not_to be_nil }
      end

      context 'when user cannot access policies tab' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'Dependency Firewall', :saas_dependency_firewall do
      # The firewall is enabled on the root group's settings, so this needs a group-owned project
      # rather than the personal-namespace project the rest of this file uses.
      let_it_be_with_reload(:root_group) { create(:group) }
      let_it_be(:group_project) { create(:project, group: root_group) }
      let_it_be(:group_owner) { create(:user, owner_of: root_group) }
      let_it_be(:group_guest) { create(:user, guest_of: root_group) }

      let(:item_id) { :dependency_firewall }
      let(:project) { group_project }
      let(:user) { group_owner }

      before do
        stub_licensed_features(dependency_firewall: true, security_orchestration_policies: true)
        root_group.namespace_settings.update!(dependency_firewall_enabled: true)
      end

      it { is_expected.not_to be_nil }

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
          root_group.namespace_settings.update!(dependency_firewall_enabled: false)
        end

        it { is_expected.to be_nil }
      end

      # a guest, not a nil user: a nil user is already rejected by can_access_some_page?,
      # so it would pass even if the permission check were removed
      context 'when the user cannot read security orchestration policies' do
        let(:user) { group_guest }

        it { is_expected.to be_nil }
      end
    end

    describe 'Audit events' do
      let(:item_id) { :audit_events }

      context 'when user can access audit events' do
        it { is_expected.not_to be_nil }

        context 'when feature audit events is licensed' do
          before do
            stub_licensed_features(audit_events: true)
          end

          it { is_expected.not_to be_nil }
        end

        context 'when feature audit events is not licensed' do
          before do
            stub_licensed_features(audit_events: false)
          end

          context 'when show promotions is enabled' do
            it { is_expected.not_to be_nil }
          end

          context 'when show promotions is disabled' do
            let(:show_promotions) { false }

            it { is_expected.to be_nil }
          end
        end
      end

      context 'when user cannot access audit events' do
        let(:user) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe 'Compliance center' do
      let(:item_id) { :compliance }

      context 'when project_level_compliance_dashboard feature is enabled' do
        before do
          stub_licensed_features(project_level_compliance_dashboard: true)
        end

        context 'when project is in personal namespace' do
          it { is_expected.to be_nil }
        end

        context 'when project is in group' do
          let_it_be(:user) { create(:user) }
          let_it_be(:project) { create(:project, :private, :in_group) }

          context 'when user is an owner' do
            before_all do
              project.add_owner(user)
            end

            it { is_expected.not_to be_nil }
          end

          context 'when user is a security manager' do
            before_all do
              project.add_security_manager(user)
            end

            it { is_expected.not_to be_nil }
          end

          context 'when user is assigned a custom role with `read_compliance_dashboard` ability' do
            let_it_be(:member_role) { create(:member_role, :guest, :read_compliance_dashboard, namespace: project.group) }
            let_it_be(:member) { create(:project_member, :guest, user: user, source: project, member_role: member_role) }

            before do
              stub_licensed_features(project_level_compliance_dashboard: true, custom_roles: true)
            end

            it { is_expected.not_to be_nil }

            context 'when custom roles feature is disabled' do
              before do
                stub_licensed_features(project_level_compliance_dashboard: true, custom_roles: false)
              end

              it { is_expected.to be_nil }
            end
          end

          context 'when user is assigned a custom role with `admin_compliance_framework` ability' do
            let_it_be(:member_role) { create(:member_role, :guest, :admin_compliance_framework, namespace: project.group) }
            let_it_be(:member) { create(:project_member, :guest, user: user, source: project, member_role: member_role) }

            before do
              stub_licensed_features(project_level_compliance_dashboard: true, custom_roles: true)
            end

            it { is_expected.not_to be_nil }

            context 'when custom roles feature is disabled' do
              before do
                stub_licensed_features(project_level_compliance_dashboard: true, custom_roles: false)
              end

              it { is_expected.to be_nil }
            end
          end
        end
      end

      context 'when project_level_compliance_dashboard feature is not enabled' do
        it { is_expected.to be_nil }
      end
    end

    describe 'Secrets manager' do
      let(:item_id) { :secrets_manager }
      let_it_be_with_reload(:secrets_manager) { build(:project_secrets_manager, project: project) }

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
          described_class.new(context).renderable_items.find { |i| i.item_id == item_id }
        end

        it_behaves_like 'secrets manager nav item with a New badge'
      end

      context 'when not enrolled' do
        before do
          stub_licensed_features(native_secrets_management: true)
          stub_application_setting(secrets_manager_instance_enrolled: false)
        end

        it { is_expected.to be_nil }
      end

      context 'when user does not have read_project_secrets permission' do
        let(:guest) { create(:user) }
        let(:context) { Sidebars::Projects::Context.new(current_user: guest, container: project) }

        before do
          stub_licensed_features(native_secrets_management: true)
        end

        it { is_expected.to be_nil }
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(secrets_manager: false)
          stub_licensed_features(native_secrets_management: true)
        end

        it { is_expected.to be_nil }
      end

      context 'when feature license is disabled' do
        before do
          stub_licensed_features(native_secrets_management: false)
        end

        it { is_expected.to be_nil }
      end

      context 'when the paid experience is disabled' do
        # Exercises the legacy "provisioned and active" gate (the flag defaults to enabled in tests).
        before do
          stub_feature_flags(secrets_manager_paid_experience: false)
          stub_licensed_features(native_secrets_management: true)
        end

        context 'when secrets manager is not active' do
          before do
            secrets_manager.update!(status: SecretsManagement::ProjectSecretsManager::STATUSES[:deprovisioning])
          end

          it { is_expected.to be_nil }
        end
      end

      context 'when the paid experience is enabled' do
        # The entitlement is resolved for the project's root namespace, which must be a root group.
        let_it_be(:group) { create(:group) }
        let_it_be(:group_project) { create(:project, group: group) }
        let_it_be(:reporter) { create(:user).tap { |u| group_project.add_reporter(u) } }

        let(:user) { reporter }
        let(:context) do
          Sidebars::Projects::Context.new(
            current_user: user, container: group_project,
            show_promotions: show_promotions, show_discover_project_security: show_discover_project_security
          )
        end

        before do
          stub_feature_flags(secrets_manager: group_project)
          stub_licensed_features(native_secrets_management: true)
        end

        %i[trial paid offline_paid blocked].each do |state|
          context "when the entitlement state is #{state}" do
            before do
              stub_secrets_manager_entitlement(state: state)
            end

            it 'shows an enabled link' do
              expect(items).not_to be_nil
            end
          end
        end

        context 'when the entitlement state is trial_eligible' do
          before do
            stub_secrets_manager_entitlement(state: :trial_eligible)
          end

          it { is_expected.to be_nil }
        end

        context 'when the entitlement state is ineligible' do
          before do
            stub_secrets_manager_entitlement(state: :ineligible)
          end

          it { is_expected.to be_nil }
        end

        context 'when secrets manager is not provisioned but the namespace is entitled' do
          let_it_be(:unprovisioned_project) { create(:project, group: group) }
          let_it_be(:reporter) { create(:user).tap { |u| unprovisioned_project.add_reporter(u) } }

          let(:context) do
            Sidebars::Projects::Context.new(
              current_user: user, container: unprovisioned_project,
              show_promotions: show_promotions, show_discover_project_security: show_discover_project_security
            )
          end

          before do
            stub_feature_flags(secrets_manager: unprovisioned_project)
            stub_secrets_manager_entitlement(state: :trial)
          end

          it 'shows an enabled link before provisioning' do
            expect(items).not_to be_nil
          end
        end
      end
    end
  end

  describe 'Feature Library metadata' do
    using RSpec::Parameterized::TableSyntax

    subject(:item) do
      described_class.new(context).renderable_items.find { |i| i.item_id == item_id }
    end

    context 'with Ultimate items' do
      before do
        stub_licensed_features(
          security_dashboard: true,
          security_on_demand_scans: true,
          dependency_scanning: true,
          security_orchestration_policies: true
        )
      end

      where(:item_id) do
        %i[dashboard vulnerability_report on_demand_scans dependency_list scan_policies]
      end

      with_them do
        it 'tags the item as an Ultimate feature', :aggregate_failures do
          serialized = item.serialize_for_super_sidebar

          expect(serialized[:tier]).to eq(:ultimate)
          expect(serialized).to include(:description, :library_icon)
        end
      end
    end

    describe 'Audit events' do
      let(:item_id) { :audit_events }

      before do
        stub_licensed_features(audit_events: true)
      end

      it 'tags the item as a Premium feature', :aggregate_failures do
        serialized = item.serialize_for_super_sidebar

        expect(serialized[:tier]).to eq(:premium)
        expect(serialized).to include(:description, :library_icon)
      end
    end

    describe 'Compliance center' do
      let(:item_id) { :compliance }
      let_it_be(:user) { create(:user) }
      let_it_be(:project) { create(:project, :private, :in_group) }

      before_all do
        project.add_owner(user)
      end

      before do
        stub_licensed_features(project_level_compliance_dashboard: true)
      end

      it 'tags the item as an Ultimate feature', :aggregate_failures do
        serialized = item.serialize_for_super_sidebar

        expect(serialized[:tier]).to eq(:ultimate)
        expect(serialized).to include(:description, :library_icon)
      end
    end

    describe 'Secrets manager' do
      let(:item_id) { :secrets_manager }
      let_it_be(:secrets_manager, freeze: false) { build(:project_secrets_manager, project: project) }

      before_all do
        secrets_manager.activate!
      end

      before do
        enroll_instance_in_secrets_manager
        stub_licensed_features(native_secrets_management: true)
      end

      it 'exposes Feature Library metadata without a tier', :aggregate_failures do
        serialized = item.serialize_for_super_sidebar

        expect(serialized).to include(:description, :library_icon)
        expect(serialized[:tier]).to be_nil
      end
    end
  end
end
