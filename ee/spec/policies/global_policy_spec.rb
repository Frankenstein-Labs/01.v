# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GlobalPolicy, :aggregate_failures, feature_category: :shared do
  include AdminModeHelper
  include ExternalAuthorizationServiceHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:admin) { create(:admin) }
  let_it_be_with_reload(:current_user) { create(:user) }
  let_it_be(:user) { create(:user) }
  let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }

  subject { described_class.new(current_user, [user]) }

  describe 'reading operations dashboard' do
    context 'when licensed' do
      before do
        stub_licensed_features(operations_dashboard: true)
      end

      it { is_expected.to be_allowed(:read_operations_dashboard) }

      context 'and the user is not logged in' do
        let(:current_user) { nil }

        it { is_expected.to be_disallowed(:read_operations_dashboard) }
      end
    end

    context 'when unlicensed' do
      before do
        stub_licensed_features(operations_dashboard: false)
      end

      it { is_expected.to be_disallowed(:read_operations_dashboard) }
    end
  end

  describe 'access_workspaces_feature ability' do
    where(:anonymous, :licensed, :allowed) do
      # anonymous  | licensed  | allowed
      true         | true      | false
      false        | false     | false
      true         | false     | false
      false        | true      | true
    end

    with_them do
      let(:current_user) { anonymous ? nil : user }

      before do
        stub_licensed_features(remote_development: licensed)
      end

      it { is_expected.to(allowed ? be_allowed(:access_workspaces_feature) : be_disallowed(:access_workspace_feature)) }
    end

    context 'when anon=false and licensed=true it is allowed' do
      # TODO: This is a redundant test because the TableSyntax test above was giving false positives.
      #       See https://gitlab.com/gitlab-org/gitlab/-/merge_requests/136642#note_1670763898

      let(:current_user) { user }

      before do
        stub_licensed_features(remote_development: true)
      end

      it { is_expected.to be_allowed(:access_workspaces_feature) }
    end
  end

  it { is_expected.to be_disallowed(:read_licenses) }
  it { is_expected.to be_disallowed(:delete_license) }
  it { is_expected.to be_disallowed(:read_all_geo) }
  it { is_expected.to be_disallowed(:read_all_workspaces) }
  it { is_expected.to be_disallowed(:update_gitlab_subscription) }
  it { is_expected.to be_disallowed(:read_cloud_connector_status) }
  it { is_expected.to be_disallowed(:read_admin_subscription) }
  it { is_expected.to be_disallowed(:read_admin_data_management) }
  it { is_expected.to be_disallowed(:read_ldap_admin_role_link) }
  it { is_expected.to be_disallowed(:create_ldap_admin_role_link) }
  it { is_expected.to be_disallowed(:delete_ldap_admin_role_link) }

  context 'when admin mode enabled', :enable_admin_mode do
    it { expect(described_class.new(admin, [user])).to be_allowed(:read_licenses) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:delete_license) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:read_all_geo) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:read_all_workspaces) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:update_gitlab_subscription) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:read_cloud_connector_status) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:read_admin_subscription) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:read_ldap_admin_role_link) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:create_ldap_admin_role_link) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:delete_ldap_admin_role_link) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:update_subscription_usage_cap) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:read_subscription_usage) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:force_hard_delete_ai_catalog_item) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:clear_active_context_dead_queue) }
    it { expect(described_class.new(admin, [user])).to be_allowed(:replay_active_context_dead_queue) }
  end

  context 'when admin mode disabled' do
    it { expect(described_class.new(admin, [user])).to be_disallowed(:read_licenses) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:delete_license) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:read_all_geo) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:read_all_workspaces) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:update_gitlab_subscription) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:read_cloud_connector_status) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:read_admin_subscription) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:read_admin_data_management) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:read_ldap_admin_role_link) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:create_ldap_admin_role_link) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:delete_ldap_admin_role_link) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:update_subscription_usage_cap) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:read_subscription_usage) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:force_hard_delete_ai_catalog_item) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:clear_active_context_dead_queue) }
    it { expect(described_class.new(admin, [user])).to be_disallowed(:replay_active_context_dead_queue) }
  end

  it { expect_disallowed(:force_hard_delete_ai_catalog_item) }
  it { expect_disallowed(:clear_active_context_dead_queue) }
  it { expect_disallowed(:replay_active_context_dead_queue) }

  describe 'Secrets Manager instance enrollment permissions' do
    let(:abilities) do
      [:create_secrets_manager_enrollment, :delete_secrets_manager_enrollment, :read_secrets_manager_enrollment]
    end

    before do
      allow(::License).to receive(:feature_available?).and_call_original
      allow(::License).to receive(:feature_available?).with(:native_secrets_management).and_return(true)
    end

    context 'when admin mode is enabled', :enable_admin_mode do
      let(:policy) { described_class.new(admin, [user]) }

      it 'allows all enrollment abilities' do
        abilities.each { |ability| expect(policy).to be_allowed(ability) }
      end

      context 'when on GitLab.com', :saas do
        it 'disallows all enrollment abilities (instance enrollment is self-managed only)' do
          abilities.each { |ability| expect(policy).to be_disallowed(ability) }
        end
      end

      context 'when license is not available' do
        before do
          allow(::License).to receive(:feature_available?).with(:native_secrets_management).and_return(false)
        end

        it 'disallows all enrollment abilities' do
          abilities.each { |ability| expect(policy).to be_disallowed(ability) }
        end
      end

      context 'when enrollment feature flag is disabled' do
        before do
          stub_feature_flags(secrets_manager_instance_enrollment: false)
        end

        it 'disallows all enrollment abilities' do
          abilities.each { |ability| expect(policy).to be_disallowed(ability) }
        end
      end
    end

    context 'when admin mode is disabled' do
      let(:policy) { described_class.new(admin, [user]) }

      it 'disallows all enrollment abilities' do
        abilities.each { |ability| expect(policy).to be_disallowed(ability) }
      end
    end

    context 'when current user is not an admin' do
      it 'disallows all enrollment abilities' do
        abilities.each { |ability| is_expected.to be_disallowed(ability) }
      end
    end
  end

  describe ':report_ai_catalog_item' do
    context 'when user is logged in and abuse notification email is present' do
      let(:current_user) { create(:user) }

      before do
        stub_application_setting(abuse_notification_email: 'abuse@example.com')
      end

      it { expect_allowed(:report_ai_catalog_item) }
    end

    context 'when user is logged in but abuse notification email is not configured' do
      let(:current_user) { create(:user) }

      before do
        stub_application_setting(abuse_notification_email: '')
      end

      it { expect_disallowed(:report_ai_catalog_item) }
    end

    context 'when user is anonymous' do
      let(:current_user) { nil }

      before do
        stub_application_setting(abuse_notification_email: 'abuse@example.com')
      end

      it { expect_disallowed(:report_ai_catalog_item) }
    end
  end

  shared_examples 'analytics policy' do |action|
    context 'anonymous user' do
      let(:current_user) { nil }

      it 'is not allowed' do
        is_expected.to be_disallowed(action)
      end
    end

    context 'authenticated user' do
      it 'is allowed' do
        is_expected.to be_allowed(action)
      end
    end
  end

  describe 'view_productivity_analytics' do
    include_examples 'analytics policy', :view_productivity_analytics
  end

  describe 'update_max_pages_size' do
    context 'when feature is enabled' do
      before do
        stub_licensed_features(pages_size_limit: true)
      end

      it { is_expected.to be_disallowed(:update_max_pages_size) }

      context 'when admin mode enabled', :enable_admin_mode do
        it { expect(described_class.new(admin, [user])).to be_allowed(:update_max_pages_size) }
      end

      context 'when admin mode disabled' do
        it { expect(described_class.new(admin, [user])).to be_disallowed(:update_max_pages_size) }
      end
    end

    it { expect(described_class.new(admin, [user])).to be_disallowed(:update_max_pages_size) }
  end

  describe 'create_group_with_default_branch_protection' do
    context 'for an admin' do
      let(:current_user) { admin }

      context 'when the `default_branch_protection_restriction_in_groups` feature is available' do
        before do
          stub_licensed_features(default_branch_protection_restriction_in_groups: true)
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is enabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: true)
          end

          it { is_expected.to be_allowed(:create_group_with_default_branch_protection) }
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          context 'when admin mode is enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(:create_group_with_default_branch_protection) }
          end

          context 'when admin mode is disabled' do
            it { is_expected.to be_disallowed(:create_group_with_default_branch_protection) }
          end
        end
      end

      context 'when the `default_branch_protection_restriction_in_groups` feature is not available' do
        before do
          stub_licensed_features(default_branch_protection_restriction_in_groups: false)
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is enabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: true)
          end

          it { is_expected.to be_allowed(:create_group_with_default_branch_protection) }
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          it { is_expected.to be_allowed(:create_group_with_default_branch_protection) }
        end
      end
    end

    context 'for a normal user' do
      let(:current_user) { create(:user) }

      context 'when the `default_branch_protection_restriction_in_groups` feature is available' do
        before do
          stub_licensed_features(default_branch_protection_restriction_in_groups: true)
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is enabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: true)
          end

          it { is_expected.to be_allowed(:create_group_with_default_branch_protection) }
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          it { is_expected.to be_disallowed(:create_group_with_default_branch_protection) }
        end
      end

      context 'when the `default_branch_protection_restriction_in_groups` feature is not available' do
        before do
          stub_licensed_features(default_branch_protection_restriction_in_groups: false)
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is enabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: true)
          end

          it { is_expected.to be_allowed(:create_group_with_default_branch_protection) }
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          it { is_expected.to be_allowed(:create_group_with_default_branch_protection) }
        end
      end
    end
  end

  describe 'custom roles' do
    describe 'various permissions' do
      where(:permission, :license) do
        :admin_member_role | :custom_roles
        :view_member_roles | :custom_roles
        :view_member_roles | :default_roles_assignees
        :read_admin_role   | :custom_roles
        :create_admin_role | :custom_roles
      end

      include_examples 'permission is allowed/disallowed with feature flags toggled'
    end

    describe 'read_member_role' do
      let(:permissions) { [:read_member_role] }

      context 'when custom_roles feature is enabled' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        context 'for anynomous user' do
          let(:current_user) { nil }

          it { is_expected.to be_disallowed(*permissions) }
        end

        context 'for registered user' do
          let(:current_user) { user }

          it { is_expected.to be_allowed(*permissions) }
        end
      end

      context 'when custom_roles feature is disabled' do
        context 'when admin mode enabled', :enable_admin_mode do
          it { expect(described_class.new(admin, [user])).to be_disallowed(*permissions) }
        end
      end
    end
  end

  describe ':export_user_permissions', :enable_admin_mode do
    let(:policy) { :export_user_permissions }

    let_it_be(:admin) { build_stubbed(:admin) }
    let_it_be(:guest) { build_stubbed(:user) }

    where(:role, :licensed, :allowed) do
      :admin | true | true
      :admin | false | false
      :guest | true | false
      :guest | false | false
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        stub_licensed_features(export_user_permissions: licensed)
      end

      it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
    end
  end

  describe 'create_group_via_api' do
    let(:policy) { :create_group_via_api }

    context 'when on .com', :saas do
      before do
        stub_ee_application_setting(top_level_group_creation_enabled: false)
      end

      context 'when user is an admin', :do_not_mock_admin_mode_setting do
        let(:current_user) { admin }

        it { is_expected.to be_allowed(policy) }

        context 'when in admin_mode', :enable_admin_mode do
          it { is_expected.to be_allowed(policy) }
        end
      end

      context 'when user is a non-admin user' do
        let(:current_user) { user }

        it { is_expected.not_to be_allowed(policy) }
      end
    end

    context 'when on self-managed' do
      context 'when the top_level_group_creation_enabled application_setting is enabled (default)' do
        context 'when user is an admin', :do_not_mock_admin_mode_setting do
          let(:current_user) { admin }

          it { is_expected.to be_allowed(policy) }

          context 'when in admin_mode', :enable_admin_mode do
            it { is_expected.to be_allowed(policy) }
          end
        end

        context 'when user is a non-admin user' do
          let(:current_user) { user }

          it { is_expected.to be_allowed(policy) }
        end
      end

      context 'when the top_level_group_creation_enabled application_setting is disabled' do
        before do
          stub_ee_application_setting(top_level_group_creation_enabled: false)
        end

        context 'when user is an admin', :enable_admin_mode do
          let(:current_user) { admin }

          it { is_expected.not_to be_allowed(policy) }
        end

        context 'when user is a non-admin user' do
          let(:current_user) { user }

          it { is_expected.not_to be_allowed(policy) }
        end
      end
    end
  end

  describe ':view_instance_devops_adoption & :manage_devops_adoption_namespaces', :enable_admin_mode do
    let(:current_user) { admin }

    context 'when license does not include the feature' do
      before do
        stub_licensed_features(instance_level_devops_adoption: false)
      end

      it { is_expected.to be_disallowed(:view_instance_devops_adoption, :manage_devops_adoption_namespaces) }
    end

    context 'when feature is enabled and license include the feature' do
      before do
        stub_licensed_features(instance_level_devops_adoption: true)
      end

      it { is_expected.to be_allowed(:view_instance_devops_adoption, :manage_devops_adoption_namespaces) }

      context 'for non-admins' do
        let(:current_user) { user }

        it { is_expected.to be_disallowed(:view_instance_devops_adoption, :manage_devops_adoption_namespaces) }
      end
    end

    context 'when feature is enabled through usage ping features' do
      before do
        stub_usage_ping_features(true)
      end

      it { is_expected.to be_allowed(:view_instance_devops_adoption, :manage_devops_adoption_namespaces) }

      context 'for non-admins' do
        let(:current_user) { user }

        it { is_expected.to be_disallowed(:view_instance_devops_adoption, :manage_devops_adoption_namespaces) }
      end
    end
  end

  describe 'read_runner_usage' do
    include AdminModeHelper

    where(:licensed, :is_admin, :enable_admin_mode, :clickhouse_configured, :expected) do
      true  | true  | true  | true  | true
      false | true  | true  | true  | false
      true  | false | true  | true  | false
      true  | true  | false | true  | false
      true  | true  | true  | false | false
    end

    with_them do
      before do
        stub_licensed_features(runner_performance_insights: licensed)

        enable_admin_mode!(admin) if enable_admin_mode

        allow(::Gitlab::ClickHouse).to receive(:configured?).and_return(clickhouse_configured)
      end

      let(:current_user) { is_admin ? admin : user }

      it 'matches expectation' do
        if expected
          is_expected.to be_allowed(:read_runner_usage)
        else
          is_expected.to be_disallowed(:read_runner_usage)
        end
      end
    end
  end

  describe 'read_jobs_statistics' do
    context 'when feature is enabled' do
      before do
        stub_licensed_features(runner_performance_insights: true)
      end

      it { is_expected.to be_disallowed(:read_jobs_statistics) }

      context 'when admin mode enabled', :enable_admin_mode do
        it { expect(described_class.new(admin, [user])).to be_allowed(:read_jobs_statistics) }
      end

      context 'when admin mode disabled' do
        it { expect(described_class.new(admin, [user])).to be_disallowed(:read_jobs_statistics) }
      end
    end

    context 'when feature is disabled' do
      before do
        stub_licensed_features(runner_performance_insights: false)
      end

      context 'when admin mode enabled', :enable_admin_mode do
        it { expect(described_class.new(admin, [user])).to be_disallowed(:read_jobs_statistics) }
      end
    end
  end

  describe 'read_namespace_duo_availability' do
    it { is_expected.to be_disallowed(:read_namespace_duo_availability) }

    context 'when admin mode enabled', :enable_admin_mode do
      it { expect(described_class.new(admin, [user])).to be_allowed(:read_namespace_duo_availability) }
    end

    context 'when admin mode disabled' do
      it { expect(described_class.new(admin, [user])).to be_disallowed(:read_namespace_duo_availability) }
    end

    context 'when the user is an auditor' do
      let(:current_user) { create(:user, :auditor) }

      it { is_expected.to be_disallowed(:read_namespace_duo_availability) }
    end
  end

  describe 'read runner upgrade status' do
    where(:license_available?, :paid_namespace?, :allowed?) do
      true  | true  | true
      true  | false | true
      false | true  | true
      false | false | false
    end

    with_them do
      before do
        stub_licensed_features(runner_upgrade_management: license_available?)
        allow(current_user).to receive(:belongs_to_paid_namespace?).and_return(paid_namespace?)
      end

      it 'matches expected permission' do
        if allowed?
          is_expected.to be_allowed(:read_runner_upgrade_status)
        else
          is_expected.to be_disallowed(:read_runner_upgrade_status)
        end
      end
    end
  end

  describe 'admin_instance_external_audit_events' do
    let_it_be(:admin) { create(:admin) }
    let_it_be(:user) { create(:user) }

    shared_examples 'admin external events is not allowed' do
      context 'when user is instance admin' do
        context 'when admin mode enabled', :enable_admin_mode do
          it { expect(described_class.new(admin, nil)).to be_disallowed(:admin_instance_external_audit_events) }
        end

        context 'when admin mode disabled' do
          it { expect(described_class.new(admin, nil)).to be_disallowed(:admin_instance_external_audit_events) }
        end
      end

      context 'when user is not instance admin' do
        it { expect(described_class.new(user, nil)).to be_disallowed(:admin_instance_external_audit_events) }
      end
    end

    context 'when licence is enabled' do
      before do
        stub_licensed_features(external_audit_events: true)
      end

      context 'when user is instance admin' do
        context 'when admin mode enabled', :enable_admin_mode do
          it { expect(described_class.new(admin, nil)).to be_allowed(:admin_instance_external_audit_events) }
        end

        context 'when admin mode disabled' do
          it { expect(described_class.new(admin, nil)).to be_disallowed(:admin_instance_external_audit_events) }
        end
      end

      context 'when user is not instance admin' do
        it { expect(described_class.new(user, nil)).to be_disallowed(:admin_instance_external_audit_events) }
      end
    end

    context 'when licence is not enabled' do
      it_behaves_like 'admin external events is not allowed'
    end
  end

  describe 'access_code_suggestions' do
    let(:policy) { :access_code_suggestions }

    let_it_be_with_reload(:current_user) { create(:user) }

    where(:code_suggestions_licensed, :duo_pro_seat_assigned, :lock_duo_features_enabled,
      :code_suggestions_enabled_for_user) do
      true  | true  | false  |  be_allowed(:access_code_suggestions)
      true  | false | false  |  be_disallowed(:access_code_suggestions)
      true  | false | true   |  be_disallowed(:access_code_suggestions)
      true  | true  | true   |  be_disallowed(:access_code_suggestions)
      false | true  | false  |  be_disallowed(:access_code_suggestions)
      false | false | false  |  be_disallowed(:access_code_suggestions)
      false | true  | true   |  be_disallowed(:access_code_suggestions)
      false | false | true   |  be_disallowed(:access_code_suggestions)
    end

    with_them do
      before do
        stub_licensed_features(code_suggestions: code_suggestions_licensed)
        stub_application_setting(
          duo_features_enabled: !lock_duo_features_enabled,
          lock_duo_features_enabled: lock_duo_features_enabled
        )

        # This is needed to allow responding differently based on the arguments. We make the default throw an error
        # to check we don't get unexpected calls.
        # See https://rspec.info/features/3-12/rspec-mocks/setting-constraints/matching-arguments/
        allow(current_user).to receive(:allowed_to_use?).and_raise(StandardError)

        allow(current_user).to receive(:allowed_to_use?).with(:code_suggestions).and_return(duo_pro_seat_assigned)
      end

      it { is_expected.to code_suggestions_enabled_for_user }
    end

    context 'when an active SM gitlab_credits add-on exists (free-tier self-managed)' do
      before do
        stub_licensed_features(code_suggestions: false)
        stub_application_setting(lock_duo_features_enabled: false)
        allow(::GitlabSubscriptions::Duo).to receive(:active_self_managed_gitlab_credits?).and_return(true)
        allow(current_user).to receive(:allowed_to_use?).with(:code_suggestions).and_return(true)
      end

      it { is_expected.to be_allowed(:access_code_suggestions) }
    end
  end

  describe 'access_duo_classic_chat' do
    let(:policy) { :access_duo_classic_chat }

    let_it_be_with_reload(:current_user) { create(:user) }

    context 'when on .org or .com', :saas do
      where(:duo_pro_seat_assigned, :duo_chat_enabled_for_user) do
        true  | be_allowed(policy)
        false | be_disallowed(policy)
      end

      with_them do
        before do
          allow(current_user).to receive(:allowed_to_use?).with(:chat,
            unit_primitive_name: :duo_classic_chat).and_return(duo_pro_seat_assigned)
        end

        it { is_expected.to duo_chat_enabled_for_user }
      end
    end

    context 'when not on .org or .com' do
      where(:lock_duo_features_enabled, :duo_pro_seat_assigned, :duo_chat_enabled_for_user) do
        true  | true  | be_disallowed(policy)
        true  | false | be_disallowed(policy)
        false | false | be_disallowed(policy)
        false | true  | be_allowed(policy)
      end

      with_them do
        before do
          allow(::Gitlab).to receive(:org_or_com?).and_return(false)
          stub_ee_application_setting(
            duo_features_enabled: !lock_duo_features_enabled,
            lock_duo_features_enabled: lock_duo_features_enabled
          )
          allow(current_user).to receive(:allowed_to_use?).with(:chat,
            unit_primitive_name: :duo_classic_chat).and_return(duo_pro_seat_assigned)
        end

        it { is_expected.to duo_chat_enabled_for_user }
      end
    end

    context 'when amazon q is connected' do
      where(:duo_chat_on_saas, :amazon_q_connected, :duo_chat_enabled_for_user) do
        true  | true  | be_allowed(policy)
        false | true  | be_allowed(policy)
        true  | false | be_disallowed(policy)
        true  | false | be_disallowed(policy)
      end

      with_them do
        before do
          allow(::Gitlab).to receive(:com?).and_return(duo_chat_on_saas)
          allow(::Ai::AmazonQ).to receive(:connected?).and_return(amazon_q_connected)
          stub_licensed_features(ai_chat: true, amazon_q: true)
        end

        it { is_expected.to duo_chat_enabled_for_user }
      end
    end
  end

  describe 'access_duo_agentic_chat' do
    let(:policy) { :access_duo_agentic_chat }
    let_it_be_with_reload(:current_user) { create(:user) }

    context 'when on .org or .com', :saas do
      where(:duo_agentic_chat_enabled_for_user, :allowed) do
        true  | be_allowed(policy)
        false | be_disallowed(policy)
      end

      with_them do
        before do
          allow(current_user).to receive(:allowed_to_use?).with(:agentic_chat, unit_primitive_name: :duo_chat)
            .and_return(duo_agentic_chat_enabled_for_user)
        end

        it { is_expected.to allowed }
      end

      context 'when user is nil' do
        let(:current_user) { nil }

        it { is_expected.to be_disallowed(policy) }
      end
    end

    context 'when not on .org or .com' do
      where(:lock_duo_features_enabled, :duo_agentic_chat_enabled_for_user, :allowed) do
        true  | true  | be_disallowed(policy)
        true  | false | be_disallowed(policy)
        false | false | be_disallowed(policy)
        false | true  | be_allowed(policy)
      end

      with_them do
        before do
          allow(::Gitlab).to receive(:org_or_com?).and_return(false)
          stub_ee_application_setting(
            duo_features_enabled: !lock_duo_features_enabled,
            lock_duo_features_enabled: lock_duo_features_enabled
          )
          allow(current_user).to receive(:allowed_to_use?).with(:agentic_chat, unit_primitive_name: :duo_chat)
            .and_return(duo_agentic_chat_enabled_for_user)
        end

        it { is_expected.to allowed }
      end
    end
  end

  describe 'access_duo_entry_point' do
    let_it_be_with_reload(:current_user) { create(:user) }

    where(:has_classic_chat, :has_agentic_chat, :allowed) do
      true  | true  | be_allowed(:access_duo_entry_point)
      true  | false | be_allowed(:access_duo_entry_point)
      false | true  | be_allowed(:access_duo_entry_point)
      false | false | be_disallowed(:access_duo_entry_point)
    end

    with_them do
      before do
        allow(current_user).to receive(:allowed_to_use?)
          .with(:chat, unit_primitive_name: :duo_classic_chat).and_return(has_classic_chat)
        allow(current_user).to receive(:allowed_to_use?)
          .with(:agentic_chat, unit_primitive_name: :duo_chat).and_return(has_agentic_chat)
      end

      it { is_expected.to allowed }
    end

    context 'when user is nil' do
      let(:current_user) { nil }

      it { is_expected.to be_disallowed(:access_duo_entry_point) }
    end
  end

  describe 'read_ai_catalog' do
    before do
      allow(Ai::Catalog).to receive(:available?).and_return(ai_catalog_available)
    end

    context 'when AI Catalog is available for the instance' do
      let(:ai_catalog_available) { true }

      it { is_expected.to be_allowed(:read_ai_catalog) }
    end

    context 'when AI Catalog is not available for the instance' do
      let(:ai_catalog_available) { false }

      it { is_expected.to be_disallowed(:read_ai_catalog) }
    end
  end

  describe 'read_ai_catalog_flow' do
    before do
      allow(Ai::Catalog).to receive(:available?).and_return(ai_catalog_available)
    end

    context 'when AI Catalog is available' do
      let(:ai_catalog_available) { true }

      it { is_expected.to be_allowed(:read_ai_catalog_flow) }
    end

    context 'when AI Catalog is not available' do
      let(:ai_catalog_available) { false }

      it { is_expected.to be_disallowed(:read_ai_catalog_flow) }
    end
  end

  describe 'git access' do
    context 'security policy bot' do
      let(:current_user) { security_policy_bot }

      it { is_expected.to be_allowed(:access_git) }
    end
  end

  describe 'api access' do
    context 'security policy bot' do
      let(:current_user) { security_policy_bot }

      it { is_expected.to be_allowed(:access_api) }
      it { is_expected.to be_allowed(:execute_graphql_mutation) }
    end
  end

  describe 'explain git commands' do
    let(:policy) { :access_glab_ask_git_command }

    where(:lock_duo_features_enabled, :allowed_to_use, :enabled_for_user) do
      false | false | be_disallowed(:access_glab_ask_git_command)
      true  | true  | be_disallowed(:access_glab_ask_git_command)
      false | true  | be_allowed(:access_glab_ask_git_command)
    end

    with_them do
      before do
        stub_application_setting(
          duo_features_enabled: !lock_duo_features_enabled,
          lock_duo_features_enabled: lock_duo_features_enabled
        )

        allow(current_user).to receive(:allowed_to_use?)
          .with(:glab_ask_git_command, licensed_feature: :glab_ask_git_command).and_return(allowed_to_use)
      end

      it { is_expected.to enabled_for_user }
    end

    context 'when user is nil' do
      let(:current_user) { nil }

      it { is_expected.to be_disallowed(policy) }
    end
  end

  describe 'read_enterprise_ai_analytics' do
    context "when regular user" do
      let(:current_user) { build(:user) }

      it { is_expected.to be_disallowed(:read_enterprise_ai_analytics) }
    end

    context 'when admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { is_expected.to be_allowed(:read_enterprise_ai_analytics) }
    end
  end

  describe 'manage instance AI model configuration' do
    let_it_be(:active_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active) }

    let(:current_user) { admin }

    shared_context 'with expected license and active add-on' do
      before do
        stub_licensed_features(self_hosted_models: true)
        allow(::GitlabSubscriptions::AddOnPurchase)
          .to receive_message_chain(:for_self_managed, :for_duo_core_pro_or_enterprise, :active, :exists?)
          .and_return(true)
        allow(::GitlabSubscriptions::AddOnPurchase)
          .to receive_message_chain(:for_self_managed, :for_self_hosted_dap, :active, :exists?)
          .and_return(false)
      end
    end

    describe "manage self-hosted AI models" do
      using RSpec::Parameterized::TableSyntax

      context "when regular user" do
        let(:current_user) { build(:user) }

        include_context 'with expected license and active add-on'

        it { is_expected.to be_disallowed(:manage_self_hosted_models_settings) }
      end

      context 'when admin', :enable_admin_mode do
        # rubocop:disable Layout/LineLength -- Table syntax requires long lines for readability
        where(
          :is_licensed, :is_active_duo_add_on, :is_active_dap_add_on, :is_duo_enterprise, :is_saas,
          :dedicated_instance, :allow_dedicated_self_hosted, :amazon_q_enabled, :is_offline_license,
          :can_manage_self_hosted_settings
        ) do
          # Both add-on types available
          true  | true  | true  | true  | false | false | false | false | false | be_allowed(:manage_self_hosted_models_settings)
          # Only Duo Core/Pro/Enterprise add-on
          true  | true  | false | true  | false | false | false | false | false | be_allowed(:manage_self_hosted_models_settings)
          # Only DAP add-on with offline license
          true  | false | true  | false | false | false | false | false | true  | be_allowed(:manage_self_hosted_models_settings)
          # Only DAP add-on with online license (dap_self_hosted? returns true for online)
          true  | false | true  | false | false | false | false | false | false | be_allowed(:manage_self_hosted_models_settings)
          # Amazon Q enabled
          true  | true  | false | false | false | false | false | true  | false | be_disallowed(:manage_self_hosted_models_settings)
          # Is SaaS
          true  | true  | true  | true  | true  | false | false | false | false | be_disallowed(:manage_self_hosted_models_settings)
          # Dedicated instance
          true  | true  | false | true  | false | true  | false | false | false | be_disallowed(:manage_self_hosted_models_settings)
          # Allowed dedicated instance
          true  | true  | false | true  | false | true  | true  | false | false | be_allowed(:manage_self_hosted_models_settings)
          # No license
          false | true  | false | true  | false | false | false | false | false | be_disallowed(:manage_self_hosted_models_settings)
        end
        # rubocop:enable Layout/LineLength

        with_them do
          let(:license_double) do
            instance_double('License', offline_cloud_license?: is_offline_license)
          end

          before do
            stub_licensed_features(self_hosted_models: is_licensed)
            allow(License).to receive(:current).and_return(license_double)
            allow(::GitlabSubscriptions::AddOnPurchase)
              .to receive_message_chain(:for_self_managed, :for_duo_core_pro_or_enterprise, :active, :exists?)
              .and_return(is_active_duo_add_on)
            allow(::GitlabSubscriptions::AddOnPurchase)
              .to receive_message_chain(:for_self_managed, :for_self_hosted_dap, :active, :exists?)
              .and_return(is_active_dap_add_on)
            allow(::Ai::AmazonQ).to receive(:connected?).and_return(amazon_q_enabled)
            allow(::GitlabSubscriptions::AddOnPurchase)
              .to receive_message_chain(:for_self_managed, :for_duo_enterprise, :active, :exists?)
              .and_return(is_duo_enterprise)

            stub_saas_features(gitlab_com_subscriptions: is_saas)

            allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(dedicated_instance)
            stub_env('ALLOW_DEDICATED_SELF_HOSTED_AIGW', allow_dedicated_self_hosted.to_s)
          end

          it { is_expected.to can_manage_self_hosted_settings }
        end
      end
    end

    describe "manage instance model selection" do
      using RSpec::Parameterized::TableSyntax

      context "when regular user" do
        let(:current_user) { build(:user) }

        include_context 'with expected license and active add-on'

        it { is_expected.to be_disallowed(:manage_instance_model_selection) }
      end

      context 'when admin', :enable_admin_mode do
        where(
          :amazon_q_enabled, :is_licensed, :is_offline_license, :can_manage_instance_model_selection
        ) do
          # Online license with license
          false | true  | false | be_allowed(:manage_instance_model_selection)
          # Amazon Q connected
          true  | true  | false | be_disallowed(:manage_instance_model_selection)
          # Offline license (blocks instance_model_selection_available)
          false | true  | true  | be_disallowed(:manage_instance_model_selection)
          # No license
          false | false | false | be_disallowed(:manage_instance_model_selection)
        end
        with_them do
          let(:license_double) do
            instance_double('License', offline_cloud_license?: is_offline_license)
          end

          before do
            stub_licensed_features(self_hosted_models: is_licensed)
            allow(License).to receive(:current).and_return(license_double)
            allow(::Ai::AmazonQ).to receive(:connected?).and_return(amazon_q_enabled)
          end

          it { is_expected.to can_manage_instance_model_selection }
        end
      end
    end

    describe "model selection allowlist" do
      using RSpec::Parameterized::TableSyntax

      context "when regular user" do
        let(:current_user) { build(:user) }

        it { expect_disallowed(:read_model_selection_allowlist, :update_model_selection_allowlist) }
      end

      context 'when admin', :enable_admin_mode do
        where(:online_cloud_license, :allowlist_accessible) do
          true  | true
          false | false
        end

        with_them do
          let(:license_double) do
            instance_double('License', online_cloud_license?: online_cloud_license)
          end

          before do
            allow(License).to receive(:current).and_return(license_double)
          end

          it 'matches expected access for read and update' do
            if allowlist_accessible
              expect_allowed(:read_model_selection_allowlist, :update_model_selection_allowlist)
            else
              expect_disallowed(:read_model_selection_allowlist, :update_model_selection_allowlist)
            end
          end
        end
      end
    end

    describe "manage self-hosted DAP models" do
      using RSpec::Parameterized::TableSyntax

      context "when regular user" do
        let(:current_user) { build(:user) }

        it { is_expected.to be_disallowed(:read_dap_self_hosted_model) }
        it { is_expected.to be_disallowed(:update_dap_self_hosted_model) }
      end

      context 'when admin', :enable_admin_mode do # -- Table syntax requires long lines for readability
        where(
          :is_offline_license, :is_dap_add_on_available, :can_read_dap_models, :can_update_dap_models
        ) do
          # Online license (always allowed regardless of add-on)
          false | true  |  be_allowed(:read_dap_self_hosted_model)   | be_allowed(:update_dap_self_hosted_model)
          # Online license without DAP add-on (still allowed)
          false | false |  be_allowed(:read_dap_self_hosted_model)   | be_allowed(:update_dap_self_hosted_model)
          # Offline cloud license with DAP add-on
          true  | true  | be_allowed(:read_dap_self_hosted_model)    | be_allowed(:update_dap_self_hosted_model)
          # Offline cloud license without DAP add-on
          true  | false | be_disallowed(:read_dap_self_hosted_model) | be_disallowed(:update_dap_self_hosted_model)
        end
        with_them do
          let(:license_double) do
            instance_double('License', offline_cloud_license?: is_offline_license)
          end

          before do
            allow(License).to receive(:current).and_return(license_double)
            allow(::GitlabSubscriptions::AddOnPurchase)
              .to receive_message_chain(:for_self_managed, :for_self_hosted_dap, :active, :exists?)
              .and_return(is_dap_add_on_available)
          end

          it { is_expected.to can_read_dap_models }
          it { is_expected.to can_update_dap_models }
        end
      end
    end
  end

  context 'custom permissions', :enable_admin_mode do
    let_it_be(:enabled_for_all) { %i[access_admin_area read_application_statistics] }

    where(:custom_ability, :enabled_permissions) do
      :read_admin_cicd         | %i[read_admin_cicd]
      :read_admin_subscription | %i[read_admin_subscription read_billable_member read_licenses]
      :read_admin_users        | %i[read_admin_users]
      :read_admin_groups       | %i[read_admin_groups]
      :read_admin_projects     | %i[read_admin_projects]
    end

    with_them do
      context 'when a user is assigned an admin custom role' do
        before do
          create(:admin_member_role, custom_ability, user: current_user)
        end

        context 'when custom_roles feature is enabled' do
          before do
            stub_licensed_features(custom_roles: true)
          end

          it { is_expected.to be_allowed(*(enabled_permissions + enabled_for_all)) }
        end

        context 'when custom_roles feature is disabled' do
          before do
            stub_licensed_features(custom_roles: false)
          end

          it { is_expected.to be_disallowed(*(enabled_permissions + enabled_for_all)) }
        end
      end
    end

    context 'with read_admin_monitoring custom role' do
      def base_permissions
        %i[read_admin_background_migrations
          read_admin_gitaly_servers
          read_admin_health_check
          read_admin_system_information
          access_admin_area
          read_application_statistics]
      end

      def permissions_with_data_management
        base_permissions.insert(1, :read_admin_data_management)
      end

      where(:custom_roles_enabled, :data_management_enabled, :geo_enabled, :check_policy) do
        true  | true  | true  | be_allowed(*permissions_with_data_management)
        true  | true  | false | be_allowed(*base_permissions)
        true  | false | false | be_allowed(*base_permissions)
        false | true  | true  | be_disallowed(*base_permissions)
        false | true  | false | be_disallowed(*base_permissions)
        false | false | false | be_disallowed(*base_permissions)
      end

      with_them do
        before do
          create(:admin_member_role, :read_admin_monitoring, user: current_user)

          allow(::Gitlab::Geo).to receive(:enabled?).and_return(geo_enabled)
          stub_licensed_features(data_management: data_management_enabled, custom_roles: custom_roles_enabled)
        end

        it { is_expected.to check_policy }
      end
    end
  end

  describe 'manage duo core features' do
    let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
    let(:current_user) { admin }

    context 'when Duo Core features are not available', :enable_admin_mode do
      before do
        stub_licensed_features(code_suggestions: false, ai_chat: false)
      end

      it { is_expected.to be_disallowed(:update_duo_core_setting) }
    end

    context 'when Duo Core features are available' do
      context 'when user is not an admin' do
        let(:current_user) { user }

        it { is_expected.to be_disallowed(:update_duo_core_setting) }
      end

      context 'with admin mode disabled' do
        it { is_expected.to be_disallowed(:update_duo_core_setting) }
      end

      context 'with admin mode enabled', :enable_admin_mode do
        it { is_expected.to be_allowed(:update_duo_core_setting) }
      end
    end
  end

  describe 'update AI Gateway timeout' do
    let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
    let(:current_user) { admin }

    context 'when user is not an admin' do
      let(:current_user) { user }

      it { is_expected.to be_disallowed(:update_ai_gateway_timeout) }
    end

    context 'with admin mode disabled' do
      it { is_expected.to be_disallowed(:update_ai_gateway_timeout) }
    end

    context 'with admin mode enabled', :enable_admin_mode do
      it { is_expected.to be_allowed(:update_ai_gateway_timeout) }

      context 'when Duo Core features are not available' do
        before do
          stub_licensed_features(code_suggestions: false, ai_chat: false)
        end

        it { is_expected.to be_allowed(:update_ai_gateway_timeout) }
      end

      context 'on a Dedicated instance' do
        before do
          allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(true)
        end

        it { is_expected.to be_allowed(:update_ai_gateway_timeout) }
      end
    end
  end

  describe 'manage third party agents access' do
    using RSpec::Parameterized::TableSyntax

    describe ':create_third_party_agent_direct_access_token permission' do
      where(:direct_access_setting_disabled, :user_allowed, :check_policy) do
        false | true  | be_allowed(:create_third_party_agent_direct_access_token)
        false | false | be_disallowed(:create_third_party_agent_direct_access_token)
        true  | true  | be_disallowed(:create_third_party_agent_direct_access_token)
        true  | false | be_disallowed(:create_third_party_agent_direct_access_token)
      end

      with_them do
        before do
          stub_application_setting(disabled_direct_code_suggestions: direct_access_setting_disabled)
          allow(current_user).to receive(:allowed_to_use?).with(
            :duo_agent_platform, unit_primitive_name: :ai_gateway_model_provider_proxy
          ).and_return(user_allowed)
          allow(current_user).to receive(:duo_agent_platform_enabled_via_credits?).and_return(false)
        end

        it { is_expected.to check_policy }
      end

      context 'when user has no paid add-on but has credits with DAP enabled' do
        before do
          stub_application_setting(disabled_direct_code_suggestions: false)
          allow(current_user).to receive(:allowed_to_use?).with(
            :duo_agent_platform, unit_primitive_name: :ai_gateway_model_provider_proxy
          ).and_return(false)
          allow(current_user).to receive(:duo_agent_platform_enabled_via_credits?).and_return(true)
        end

        it { is_expected.to be_allowed(:create_third_party_agent_direct_access_token) }
      end

      context 'when user is anonymous' do
        let(:current_user) { nil }

        it { is_expected.to be_disallowed(:create_third_party_agent_direct_access_token) }
      end
    end
  end

  describe 'data management' do
    let(:current_user) { admin }

    where(:admin_mode, :data_management_available, :geo_enabled, :check_policy) do
      true  | true  | true  | be_allowed(:read_admin_data_management)
      true  | true  | false | be_disallowed(:read_admin_data_management)
      true  | false | true  | be_disallowed(:read_admin_data_management)
      true  | false | false | be_disallowed(:read_admin_data_management)
      false | true  | true  | be_disallowed(:read_admin_data_management)
      false | true  | false | be_disallowed(:read_admin_data_management)
      false | false | true  | be_disallowed(:read_admin_data_management)
      false | false | false | be_disallowed(:read_admin_data_management)
    end

    with_them do
      before do
        enable_admin_mode!(current_user) if admin_mode
        allow(::Gitlab::Geo).to receive(:enabled?).and_return(geo_enabled)
        stub_licensed_features(data_management: data_management_available)
      end

      it { is_expected.to check_policy }
    end
  end

  describe 'read_admin_knowledge_graph_settings' do
    let(:current_user) { admin }

    where(:admin_mode, :saas, :orbit_licensed, :ff_enabled, :check_policy) do
      true  | false | true  | true  | be_allowed(:read_admin_knowledge_graph_settings)
      true  | true  | true  | true  | be_disallowed(:read_admin_knowledge_graph_settings)
      true  | false | false | true  | be_disallowed(:read_admin_knowledge_graph_settings)
      true  | false | true  | false | be_disallowed(:read_admin_knowledge_graph_settings)
      false | false | true  | true  | be_disallowed(:read_admin_knowledge_graph_settings)
    end

    with_them do
      before do
        enable_admin_mode!(current_user) if admin_mode
        stub_saas_features(gitlab_com_subscriptions: saas)
        stub_licensed_features(orbit: orbit_licensed)
        stub_feature_flags(knowledge_graph: ff_enabled)
        stub_config(knowledge_graph: { 'enabled' => true })
      end

      it { is_expected.to check_policy }
    end

    context 'when user is non-admin' do
      let(:current_user) { user }

      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        stub_licensed_features(orbit: true)
        stub_feature_flags(knowledge_graph: true)
        stub_config(knowledge_graph: { 'enabled' => true })
      end

      it { is_expected.to be_disallowed(:read_admin_knowledge_graph_settings) }
    end
  end

  describe 'designating account beneficiaries' do
    where(:saas_feature_available, :is_enterprise_user, :check_policy) do
      true   | false  | be_allowed(:create_designated_account_beneficiaries)
      true   | true   | be_disallowed(:create_designated_account_beneficiaries)
      false  | false  | be_disallowed(:create_designated_account_beneficiaries)
      false  | true   | be_disallowed(:create_designated_account_beneficiaries)
    end

    with_them do
      let(:enterprise_group) { create(:group) }
      let(:enterprise_user) { create(:user, enterprise_group: enterprise_group) }
      let(:current_user) { is_enterprise_user ? enterprise_user : user }

      before do
        stub_saas_features(designated_account_beneficiaries: saas_feature_available)
      end

      it { is_expected.to check_policy }
    end
  end

  describe 'enterprise user disallowed personal snippets' do
    where(:is_enterprise_user, :allow_personal_snippets, :check_policy) do
      true   | false  | be_disallowed(:create_snippet)
      true   | true   | be_allowed(:create_snippet)
      false  | false  | be_allowed(:create_snippet)
      false  | true   | be_allowed(:create_snippet)
    end

    before do
      stub_licensed_features(allow_personal_snippets: true)
      stub_saas_features(allow_personal_snippets: true)
    end

    with_them do
      let(:enterprise_group) do
        create(:group).tap { |group| group.update!(allow_personal_snippets: allow_personal_snippets) }
      end

      let(:enterprise_user) { create(:user, enterprise_group: enterprise_group) }
      let(:current_user) { is_enterprise_user ? enterprise_user : user }

      it { is_expected.to check_policy }
    end
  end

  describe ':assign_default_duo_group' do
    describe 'When the instance is SAAS', :saas do
      context 'with no user assignments' do
        before do
          stub_application_setting(duo_features_enabled: true)
        end

        it { is_expected.to be_disallowed(:assign_default_duo_group) }
      end

      it { is_expected.to be_disallowed(:assign_default_duo_group) }
    end

    context 'with duo user assignments' do
      let!(:groups) { create_list(:group, 2) }

      let!(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :duo_pro) }

      let!(:add_on_purchases) do
        [
          create(:gitlab_subscription_add_on_purchase, namespace: groups[0], add_on: duo_pro_add_on),
          create(:gitlab_subscription_add_on_purchase, namespace: groups[1], add_on: duo_pro_add_on),
          create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: groups[0])
        ]
      end

      let!(:purchases_to_assign) { add_on_purchases }

      let!(:user_assignments) do
        purchases_to_assign.map do |purchase|
          create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: purchase, user: current_user)
        end
      end

      let(:duo_features_enabled) { true }
      let(:amazon_q_enabled) { false }

      before do
        stub_application_setting(duo_features_enabled: duo_features_enabled)

        groups.each do |group|
          group.add_reporter(current_user)
        end

        allow(::Ai::AmazonQ).to receive(:connected?).and_return(amazon_q_enabled)
      end

      context 'with seats assigned to user' do
        using RSpec::Parameterized::TableSyntax

        # Since this policy work with logical AND operator
        # We only need to test when one variable is false and the rest is true to validate it works correctly
        # This make this test more intelligible
        where(:amazon_q_enabled, :duo_features_enabled, :allowed?) do
          false | false | false
          true  | true  | false
          false | true  | true
        end

        with_them do
          it 'allows the user accordingly' do
            if allowed?
              is_expected.to be_allowed(:assign_default_duo_group)
            else
              is_expected.to be_disallowed(:assign_default_duo_group)
            end
          end
        end
      end
    end
  end

  describe ':update_governing_knowledge_graph_namespace' do
    context 'when SaaS', :saas do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when the knowledge_graph_billing feature flag is disabled' do
        before do
          stub_feature_flags(knowledge_graph_billing: false)
        end

        it { is_expected.to be_disallowed(:update_governing_knowledge_graph_namespace) }
      end

      context 'when user has no eligible candidate namespaces' do
        it { is_expected.to be_disallowed(:update_governing_knowledge_graph_namespace) }
      end

      context 'when user has a paid namespace with Orbit enabled' do
        let_it_be(:group) { create(:group) }

        before_all do
          create(:gitlab_subscription, :premium, namespace: group)
          create(:knowledge_graph_enabled_namespace, namespace: group)
          group.add_developer(current_user)
        end

        it { is_expected.to be_allowed(:update_governing_knowledge_graph_namespace) }
      end
    end

    context 'when self-managed' do
      let_it_be(:group) { create(:group) }

      before_all do
        group.add_developer(current_user)
      end

      it { is_expected.to be_disallowed(:update_governing_knowledge_graph_namespace) }
    end
  end
end
