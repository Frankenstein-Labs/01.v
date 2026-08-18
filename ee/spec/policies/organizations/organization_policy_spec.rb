# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::OrganizationPolicy, feature_category: :system_access do
  let_it_be(:organization) { create(:organization) }

  let_it_be(:owner) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:non_member) { create(:user) }
  let_it_be(:admin) { create(:user, :admin) }

  let(:current_user) { non_member }

  subject(:policy) { described_class.new(current_user, organization) }

  before_all do
    create(:organization_user, :owner, organization: organization, user: owner)
    create(:organization_user, organization: organization, user: guest, access_level: :default)
  end

  RSpec.shared_context 'with licensed features' do |features|
    before do
      stub_licensed_features(features)
    end
  end

  it { is_expected.to be_disallowed(:read_dependency) }
  it { is_expected.to be_disallowed(:read_licenses) }

  describe 'read_organization_analytics' do
    context 'when the user is an admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { is_expected.to be_allowed(:read_organization_analytics) }
      end

      context 'when admin mode is disabled' do
        it { is_expected.to be_disallowed(:read_organization_analytics) }
      end
    end

    context 'when the user is an organization owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(:read_organization_analytics) }
    end

    context 'when the user is an organization guest' do
      let(:current_user) { guest }

      it { is_expected.to be_allowed(:read_organization_analytics) }
    end

    context 'when the user is not a member of the organization' do
      let(:current_user) { non_member }

      it { is_expected.to be_disallowed(:read_organization_analytics) }
    end

    context 'when the user is anonymous' do
      let(:current_user) { nil }

      it { is_expected.to be_disallowed(:read_organization_analytics) }
    end
  end

  context 'when the user is an admin' do
    let(:current_user) { admin }

    context 'when admin mode is enabled', :enable_admin_mode do
      context 'when dependency scanning is enabled' do
        include_context 'with licensed features', dependency_scanning: true

        it { is_expected.to be_allowed(:read_dependency) }
      end

      context 'when license scanning is enabled' do
        include_context 'with licensed features', license_scanning: true

        it { is_expected.to be_allowed(:read_licenses) }
      end

      it { is_expected.to be_disallowed(:read_dependency) }
      it { is_expected.to be_disallowed(:read_licenses) }
    end

    context 'when admin mode is disabled' do
      it { is_expected.to be_disallowed(:read_dependency) }
      it { is_expected.to be_disallowed(:read_licenses) }
    end
  end

  context 'when the user is an organization owner' do
    let(:current_user) { owner }

    context 'when dependency scanning is enabled' do
      include_context 'with licensed features', dependency_scanning: true

      it { is_expected.to be_allowed(:read_dependency) }
    end

    context 'when license scanning is enabled' do
      include_context 'with licensed features', license_scanning: true

      it { is_expected.to be_allowed(:read_licenses) }
    end

    it { is_expected.to be_disallowed(:read_dependency) }
    it { is_expected.to be_disallowed(:read_licenses) }
  end

  context 'when the user is an organization guest' do
    let(:current_user) { guest }

    context 'when dependency scanning is enabled' do
      include_context 'with licensed features', dependency_scanning: true

      it { is_expected.to be_allowed(:read_dependency) }
    end

    context 'when license scanning is enabled' do
      include_context 'with licensed features', license_scanning: true

      it { is_expected.to be_allowed(:read_licenses) }
    end

    it { is_expected.to be_disallowed(:read_dependency) }
    it { is_expected.to be_disallowed(:read_licenses) }
  end

  describe 'security dashboard permissions' do
    context 'when security dashboard is licensed' do
      include_context 'with licensed features', security_dashboard: true

      context 'when the user is an organization owner' do
        let(:current_user) { owner }

        it { is_expected.to be_allowed(:read_security_resource) }
      end

      context 'when the user is an admin', :enable_admin_mode do
        let(:current_user) { admin }

        it { is_expected.to be_allowed(:read_security_resource) }
      end

      context 'when the user is an organization guest' do
        let(:current_user) { guest }

        it { is_expected.to be_disallowed(:read_security_resource) }
      end

      context 'when the user is not a member of the organization' do
        let(:current_user) { non_member }

        it { is_expected.to be_disallowed(:read_security_resource) }
      end

      context 'when the user is an admin without admin mode' do
        let(:current_user) { admin }

        it { is_expected.to be_disallowed(:read_security_resource) }
      end
    end

    context 'when security dashboard is not licensed' do
      let(:current_user) { owner }

      it { is_expected.to be_disallowed(:read_security_resource) }
    end
  end

  describe 'configurable work item types permissions' do
    let(:type_actions) { %i[create_work_item_type update_work_item_type] }
    let(:settings_actions) { %i[read_work_item_setting update_work_item_setting] }
    let(:actions) { type_actions + settings_actions }

    before do
      stub_licensed_features(configurable_work_item_types: true)
    end

    it { is_expected.to be_disallowed(*actions) }

    context 'when user is admin' do
      let(:current_user) { admin }

      it { is_expected.to be_disallowed(*actions) }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { is_expected.to be_allowed(*actions) }
      end
    end

    context 'when user is organization owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(*actions) }

      context 'when configurable work item types is not licensed' do
        before do
          stub_licensed_features(configurable_work_item_types: false)
        end

        it { is_expected.to be_disallowed(*actions) }
      end
    end

    context 'when user is organization member' do
      let(:current_user) { guest }

      it { is_expected.to be_disallowed(*actions) }
    end
  end

  describe 'custom dashboard permissions' do
    it { is_expected.to be_disallowed(:read_system_dashboard) }
    it { is_expected.to be_disallowed(:read_custom_dashboard) }
    it { is_expected.to be_disallowed(:create_custom_dashboard) }

    context 'when user is organization owner' do
      let(:current_user) { owner }

      it { is_expected.to be_allowed(:read_system_dashboard) }
      it { is_expected.to be_allowed(:read_custom_dashboard) }
      it { is_expected.to be_allowed(:create_custom_dashboard) }

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(custom_dashboard_storage: false)
        end

        it { is_expected.to be_allowed(:read_system_dashboard) }
        it { is_expected.to be_disallowed(:read_custom_dashboard) }
        it { is_expected.to be_disallowed(:create_custom_dashboard) }
      end

      context 'when the feature flag is enabled only for this user' do
        before do
          stub_feature_flags(custom_dashboard_storage: owner)
        end

        it { is_expected.to be_allowed(:read_custom_dashboard) }
        it { is_expected.to be_allowed(:create_custom_dashboard) }
      end

      context 'when the feature flag is enabled only for a different user' do
        before do
          stub_feature_flags(custom_dashboard_storage: create(:user))
        end

        it { is_expected.to be_disallowed(:read_custom_dashboard) }
        it { is_expected.to be_disallowed(:create_custom_dashboard) }
      end
    end

    context 'when user is organization member' do
      let(:current_user) { guest }

      it { is_expected.to be_allowed(:read_system_dashboard) }
      it { is_expected.to be_allowed(:read_custom_dashboard) }
      it { is_expected.to be_disallowed(:create_custom_dashboard) }

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(custom_dashboard_storage: false)
        end

        it { is_expected.to be_allowed(:read_system_dashboard) }
        it { is_expected.to be_disallowed(:read_custom_dashboard) }
        it { is_expected.to be_disallowed(:create_custom_dashboard) }
      end
    end

    context 'when user is an admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { is_expected.to be_allowed(:read_system_dashboard) }
        it { is_expected.to be_allowed(:read_custom_dashboard) }
        it { is_expected.to be_allowed(:create_custom_dashboard) }

        context 'when feature flag is disabled' do
          before do
            stub_feature_flags(custom_dashboard_storage: false)
          end

          it { is_expected.to be_allowed(:read_system_dashboard) }
          it { is_expected.to be_disallowed(:read_custom_dashboard) }
          it { is_expected.to be_disallowed(:create_custom_dashboard) }
        end
      end

      context 'when admin mode is disabled' do
        it { is_expected.to be_disallowed(:read_system_dashboard) }
        it { is_expected.to be_disallowed(:read_custom_dashboard) }
        it { is_expected.to be_disallowed(:create_custom_dashboard) }
      end
    end
  end

  [:read_govern_policy, :delete_govern_policy].each do |govern_policy_ability|
    describe govern_policy_ability.to_s do
      context 'when the user is an organization member' do
        let(:current_user) { guest }

        it { expect_disallowed(govern_policy_ability) }
      end

      context 'when the user is an organization owner' do
        let(:current_user) { owner }

        it { expect_allowed(govern_policy_ability) }
      end

      context 'when the user is an admin', :enable_admin_mode do
        let(:current_user) { admin }

        it { expect_allowed(govern_policy_ability) }
      end

      context 'when the user is not a member of the organization' do
        let(:current_user) { non_member }

        it { expect_disallowed(govern_policy_ability) }
      end

      context 'when the user is anonymous' do
        let(:current_user) { nil }

        it { expect_disallowed(govern_policy_ability) }
      end
    end
  end

  describe 'govern_policy write abilities' do
    let(:write_abilities) { [:create_govern_policy, :update_govern_policy, :delete_govern_policy] }

    context 'when the user is an organization member' do
      let(:current_user) { guest }

      it { expect_disallowed(*write_abilities) }
    end

    context 'when the user is an organization owner' do
      let(:current_user) { owner }

      it { expect_allowed(*write_abilities) }
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { expect_allowed(*write_abilities) }
    end

    context 'when the user is not a member of the organization' do
      let(:current_user) { non_member }

      it { expect_disallowed(*write_abilities) }
    end

    context 'when the user is anonymous' do
      let(:current_user) { nil }

      it { expect_disallowed(*write_abilities) }
    end
  end

  describe 'cd_application abilities' do
    context 'when the user is an organization member' do
      let(:current_user) { guest }

      it { expect_disallowed(:read_cd_application, :create_cd_application) }
    end

    context 'when the user is an organization owner' do
      let(:current_user) { owner }

      it { expect_allowed(:read_cd_application, :create_cd_application) }
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { expect_allowed(:read_cd_application, :create_cd_application) }
    end

    context 'when the user is not a member of the organization' do
      let(:current_user) { non_member }

      it { expect_disallowed(:read_cd_application, :create_cd_application) }
    end
  end

  describe 'cd_environment abilities' do
    context 'when the user is an organization member' do
      let(:current_user) { guest }

      it { expect_disallowed(:read_cd_environment, :create_cd_environment) }
    end

    context 'when the user is an organization owner' do
      let(:current_user) { owner }

      it { expect_allowed(:read_cd_environment, :create_cd_environment) }
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { expect_allowed(:read_cd_environment, :create_cd_environment) }
    end

    context 'when the user is not a member of the organization' do
      let(:current_user) { non_member }

      it { expect_disallowed(:read_cd_environment, :create_cd_environment) }
    end
  end

  describe 'cd_rollout abilities' do
    context 'when the user is an organization member' do
      let(:current_user) { guest }

      it { expect_disallowed(:create_cd_rollout) }
    end

    context 'when the user is an organization owner' do
      let(:current_user) { owner }

      it { expect_allowed(:create_cd_rollout) }
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { expect_allowed(:create_cd_rollout) }
    end

    context 'when the user is not a member of the organization' do
      let(:current_user) { non_member }

      it { expect_disallowed(:create_cd_rollout) }
    end
  end

  describe 'cd read abilities' do
    let(:read_abilities) do
      [
        :read_cd_service,
        :read_cd_artifact_source,
        :read_cd_version_set,
        :read_cd_application_flow_definition,
        :read_cd_rollout,
        :read_cd_application_link
      ]
    end

    context 'when the user is an organization member' do
      let(:current_user) { guest }

      it { expect_disallowed(*read_abilities) }
    end

    context 'when the user is an organization owner' do
      let(:current_user) { owner }

      it { expect_allowed(*read_abilities) }
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { expect_allowed(*read_abilities) }
    end

    context 'when the user is not a member of the organization' do
      let(:current_user) { non_member }

      it { expect_disallowed(*read_abilities) }
    end
  end

  describe 'duo_flow_callback_hook abilities' do
    let(:abilities) do
      [:create_duo_flow_callback_hook, :read_duo_flow_callback_hook, :delete_duo_flow_callback_hook]
    end

    context 'when the user is an organization member' do
      let(:current_user) { guest }

      it { expect_disallowed(*abilities) }
    end

    context 'when the user is an organization owner' do
      let(:current_user) { owner }

      it { expect_allowed(*abilities) }
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { expect_allowed(*abilities) }
    end

    context 'when the user is not a member of the organization' do
      let(:current_user) { non_member }

      it { expect_disallowed(*abilities) }
    end
  end
end
