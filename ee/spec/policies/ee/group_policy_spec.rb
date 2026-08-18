# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupPolicy, feature_category: :groups_and_projects do
  include AdminModeHelper
  include LoginHelpers

  using RSpec::Parameterized::TableSyntax

  def stub_group_saml_config(enabled)
    allow(::Gitlab::Auth::GroupSaml::Config).to receive_messages(enabled?: enabled)
  end

  include_context 'GroupPolicy context'
  # Can't move to GroupPolicy context because auditor trait is not present
  # outside of EE context and FOSS will fail on this
  let_it_be(:auditor) { create(:user, :auditor) }

  let(:epic_rules) do
    %i[
      read_epic
      create_epic
      admin_epic
      destroy_epic
      read_confidential_epic
      read_epic_board
      read_epic_board_list
      admin_epic_board
      admin_epic_board_list
    ]
  end

  let(:auditor_permissions) do
    %i[
      read_billing
      read_cluster
      read_confidential_issues
      read_container_image
      read_cycle_analytics
      read_group
      read_group_activity
      read_group_all_available_runners
      read_group_boards
      read_group_issues
      read_group_labels
      read_group_merge_requests
      read_group_metadata
      read_group_milestones
      read_group_security_dashboard
      read_issue
      read_issue_board
      read_issue_board_list
      read_label
      read_milestone
      read_namespace
      read_runners
      read_vulnerability
    ]
  end

  context 'when epics feature is disabled' do
    let(:current_user) { owner }

    it { expect_disallowed(*epic_rules) }
  end

  context 'when epics feature is enabled' do
    before do
      stub_licensed_features(epics: true)
    end

    context 'when user is owner' do
      let(:current_user) { owner }

      it { expect_allowed(*epic_rules) }
    end

    context 'when user is admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { expect_allowed(*epic_rules) }
      end

      context 'when admin mode is disabled' do
        it { expect_disallowed(*epic_rules) }
      end
    end

    context 'when user is maintainer' do
      let(:current_user) { maintainer }

      it { expect_allowed(*(epic_rules - [:destroy_epic])) }
      it { expect_disallowed(:destroy_epic) }
    end

    context 'when user is developer' do
      let(:current_user) { developer }

      it { expect_allowed(*(epic_rules - [:destroy_epic])) }
      it { expect_disallowed(:destroy_epic) }
    end

    context 'when user is reporter' do
      let(:current_user) { reporter }

      it { expect_allowed(*(epic_rules - [:destroy_epic])) }
      it { expect_disallowed(:destroy_epic) }
    end

    context 'when user is planner' do
      let(:current_user) { planner }

      it { expect_allowed(*epic_rules) }
    end

    context 'when user is guest' do
      let(:current_user) { guest }

      it { expect_allowed(:read_epic, :read_epic_board, :read_subgroup_epic) }
      it { expect_disallowed(*(epic_rules - [:read_epic, :read_epic_board, :read_epic_board_list])) }
    end

    context 'when user is support bot' do
      let_it_be(:current_user) { create(:support_bot) }

      before do
        allow(::ServiceDesk).to receive(:supported?).and_return(true)
      end

      context 'when group has at least one project with service desk enabled' do
        let_it_be(:project_with_service_desk) do
          create(:project, group: group, service_desk_enabled: true)
        end

        it { expect_allowed(:read_epic, :read_epic_iid) }
        it { expect_disallowed(*(epic_rules - [:read_epic, :read_epic_iid])) }
      end

      context 'when group does not have projects with service desk enabled' do
        let_it_be(:project_without_service_desk) do
          create(:project, group: group, service_desk_enabled: false)
        end

        it { expect_disallowed(*epic_rules) }
      end
    end

    context 'when user is not member' do
      let(:current_user) { non_group_member }

      it { expect_disallowed(*epic_rules) }
    end

    context 'when user is anonymous' do
      let(:current_user) { nil }

      it { expect_disallowed(*epic_rules) }
    end
  end

  describe 'govern_policy abilities' do
    let(:govern_policy_abilities) do
      [:create_govern_policy, :read_govern_policy, :update_govern_policy, :delete_govern_policy]
    end

    context 'when user is owner' do
      let(:current_user) { owner }

      it { expect_allowed(*govern_policy_abilities) }
    end

    context 'when user is admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { expect_allowed(*govern_policy_abilities) }
      end

      context 'when admin mode is disabled' do
        it { expect_disallowed(*govern_policy_abilities) }
      end
    end

    context 'when user is maintainer' do
      let(:current_user) { maintainer }

      it { expect_disallowed(*govern_policy_abilities) }
    end

    context 'when user is auditor' do
      let(:current_user) { auditor }

      it { expect_allowed(:read_govern_policy) }
      it { expect_disallowed(:create_govern_policy, :update_govern_policy, :delete_govern_policy) }
    end

    context 'when user is not member' do
      let(:current_user) { non_group_member }

      it { expect_disallowed(*govern_policy_abilities) }
    end

    context 'when user is anonymous' do
      let(:current_user) { nil }

      it { expect_disallowed(*govern_policy_abilities) }
    end
  end

  context 'when iterations feature is disabled' do
    let(:current_user) { owner }

    before do
      stub_licensed_features(iterations: false)
    end

    it 'disallows iteration actions' do
      expect_disallowed(:read_iteration, :create_iteration, :admin_iteration, :create_iteration_cadence,
        :admin_iteration_cadence)
    end
  end

  context 'when iterations feature is enabled' do
    let(:read_actions) { [:read_iteration, :read_iteration_cadence] }
    let(:edit_actions) { [:create_iteration, :admin_iteration, :create_iteration_cadence, :admin_iteration_cadence] }

    before do
      stub_licensed_features(iterations: true)
    end

    where(:role, :actions, :allowed) do
      :none     | ref(:read_actions) | false
      :none     | ref(:edit_actions) | false
      :guest    | ref(:read_actions) | true
      :guest    | ref(:edit_actions) | false
      :planner  | ref(:read_actions) | true
      :planner  | ref(:edit_actions) | true
      :reporter | ref(:read_actions) | true
      :reporter | ref(:edit_actions) | true
    end

    with_them do
      let(:current_user) { try(role) }

      it { is_expected.to(allowed ? be_allowed(*actions) : be_disallowed(*actions)) }
    end

    context 'when project is public' do
      let_it_be(:group) { create(:group, :public, :owner_subgroup_creation_only) }

      context 'when user is logged out' do
        let(:current_user) { nil }

        it { expect_allowed(:read_iteration, :read_iteration_cadence) }

        it 'disallows iteration write actions' do
          expect_disallowed(:create_iteration, :admin_iteration, :create_iteration_cadence, :admin_iteration_cadence)
        end
      end
    end
  end

  describe ':rollover_issues' do
    let_it_be(:automation_bot) { Users::Internal.in_organization(group.organization_id).automation_bot }

    context 'when iterations feature is disabled' do
      before do
        stub_licensed_features(iterations: false)
      end

      context 'when user is a reporter' do
        let(:current_user) { reporter }

        it { expect_disallowed(:rollover_issues) }
      end

      context 'when user is the automation bot' do
        let(:current_user) { automation_bot }

        it { expect_disallowed(:rollover_issues) }
      end
    end

    context 'when iterations feature is enabled' do
      before do
        stub_licensed_features(iterations: true)
      end

      where(:role, :allowed) do
        :anonymous        | false
        :non_group_member | false
        :guest            | false
        :planner          | false
        :reporter         | true
        :developer        | true
        :maintainer       | true
        :owner            | true
      end

      with_them do
        let(:current_user) { try(role) }

        it { is_expected.to(allowed ? be_allowed(:rollover_issues) : be_disallowed(:rollover_issues)) }
      end

      context 'when user is the automation bot' do
        let(:current_user) { automation_bot }

        it { expect_allowed(:rollover_issues) }
      end
    end
  end

  context 'when custom fields are available' do
    before do
      stub_licensed_features(custom_fields: true)
    end

    context 'when user is a guest' do
      let(:current_user) { guest }

      it { expect_allowed(:read_custom_field) }
      it { expect_disallowed(:admin_custom_field) }
    end

    context 'when user is a maintainer' do
      let(:current_user) { maintainer }

      it { expect_allowed(:read_custom_field, :admin_custom_field) }
    end

    context 'when user is logged out' do
      let(:current_user) { nil }

      it { expect_disallowed(:read_custom_field) }
    end
  end

  context 'when custom fields are not available' do
    let(:current_user) { guest }

    before do
      stub_licensed_features(custom_fields: false)
    end

    it { expect_disallowed(:read_custom_field, :admin_custom_field) }
  end

  context 'when cluster deployments is available' do
    let(:current_user) { maintainer }

    before do
      stub_licensed_features(cluster_deployments: true)
    end

    it { expect_allowed(:read_cluster_environments) }
  end

  context 'when cluster deployments is not available' do
    let(:current_user) { maintainer }

    before do
      stub_licensed_features(cluster_deployments: false)
    end

    it { expect_disallowed(:read_cluster_environments) }
  end

  context 'when security scan profiles is available' do
    let(:current_user) { maintainer }

    before do
      stub_licensed_features(security_scan_profiles: true)
    end

    it { expect_allowed(:create_security_scan_profiles) }
    it { expect_allowed(:update_security_scan_profiles) }
    it { expect_allowed(:delete_security_scan_profiles) }
  end

  context 'when security scan profiles is not available' do
    let(:current_user) { maintainer }

    before do
      stub_licensed_features(security_scan_profiles: false)
    end

    it 'prevents security scan profiles abilities' do
      expect_disallowed(
        :read_security_scan_profiles,
        :apply_security_scan_profiles,
        :create_security_scan_profiles,
        :update_security_scan_profiles,
        :delete_security_scan_profiles
      )
    end
  end

  describe 'invite_group_members policy' do
    context 'when on saas', :saas do
      let(:policy) { :invite_group_members }
      let(:app_setting) { :disable_invite_members }

      before do
        stub_saas_features(group_disable_invite_members: true)
      end

      context 'with disable_invite_members is available in license' do
        where(:role, :group_setting, :application_setting, :allowed) do
          :guest      | true | true | false
          :planner    | true | true | false
          :reporter   | true | true | false
          :developer  | true | true | false
          :maintainer | false | true | false
          :maintainer | true | true | false
          :owner      | false | true | true
          :owner      | false | false | true
          :owner      | true  | true | false
          :owner      | true  | false | false
          :admin      | false | true |  true
          :admin      | false | false | true
          :admin      | false | true | true
          :admin      | false | false | true
        end

        with_them do
          let(:current_user) { public_send(role) }

          before do
            stub_licensed_features(disable_invite_members: true)
            stub_application_setting(app_setting => application_setting)
            allow(group).to receive(:disable_invite_members?).and_return(group_setting)
            enable_admin_mode!(current_user) if role == :admin
          end

          it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
        end
      end

      context 'with disable_invite_members not available in license' do
        where(:role, :group_setting, :application_setting, :allowed) do
          :guest      | true | true | false
          :planner    | true | true | false
          :reporter   | true | true | false
          :developer  | true | true | false
          :maintainer | false | true |  false
          :maintainer | true | true   | false
          :owner      | false  | true | true
          :owner      | false  | false | true
          :owner      | true   | false | true
          :owner      | true   | true | true
          :admin      | false  | true | true
          :admin      | true | false | true
        end

        with_them do
          let(:current_user) { public_send(role) }

          before do
            stub_licensed_features(disable_invite_members: false)
            stub_application_setting(app_setting => application_setting)
            allow(group).to receive(:disable_invite_members?).and_return(group_setting)
            enable_admin_mode!(current_user) if role == :admin
          end

          it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
        end
      end
    end

    context 'when self-managed' do
      before do
        allow(Gitlab).to receive(:com?).and_return(false)
      end

      let(:app_setting) { :disable_invite_members }
      let(:policy) { :invite_group_members }

      context 'with disable_invite_members available in license' do
        where(:role, :setting, :admin_mode, :allowed) do
          :guest      | true  | nil    | false
          :planner    | true  | nil    | false
          :reporter   | true  | nil    | false
          :developer  | true  | nil    | false
          :maintainer | false | nil    | false
          :maintainer | true  | nil    | false
          :owner      | false | nil    | true
          :owner      | true  | nil    | false
          :admin      | false | false  | false
          :admin      | false | true   | true
          :admin      | true  | false  | false
        end

        with_them do
          let(:current_user) { public_send(role) }

          before do
            stub_licensed_features(disable_invite_members: true)
            stub_application_setting(app_setting => setting)
            enable_admin_mode!(current_user) if admin_mode
          end

          it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
        end
      end

      context 'with disable_invite_members not available in license' do
        where(:role, :setting, :admin_mode, :allowed) do
          :guest      | true  | nil    | false
          :planner    | true  | nil    | false
          :reporter   | true  | nil    | false
          :developer  | true  | nil    | false
          :maintainer | false | nil    | false
          :maintainer | true  | nil    | false
          :owner      | false | nil    | true
          :owner      | true  | nil    | true
          :admin      | false | false  | false
          :admin      | false | true   | true
          :admin      | true  | false  | false
          :admin      | true  | true   | true
        end

        with_them do
          let(:current_user) { public_send(role) }

          before do
            stub_licensed_features(disable_invite_members: false)
            stub_application_setting(app_setting => setting)
            enable_admin_mode!(current_user) if admin_mode
          end

          it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
        end
      end
    end
  end

  describe 'modify_value_stream_dashboard_settings policy' do
    context 'when analytics dashboard is available' do
      let(:current_user) { maintainer }

      before do
        stub_licensed_features(group_level_analytics_dashboard: true)
      end

      it { expect_allowed(:modify_value_stream_dashboard_settings) }

      context 'when the current user is the owner' do
        let(:current_user) { owner }

        it { expect_allowed(:modify_value_stream_dashboard_settings) }
      end

      context 'when the current user is admin', :enable_admin_mode do
        let(:current_user) { admin }

        it { expect_allowed(:modify_value_stream_dashboard_settings) }
      end

      context 'when a sub-group is given' do
        let_it_be(:sub_group) { create(:group, :private, parent: group) }

        subject { described_class.new(maintainer, sub_group) }

        it { expect_disallowed(:modify_value_stream_dashboard_settings) }
      end

      context 'when the user is not a maintainer' do
        let(:current_user) { developer }

        it { expect_disallowed(:modify_value_stream_dashboard_settings) }
      end
    end

    context 'when analytics dashboard is not available' do
      let(:current_user) { maintainer }

      before do
        stub_licensed_features(group_level_analytics_dashboard: false)
      end

      it { expect_disallowed(:modify_value_stream_dashboard_settings) }
    end
  end

  context 'when contribution analytics is available' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(contribution_analytics: true)
    end

    context 'when signed in user is a member of the group' do
      it 'allows contribution analytics abilities', :aggregate_failures do
        expect_allowed(:read_group_contribution_analytics)
        expect_allowed(:read_contribution_analytics)
      end
    end

    describe 'when user is not a member of the group' do
      let(:current_user) { non_group_member }
      let_it_be(:private_group) { create(:group, :private) }

      subject { described_class.new(non_group_member, private_group) }

      context 'when user is not invited to any of the group projects' do
        it 'prevents contribution analytics abilities', :aggregate_failures do
          expect_disallowed(:read_group_contribution_analytics)
          expect_disallowed(:read_contribution_analytics)
        end
      end

      context 'when user is invited to a group project, but not to the group' do
        let_it_be(:private_project) { create(:project, :private, group: private_group, guests: non_group_member) }

        it 'prevents contribution analytics abilities', :aggregate_failures do
          expect_disallowed(:read_group_contribution_analytics)
          expect_disallowed(:read_contribution_analytics)
        end
      end

      context 'when user has an auditor role' do
        before do
          allow(current_user).to receive(:auditor?).and_return(true)
        end

        it 'allows contribution analytics abilities', :aggregate_failures do
          expect_allowed(:read_group_contribution_analytics)
          expect_allowed(:read_contribution_analytics)
        end
      end
    end
  end

  context 'when contribution analytics is not available' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(contribution_analytics: false)
    end

    it 'prevents contribution analytics abilities', :aggregate_failures do
      expect_disallowed(:read_group_contribution_analytics)
      expect_disallowed(:read_contribution_analytics)
    end
  end

  context 'when dora4 analytics is available' do
    before do
      stub_licensed_features(dora4_analytics: true)
    end

    context 'when the user is a developer' do
      let(:current_user) { developer }

      it { expect_allowed(:read_dora4_analytics) }
    end

    context 'when the user is an auditor' do
      let(:current_user) { auditor }

      it { expect_allowed(:read_dora4_analytics) }
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { expect_allowed(:read_dora4_analytics) }
    end
  end

  context 'when dora4 analytics is not available' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(dora4_analytics: false)
    end

    it { expect_disallowed(:read_dora4_analytics) }
  end

  describe ':read_customizable_dashboards', :enable_admin_mode do
    where(:role, :allowed) do
      :guest     | false
      :planner   | false
      :reporter  | true
      :developer | true
      :admin     | true
    end

    with_them do
      let(:current_user) { public_send(role) }

      it 'allows or disallows read_customizable_dashboards based on role' do
        is_expected.to(
          allowed ? be_allowed(:read_customizable_dashboards) : be_disallowed(:read_customizable_dashboards)
        )
      end
    end
  end

  describe 'cd_application abilities' do
    # CD entities are organization-only. Group ownership is deferred to a later iteration.
    where(:role, :allowed) do
      :anonymous        | false
      :non_group_member | false
      :guest            | false
      :reporter         | false
      :developer        | false
      :maintainer       | false
      :owner            | false
    end

    with_them do
      let(:current_user) { try(role) }

      it { is_expected.to(allowed ? be_allowed(:read_cd_application) : be_disallowed(:read_cd_application)) }
      it { is_expected.to(allowed ? be_allowed(:create_cd_application) : be_disallowed(:create_cd_application)) }
    end
  end

  describe 'cd_environment abilities' do
    # CD entities are organization-only. Group ownership is deferred to a later iteration.
    where(:role, :allowed) do
      :anonymous        | false
      :non_group_member | false
      :guest            | false
      :reporter         | false
      :developer        | false
      :maintainer       | false
      :owner            | false
    end

    with_them do
      let(:current_user) { try(role) }

      it { is_expected.to(allowed ? be_allowed(:read_cd_environment) : be_disallowed(:read_cd_environment)) }
      it { is_expected.to(allowed ? be_allowed(:create_cd_environment) : be_disallowed(:create_cd_environment)) }
    end
  end

  describe ':read_enterprise_ai_analytics' do
    context 'when on SAAS', :saas do
      it_behaves_like 'ai permission to', :read_enterprise_ai_analytics
    end

    context 'when on self-managed' do
      it_behaves_like 'ai permission to', :read_enterprise_ai_analytics
    end
  end

  describe ':read_pro_ai_analytics' do
    context 'when on SAAS', :saas do
      it_behaves_like 'ai permission to', :read_pro_ai_analytics
    end

    context 'when on self-managed' do
      it_behaves_like 'ai permission to', :read_pro_ai_analytics
    end
  end

  describe 'analytics value streams' do
    context 'when feature is not available' do
      context 'and user is admin', :enable_admin_mode do
        let(:current_user) { admin }

        it { expect_disallowed(:admin_value_stream) }
      end

      context 'and user is reporter' do
        let(:current_user) { reporter }

        it { expect_disallowed(:admin_value_stream) }
      end
    end

    context 'when user feature is available' do
      before do
        stub_licensed_features(cycle_analytics_for_groups: true)
      end

      context 'and user is guest' do
        let(:current_user) { guest }

        it { expect_disallowed(:admin_value_stream) }
      end

      context 'and user is reporter' do
        let(:current_user) { reporter }

        it { expect_allowed(:admin_value_stream) }
      end

      context 'and user is admin', :enable_admin_mode do
        let(:current_user) { admin }

        it { expect_allowed(:admin_value_stream) }
      end
    end
  end

  context 'when exporting group memberships' do
    let(:current_user) { owner }

    context 'when exporting user permissions is not available' do
      before do
        stub_licensed_features(export_user_permissions: false)
      end

      it { expect_disallowed(:export_group_memberships) }
    end

    context 'when exporting user permissions is available' do
      before do
        stub_licensed_features(export_user_permissions: true)
      end

      it { expect_allowed(:export_group_memberships) }
    end
  end

  context 'when group activity analytics is available' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(group_activity_analytics: true)
    end

    it { expect_allowed(:read_group_activity_analytics) }
  end

  context 'when group activity analytics is not available' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(group_activity_analytics: false)
    end

    it { expect_disallowed(:read_group_activity_analytics) }
  end

  context 'when group CI/CD analytics' do
    shared_examples 'allows view_group_ci_cd_analytics for reporter+' do
      context 'when the user has at least reporter permissions' do
        let(:current_user) { reporter }

        it { expect_allowed(:view_group_ci_cd_analytics) }
      end

      context 'when the user has less than reporter permissions' do
        let(:current_user) { guest }

        it { expect_disallowed(:view_group_ci_cd_analytics) }
      end

      context 'when the user has auditor permissions' do
        let(:current_user) { auditor }

        it { expect_allowed(:view_group_ci_cd_analytics) }
      end
    end

    context 'when all group CI/CD analytics features are available' do
      before do
        stub_licensed_features(group_ci_cd_analytics_pipelines: true, group_ci_cd_analytics_releases: true)
      end

      it_behaves_like 'allows view_group_ci_cd_analytics for reporter+'
    end

    context 'when only pipelines feature is available' do
      before do
        stub_licensed_features(group_ci_cd_analytics_pipelines: true, group_ci_cd_analytics_releases: false)
      end

      it_behaves_like 'allows view_group_ci_cd_analytics for reporter+'
    end

    context 'when only releases feature is available' do
      before do
        stub_licensed_features(group_ci_cd_analytics_pipelines: false, group_ci_cd_analytics_releases: true)
      end

      it_behaves_like 'allows view_group_ci_cd_analytics for reporter+'
    end

    context 'when no group CI/CD analytics features are available' do
      let(:current_user) { reporter }

      before do
        stub_licensed_features(group_ci_cd_analytics_pipelines: false, group_ci_cd_analytics_releases: false)
      end

      it { expect_disallowed(:view_group_ci_cd_analytics) }
    end
  end

  context 'when group repository analytics is available' do
    before do
      stub_licensed_features(group_repository_analytics: true)
    end

    context 'for guests' do
      let(:current_user) { guest }

      it { expect_disallowed(:read_group_repository_analytics) }
    end

    context 'for reporter+' do
      let(:current_user) { reporter }

      it { expect_allowed(:read_group_repository_analytics) }
    end

    context 'for auditor' do
      let(:current_user) { auditor }

      it { expect_allowed(:read_group_repository_analytics) }
    end
  end

  context 'when group repository analytics is not available' do
    let(:current_user) { maintainer }

    before do
      stub_licensed_features(group_repository_analytics: false)
    end

    it { expect_disallowed(:read_group_repository_analytics) }
  end

  context 'when group cycle analytics is available' do
    before do
      stub_licensed_features(cycle_analytics_for_groups: true)
    end

    context 'for guests' do
      let(:current_user) { guest }

      it { expect_disallowed(:read_cycle_analytics) }
      it { expect_disallowed(:read_group_stage) }
      it { expect_disallowed(:view_type_of_work_charts) }
    end

    context 'for reporter+' do
      let(:current_user) { reporter }

      it { expect_allowed(:read_cycle_analytics) }
      it { expect_allowed(:read_group_stage) }
      it { expect_allowed(:view_type_of_work_charts) }
    end

    context 'for auditor' do
      let(:current_user) { auditor }

      it { expect_allowed(:read_cycle_analytics) }
      it { expect_allowed(:read_group_stage) }
      it { expect_allowed(:view_type_of_work_charts) }
    end
  end

  context 'when group cycle analytics is not available' do
    let(:current_user) { maintainer }

    before do
      stub_licensed_features(cycle_analytics_for_groups: false)
    end

    it { expect_disallowed(:read_cycle_analytics) }
  end

  context 'when group coverage reports is available' do
    before do
      stub_licensed_features(group_coverage_reports: true)
    end

    context 'for guests' do
      let(:current_user) { guest }

      it { expect_disallowed(:read_group_coverage_reports) }
    end

    context 'for reporter+' do
      let(:current_user) { reporter }

      it { expect_allowed(:read_group_coverage_reports) }
    end
  end

  context 'when group coverage reports is not available' do
    let(:current_user) { maintainer }

    before do
      stub_licensed_features(group_coverage_reports: false)
    end

    it { expect_disallowed(:read_group_coverage_reports) }
  end

  describe 'per group SAML' do
    context 'when group_saml is unavailable' do
      let(:current_user) { owner }

      context 'when group saml config is disabled' do
        before do
          stub_group_saml_config(false)
        end

        it { expect_disallowed(:admin_group_saml) }
      end

      context 'when the group is a subgroup' do
        before do
          stub_group_saml_config(true)
        end

        subject { described_class.new(current_user, subgroup) }

        it { expect_disallowed(:admin_group_saml) }
      end

      context 'when the feature is not licensed' do
        before do
          stub_group_saml_config(true)
          stub_licensed_features(group_saml: false)
        end

        it { expect_disallowed(:admin_group_saml) }
      end
    end

    context 'when group_saml is available' do
      before do
        stub_licensed_features(group_saml: true)
      end

      context 'when group_saml_group_sync is not licensed' do
        context 'with an enabled SAML provider' do
          let_it_be(:saml_provider) { create(:saml_provider, group: group, enabled: true) }

          context 'when user is owner' do
            let(:current_user) { owner }

            it { expect_disallowed(:admin_saml_group_links) }
          end

          context 'when user is admin' do
            let(:current_user) { admin }

            it 'is disallowed even with admin mode', :enable_admin_mode do
              expect_disallowed(:admin_saml_group_links)
            end
          end
        end
      end

      context 'when group_saml_group_sync is licensed', :saas do
        before do
          stub_group_saml_config(true)
          stub_application_setting(check_namespace_plan: true)
        end

        before_all do
          create(:license, plan: License::ULTIMATE_PLAN)
          create(:gitlab_subscription, :premium, namespace: group)
        end

        context 'without an enabled SAML provider' do
          context 'when user is maintainer' do
            let(:current_user) { maintainer }

            it { expect_disallowed(:admin_group_saml) }
            it { expect_disallowed(:admin_saml_group_links) }
          end

          context 'when user is owner' do
            let(:current_user) { owner }

            it { expect_allowed(:admin_group_saml) }
            it { expect_disallowed(:admin_saml_group_links) }
          end

          context 'when user is admin' do
            let(:current_user) { admin }

            context 'when admin mode is enabled', :enable_admin_mode do
              it { expect_allowed(:admin_group_saml) }
              it { expect_disallowed(:admin_saml_group_links) }
            end

            context 'when admin mode is disabled' do
              it { expect_disallowed(:admin_group_saml) }
              it { expect_disallowed(:admin_saml_group_links) }
            end
          end
        end

        context 'with an enabled SAML provider' do
          let_it_be(:saml_provider) { create(:saml_provider, group: group, enabled: true) }

          context 'when user is maintainer' do
            let(:current_user) { maintainer }

            it { expect_disallowed(:admin_saml_group_links) }
          end

          context 'when user is owner' do
            let(:current_user) { owner }

            it { expect_allowed(:admin_saml_group_links) }
          end

          context 'when user is admin' do
            let(:current_user) { admin }

            context 'when admin mode is enabled', :enable_admin_mode do
              it { expect_allowed(:admin_saml_group_links) }
            end

            context 'when admin mode is disabled' do
              it { expect_disallowed(:admin_saml_group_links) }
            end
          end

          context 'when the group is a subgroup' do
            let(:current_user) { owner }

            subject { described_class.new(current_user, subgroup) }

            it { expect_allowed(:admin_saml_group_links) }
          end
        end
      end

      context 'with SSO enforcement enabled' do
        let(:current_user) { guest }

        let_it_be(:saml_provider) { create(:saml_provider, group: group, enforced_sso: true) }

        context 'when in context of the user web activity' do
          around do |example|
            session = {}

            session['warden.user.user.key'] = [[current_user.id], current_user.authenticatable_salt]

            Gitlab::Session.with_session(session) do
              example.run
            end
          end

          it 'prevents access without a SAML session' do
            expect_disallowed(:read_group)
          end

          it 'allows access with a SAML session' do
            Gitlab::Auth::GroupSaml::SsoEnforcer.new(saml_provider).update_session

            expect_allowed(:read_group)
          end
        end

        context 'when there is no global session or sso state' do
          it "allows access because we haven't yet restricted all use cases" do
            expect_allowed(:read_group)
          end

          context 'when the current user is a deploy token' do
            let(:current_user) { create(:deploy_token, :group, groups: [group], read_package_registry: true) }

            it 'allows access without a SAML session' do
              expect_allowed(:read_group)
            end
          end
        end
      end

      context 'without SSO enforcement enabled' do
        let(:current_user) { guest }

        let_it_be(:saml_provider) { create(:saml_provider, group: group, enforced_sso: false) }

        context 'when in context of the user web activity' do
          around do |example|
            session = {}

            session['warden.user.user.key'] = [[current_user.id], current_user.authenticatable_salt]

            Gitlab::Session.with_session(session) do
              example.run
            end
          end

          it 'allows access when the user has no Group SAML identity' do
            expect_allowed(:read_group)
          end
        end

        context 'when there is no global session or sso state' do
          context 'when the current user is a deploy token' do
            let(:current_user) { create(:deploy_token, :group, groups: [group], read_package_registry: true) }

            it 'allows access without a SAML session' do
              expect_allowed(:read_group)
            end
          end
        end
      end
    end

    context 'when reading a group' do
      context 'when SAML SSO is enabled for resource' do
        let(:saml_provider) { create(:saml_provider, enabled: true, enforced_sso: false) }
        let(:identity) { create(:group_saml_identity, saml_provider: saml_provider) }
        let(:root_group) { saml_provider.group }
        let(:subgroup) { create(:group, parent: root_group) }
        let(:member_with_identity) { identity.user }
        let(:member_without_identity) { create(:user) }
        let(:non_member) { create(:user) }
        let(:not_signed_in_user) { nil }

        before do
          stub_licensed_features(group_saml: true, auditor_user: true)
          root_group.add_developer(member_with_identity)
          root_group.add_developer(member_without_identity)
        end

        subject { described_class.new(current_user, resource) }

        shared_examples 'does not allow read group' do
          it 'does not allow read group' do
            expect_disallowed(:read_group)
          end
        end

        shared_examples 'allows to read group' do
          it 'allows read group' do
            expect_allowed(:read_group)
          end
        end

        shared_examples 'does not allow to read group due to its visibility level' do
          it 'does not allow to read group due to its visibility level', :aggregate_failures do
            expect(resource.root_ancestor.saml_provider.enforced_sso?).to be(false)

            expect_disallowed(:read_group)
          end
        end

        # See https://docs.gitlab.com/ee/user/group/saml_sso/#sso-enforcement
        where(:resource, :resource_visibility_level, :enforced_sso?, :user, :user_is_resource_owner?,
          :user_with_saml_session?, :user_is_admin?, :enable_admin_mode?, :user_is_auditor?, :shared_examples) do
          # Project/Group visibility: Private; Enforce SSO setting: Off

          ref(:root_group) | 'private' | false | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:root_group) | 'private' | false | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'private' | false | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'private' | false | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read group'
          ref(:root_group) | 'private' | false | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read group'
          ref(:root_group) | 'private' | false | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read group'
          ref(:subgroup)   | 'private' | false | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | false | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | false | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'private' | false | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | false | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read group'
          ref(:subgroup)   | 'private' | false | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read group'

          ref(:root_group) | 'private' | false | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'private' | false | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'allows to read group'

          ref(:root_group) | 'private' | false | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'does not allow to read group due to its visibility level'
          ref(:root_group) | 'private' | false | ref(:non_member)              | nil   | nil   | true | false | nil  | 'does not allow to read group due to its visibility level'
          ref(:root_group) | 'private' | false | ref(:non_member)              | nil   | nil   | true | true  | nil  | 'allows to read group'
          ref(:root_group) | 'private' | false | ref(:non_member)              | nil   | nil   | nil  | nil   | true | 'allows to read group'
          ref(:root_group) | 'private' | false | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'does not allow to read group due to its visibility level'
          ref(:subgroup)   | 'private' | false | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'does not allow to read group due to its visibility level'
          ref(:subgroup)   | 'private' | false | ref(:non_member)              | nil   | nil   | true | false | nil  | 'does not allow to read group due to its visibility level'
          ref(:subgroup)   | 'private' | false | ref(:non_member)              | nil   | nil   | true | true  | nil  | 'allows to read group'
          ref(:subgroup)   | 'private' | false | ref(:non_member)              | nil   | nil   | nil  | nil   | true | 'allows to read group'
          ref(:subgroup)   | 'private' | false | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'does not allow to read group due to its visibility level'

          # Project/Group visibility: Private; Enforce SSO setting: On

          ref(:root_group) | 'private' | true  | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:root_group) | 'private' | true  | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'private' | true  | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'private' | true  | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read group'
          ref(:root_group) | 'private' | true  | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read group'
          ref(:root_group) | 'private' | true  | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read group'

          ref(:root_group) | 'private' | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'does not allow read group'
          ref(:root_group) | 'private' | true  | ref(:member_without_identity) | true  | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'private' | true  | ref(:member_without_identity) | false | nil   | true | false | nil  | 'does not allow read group'
          ref(:root_group) | 'private' | true  | ref(:member_without_identity) | false | nil   | true | true  | nil  | 'allows to read group'
          ref(:root_group) | 'private' | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | true | 'allows to read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_without_identity) | true  | nil   | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_without_identity) | false | nil   | true | false | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_without_identity) | false | nil   | true | true  | nil  | 'allows to read group'
          ref(:subgroup)   | 'private' | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | true | 'allows to read group'

          ref(:root_group) | 'private' | true  | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'does not allow read group'
          ref(:root_group) | 'private' | true  | ref(:non_member)              | nil   | nil   | true | false | nil  | 'does not allow read group'
          ref(:root_group) | 'private' | true  | ref(:non_member)              | nil   | nil   | true | true  | nil  | 'allows to read group'
          ref(:root_group) | 'private' | true  | ref(:non_member)              | nil   | nil   | nil  | nil   | true | 'allows to read group'
          ref(:root_group) | 'private' | true  | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | true  | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | true  | ref(:non_member)              | nil   | nil   | true | false | nil  | 'does not allow read group'
          ref(:subgroup)   | 'private' | true  | ref(:non_member)              | nil   | nil   | true | true  | nil  | 'allows to read group'
          ref(:subgroup)   | 'private' | true  | ref(:non_member)              | nil   | nil   | nil  | nil   | true | 'allows to read group'
          ref(:subgroup)   | 'private' | true  | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'does not allow read group'

          # Project/Group visibility: Public; Enforce SSO setting: Off

          ref(:root_group) | 'public'  | false | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:root_group) | 'public'  | false | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | false | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | false | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read group'
          ref(:root_group) | 'public'  | false | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | false | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read group'
          ref(:subgroup)   | 'public'  | false | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'public'  | false | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'public'  | false | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | false | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read group'
          ref(:subgroup)   | 'public'  | false | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | false | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read group'

          ref(:root_group) | 'public'  | false | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | false | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'allows to read group'

          ref(:root_group) | 'public'  | false | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | false | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | false | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | false | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'allows to read group'

          # Project/Group visibility: Public; Enforce SSO setting: On

          ref(:root_group) | 'public'  | true  | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:root_group) | 'public'  | true  | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | true  | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | true  | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read group'
          ref(:root_group) | 'public'  | true  | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | true  | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_with_identity)    | false | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_with_identity)    | true  | false | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_with_identity)    | false | true  | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_with_identity)    | false | false | true | false | nil  | 'does not allow read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_with_identity)    | false | false | true | true  | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_with_identity)    | false | false | nil  | nil   | true | 'allows to read group'

          ref(:root_group) | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'does not allow read group'
          ref(:root_group) | 'public'  | true  | ref(:member_without_identity) | true  | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | true  | ref(:member_without_identity) | false | nil   | true | false | nil  | 'does not allow read group'
          ref(:root_group) | 'public'  | true  | ref(:member_without_identity) | false | nil   | true | true  | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | true | 'allows to read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_without_identity) | true  | nil   | nil  | nil   | nil  | 'does not allow read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_without_identity) | false | nil   | true | false | nil  | 'does not allow read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_without_identity) | false | nil   | true | true  | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil  | nil   | true | 'allows to read group'

          ref(:root_group) | 'public'  | true  | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:root_group) | 'public'  | true  | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | true  | ref(:non_member)              | nil   | nil   | nil  | nil   | nil  | 'allows to read group'
          ref(:subgroup)   | 'public'  | true  | ref(:not_signed_in_user)      | nil   | nil   | nil  | nil   | nil  | 'allows to read group'
        end

        with_them do
          context "when SSO-only enforcement option is #{params[:enforced_sso?] ? 'enabled' : 'not enabled'}" do
            around do |example|
              session = {}

              session['warden.user.user.key'] = [[user.id], user.authenticatable_salt] if user.is_a?(User)

              Gitlab::Session.with_session(session) do
                example.run
              end
            end

            before do
              saml_provider.update!(enforced_sso: enforced_sso?)
            end

            context "when resource is #{params[:resource_visibility_level]}" do
              before do
                resource.update!(visibility_level: Gitlab::VisibilityLevel.string_options[resource_visibility_level])
              end

              context 'for user', enable_admin_mode: params[:enable_admin_mode?] do
                before do
                  if user_is_resource_owner?
                    resource.root_ancestor.member(user).update_column(:access_level, Gitlab::Access::OWNER)
                  end

                  Gitlab::Auth::GroupSaml::SsoEnforcer.new(saml_provider).update_session if user_with_saml_session?

                  user.update!(admin: true) if user_is_admin?
                  user.update!(auditor: true) if user_is_auditor?
                end

                let(:current_user) { user }

                include_examples params[:shared_examples]
              end
            end
          end
        end
      end
    end
  end

  describe 'admin_saml_group_links for global SAML' do
    let(:current_user) { owner }

    it { expect_disallowed(:admin_saml_group_links) }

    context 'when global SAML is enabled' do
      context 'when the groups attribute is not configured' do
        before do
          stub_basic_saml_config
        end

        it { expect_disallowed(:admin_saml_group_links) }
      end

      context 'when the groups attribute is configured' do
        before do
          stub_omniauth_config(providers: [{ name: 'saml', groups_attribute: 'Groups', args: {} }])
        end

        it { expect_disallowed(:admin_saml_group_links) }

        context 'when saml_group_sync feature is licensed' do
          before do
            stub_licensed_features(saml_group_sync: true)
          end

          it { expect_allowed(:admin_saml_group_links) }

          context 'when the current user is not an admin or owner' do
            let(:current_user) { maintainer }

            it { expect_disallowed(:admin_saml_group_links) }
          end
        end
      end
    end
  end

  context 'with ip restriction' do
    let(:current_user) { maintainer }

    before do
      allow(Gitlab::IpAddressState).to receive(:current).and_return('192.168.0.2')
      stub_licensed_features(group_ip_restriction: true, epics: true)
      stub_config(dependency_proxy: { enabled: true })
    end

    context 'without restriction' do
      it { expect_allowed(:read_group) }
      it { expect_allowed(:read_milestone) }
      it { expect_allowed(:read_package) }
      it { expect_allowed(:create_package) }
      it { expect_allowed(:destroy_package) }
      it { expect_allowed(:create_epic) }
      it { expect_allowed(:read_dependency_proxy) }
      it { expect_disallowed(:admin_package) }
      it { expect_disallowed(:admin_dependency_proxy) }
    end

    context 'with restriction' do
      before do
        create(:ip_restriction, group: group, range: range)
      end

      context 'when address is within the range' do
        let(:range) { '192.168.0.0/24' }

        it { expect_allowed(:read_group) }
        it { expect_allowed(:read_milestone) }
        it { expect_allowed(:read_package) }
        it { expect_allowed(:create_package) }
        it { expect_allowed(:destroy_package) }
        it { expect_allowed(:create_epic) }
        it { expect_allowed(:read_dependency_proxy) }
        it { expect_disallowed(:admin_package) }
        it { expect_disallowed(:admin_dependency_proxy) }
      end

      context 'when address is outside the range' do
        let(:range) { '10.0.0.0/8' }

        context 'as maintainer' do
          it { expect_disallowed(:read_group) }
          it { expect_disallowed(:read_milestone) }
          it { expect_disallowed(:read_package) }
          it { expect_disallowed(:create_package) }
          it { expect_disallowed(:destroy_package) }
          it { expect_disallowed(:create_epic) }
          it { expect_disallowed(:admin_package) }
          it { expect_disallowed(:read_dependency_proxy) }
          it { expect_disallowed(:admin_dependency_proxy) }
        end

        context 'as owner' do
          let(:current_user) { owner }

          it { expect_allowed(:read_group) }
          it { expect_allowed(:read_milestone) }
          it { expect_allowed(:read_package) }
          it { expect_allowed(:create_package) }
          it { expect_allowed(:destroy_package) }
          it { expect_allowed(:admin_package) }
          it { expect_allowed(:read_dependency_proxy) }
          it { expect_allowed(:admin_dependency_proxy) }
        end

        context 'as auditor' do
          let(:current_user) { auditor }

          it { expect_allowed(:read_group) }
          it { expect_allowed(:read_milestone) }
          it { expect_allowed(:read_audit_event) }
          it { expect_allowed(:read_dependency_proxy) }
          it { expect_disallowed(:admin_dependency_proxy) }
        end
      end
    end
  end

  context 'when LDAP sync is not enabled' do
    context 'when user is owner' do
      let(:current_user) { owner }

      it { expect_disallowed(:override_group_member) }
      it { expect_allowed(:admin_ldap_group_links) }

      context 'when group owners cannot manage ldap' do
        before do
          stub_application_setting(allow_group_owners_to_manage_ldap: false)
        end

        it { expect_disallowed(:admin_ldap_group_links) }
      end
    end

    context 'when user is admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { expect_disallowed(:override_group_member) }
        it { expect_allowed(:admin_ldap_group_links) }
      end

      context 'when admin mode is disabled' do
        it { expect_disallowed(:override_group_member) }
        it { expect_disallowed(:admin_ldap_group_links) }
      end
    end
  end

  context 'when memberships locked to SAML' do
    let(:saml_with_group_sync) do
      {
        name: 'saml',
        groups_attribute: 'groups',
        external_groups: [],
        args: {}
      }
    end

    before do
      stub_application_setting(lock_memberships_to_saml: true)
      stub_licensed_features(saml_group_sync: true)
    end

    context 'when group is a root group' do
      before do
        stub_omniauth_config(providers: [saml_with_group_sync])
        allow(Devise).to receive(:omniauth_providers).and_return([:saml])
      end

      context 'when SAML group link sync is enabled' do
        before_all do
          create(:saml_group_link, group: group)
        end

        context 'when user is admin' do
          let(:current_user) { admin }

          context 'when admin mode is enabled', :enable_admin_mode do
            it { expect_allowed(:admin_group_member) }
          end

          context 'when admin mode is disabled' do
            it { expect_disallowed(:admin_group_member) }
          end
        end

        context 'when user is owner' do
          let(:current_user) { owner }

          it { expect_disallowed(:admin_group_member) }
        end

        context 'when user is maintainer' do
          let(:current_user) { maintainer }

          it { expect_disallowed(:admin_group_member) }
        end
      end

      context 'when no SAML sync is enabled' do
        before do
          allow(group).to receive(:saml_group_links_exists?).and_return(false)
        end

        context 'when user is admin' do
          let(:current_user) { admin }

          it { expect_disallowed(:admin_group_member) }
        end

        context 'when user is owner' do
          let(:current_user) { owner }

          it { expect_allowed(:admin_group_member) }
        end
      end
    end

    context 'when group is not a root group' do
      let_it_be(:parent_group) { create(:group, owners: owner) }
      let_it_be(:group) { create(:group, :private, parent: parent_group, owners: owner) }

      before do
        stub_omniauth_config(providers: [saml_with_group_sync])
        allow(Devise).to receive(:omniauth_providers).and_return([:saml])
      end

      context 'when SAML group link sync is enabled' do
        before_all do
          create(:saml_group_link, group: parent_group)
        end

        context 'when user is admin' do
          let(:current_user) { admin }

          context 'when admin mode is enabled', :enable_admin_mode do
            it { expect_allowed(:admin_group_member) }
          end

          context 'when admin mode is disabled' do
            it { expect_disallowed(:admin_group_member) }
          end
        end

        context 'when user is owner' do
          let(:current_user) { owner }

          it { expect_disallowed(:admin_group_member) }
        end

        context 'when user is maintainer' do
          let(:current_user) { maintainer }

          it { expect_disallowed(:admin_group_member) }
        end

        context 'when child group has different owner than parent group' do
          let_it_be(:sub_group_owner) { create(:user, owner_of: group) }
          let(:current_user) { sub_group_owner }

          it { expect_disallowed(:admin_group_member) }
        end
      end

      context 'when no SAML group link sync is enabled' do
        before do
          allow(group).to receive(:saml_group_links_exists?).and_return(false)
        end

        context 'when user is admin' do
          let(:current_user) { admin }

          it { expect_disallowed(:admin_group_member) }
        end

        context 'when user is owner' do
          let(:current_user) { owner }

          it { expect_allowed(:admin_group_member) }
        end

        context 'when user is maintainer' do
          let(:current_user) { maintainer }

          it { expect_disallowed(:admin_group_member) }
        end
      end
    end

    context 'when group is synced via GroupSaml', :saas do
      before do
        stub_licensed_features(group_saml: true, saml_group_sync: true)
        stub_group_saml_config(true)
        create(:saml_provider, group: group.root_ancestor, enabled: true)
      end

      context 'when SAML group link is configured' do
        before_all do
          create(:saml_group_link, group: group)
        end

        context 'when user is admin' do
          let(:current_user) { admin }

          context 'when admin mode is enabled', :enable_admin_mode do
            it { expect_allowed(:admin_group_member) }
          end

          context 'when admin mode is disabled' do
            it { expect_disallowed(:admin_group_member) }
          end
        end

        context 'when user is owner' do
          let(:current_user) { owner }

          it { expect_disallowed(:admin_group_member) }
        end

        context 'when user is maintainer' do
          let(:current_user) { maintainer }

          it { expect_disallowed(:admin_group_member) }
        end
      end

      context 'when SAML group link is not configured' do
        before do
          allow(group).to receive(:saml_group_links_exists?).and_return(false)
        end

        context 'when user is admin' do
          let(:current_user) { admin }

          it { expect_disallowed(:admin_group_member) }
        end

        context 'when user is owner' do
          let(:current_user) { owner }

          it { expect_allowed(:admin_group_member) }
        end
      end
    end
  end

  context 'when LDAP sync is enabled' do
    before do
      allow(group).to receive(:ldap_synced?).and_return(true)
    end

    context 'with no user' do
      let(:current_user) { nil }

      it { expect_disallowed(:override_group_member) }
      it { expect_disallowed(:admin_ldap_group_links) }
    end

    context 'when user is guest' do
      let(:current_user) { guest }

      it { expect_disallowed(:override_group_member) }
      it { expect_disallowed(:admin_ldap_group_links) }
    end

    context 'when user is planner' do
      let(:current_user) { planner }

      it { expect_disallowed(:override_group_member) }
      it { expect_disallowed(:admin_ldap_group_links) }
    end

    context 'when user is reporter' do
      let(:current_user) { reporter }

      it { expect_disallowed(:override_group_member) }
      it { expect_disallowed(:admin_ldap_group_links) }
    end

    context 'when user is developer' do
      let(:current_user) { developer }

      it { expect_disallowed(:override_group_member) }
      it { expect_disallowed(:admin_ldap_group_links) }
    end

    context 'when user is maintainer' do
      let(:current_user) { maintainer }

      it { expect_disallowed(:override_group_member) }
      it { expect_disallowed(:admin_ldap_group_links) }
    end

    context 'when user is owner' do
      let(:current_user) { owner }

      context 'when group owners can manage ldap' do
        it { expect_allowed(:override_group_member) }
      end

      context 'when group owners cannot manage ldap' do
        before do
          stub_application_setting(allow_group_owners_to_manage_ldap: false)
        end

        it { expect_disallowed(:override_group_member) }
        it { expect_disallowed(:admin_ldap_group_links) }
      end
    end

    context 'when user is admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { expect_allowed(:override_group_member) }
        it { expect_allowed(:admin_ldap_group_links) }
      end

      context 'when admin mode is disabled' do
        it { expect_disallowed(:override_group_member) }
        it { expect_disallowed(:admin_ldap_group_links) }
      end
    end

    context 'when memberships locked to LDAP' do
      before do
        stub_application_setting(allow_group_owners_to_manage_ldap: true)
        stub_application_setting(lock_memberships_to_ldap: true)
      end

      context 'when user is admin' do
        let(:current_user) { admin }

        context 'when admin mode enabled', :enable_admin_mode do
          it { expect_allowed(:override_group_member) }
          it { expect_allowed(:update_group_member) }
        end

        context 'when admin mode disabled' do
          it { expect_disallowed(:override_group_member) }
          it { expect_disallowed(:update_group_member) }
        end
      end

      context 'when user is owner' do
        let(:current_user) { owner }

        it { expect_disallowed(:admin_group_member) }
        it { expect_disallowed(:override_group_member) }
        it { expect_disallowed(:update_group_member) }
        it { expect_allowed(:admin_service_account_member) }
      end
    end
  end

  describe 'read_group_credentials_inventory' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:non_member) { create(:user) }
    let_it_be(:read_policy) { :read_group_credentials_inventory }
    let_it_be(:admin_policy) { :admin_group_credentials_inventory }

    where(:user, :admin_mode?, :saas?, :licensed?, :allowed) do
      ref(:admin)      | false | false | false | false
      ref(:admin)      | true  | false | false | false
      ref(:admin)      | true  | true  | false | false
      ref(:admin)      | false | false | true  | false
      ref(:admin)      | false | true  | true  | false
      ref(:admin)      | true  | false | true  | false
      ref(:admin)      | false | true  | false | false
      ref(:admin)      | true  | true  | true  | true

      ref(:owner)      | nil   | false | false | false
      ref(:owner)      | nil   | true  | false | false
      ref(:owner)      | nil   | false | true  | false
      ref(:owner)      | nil   | true  | false | false
      ref(:owner)      | nil   | true  | true  | true

      ref(:maintainer) | nil   | true  | true  | false
      ref(:developer)  | nil   | true  | true  | false
      ref(:reporter)   | nil   | true  | true  | false
      ref(:guest)      | nil   | true  | true  | false
      ref(:non_member) | nil   | true  | true  | false
      nil              | nil   | true  | true  | false
    end

    with_them do
      let(:current_user) { user }

      before do
        stub_licensed_features(credentials_inventory: licensed?)
      end

      context 'for user', saas: params[:saas?], enable_admin_mode: params[:admin_mode?] do
        it { is_expected.to(allowed ? be_allowed(read_policy) : be_disallowed(read_policy)) }
        it { is_expected.to(allowed ? be_allowed(admin_policy) : be_disallowed(admin_policy)) }
      end
    end

    context 'when in subgroup', :saas do
      let(:current_user) { owner }
      let_it_be(:subgroup) { create(:group, :private, parent: group) }

      subject { described_class.new(current_user, subgroup) }

      before do
        stub_licensed_features(credentials_inventory: true)
      end

      it { expect_disallowed(read_policy) }
      it { expect_disallowed(admin_policy) }
    end
  end

  describe 'change_prevent_group_forking' do
    context 'when feature is disabled' do
      context 'with owner' do
        let(:current_user) { owner }

        it { expect_disallowed(:change_prevent_group_forking) }
      end

      context 'with maintainer' do
        let(:current_user) { maintainer }

        it { expect_disallowed(:change_prevent_group_forking) }
      end
    end

    context 'when feature is enabled' do
      before do
        stub_licensed_features(group_forking_protection: true)
      end

      context 'with owner' do
        let(:current_user) { owner }

        it { expect_allowed(:change_prevent_group_forking) }

        context 'when group has parent' do
          let_it_be(:group) { create(:group, :private, parent: create(:group)) }

          it { expect_disallowed(:change_prevent_group_forking) }
        end
      end

      context 'with maintainer' do
        let(:current_user) { maintainer }

        it { expect_disallowed(:change_prevent_group_forking) }
      end
    end
  end

  describe "security dashboard policies" do
    where(:policy, :role, :admin_mode, :allowed) do
      :admin_vulnerability           | :admin              | false | false
      :admin_vulnerability           | :admin              | true  | true
      :admin_vulnerability           | :auditor            | nil   | false
      :admin_vulnerability           | :developer          | nil   | false
      :admin_vulnerability           | :guest              | nil   | false
      :admin_vulnerability           | :planner            | nil   | false
      :admin_vulnerability           | :maintainer         | nil   | true
      :admin_vulnerability           | :owner              | nil   | true
      :admin_vulnerability           | :reporter           | nil   | false
      :admin_vulnerability           | :security_manager   | nil   | true
      :read_group_security_dashboard | :admin              | false | false
      :read_group_security_dashboard | :admin              | true  | true
      :read_group_security_dashboard | :auditor            | nil   | true
      :read_group_security_dashboard | :developer          | nil   | true
      :read_group_security_dashboard | :guest              | nil   | false
      :read_group_security_dashboard | :planner            | nil   | false
      :read_group_security_dashboard | :maintainer         | nil   | true
      :read_group_security_dashboard | :owner              | nil   | true
      :read_group_security_dashboard | :reporter           | nil   | false
      :read_group_security_dashboard | :security_manager   | nil   | true
      :read_vulnerability            | :admin              | false | false
      :read_vulnerability            | :admin              | true  | true
      :read_vulnerability            | :auditor            | nil   | true
      :read_vulnerability            | :developer          | nil   | true
      :read_vulnerability            | :guest              | nil   | false
      :read_vulnerability            | :planner            | nil   | false
      :read_vulnerability            | :maintainer         | nil   | true
      :read_vulnerability            | :owner              | nil   | true
      :read_vulnerability            | :reporter           | nil   | false
      :read_vulnerability            | :security_manager   | nil   | true
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        enable_admin_mode!(current_user) if admin_mode
      end

      context "with security_dashboard enabled" do
        before do
          stub_licensed_features(security_dashboard: true)
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end

      context "with security_dashboard disabled" do
        before do
          stub_licensed_features(security_dashboard: false)
        end

        it { expect_disallowed(policy) }
      end
    end
  end

  describe ':read_vulnerability_statistics' do
    let(:permission) { :read_vulnerability_statistics }

    where(:role, :admin_mode, :allowed) do
      :guest            | nil   | false
      :planner          | nil   | false
      :reporter         | nil   | false
      :developer        | nil   | true
      :security_manager | nil   | true
      :maintainer       | nil   | true
      :owner            | nil   | true
      :auditor          | nil   | true
      :admin            | true  | true
      :admin            | false | false
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        stub_licensed_features(security_dashboard: true)
        enable_admin_mode!(current_user) if admin_mode
      end

      it { allowed ? expect_allowed(permission) : expect_disallowed(permission) }
    end
  end

  describe 'resolve_vulnerability_with_ai' do
    before do
      stub_licensed_features(
        security_dashboard: true,
        ai_features: true
      )
      allow(current_user).to receive(:allowed_to_use?).and_return(true)
    end

    context 'when user cannot :read_security_resource' do
      let(:current_user) { guest }

      where(:duo_features_enabled, :cs_matcher) do
        true  | be_disallowed(:resolve_vulnerability_with_ai)
        false | be_disallowed(:resolve_vulnerability_with_ai)
      end

      with_them do
        before do
          group.namespace_settings.update!(duo_features_enabled: duo_features_enabled)
        end

        it { is_expected.to cs_matcher }
      end
    end

    context 'when user can?(:read_security_resource)' do
      let(:current_user) { developer }

      where(:duo_features_enabled, :cs_matcher) do
        true  | be_allowed(:resolve_vulnerability_with_ai)
        false | be_disallowed(:resolve_vulnerability_with_ai)
      end

      with_them do
        before do
          group.namespace_settings.update!(duo_features_enabled: duo_features_enabled)
        end

        it { is_expected.to cs_matcher }
      end
    end
  end

  describe 'access_ai_review_mr permission' do
    let(:current_user) { developer }

    before do
      stub_licensed_features(ai_features: true)
      group.namespace_settings.update!(duo_features_enabled: true)
    end

    it 'calls allowed_to_use? with correct root_namespace parameter' do
      expect(current_user).to receive(:allowed_to_use?).with(
        :review_merge_request,
        licensed_feature: :review_merge_request,
        root_namespace: group.root_ancestor
      ).and_return(true)

      expect_allowed(:access_ai_review_mr)
    end

    context 'when user is not allowed to use review_merge_request' do
      before do
        allow(current_user).to receive(:allowed_to_use?)
          .with(:review_merge_request, licensed_feature: :review_merge_request, root_namespace: group.root_ancestor)
          .and_return(false)
      end

      it { expect_disallowed(:access_ai_review_mr) }
    end

    context 'when user is nil' do
      let(:current_user) { nil }

      it { expect_disallowed(:access_ai_review_mr) }
    end
  end

  describe ':read_dependency' do
    let(:policy) { :read_dependency }

    where(:role, :admin_mode, :allowed) do
      :guest            | nil   | false
      :planner          | nil   | false
      :reporter         | nil   | false
      :security_manager | nil   | true
      :developer        | nil   | true
      :maintainer       | nil   | true
      :owner            | nil   | true
      :auditor          | nil   | true
      :admin            | true  | true
      :admin            | false | false
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        enable_admin_mode!(current_user) if admin_mode
      end

      context 'when licensed feature `dependency_scanning` is enabled' do
        before do
          stub_licensed_features(dependency_scanning: true)
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end

      context 'when licensed feature `dependency_scanning` is disabled' do
        before do
          stub_licensed_features(dependency_scanning: false)
        end

        it { expect_disallowed(policy) }
      end
    end
  end

  describe ':read_subscription_usage' do
    let(:policy) { :read_subscription_usage }

    where(:role, :admin_mode, :allowed) do
      :guest      | nil   | false
      :planner    | nil   | false
      :reporter   | nil   | false
      :developer  | nil   | false
      :maintainer | nil   | false
      :owner      | nil   | true
      :auditor    | nil   | false
      :admin      | true  | true
      :admin      | false | false
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        enable_admin_mode!(current_user) if admin_mode
      end

      it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
    end
  end

  describe ':update_subscription_usage_cap' do
    let(:policy) { :update_subscription_usage_cap }

    where(:role, :admin_mode, :allowed) do
      :guest      | nil   | false
      :planner    | nil   | false
      :reporter   | nil   | false
      :developer  | nil   | false
      :maintainer | nil   | false
      :owner      | nil   | true
      :auditor    | nil   | false
      :admin      | true  | true
      :admin      | false | false
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        enable_admin_mode!(current_user) if admin_mode
      end

      it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
    end
  end

  describe ':read_licenses' do
    let(:policy) { :read_licenses }

    where(:role, :admin_mode, :allowed) do
      :guest            | nil   | false
      :planner          | nil   | false
      :reporter         | nil   | false
      :security_manager | nil   | true
      :developer        | nil   | true
      :maintainer       | nil   | true
      :owner            | nil   | true
      :auditor          | nil   | true
      :admin            | true  | true
      :admin            | false | false
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        enable_admin_mode!(current_user) if admin_mode
      end

      context 'when licensed feature `license_scanning` is enabled' do
        before do
          stub_licensed_features(license_scanning: true)
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end

      context 'when licensed feature `license_scanning` is disabled' do
        before do
          stub_licensed_features(license_scanning: false)
        end

        it { expect_disallowed(policy) }
      end
    end
  end

  describe 'read_group_security_dashboard & create_vulnerability_export' do
    let(:abilities) do
      %i[read_group_security_dashboard create_vulnerability_export read_security_resource]
    end

    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'with admin' do
      let(:current_user) { admin }

      context 'when admin mode is enabled', :enable_admin_mode do
        it { expect_allowed(*abilities) }
      end

      context 'when admin mode is disabled' do
        it { expect_disallowed(*abilities) }
      end
    end

    context 'with owner' do
      let(:current_user) { owner }

      it { expect_allowed(*abilities) }
    end

    context 'with maintainer' do
      let(:current_user) { maintainer }

      it { expect_allowed(*abilities) }
    end

    context 'with developer' do
      let(:current_user) { developer }

      it { expect_allowed(*abilities) }

      context 'when security dashboard features is not available' do
        before do
          stub_licensed_features(security_dashboard: false)
        end

        it { expect_disallowed(*abilities) }
      end
    end

    context 'with reporter' do
      let(:current_user) { reporter }

      it { expect_disallowed(*abilities) }
    end

    context 'with planner' do
      let(:current_user) { planner }

      it { expect_disallowed(*abilities) }
    end

    context 'with guest' do
      let(:current_user) { guest }

      it { expect_disallowed(*abilities) }
    end

    context 'with non member' do
      let(:current_user) { non_group_member }

      it { expect_disallowed(*abilities) }
    end

    context 'with anonymous' do
      let(:current_user) { nil }

      it { expect_disallowed(*abilities) }
    end
  end

  describe 'private nested group use the highest access level from the group and inherited permissions' do
    let_it_be(:nested_group) { create(:group, :private, parent: group, guests: [guest, reporter, developer, maintainer], owners: owner) }

    before do
      group.members.all_owners.destroy_all # rubocop: disable Cop/DestroyAll -- removes all owners to set up a specific role scenario
      group.add_guest(owner)
    end

    subject { described_class.new(current_user, nested_group) }

    context 'when user is auditor' do
      let(:current_user) { auditor }
      let(:permissions) { auditor_permissions }

      before do
        stub_licensed_features(security_dashboard: true, cycle_analytics_for_groups: true)
      end

      it_behaves_like 'valid permissions'
    end
  end

  context 'when push_rules is not enabled by the current license' do
    before do
      stub_licensed_features(push_rules: false)
    end

    let(:current_user) { maintainer }

    it { expect_disallowed(:change_push_rules) }
  end

  context 'when push_rules is enabled by the current license' do
    before do
      stub_licensed_features(push_rules: true)
    end

    let(:current_user) { maintainer }

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { expect_allowed(:change_push_rules) }
    end

    context 'when the user is a maintainer' do
      let(:current_user) { maintainer }

      it { expect_allowed(:change_push_rules) }
    end

    context 'when the user is a developer' do
      let(:current_user) { developer }

      it { expect_disallowed(:change_push_rules) }
    end
  end

  context 'when commit_committer_check is not enabled by the current license' do
    before do
      stub_licensed_features(commit_committer_check: false)
    end

    let(:current_user) { maintainer }

    it { expect_disallowed(:change_commit_committer_check) }
  end

  context 'when commit_committer_check is enabled by the current license' do
    before do
      stub_licensed_features(commit_committer_check: true)
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { expect_allowed(:change_commit_committer_check) }
    end

    context 'when the user is a maintainer' do
      let(:current_user) { maintainer }

      it { expect_allowed(:change_commit_committer_check) }
    end

    context 'when the user is a developer' do
      let(:current_user) { developer }

      it { expect_disallowed(:change_commit_committer_check) }
    end
  end

  context 'when commit_committer_name_check is not enabled by the current license' do
    before do
      stub_licensed_features(commit_committer_name_check: false)
    end

    let(:current_user) { maintainer }

    it { expect_disallowed(:change_commit_committer_name_check) }
  end

  context 'when commit_committer_name_check is enabled by the current license' do
    before do
      stub_licensed_features(commit_committer_name_check: true)
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { expect_allowed(:change_commit_committer_name_check) }
    end

    context 'when the user is a maintainer' do
      let(:current_user) { maintainer }

      it { expect_allowed(:change_commit_committer_name_check) }
    end

    context 'when the user is a developer' do
      let(:current_user) { developer }

      it { expect_disallowed(:change_commit_committer_name_check) }
    end
  end

  context 'when reject_unsigned_commits is not enabled by the current license' do
    before do
      stub_licensed_features(reject_unsigned_commits: false)
    end

    let(:current_user) { maintainer }

    it { expect_disallowed(:change_reject_unsigned_commits) }
  end

  context 'when reject_unsigned_commits is enabled by the current license' do
    before do
      stub_licensed_features(reject_unsigned_commits: true)
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { expect_allowed(:change_reject_unsigned_commits) }
    end

    context 'when the user is a maintainer' do
      let(:current_user) { maintainer }

      it { expect_allowed(:change_reject_unsigned_commits) }
    end

    context 'when the user is a developer' do
      let(:current_user) { developer }

      it { expect_disallowed(:change_reject_unsigned_commits) }
    end
  end

  context 'when reject_non_dco_commits is not enabled by the current license' do
    before do
      stub_licensed_features(reject_non_dco_commits: false)
    end

    let(:current_user) { maintainer }

    it { expect_disallowed(:change_reject_non_dco_commits) }
  end

  context 'when reject_non_dco_commits is enabled by the current license' do
    before do
      stub_licensed_features(reject_non_dco_commits: true)
    end

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      it { expect_allowed(:change_reject_non_dco_commits) }
    end

    context 'when the user is a maintainer' do
      let(:current_user) { maintainer }

      it { expect_allowed(:change_reject_non_dco_commits) }
    end

    context 'when the user is a developer' do
      let(:current_user) { developer }

      it { expect_disallowed(:change_reject_non_dco_commits) }
    end
  end

  shared_examples 'analytics policy' do |action|
    shared_examples 'policy by role' do |role|
      context role do
        let(:current_user) { public_send(role) }

        it 'is allowed' do
          expect_allowed(action)
        end
      end
    end

    %w[owner maintainer developer reporter].each do |role|
      include_examples 'policy by role', role
    end

    context 'when user is admin' do
      let(:current_user) { admin }

      it 'is allowed when admin mode is enabled', :enable_admin_mode do
        expect_allowed(action)
      end

      it 'is not allowed when admin mode is disabled' do
        expect_disallowed(action)
      end
    end

    context 'when user is guest' do
      let(:current_user) { guest }

      it 'is not allowed' do
        expect_disallowed(action)
      end
    end

    context 'when user is planner' do
      let(:current_user) { planner }

      it 'is not allowed' do
        expect_disallowed(action)
      end
    end
  end

  describe 'view_productivity_analytics' do
    include_examples 'analytics policy', :view_productivity_analytics
  end

  describe '#read_group_saml_identity' do
    let_it_be_with_reload(:saml_provider) { create(:saml_provider, group: group, enabled: true) }

    context 'for owner' do
      let(:current_user) { owner }

      it { expect_allowed(:read_group_saml_identity) }

      context 'without Group SAML enabled' do
        before do
          saml_provider.update!(enabled: false)
        end

        it { expect_disallowed(:read_group_saml_identity) }
      end
    end

    %w[maintainer developer reporter guest].each do |role|
      context "for #{role}" do
        let(:current_user) { public_send(role) }

        it { expect_disallowed(:read_group_saml_identity) }
      end
    end
  end

  describe '#read_group_scim_identity' do
    let_it_be_with_reload(:saml_provider) { create(:saml_provider, group: group, enabled: true) }

    context 'for owner' do
      let(:current_user) { owner }

      it { expect_allowed(:read_group_scim_identity) }

      context 'without Group SAML enabled' do
        before do
          saml_provider.update!(enabled: false)
        end

        it { expect_disallowed(:read_group_scim_identity) }
      end
    end

    %w[maintainer developer reporter guest].each do |role|
      context "for #{role}" do
        let(:current_user) { public_send(role) }

        it { expect_disallowed(:read_group_scim_identity) }
      end
    end
  end

  describe 'update_default_branch_protection' do
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

          context 'when admin mode is enabled', :enable_admin_mode do
            it { expect_allowed(:update_default_branch_protection) }
          end

          context 'when admin mode is disabled' do
            it { expect_disallowed(:update_default_branch_protection) }
          end
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          context 'when admin mode is enabled', :enable_admin_mode do
            it { expect_allowed(:update_default_branch_protection) }
          end

          context 'when admin mode is disabled' do
            it { expect_disallowed(:update_default_branch_protection) }
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

          context 'when admin mode is enabled', :enable_admin_mode do
            it { expect_allowed(:update_default_branch_protection) }
          end

          context 'when admin mode is disabled' do
            it { expect_disallowed(:update_default_branch_protection) }
          end
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          context 'when admin mode is enabled', :enable_admin_mode do
            it { expect_allowed(:update_default_branch_protection) }
          end

          context 'when admin mode is disabled' do
            it { expect_disallowed(:update_default_branch_protection) }
          end
        end
      end
    end

    context 'for an owner' do
      let(:current_user) { owner }

      context 'when the `default_branch_protection_restriction_in_groups` feature is available' do
        before do
          stub_licensed_features(default_branch_protection_restriction_in_groups: true)
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is enabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: true)
          end

          it { expect_allowed(:update_default_branch_protection) }
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          it { expect_disallowed(:update_default_branch_protection) }
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

          it { expect_allowed(:update_default_branch_protection) }
        end

        context 'when the setting `group_owners_can_manage_default_branch_protection` is disabled' do
          before do
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: false)
          end

          it { expect_allowed(:update_default_branch_protection) }
        end
      end
    end
  end

  describe ':admin_ci_minutes' do
    let(:policy) { :admin_ci_minutes }

    where(:role, :admin_mode, :allowed) do
      :guest      | nil   | false
      :planner    | nil   | false
      :reporter   | nil   | false
      :developer  | nil   | false
      :maintainer | nil   | false
      :owner      | nil   | true
      :admin      | true  | true
      :admin      | false | false
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        enable_admin_mode!(current_user) if admin_mode
      end

      it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
    end
  end

  describe ':lock_namespace_duo_feature' do
    let(:policy) { :lock_namespace_duo_feature }

    where(:role, :admin_mode, :allowed) do
      :guest      | nil   | false
      :planner    | nil   | false
      :reporter   | nil   | false
      :developer  | nil   | false
      :maintainer | nil   | false
      :owner      | nil   | false
      :auditor    | nil   | false
      :admin      | true  | true
      :admin      | false | false
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        enable_admin_mode!(current_user) if admin_mode
      end

      it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
    end
  end

  describe ':read_audit_event' do
    let(:policy) { :read_audit_event }

    where(:role, :admin_mode, :allowed) do
      :guest            | nil   | false
      :planner          | nil   | false
      :reporter         | nil   | false
      :security_manager | nil   | true
      :developer        | nil   | true
      :maintainer       | nil   | true
      :owner            | nil   | true
      :admin            | true  | true
      :admin            | false | false
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        enable_admin_mode!(current_user) if admin_mode
      end

      it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
    end
  end

  describe ':read_any_audit_event' do
    let(:policy) { :read_any_audit_event }

    where(:role, :admin_mode, :allowed) do
      :auditor          | nil   | true
      :guest            | nil   | false
      :planner          | nil   | false
      :reporter         | nil   | false
      :security_manager | nil   | true
      :developer        | nil   | false
      :maintainer       | nil   | true
      :owner            | nil   | true
      :admin            | true  | true
      :admin            | false | false
    end

    with_them do
      let(:current_user) { public_send(role) }

      before do
        enable_admin_mode!(current_user) if admin_mode
      end

      it 'enables and prevents the permission as expected' do
        if allowed
          expect_allowed(policy)
        else
          expect_disallowed(policy)
        end
      end
    end
  end

  context 'when group is read only' do
    let(:current_user) { owner }
    let(:policies) do
      %i[create_epic update_epic admin_pipeline register_group_runners add_cluster create_cluster
        update_cluster admin_cluster create_deploy_token create_subgroup create_package]
    end

    before do
      allow(group).to receive(:read_only?).and_return(read_only)
      stub_licensed_features(epics: true)
    end

    context 'when the group is read only' do
      let(:read_only) { true }

      it { expect_disallowed(*policies) }
      it { expect_allowed(:read_billable_member) }
    end

    context 'when the group is not read only' do
      let(:read_only) { false }

      it { expect_allowed(*policies) }
    end
  end

  context 'when under .com', :saas do
    it_behaves_like 'model with wiki policies' do
      let_it_be_with_refind(:container) { create(:group_with_plan, plan: :premium_plan) }
      let_it_be(:user) { owner }

      before_all do
        create(:license, plan: License::PREMIUM_PLAN)
      end

      before do
        enable_namespace_license_check!
      end

      def set_access_level(access_level)
        container.group_feature.update_attribute(:wiki_access_level, access_level)
      end

      context 'when the feature is not licensed on this group' do
        let_it_be(:container) { create(:group_with_plan, plan: :bronze_plan) }

        it 'does not include the wiki permissions' do
          expect_disallowed(*wiki_permissions[:all])
        end
      end
    end
  end

  it_behaves_like 'update namespace limit policy'

  context 'with group access tokens', :saas do
    context 'with GitLab.com Core resource access tokens', :saas do
      before do
        stub_ee_application_setting(should_check_namespace_plan: true)
      end

      context 'with owner access' do
        let(:current_user) { owner }

        it { expect_disallowed(:create_resource_access_tokens) }
        it { expect_disallowed(:admin_setting_to_allow_resource_access_token_creation) }
        it { expect_allowed(:read_resource_access_tokens) }
        it { expect_allowed(:destroy_resource_access_tokens) }
      end
    end

    context 'on GitLab.com paid', :saas do
      let_it_be_with_refind(:group) { create(:group_with_plan, plan: :bronze_plan) }

      context 'with owner' do
        let(:current_user) { owner }

        before_all do
          group.add_owner(owner)
        end

        it_behaves_like 'GitLab.com Paid plan resource access tokens'

        context 'when creating resource access tokens' do
          it { expect_allowed(:create_resource_access_tokens) }

          context 'when resource access token creation is not allowed' do
            before do
              group.namespace_settings.update_column(:resource_access_token_creation_allowed, false)
            end

            it { expect_disallowed(:create_resource_access_tokens) }
          end

          context 'when parent group has resource access token creation disabled' do
            let_it_be_with_reload(:namespace_settings) do
              create(:namespace_settings, resource_access_token_creation_allowed: false)
            end

            let_it_be(:parent) { create(:group_with_plan, plan: :bronze_plan, namespace_settings: namespace_settings) }
            let_it_be(:group) { create(:group, parent: parent, owners: owner) }

            context 'when user cannot create resource access tokens' do
              it { expect_disallowed(:create_resource_access_tokens) }
            end

            context 'when user can render admin settings for resource access token' do
              it { expect_allowed(:admin_setting_to_allow_resource_access_token_creation) }
            end
          end
        end

        context 'when reading resource access tokens' do
          it { expect_allowed(:read_resource_access_tokens) }
        end

        context 'when destroying resource access tokens' do
          it { expect_allowed(:destroy_resource_access_tokens) }
        end

        context 'when admin settings allow resource access token' do
          it { expect_allowed(:admin_setting_to_allow_resource_access_token_creation) }
        end
      end

      context 'with developer' do
        let(:current_user) { developer }

        before_all do
          group.add_developer(developer)
        end

        context 'when creating resource access tokens' do
          it { expect_disallowed(:create_resource_access_tokens) }
        end

        context 'when reading resource access tokens' do
          it { expect_disallowed(:read_resource_access_tokens) }
        end

        context 'when destroying resource access tokens' do
          it { expect_disallowed(:destroy_resource_access_tokens) }
        end
      end
    end
  end

  describe ':read_group_release_stats' do
    shared_examples 'read_group_release_stats permissions' do
      context 'when `group_ci_cd_analytics_releases` feature is available' do
        before do
          stub_licensed_features(group_ci_cd_analytics_releases: true)
        end

        context 'when user is logged out' do
          let(:current_user) { nil }

          it { expect_disallowed(:read_group_release_stats) }
        end

        context 'when user is not a member of the group' do
          let(:current_user) { non_group_member }

          it { expect_disallowed(:read_group_release_stats) }
        end

        context 'when user is guest' do
          let(:current_user) { guest }

          it { expect_allowed(:read_group_release_stats) }
        end
      end

      context 'when `group_ci_cd_analytics_releases` feature is not available' do
        before do
          stub_licensed_features(group_ci_cd_analytics_releases: false)
        end

        context 'when user is guest' do
          let(:current_user) { guest }

          it { expect_disallowed(:read_group_release_stats) }
        end
      end
    end

    context 'when group is private' do
      it_behaves_like 'read_group_release_stats permissions'
    end

    context 'when group is public' do
      let_it_be(:group) { create(:group, :public, guests: guest) }

      it_behaves_like 'read_group_release_stats permissions'
    end

    describe ':admin_merge_request_approval_settings' do
      let(:policy) { :admin_merge_request_approval_settings }

      where(:role, :licensed, :admin_mode, :root_group, :allowed) do
        :guest      | true  | nil   | true  | false
        :guest      | false | nil   | true  | false
        :planner    | true  | nil   | true  | false
        :planner    | false | nil   | true  | false
        :reporter   | true  | nil   | true  | false
        :reporter   | false | nil   | true  | false
        :developer  | true  | nil   | true  | false
        :developer  | false | nil   | true  | false
        :maintainer | true  | nil   | true  | false
        :maintainer | false | nil   | true  | false
        :owner      | true  | nil   | true  | true
        :owner      | true  | nil   | false | false
        :owner      | false | nil   | true  | false
        :admin      | true  | true  | true  | true
        :admin      | true  | true  | false | false
        :admin      | false | true  | true  | false
        :admin      | true  | false | true  | false
        :admin      | false | false | true  | false
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          stub_licensed_features(merge_request_approvers: licensed)
          enable_admin_mode!(current_user) if admin_mode
          group.parent = build(:group) unless root_group
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end

    describe 'approval rule editing' do
      context 'when the instance-level approval rule lock is enabled' do
        before do
          stub_licensed_features(admin_merge_request_approvers_rules: true, merge_request_approvers: true)
          stub_application_setting(disable_overriding_approvers_per_merge_request: true)
        end

        context 'when user is an owner' do
          let(:current_user) { owner }

          it { expect_disallowed(:create_approval_rule) }
          it { expect_disallowed(:update_approval_rule) }
          it { expect_disallowed(:delete_approval_rule) }
        end

        context 'when user is an admin', :enable_admin_mode do
          let(:current_user) { admin }

          it { expect_allowed(:create_approval_rule) }
          it { expect_allowed(:update_approval_rule) }
          it { expect_allowed(:delete_approval_rule) }
        end
      end

      context 'when the instance-level approval rule lock is disabled' do
        let(:current_user) { owner }

        before do
          stub_licensed_features(admin_merge_request_approvers_rules: true, merge_request_approvers: true)
          stub_application_setting(disable_overriding_approvers_per_merge_request: false)
        end

        it { expect_allowed(:create_approval_rule) }
        it { expect_allowed(:update_approval_rule) }
        it { expect_allowed(:delete_approval_rule) }
      end
    end

    describe 'custom roles' do
      let(:license) { :custom_roles }

      context 'when on self-managed' do
        let(:current_user) { owner }

        before do
          stub_licensed_features(license => true)
        end

        it { expect_disallowed(:admin_member_role) }
      end

      describe ':admin_member_role', :saas do
        using RSpec::Parameterized::TableSyntax

        where(:role, :allowed) do
          :guest      | false
          :planner    | false
          :reporter   | false
          :developer  | false
          :maintainer | false
          :auditor    | false
          :owner      | true
          :admin      | true
        end

        with_them do
          let(:current_user) { public_send(role) }

          before do
            enable_admin_mode!(current_user) if role == :admin
          end

          context 'with custom roles license' do
            let(:permissions) { [:admin_member_role, :view_member_roles] }

            context 'when licensed feature is enabled' do
              before do
                stub_licensed_features(license => true)
              end

              it { is_expected.to(allowed ? be_allowed(*permissions) : be_disallowed(*permissions)) }

              context 'when memberships are locked to LDAP' do
                before do
                  allow(group).to receive(:ldap_synced?).and_return(true)
                  stub_application_setting(allow_group_owners_to_manage_ldap: true)
                  stub_application_setting(lock_memberships_to_ldap: true)
                end

                it { is_expected.to(allowed ? be_allowed(*permissions) : be_disallowed(*permissions)) }
              end
            end

            context 'when licensed feature is disabled' do
              before do
                stub_licensed_features(license => false)
              end

              it { expect_disallowed(*permissions) }
            end
          end

          context 'with default roles assignees license' do
            let(:license) { :default_roles_assignees }
            let(:permissions) { [:view_member_roles] }

            context 'when licensed feature is enabled' do
              before do
                stub_licensed_features(license => true)
              end

              it { is_expected.to(allowed ? be_allowed(*permissions) : be_disallowed(*permissions)) }
            end

            context 'when licensed feature is disabled' do
              before do
                stub_licensed_features(license => false)
              end

              it { expect_disallowed(*permissions) }
            end
          end
        end
      end

      describe ':read_member_role' do
        using RSpec::Parameterized::TableSyntax

        let(:permissions) { [:read_member_role] }

        where(:role, :allowed) do
          :guest      | true
          :planner    | true
          :reporter   | true
          :developer  | true
          :maintainer | true
          :auditor    | false
          :owner      | true
          :admin      | true
        end

        with_them do
          let(:current_user) { public_send(role) }

          before do
            enable_admin_mode!(current_user) if role == :admin
          end

          context 'when custom_roles feature is enabled' do
            before do
              stub_licensed_features(custom_roles: true)
            end

            it { is_expected.to(allowed ? be_allowed(*permissions) : be_disallowed(*permissions)) }

            context 'when memberships are locked to LDAP' do
              before do
                allow(group).to receive(:ldap_synced?).and_return(true)
                stub_application_setting(allow_group_owners_to_manage_ldap: true)
                stub_application_setting(lock_memberships_to_ldap: true)
              end

              it { is_expected.to(allowed ? be_allowed(*permissions) : be_disallowed(*permissions)) }
            end
          end

          context 'when custom_roles feature is disabled' do
            before do
              stub_licensed_features(custom_roles: false)
            end

            it { expect_disallowed(*permissions) }
          end
        end
      end
    end

    describe ':start_trial' do
      let(:policy) { :start_trial }

      where(:role, :eligible_for_trial, :admin_mode, :allowed) do
        :guest      | true  | nil   | false
        :guest      | false | nil   | false
        :planner    | true  | nil   | false
        :planner    | false | nil   | false
        :reporter   | true  | nil   | false
        :reporter   | false | nil   | false
        :developer  | true  | nil   | false
        :developer  | false | nil   | false
        :maintainer | true  | nil   | true
        :maintainer | false | nil   | false
        :owner      | true  | nil   | true
        :owner      | false | nil   | false
        :admin      | true  | true  | true
        :admin      | false | true  | false
        :admin      | true  | false | false
        :admin      | false | false | false
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          allow(group).to receive(:eligible_for_trial?).and_return(eligible_for_trial)
          enable_admin_mode!(current_user) if admin_mode
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end
  end

  describe 'compliance framework permissions' do
    shared_examples 'compliance framework permissions' do
      where(:role, :licensed, :admin_mode, :allowed) do
        :owner            | true  | nil   | true
        :owner            | false | nil   | false
        :admin            | true  | true  | true
        :admin            | true  | false | false
        :maintainer       | true  | nil   | false
        :developer        | true  | nil   | false
        :security_manager | true  | nil   | true
        :security_manager | false | nil   | false
        :reporter         | true  | nil   | false
        :planner          | true  | nil   | false
        :guest            | true  | nil   | false
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          stub_licensed_features(licensed_feature => licensed)
          enable_admin_mode!(current_user) if admin_mode
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end

    context 'with :admin_compliance_framework' do
      let(:policy) { :admin_compliance_framework }
      let(:licensed_feature) { :custom_compliance_frameworks }
      let(:feature_flag_name) { nil }

      include_examples 'compliance framework permissions'
    end

    context 'with :admin_compliance_pipeline_configuration' do
      let(:policy) { :admin_compliance_pipeline_configuration }
      let(:licensed_feature) { :evaluate_group_level_compliance_pipeline }

      include_examples 'compliance framework permissions'
    end
  end

  describe 'view_devops_adoption' do
    let(:current_user) { owner }
    let(:policy) { :view_group_devops_adoption }

    context 'when license does not include the feature' do
      let(:current_user) { admin }

      before do
        stub_licensed_features(group_level_devops_adoption: false)
        enable_admin_mode!(current_user)
      end

      it { expect_disallowed(policy) }
    end

    context 'when license includes the feature' do
      where(:role, :allowed) do
        :admin            | true
        :owner            | true
        :maintainer       | true
        :developer        | true
        :reporter         | true
        :planner          | false
        :guest            | false
        :non_group_member | false
        :auditor          | true
      end

      before do
        stub_licensed_features(group_level_devops_adoption: true)
        enable_admin_mode!(current_user) if current_user.admin?
      end

      with_them do
        let(:current_user) { public_send(role) }

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end
  end

  describe 'manage_devops_adoption_namespaces' do
    let(:current_user) { owner }
    let(:policy) { :manage_devops_adoption_namespaces }

    context 'when license does not include the feature' do
      let(:current_user) { admin }

      before do
        stub_licensed_features(group_level_devops_adoption: false)
        enable_admin_mode!(current_user)
      end

      it { expect_disallowed(policy) }
    end

    context 'when license includes the feature' do
      where(:role, :allowed) do
        :admin            | true
        :owner            | true
        :maintainer       | true
        :developer        | true
        :reporter         | true
        :planner          | false
        :guest            | false
        :non_group_member | false
      end

      before do
        stub_licensed_features(group_level_devops_adoption: true)
        enable_admin_mode!(current_user) if current_user.admin?
      end

      with_them do
        let(:current_user) { public_send(role) }

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end

    context 'when license plan does not include the feature' do
      where(:role, :allowed) do
        :admin            | true
        :owner            | false
        :maintainer       | false
        :developer        | false
        :reporter         | false
        :planner          | false
        :guest            | false
        :non_group_member | false
      end

      before do
        stub_licensed_features(group_level_devops_adoption: true)
        allow(group).to receive(:feature_available?).with(:group_level_devops_adoption).and_return(false)
        enable_admin_mode!(current_user) if current_user.admin?
      end

      with_them do
        let(:current_user) { public_send(role) }

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end
  end

  context 'with external audit events' do
    let(:current_user) { owner }

    context 'when license is disabled' do
      before do
        stub_licensed_features(external_audit_events: false)
      end

      it { expect_disallowed(:admin_external_audit_events) }
    end

    context 'when license is enabled' do
      before do
        stub_licensed_features(external_audit_events: true)
      end

      it { expect_allowed(:admin_external_audit_events) }
    end

    context 'when user is security manager' do
      before do
        stub_licensed_features(external_audit_events: true)
      end

      let(:current_user) { security_manager }

      it { expect_allowed(:admin_external_audit_events) }
    end

    context 'when user is not an owner' do
      let(:current_user) { build_stubbed(:user, :auditor) }

      it { expect_disallowed(:admin_external_audit_events) }
    end
  end

  describe 'a pending membership' do
    let_it_be(:user) { create(:user) }

    context 'with a private group' do
      let_it_be(:private_group) { create(:group, :private) }

      subject { described_class.new(user, private_group) }

      where(:role) do
        RolesHelpers.testable_roles(include_owner: true)
      end

      with_them do
        it 'has permission identical to a private group in which the user is not a member' do
          create(:group_member, :awaiting, role, source: private_group, user: user)

          expect_private_group_permissions_as_if_non_member
        end
      end

      context 'with a project in the group' do
        let_it_be(:project) { create(:project, :private, namespace: private_group) }

        where(:role) do
          RolesHelpers.testable_roles(include_owner: true)
        end

        with_them do
          it 'has permission identical to a private group in which the user is not a member' do
            create(:group_member, :awaiting, role, source: private_group, user: user)

            expect_private_group_permissions_as_if_non_member
          end
        end
      end
    end

    context 'with a public group' do
      let_it_be(:public_group) { create(:group, :public) }
      let(:permissions) { public_permissions }

      subject { described_class.new(user, public_group) }

      where(:role) do
        RolesHelpers.testable_roles(include_owner: true)
      end

      with_them do
        before do
          create(:group_member, :awaiting, role, source: public_group, user: user)
        end

        it_behaves_like 'valid permissions'
      end
    end

    context 'with a group invited to another group' do
      let_it_be(:group) { create(:group, :public) }
      let_it_be(:other_group) { create(:group, :private) }

      subject { described_class.new(user, other_group) }

      before_all do
        create(:group_group_link, { shared_with_group: group, shared_group: other_group })
      end

      where(:role) do
        RolesHelpers.testable_roles(include_owner: true)
      end

      with_them do
        it 'has permission to the other group as if the user is not a member' do
          create(:group_member, :awaiting, role, source: group, user: user)

          expect_private_group_permissions_as_if_non_member
        end
      end
    end

    def expect_private_group_permissions_as_if_non_member
      expect_disallowed(*public_permissions)
      expect_disallowed(*guest_permissions)
      expect_disallowed(*reporter_permissions)
      expect_disallowed(*developer_permissions)
      expect_disallowed(*maintainer_permissions)
      expect_disallowed(*owner_permissions)
    end
  end

  describe 'security compliance policy' do
    context 'for developer and above (including auditor and security_manager)' do
      where(role: %w[maintainer developer auditor owner security_manager])

      with_them do
        let(:current_user) { public_send(role) }

        it { expect_disallowed(:read_security_orchestration_policies) }
        it { expect_disallowed(:update_security_orchestration_policy_project) }
        it { expect_disallowed(:modify_security_policy) }
      end
    end

    context 'when licensed feature is available' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'when security_orchestration_policy_configuration is not present' do
        context 'with developer or maintainer or auditor role' do
          where(role: %w[maintainer developer auditor])

          with_them do
            let(:current_user) { public_send(role) }

            it { expect_allowed(:read_security_orchestration_policies) }
            it { expect_disallowed(:update_security_orchestration_policy_project) }
          end
        end

        context 'with security manager role' do
          let(:current_user) { security_manager }

          it { expect_allowed(:read_security_orchestration_policies) }
          it { expect_disallowed(:update_security_orchestration_policy_project) }
        end

        context 'with owner role' do
          where(role: %w[owner])

          with_them do
            let(:current_user) { public_send(role) }

            it { expect_allowed(:read_security_orchestration_policies) }
            it { expect_allowed(:update_security_orchestration_policy_project) }

            it 'allows creating security policy when no config exists' do
              expect_allowed(:create_security_policy)
            end

            it 'disallows modifying since there is no policy project to push to' do
              expect_disallowed(:modify_security_policy)
            end

            context 'when security_orchestration_policy_configuration is present' do
              let_it_be(:security_policy_management_project) { create(:project) }

              before_all do
                create(:security_orchestration_policy_configuration, project: nil, namespace: group,
                  security_policy_management_project: security_policy_management_project)
              end

              it { expect_disallowed(:create_security_policy, :modify_security_policy) }
            end
          end
        end
      end

      context 'when security_orchestration_policy_configuration is present' do
        let_it_be(:security_policy_management_project) { create(:project) }
        let(:current_user) { developer }

        before do
          create(:security_orchestration_policy_configuration, project: nil, namespace: group,
            security_policy_management_project: security_policy_management_project)
        end

        context 'when current_user is developer of security_policy_management_project' do
          before_all do
            security_policy_management_project.add_developer(developer)
          end

          it 'allows modifying existing policy project' do
            expect_allowed(:modify_security_policy)
          end

          it 'disallows creating since policy project already exists' do
            expect_disallowed(:create_security_policy)
          end
        end

        context 'when current_user is not developer of security_policy_management_project' do
          it { expect_disallowed(:modify_security_policy) }
        end
      end
    end
  end

  describe 'read_usage_quotas policy' do
    context 'when reading usage quotas' do
      let(:policy) { :read_usage_quotas }

      where(:role, :admin_mode, :allowed) do
        :owner      | nil   | true
        :admin      | true  | true
        :admin      | false | false
        :maintainer | nil   | false
        :developer  | nil   | false
        :reporter   | nil   | false
        :planner    | nil   | false
        :guest      | nil   | false
      end

      with_them do
        let(:current_user) { public_send(role) }

        before do
          enable_admin_mode!(current_user) if admin_mode
        end

        it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
      end
    end
  end

  describe 'dependency proxy' do
    context 'when feature is enabled' do
      before do
        stub_config(dependency_proxy: { enabled: true })
      end

      context 'when user is auditor' do
        let(:current_user) { auditor }

        it { expect_allowed(:read_dependency_proxy) }
        it { expect_disallowed(:admin_dependency_proxy) }
      end
    end
  end

  describe 'read wiki' do
    context 'when feature is enabled' do
      before do
        stub_licensed_features(group_wikis: true)
      end

      context 'when user is auditor' do
        let(:current_user) { auditor }

        it { expect_allowed(:read_wiki) }
        it { expect_disallowed(:admin_wiki) }
      end
    end

    context 'when feature is disabled' do
      before do
        stub_licensed_features(group_wikis: false)
      end

      context 'when user is auditor' do
        let(:current_user) { auditor }

        it { expect_disallowed(:read_wiki) }
        it { expect_disallowed(:admin_wiki) }
      end
    end
  end

  describe 'group level compliance features' do
    shared_examples 'group level compliance feature' do |feature, permission|
      context 'when enabled' do
        before do
          stub_licensed_features({ feature => true })
        end

        context 'when user is eligible for access' do
          where(role: %w[owner auditor security_manager])

          with_them do
            let(:current_user) { public_send(role) }

            it { expect_allowed(permission) }
          end
        end

        context 'when admin is allowed', :enable_admin_mode do
          let(:current_user) { admin }

          it { expect_allowed(permission) }
        end
      end

      context 'when disabled' do
        before do
          stub_licensed_features({ feature => false })
        end

        context 'when user is eligible for access' do
          where(role: %w[owner auditor security_manager])

          with_them do
            let(:current_user) { public_send(role) }

            it { expect_disallowed(permission) }
          end
        end

        context 'when admin is disallowed', :enable_admin_mode do
          let(:current_user) { admin }

          it { expect_disallowed(permission) }
        end
      end
    end

    describe 'group level compliance dashboard' do
      it_behaves_like 'group level compliance feature', :group_level_compliance_dashboard, :read_compliance_dashboard
    end

    describe 'group level compliance adherence report' do
      it_behaves_like 'group level compliance feature', :group_level_compliance_adherence_report,
        :read_compliance_adherence_report
    end

    describe 'group level compliance violations report' do
      it_behaves_like 'group level compliance feature', :group_level_compliance_violations_report,
        :read_compliance_violations_report
    end
  end

  describe 'user banned from namespace' do
    let_it_be_with_reload(:current_user) { create(:user) }
    let_it_be(:group) { create(:group, :private, developers: current_user) }

    subject { described_class.new(current_user, group) }

    before do
      stub_licensed_features(unique_project_download_limit: true)
    end

    context 'when user is not banned' do
      it { expect_allowed(:read_group) }
    end

    context 'when user is banned' do
      before do
        create(:namespace_ban, user: current_user, namespace: group.root_ancestor)
      end

      it { expect_disallowed(*described_class.own_ability_map.map.keys) }

      context 'when inside a subgroup' do
        let_it_be(:group) { create(:group, :private, :nested) }

        it { expect_disallowed(*described_class.own_ability_map.map.keys) }

        context 'as an owner of the subgroup' do
          before_all do
            group.add_owner(current_user)
          end

          it { expect_disallowed(*described_class.own_ability_map.map.keys) }
        end
      end

      context 'as an admin' do
        let_it_be(:current_user) { admin }

        context 'when admin mode is enabled', :enable_admin_mode do
          it { expect_allowed(:read_group) }
        end
      end

      context 'when group is public' do
        let_it_be(:group) { create(:group, :public) }

        it { expect_disallowed(:read_group) }
      end

      context 'when licensed feature unique_project_download_limit is not available' do
        before do
          stub_licensed_features(unique_project_download_limit: false)
        end

        it { expect_allowed(:read_group) }
      end
    end
  end

  describe 'ban_group_member' do
    let_it_be(:user) { create(:user) }

    let(:group) { create(:group) }

    subject(:policy) { described_class.new(user, group) }

    where(:unique_project_download_limit_enabled, :is_owner, :enabled) do
      false | false | false
      false | true  | false
      true  | false | false
      true  | true  | true
    end

    with_them do
      before do
        allow(group).to receive(:unique_project_download_limit_enabled?)
          .and_return(unique_project_download_limit_enabled)
        group.add_owner(user) if is_owner
      end

      it 'has the correct value' do
        if enabled
          expect_allowed(:ban_group_member)
        else
          expect_disallowed(:ban_group_member)
        end
      end
    end
  end

  describe 'group cicd runners' do
    context 'when user is auditor' do
      let(:current_user) { auditor }

      it { expect_allowed(:read_runners) }
      it { expect_allowed(:read_group_all_available_runners) }
      it { expect_disallowed(:register_group_runners) }
      it { expect_disallowed(:create_runners) }
    end

    context 'when user is security_manager' do
      let(:current_user) { security_manager }

      it { expect_allowed(:read_runners) }
      it { expect_allowed(:read_group_all_available_runners) }
      it { expect_disallowed(:register_group_runners) }
      it { expect_disallowed(:create_runners) }
    end
  end

  describe 'group container registry' do
    context 'when user is auditor' do
      let(:current_user) { auditor }

      it { expect_allowed(:read_container_image) }
      it { expect_disallowed(:admin_container_image) }
    end
  end

  describe 'admin_service_accounts' do
    context 'when the feature is not licensed' do
      let(:current_user) { owner }

      before do
        stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
      end

      it { expect_allowed(:admin_service_accounts) }
      it { expect_allowed(:admin_service_account_member) }
      it { expect_allowed(:create_service_account) }
      it { expect_allowed(:delete_service_account) }
      it { expect_allowed(:read_service_account) }
    end

    context 'when feature is enabled' do
      context 'when the user is a maintainer' do
        let(:current_user) { maintainer }

        it { expect_disallowed(:admin_service_accounts) }
        it { expect_disallowed(:admin_service_account_member) }
        it { expect_disallowed(:create_service_account) }
        it { expect_disallowed(:delete_service_account) }
        it { expect_disallowed(:read_service_account) }
      end

      context 'when the user is an owner' do
        let(:current_user) { owner }

        context 'when application setting allow_top_level_group_owners_to_create_service_accounts is disabled' do
          before do
            stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: false)
          end

          it { expect_allowed(:admin_service_accounts) }
          it { expect_allowed(:admin_service_account_member) }
          it { expect_disallowed(:create_service_account) }
          it { expect_disallowed(:delete_service_account) }
          it { expect_disallowed(:read_service_account) }

          context 'when saas', :saas do
            it { expect_allowed(:admin_service_accounts) }
            it { expect_allowed(:admin_service_account_member) }
            it { expect_disallowed(:create_service_account) }
            it { expect_disallowed(:delete_service_account) }
            it { expect_disallowed(:read_service_account) }
          end
        end

        context 'when application setting allow_top_level_group_owners_to_create_service_accounts is enabled' do
          before do
            stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
          end

          it { expect_allowed(:admin_service_accounts) }
          it { expect_allowed(:admin_service_account_member) }
          it { expect_allowed(:create_service_account) }
          it { expect_allowed(:delete_service_account) }
          it { expect_allowed(:read_service_account) }

          context 'when saas', :saas do
            it { expect_allowed(:admin_service_accounts) }
            it { expect_allowed(:admin_service_account_member) }
            it { expect_allowed(:create_service_account) }
            it { expect_allowed(:delete_service_account) }
            it { expect_allowed(:read_service_account) }

            context 'when trial is active' do
              before do
                allow(group).to receive_messages(trial_active?: true)
              end

              context 'for owner with verified identity' do
                let(:current_user) { owner }

                before do
                  allow(owner).to receive(:identity_verified?).and_return(true)
                end

                it { expect_allowed(:admin_service_accounts) }
                it { expect_allowed(:admin_service_account_member) }
                it { expect_allowed(:create_service_account) }
                it { expect_allowed(:delete_service_account) }
                it { expect_allowed(:read_service_account) }
              end

              context 'for owner without verified identity' do
                let(:current_user) { owner }

                before do
                  allow(owner).to receive(:identity_verified?).and_return(false)
                end

                it { expect_disallowed(:admin_service_accounts) }
                it { expect_disallowed(:admin_service_account_member) }
                it { expect_disallowed(:create_service_account) }
                it { expect_disallowed(:delete_service_account) }
                it { expect_allowed(:read_service_account) }
              end
            end
          end

          context 'when a trial is not active' do
            before do
              allow(group).to receive_messages(gitlab_subscription: nil)
            end

            it { expect_allowed(:admin_service_accounts) }
            it { expect_allowed(:admin_service_account_member) }
            it { expect_allowed(:create_service_account) }
            it { expect_allowed(:delete_service_account) }
            it { expect_allowed(:read_service_account) }
          end

          context 'for subgroup' do
            subject { described_class.new(current_user, subgroup) }

            it { expect_allowed(:admin_service_accounts) }
            it { expect_allowed(:admin_service_account_member) }
            it { expect_allowed(:create_service_account) }
            it { expect_allowed(:delete_service_account) }
            it { expect_allowed(:read_service_account) }

            context 'when a trial is active in GitLab.com', :saas do
              let(:current_user) { owner }

              before do
                allow(subgroup.root_ancestor).to receive_messages(trial_active?: true)
              end

              context 'for owner with verified identity' do
                before do
                  allow(owner).to receive(:identity_verified?).and_return(true)
                end

                it { expect_allowed(:admin_service_accounts) }
                it { expect_allowed(:admin_service_account_member) }
                it { expect_allowed(:create_service_account) }
                it { expect_allowed(:delete_service_account) }
                it { expect_allowed(:read_service_account) }
              end

              context 'for owner without verified identity' do
                before do
                  allow(owner).to receive(:identity_verified?).and_return(false)
                end

                it { expect_disallowed(:admin_service_accounts) }
                it { expect_disallowed(:admin_service_account_member) }
                it { expect_disallowed(:create_service_account) }
                it { expect_disallowed(:delete_service_account) }
                it { expect_allowed(:read_service_account) }
              end
            end
          end
        end
      end

      context 'when the user is an instance admin' do
        let(:current_user) { admin }

        context 'when admin mode is enabled', :enable_admin_mode do
          it { expect_allowed(:admin_service_accounts) }
          it { expect_allowed(:admin_service_account_member) }
          it { expect_allowed(:create_service_account) }
          it { expect_allowed(:delete_service_account) }
          it { expect_allowed(:read_service_account) }

          context 'when a trial is active' do
            before do
              allow(group).to receive_messages(trial_active: true)
            end

            it { expect_allowed(:admin_service_accounts) }
            it { expect_allowed(:admin_service_account_member) }
            it { expect_allowed(:create_service_account) }
            it { expect_allowed(:delete_service_account) }
            it { expect_allowed(:read_service_account) }
          end

          context 'for subgroup' do
            subject { described_class.new(current_user, subgroup) }

            it { expect_allowed(:admin_service_accounts) }
            it { expect_allowed(:admin_service_account_member) }
            it { expect_allowed(:create_service_account) }
            it { expect_allowed(:delete_service_account) }
            it { expect_allowed(:read_service_account) }
          end
        end

        context 'when admin mode is not enabled' do
          it { expect_disallowed(:admin_service_accounts) }
          it { expect_disallowed(:admin_service_account_member) }
          it { expect_disallowed(:create_service_account) }
          it { expect_disallowed(:delete_service_account) }
          it { expect_disallowed(:read_service_account) }
        end
      end
    end
  end

  describe 'access_duo_classic_chat' do
    let_it_be(:current_user) { create(:user) }

    subject { described_class.new(current_user, group) }

    context 'when on SaaS instance', :saas do
      let_it_be_with_reload(:group) { create(:group_with_plan, plan: :premium_plan) }

      context 'when container is a group with AI enabled' do
        include_context 'with duo features enabled and ai chat available for group on SaaS'

        context 'when user is nil' do
          subject { described_class.new(nil, group) }

          it { expect_disallowed(:access_duo_classic_chat) }
        end

        context 'when user is a member of the group' do
          before_all do
            group.add_guest(current_user)
          end

          it { expect_allowed(:access_duo_classic_chat) }

          context 'when the group does not have an Premium SaaS license' do
            let_it_be(:group) { create(:group) }

            it { expect_disallowed(:access_duo_classic_chat) }
          end
        end

        context 'when the user is not a member but has AI enabled via another group' do
          context 'when user can view group' do
            it 'is allowed' do
              expect_allowed(:access_duo_classic_chat)
            end
          end

          context 'when user cannot view group' do
            before do
              group.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
            end

            it 'is not allowed' do
              expect_disallowed(:access_duo_classic_chat)
            end
          end
        end
      end
    end

    context 'for self-managed', :with_cloud_connector do
      let_it_be_with_reload(:group) { create(:group) }
      let(:policy) { :access_duo_classic_chat }

      context 'when not on .org or .com' do
        where(:enabled_for_user, :duo_features_enabled, :ai_features_banned, :cs_matcher) do
          true  | true  | false | be_allowed(policy)
          true  | true  | false | be_allowed(policy)
          false | false | false | be_disallowed(policy)
          false | true  | false | be_disallowed(policy)
          false | true  | true  | be_disallowed(policy)
        end

        with_them do
          before do
            allow(::Gitlab).to receive(:org_or_com?).and_return(false)
            stub_ee_application_setting(duo_features_enabled: duo_features_enabled, lock_duo_features_enabled: true)
            allow(current_user).to receive(:allowed_to_use?).and_return(enabled_for_user)
            allow(::Gitlab::CurrentSettings).to receive(:duo_never_on?).and_return(ai_features_banned)
          end

          it { is_expected.to cs_matcher }
        end
      end
    end
  end

  describe 'access_duo_agentic_chat' do
    shared_examples 'checking for allowed_to_use_for_resource' do
      before do
        allow(current_user).to receive(:allowed_to_use_for_resource?).with(:agentic_chat,
          unit_primitive_name: :duo_chat, resource: group).and_return(allowed_to_use)
      end

      context 'when allowed_to_use is true' do
        let(:allowed_to_use) { true }

        it { expect_allowed(policy) }
      end

      context 'when allowed_to_use is false' do
        let(:allowed_to_use) { false }

        it { expect_disallowed(policy) }
      end
    end

    let_it_be(:current_user) { create(:user) }
    let(:policy) { :access_duo_agentic_chat }

    subject { described_class.new(current_user, group) }

    context 'when on SaaS instance', :saas do
      let_it_be_with_reload(:group) { create(:group_with_plan, plan: :premium_plan) }

      context 'when container is a group with AI enabled' do
        include_context 'with duo features enabled and agentic chat available for group on SaaS'

        context 'when user is a member of the group' do
          before_all do
            group.add_guest(current_user)
          end

          it_behaves_like 'checking for allowed_to_use_for_resource'

          context 'when the group does not have an Premium SaaS license' do
            let_it_be(:group) { create(:group) }

            it { expect_disallowed(policy) }
          end
        end

        context 'when the user is not a member but has AI enabled via another group' do
          context 'when user can view group' do
            it_behaves_like 'checking for allowed_to_use_for_resource'
          end

          context 'when user cannot view group' do
            before do
              group.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
            end

            it 'is not allowed' do
              expect_disallowed(policy)
            end
          end
        end

        context 'with customizable permissions' do
          where(:role, :allowed) do
            :guest      | false
            :planner    | false
            :reporter   | false
            :developer  | false
            :maintainer | true
            :owner      | true
          end

          with_them do
            before do
              group.add_member(current_user, role)
              group.ai_settings.update!(minimum_access_level_execute: ::Gitlab::Access::MAINTAINER)
            end

            it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
          end

          context 'when minimum_access_level_execute is enabled for all users' do
            before_all do
              group.add_guest(current_user)
            end

            before do
              group.ai_settings.update!(minimum_access_level_execute: nil)
            end

            it { expect_allowed(policy) }
          end

          context 'when user is an org owner' do
            let_it_be(:current_user) { create(:organization_owner, organization: group.organization).user }

            before do
              group.ai_settings.update!(minimum_access_level_execute: ::Gitlab::Access::GUEST)
            end

            it { expect_allowed(policy) }
          end

          context 'when user is not a member of the public group' do
            context 'when minimum_access_level_execute is enabled for all users' do
              before do
                group.ai_settings.update!(minimum_access_level_execute: nil)
              end

              it { expect_allowed(policy) }
            end

            context 'when minimum_access_level_execute requires membership' do
              before do
                group.ai_settings.update!(minimum_access_level_execute: ::Gitlab::Access::GUEST)
              end

              it { expect_disallowed(policy) }
            end
          end

          context 'when dap_group_customizable_permissions feature flag is disabled' do
            before_all do
              group.add_guest(current_user)
            end

            before do
              stub_feature_flags(dap_group_customizable_permissions: false)
              group.ai_settings.update!(minimum_access_level_execute: ::Gitlab::Access::MAINTAINER)
            end

            it { expect_allowed(policy) }
          end
        end

        context 'when user has both Duo Core and Duo Pro subscriptions' do
          let(:group_with_duo_pro) { group } # due to shared context
          let(:group_with_duo_core) do
            create(:group, name: 'group_with_duo_core').tap do |group|
              create(:gitlab_subscription_add_on_purchase, :duo_core, namespace: group)
              group.namespace_settings.update!(
                duo_core_features_enabled: true,
                duo_features_enabled: true,
                experiment_features_enabled: true)
            end
          end

          before do
            [group_with_duo_pro, group_with_duo_core].each do |namespace|
              namespace.add_guest(current_user)
            end

            allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
          end

          subject(:policy) { described_class.new(current_user, group_with_duo_core) }

          it 'grants agentic access when visiting Duo Core namespace' do
            expect(policy.can?(:access_duo_agentic_chat)).to be(true)
          end
        end
      end
    end

    context 'for self-managed', :with_cloud_connector do
      let_it_be_with_reload(:group) { create(:group) }
      let(:policy) { :access_duo_agentic_chat }

      context 'when not on .org or .com' do
        where(:stage_check_passed, :allowed_to_use, :duo_agent_platform_enabled, :duo_features_enabled,
          :amazon_q_enabled, :ai_features_banned, :cs_matcher) do
          true  | true  | true  | true  | false | false | be_allowed(policy)
          true  | true  | true  | false | false | false | be_disallowed(policy)
          true  | false | true  | true  | false | false | be_disallowed(policy)
          true  | true  | true  | true  | true  | false | be_disallowed(policy)
          false | true  | true  | false | false | false | be_disallowed(policy)
          false | true  | true  | true  | false | false | be_disallowed(policy)
          false | false | true  | true  | false | false | be_disallowed(policy)
          false | true  | false | true  | true  | false | be_disallowed(policy)
          true  | true  | true  | true  | false | true  | be_disallowed(policy)
        end

        with_them do
          before do
            allow(::Gitlab).to receive(:org_or_com?).and_return(false)
            stub_ee_application_setting(duo_features_enabled: duo_features_enabled, lock_duo_features_enabled: true)
            allow(current_user).to receive(:allowed_to_use_for_resource?).with(:agentic_chat,
              unit_primitive_name: :duo_chat, resource: group).and_return(allowed_to_use)
            allow(::Ai::AmazonQ).to receive(:enabled?).and_return(amazon_q_enabled)
            allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group,
              :agentic_chat).and_return(stage_check_passed)
            allow(::Ai::DuoWorkflow).to receive(:duo_agent_platform_available?).and_return(duo_agent_platform_enabled)
            allow(::Gitlab::CurrentSettings).to receive(:duo_never_on?).and_return(ai_features_banned)
          end

          it { is_expected.to cs_matcher }

          context 'when current user is nil' do
            let_it_be(:current_user) { nil }

            it { expect_disallowed(:access_duo_agentic_chat) }
          end
        end
      end

      context 'with customizable permissions' do
        include_context 'with duo features enabled and agentic chat available for self-managed'

        context 'when user is a member' do
          where(:role, :allowed) do
            :guest      | false
            :planner    | false
            :reporter   | false
            :developer  | false
            :maintainer | true
            :owner      | true
          end

          with_them do
            before do
              group.add_member(current_user, role)
              Ai::Setting.for_organization(group.organization).update!(minimum_access_level_execute: ::Gitlab::Access::MAINTAINER)
            end

            it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
          end
        end

        context 'when minimum_access_level_execute is enabled for all users' do
          before_all do
            group.add_guest(current_user)
          end

          before do
            Ai::Setting.for_organization(group.organization).update!(minimum_access_level_execute: nil)
          end

          it { expect_allowed(policy) }
        end

        context 'when user is an org owner' do
          let_it_be(:current_user) { create(:organization_owner, organization: group.organization).user }

          before do
            Ai::Setting.for_organization(group.organization).update!(minimum_access_level_execute: ::Gitlab::Access::GUEST)
          end

          it { expect_allowed(policy) }
        end

        context 'when minimum access level is ADMIN' do
          before do
            Ai::Setting.for_organization(group.organization).update!(minimum_access_level_execute: ::Gitlab::Access::ADMIN)
          end

          context 'with an instance admin', :enable_admin_mode do
            let(:current_user) { admin }

            it { expect_allowed(policy) }
          end

          it 'is disabled for members' do
            group.add_owner(current_user)

            expect_disallowed(policy)
          end
        end

        context 'when the user is not a member of the public group' do
          context 'when minimum_access_level_execute is enabled for all users' do
            before do
              Ai::Setting.for_organization(group.organization).update!(minimum_access_level_execute: nil)
            end

            it { expect_allowed(policy) }
          end

          context 'when minimum_access_level_execute requires membership' do
            before do
              Ai::Setting.for_organization(group.organization).update!(minimum_access_level_execute: ::Gitlab::Access::GUEST)
            end

            it { expect_disallowed(policy) }
          end
        end

        context 'when dap_instance_customizable_permissions feature flag is disabled' do
          before do
            stub_feature_flags(dap_instance_customizable_permissions: false)
            Ai::Setting.for_organization(group.organization).update!(minimum_access_level_execute: ::Gitlab::Access::GUEST)
          end

          it { expect_allowed(policy) }
        end
      end
    end
  end

  context 'with access_duo_features' do
    where(:current_user, :duo_features_enabled, :cs_matcher) do
      ref(:guest) | true | be_allowed(:access_duo_features)
      ref(:guest) | false | be_disallowed(:access_duo_features)
      nil | true | be_disallowed(:access_duo_features)
      nil | false | be_disallowed(:access_duo_features)
    end

    with_them do
      before do
        group.namespace_settings.update!(duo_features_enabled: duo_features_enabled)
      end

      it 'matches the expected permissions' do
        is_expected.to cs_matcher
      end
    end

    context 'when the group is not yet persisted' do
      subject { described_class.new(admin, build(:group)) }

      it { expect_disallowed(:access_duo_features) }
    end

    context 'when the group has Duo features disabled but a descendant has them enabled' do
      let(:current_user) { guest }

      before do
        group.namespace_settings.update!(duo_features_enabled: false)
      end

      context 'with a descendant subgroup that has Duo features enabled' do
        let(:subgroup) { create(:group, :private, parent: group) }

        before do
          subgroup.namespace_settings.update_column(:duo_features_enabled, true)
        end

        it 'does not grant access_duo_features on the parent group' do
          expect_disallowed(:access_duo_features)
        end
      end

      context 'with a descendant project that has Duo features enabled' do
        let(:project) { create(:project, group: group) }

        before do
          project.project_setting.update!(duo_features_enabled: true)
        end

        it 'does not grant access_duo_features on the parent group' do
          expect_disallowed(:access_duo_features)
        end
      end
    end
  end

  describe 'access to group for duo workflow' do
    let_it_be_with_reload(:group) { create(:group, :public) }

    where(:current_user, :token_info, :duo_features_enabled, :cs_matcher) do
      ref(:guest)      | nil                               | true  | be_allowed(:read_group)
      ref(:guest)      | { token_scopes: [:ai_workflows] } | true  | be_allowed(:read_group)
      ref(:guest)      | { token_scopes: [:ai_workflows] } | false | be_disallowed(:read_group, :admin_group)
      ref(:guest)      | { token_scopes: [:other_scope] }  | true  | be_allowed(:read_group)
      ref(:maintainer) | { token_scopes: [:ai_workflows] } | false | be_disallowed(:read_group, :admin_group)
    end

    with_them do
      before do
        group.namespace_settings.update!(duo_features_enabled: duo_features_enabled)
        ::Current.token_info = token_info
      end

      it { is_expected.to cs_matcher }
    end

    context 'when the group has Duo features disabled but a descendant has them enabled' do
      let(:current_user) { guest }

      before do
        group.namespace_settings.update!(duo_features_enabled: false)
        ::Current.token_info = { token_scopes: [:ai_workflows] }
      end

      context 'with a descendant subgroup that has Duo features enabled' do
        let(:subgroup) { create(:group, parent: group) }

        before do
          subgroup.namespace_settings.update_column(:duo_features_enabled, true)
        end

        it 'allows group traversal but not Duo workflow execution', :aggregate_failures do
          expect_allowed(:read_group)
          expect_disallowed(:duo_workflow, :admin_duo_workflow)
        end
      end

      context 'with a descendant project that has Duo features enabled' do
        let(:project) { create(:project, group: group) }

        before do
          project.project_setting.update!(duo_features_enabled: true)
        end

        it 'allows group traversal but not Duo workflow execution', :aggregate_failures do
          expect_allowed(:read_group)
          expect_disallowed(:duo_workflow, :admin_duo_workflow)
        end
      end

      context 'with no descendant that has Duo features enabled' do
        it 'disallows group traversal and Duo workflow execution', :aggregate_failures do
          expect_disallowed(:read_group)
          expect_disallowed(:duo_workflow, :admin_duo_workflow)
        end
      end
    end
  end

  context 'with custom role' do
    include_context 'with custom role in group'

    context 'for a member role with the `read_vulnerability` ability' do
      let(:member_role_abilities) { { read_vulnerability: true } }
      let(:licensed_features) { { security_dashboard: true } }

      let(:allowed_abilities) { [:read_vulnerability, :read_group_security_dashboard] }
      let(:disallowed_abilities) { [:admin_vulnerability, :read_dependency] }

      it_behaves_like 'custom roles abilities'

      it_behaves_like 'does not call custom role query', [:developer, :maintainer, :owner]
    end

    context 'for a member role with the `admin_vulnerability` ability' do
      let(:member_role_abilities) { { read_vulnerability: true, admin_vulnerability: true } }
      let(:licensed_features) { { security_dashboard: true, security_inventory: true } }

      let(:allowed_abilities) do
        [:read_group_security_dashboard, :read_security_inventory, :read_vulnerability, :admin_vulnerability]
      end

      it_behaves_like 'custom roles abilities'

      it_behaves_like 'does not call custom role query', [:maintainer, :owner]
    end

    context 'for a member role with the `read_dependency` ability' do
      let(:member_role_abilities) { { read_dependency: true } }
      let(:licensed_features) { { dependency_scanning: true, license_scanning: true } }
      let(:allowed_abilities) { [:read_dependency, :read_licenses] }

      it_behaves_like 'custom roles abilities'

      it_behaves_like 'does not call custom role query', [:developer, :maintainer, :owner]
    end

    context 'for a member role with the `read_virtual_registry` ability' do
      let(:member_role_abilities) { { read_virtual_registry: true } }
      let(:allowed_abilities) { %i[read_virtual_registry] }

      # Guests already have :read_virtual_registry via the role YAML, so the
      # custom-role mechanism is only meaningful for sub-Guest access levels.
      it_behaves_like 'custom roles abilities', minimal_access: true

      it_behaves_like 'does not call custom role query', %i[guest planner reporter security_manager developer maintainer owner]
    end

    context 'for a member role with the `admin_group_member` ability' do
      let(:member_role_abilities) { { admin_group_member: true } }
      let(:allowed_abilities) { [:admin_group_member] }
      let(:disallowed_abilities) { [:activate_group_member] }

      it_behaves_like 'custom roles abilities'

      it_behaves_like 'does not call custom role query', [:owner]

      context 'with admin_service_account_member' do
        let_it_be(:guest) { create(:user) }
        let_it_be(:group) { create(:group) }
        let_it_be(:role) do
          create(
            :member_role,
            :guest,
            namespace: group,
            admin_group_member: true
          )
        end

        let_it_be(:group_member_guest) do
          create(
            :group_member,
            user: guest,
            source: group,
            access_level: Gitlab::Access::GUEST,
            member_role: role
          )
        end

        before do
          stub_licensed_features(custom_roles: true)
        end

        it { expect_allowed(:admin_service_account_member) }
      end
    end

    context 'for a member role with the `manage_group_access_tokens` ability' do
      let(:member_role_abilities) { { manage_group_access_tokens: true } }
      let(:allowed_abilities) do
        [:read_resource_access_tokens, :destroy_resource_access_tokens,
          :create_resource_access_tokens, :manage_resource_access_tokens]
      end

      it_behaves_like 'custom roles abilities'

      it_behaves_like 'does not call custom role query', [:owner]

      context 'when resource access token creation is not allowed' do
        before do
          create_member_role(group_member_guest)
          stub_licensed_features(custom_roles: true)
          group.root_ancestor.namespace_settings.update_column(:resource_access_token_creation_allowed, false)
        end

        it { expect_allowed(:read_resource_access_tokens, :destroy_resource_access_tokens) }
        it { expect_disallowed(:create_resource_access_tokens, :manage_resource_access_tokens) }
      end

      context 'when resource access tokens feature is unavailable' do
        before do
          create_member_role(group_member_guest)
          stub_licensed_features(custom_roles: true)
          stub_ee_application_setting(personal_access_tokens_disabled?: true)
        end

        it { expect_disallowed(*allowed_abilities) }
      end
    end

    context 'for a member role with the `admin_cicd_variables` ability' do
      let(:member_role_abilities) { { admin_cicd_variables: true } }
      let(:allowed_abilities) { [:admin_cicd_variables] }

      it_behaves_like 'custom roles abilities'

      it_behaves_like 'does not call custom role query', [:owner]
    end

    context 'for a member role with the `admin_protected_environments` ability' do
      let(:member_role_abilities) { { admin_protected_environments: true } }
      let(:allowed_abilities) { [:admin_protected_environments] }

      it_behaves_like 'custom roles abilities'

      it_behaves_like 'does not call custom role query', [:owner]
    end

    context 'for a member role with the `admin_compliance_framework` ability' do
      let(:member_role_abilities) { { read_compliance_dashboard: true, admin_compliance_framework: true } }

      let(:allowed_abilities) do
        [
          :admin_compliance_framework,
          :admin_compliance_pipeline_configuration,
          :read_compliance_dashboard,
          :read_compliance_adherence_report,
          :read_compliance_violations_report
        ]
      end

      context 'when compliance framework feature is available' do
        let(:licensed_features) do
          {
            compliance_framework: true,
            custom_compliance_frameworks: true,
            evaluate_group_level_compliance_pipeline: true,
            group_level_compliance_dashboard: true,
            group_level_compliance_adherence_report: true,
            group_level_compliance_violations_report: true
          }
        end

        it_behaves_like 'custom roles abilities'

        it_behaves_like 'does not call custom role query', [:owner]
      end

      context 'when compliance framework features are unavailable' do
        before do
          create_member_role(group_member_guest)

          stub_licensed_features(
            custom_roles: true,
            custom_compliance_frameworks: false,
            evaluate_group_level_compliance_pipeline: false,
            group_level_compliance_dashboard: false,
            group_level_compliance_adherence_report: false,
            group_level_compliance_violations_report: false
          )
        end

        it { expect_disallowed(*allowed_abilities) }
      end
    end

    context 'for a member role with the `read_compliance_dashboard` ability' do
      let(:member_role_abilities) { { read_compliance_dashboard: true } }

      let(:allowed_abilities) do
        [
          :read_compliance_dashboard,
          :read_compliance_adherence_report,
          :read_compliance_violations_report
        ]
      end

      context 'when compliance framework feature is available' do
        let(:licensed_features) do
          {
            group_level_compliance_dashboard: true,
            group_level_compliance_adherence_report: true,
            group_level_compliance_violations_report: true
          }
        end

        it_behaves_like 'custom roles abilities'

        it_behaves_like 'does not call custom role query', [:owner]
      end
    end

    context 'for a member role with the `remove_group` ability' do
      let(:member_role_abilities) { { remove_group: true } }
      let(:allowed_abilities) { [:remove_group, :view_edit_page] }

      it_behaves_like 'custom roles abilities'

      it_behaves_like 'does not call custom role query', [:owner]

      context 'when the group is a top level group' do
        before do
          create_member_role(parent_group_member_guest)
          stub_licensed_features(custom_roles: true)
        end

        subject { described_class.new(current_user, parent_group) }

        it { expect_disallowed(*allowed_abilities) }
      end
    end

    context 'for a member role with the `admin_push_rules` ability' do
      let(:member_role_abilities) { { admin_push_rules: true } }

      let(:licensed_features) do
        {
          custom_roles: true,
          push_rules: true,
          commit_committer_check: true,
          commit_committer_name_check: true,
          reject_unsigned_commits: true,
          reject_non_dco_commits: true
        }
      end

      let(:allowed_abilities) do
        [
          :admin_push_rules,
          :change_push_rules,
          :change_commit_committer_check,
          :change_commit_committer_name_check,
          :change_reject_unsigned_commits,
          :change_reject_non_dco_commits
        ]
      end

      it_behaves_like 'custom roles abilities'

      it_behaves_like 'does not call custom role query', [:maintainer, :owner]
    end

    context 'for a member role with the `manage_security_policy_link` ability' do
      let(:member_role_abilities) { { manage_security_policy_link: true } }
      let(:licensed_features) { { security_orchestration_policies: true } }

      let(:allowed_abilities) do
        [:read_security_orchestration_policies, :read_security_orchestration_policy_project,
          :update_security_orchestration_policy_project]
      end

      let(:disallowed_abilities) do
        [:modify_security_policy]
      end

      it_behaves_like 'custom roles abilities'

      it_behaves_like 'does not call custom role query', [:owner]
    end

    context 'for a member role with the `admin_web_hook` ability' do
      let(:member_role_abilities) { { admin_web_hook: true } }
      let(:allowed_abilities) { [:admin_web_hook, :read_web_hook] }

      it_behaves_like 'custom roles abilities'

      it_behaves_like 'does not call custom role query', [:owner]
    end

    context 'for a member role with the `manage_deploy_tokens` ability' do
      let(:member_role_abilities) { { manage_deploy_tokens: true } }

      let(:allowed_abilities) do
        [:manage_deploy_tokens, :read_deploy_token, :create_deploy_token, :destroy_deploy_token, :view_edit_page]
      end

      it_behaves_like 'custom roles abilities'

      it_behaves_like 'does not call custom role query', [:owner]
    end

    context 'for a member role with the `manage_merge_request_settings` ability' do
      let(:member_role_abilities) { { read_code: true, manage_merge_request_settings: true } }
      let(:allowed_abilities) { [:manage_merge_request_settings, :view_edit_page] }

      it_behaves_like 'custom roles abilities'

      it_behaves_like 'does not call custom role query', [:owner]

      context 'when the group is a top level group and the `merge_request_approvers` feature is available' do
        before do
          create_member_role(parent_group_member_guest)
          stub_licensed_features(custom_roles: true, merge_request_approvers: true)
        end

        subject { described_class.new(current_user, parent_group) }

        it { expect_allowed(:admin_merge_request_approval_settings) }
      end
    end

    context 'for a member role with the `admin_runners` ability' do
      let(:member_role_abilities) { { read_runners: true, admin_runners: true } }
      let(:allowed_abilities) do
        [
          :admin_runners,
          :create_runners,
          :read_group_all_available_runners,
          :read_runners
        ]
      end

      it_behaves_like 'custom roles abilities'

      it_behaves_like 'does not call custom role query', [:owner]
    end

    context 'for a member role with the `admin_integrations` ability' do
      let(:member_role_abilities) { { admin_integrations: true } }

      let(:allowed_abilities) { [:admin_integrations] }

      it_behaves_like 'custom roles abilities'

      it_behaves_like 'does not call custom role query', [:owner]
    end

    context 'for a member role with the `read_crm_contact` ability' do
      let(:member_role_abilities) { { read_crm_contact: true } }
      let(:allowed_abilities) { [:read_crm_contact] }

      it_behaves_like 'custom roles abilities'

      it_behaves_like 'does not call custom role query', [:planner, :reporter, :developer, :maintainer, :owner]
    end

    context 'for a member role with the `read_runners` ability' do
      let(:member_role_abilities) { { read_runners: true } }
      let(:allowed_abilities) { [:read_runners, :read_group_all_available_runners] }

      it_behaves_like 'custom roles abilities'

      it_behaves_like 'does not call custom role query', [:security_manager, :maintainer, :owner]
    end

    context 'for a member role with the `admin_security_attributes` ability' do
      let(:member_role_abilities) { { admin_security_attributes: true, read_security_attribute: true } }

      context 'when security_attributes feature is available' do
        let(:allowed_abilities) { [:admin_security_attributes] }
        let(:licensed_features) { { security_attributes: true } }

        it_behaves_like 'custom roles abilities'

        it_behaves_like 'does not call custom role query', [:maintainer, :owner, :security_manager]
      end

      context 'when security_attributes feature is not available' do
        let(:disallowed_abilities) { [:admin_security_attributes, :read_security_attribute] }
        let(:licensed_features) { { security_attributes: false } }

        it_behaves_like 'custom roles abilities'
      end
    end
  end

  describe ':destroy_group policy' do
    context 'when default_project_deletion_protection is set to true' do
      before do
        stub_application_setting(default_project_deletion_protection: true)
        stub_licensed_features(custom_roles: true)
      end

      context 'with admin', :enable_admin_mode do
        let(:current_user) { admin }

        it { expect_allowed(:remove_group) }
      end

      context 'with owner' do
        let(:current_user) { owner }

        context 'when group is empty' do
          it { expect_allowed(:remove_group) }
        end

        context 'when group has only inactive project' do
          let_it_be(:project_marked_for_deletion) do
            create(:project, group: group, marked_for_deletion_at: Time.current)
          end

          let_it_be(:project_archived) do
            create(:project, group: group, archived: true)
          end

          it { expect_allowed(:remove_group) }
        end

        context 'when group has at least one active project' do
          let_it_be(:project) do
            create(:project, group: group)
          end

          it { expect_disallowed(:remove_group) }
        end
      end
    end
  end

  context 'for :read_limit_alert' do
    context 'when the user is a guest member of the group' do
      let(:current_user) { guest }

      it { expect_allowed(:read_limit_alert) }
    end

    context 'when the user is not a member of the group' do
      let(:current_user) { non_group_member }

      it { expect_disallowed(:read_limit_alert) }
    end
  end

  context 'with saved replies permissions' do
    let(:current_user) { owner }

    context 'when no license is present' do
      before do
        stub_licensed_features(group_saved_replies: false)
      end

      it 'disallows saved replies actions' do
        expect_disallowed(:read_saved_replies, :create_saved_replies, :update_saved_replies, :destroy_saved_replies)
      end
    end

    context 'with correct license' do
      before do
        stub_licensed_features(group_saved_replies: true)
      end

      it 'allows saved replies actions' do
        expect_allowed(:read_saved_replies, :create_saved_replies, :update_saved_replies, :destroy_saved_replies)
      end

      context 'when the user is a guest' do
        let(:current_user) { guest }

        it { expect_allowed(:read_saved_replies) }

        it { expect_disallowed(:create_saved_replies, :update_saved_replies, :destroy_saved_replies) }
      end

      context 'when the user is a reporter' do
        let(:current_user) { reporter }

        it { expect_allowed(:read_saved_replies) }

        it { expect_disallowed(:create_saved_replies, :update_saved_replies, :destroy_saved_replies) }
      end

      context 'when the user is a developer' do
        let(:current_user) { developer }

        it 'allows all saved replies actions' do
          expect_allowed(:read_saved_replies, :create_saved_replies, :update_saved_replies, :destroy_saved_replies)
        end
      end

      context 'when the user is a planner' do
        let(:current_user) { planner }

        it { expect_disallowed(:create_saved_replies, :update_saved_replies, :destroy_saved_replies) }
      end

      context 'when the user is a guest member of the group' do
        let(:current_user) { guest }

        it { expect_disallowed(:create_saved_replies, :update_saved_replies, :destroy_saved_replies) }
      end
    end
  end

  describe 'read_runner_cloud_provisioning_info policy' do
    let(:current_user) { maintainer }

    it { expect_disallowed(:read_runner_cloud_provisioning_info) }

    context 'when SaaS-only feature is available' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      context 'when the user is a maintainer' do
        let(:current_user) { maintainer }

        it { expect_allowed(:read_runner_cloud_provisioning_info) }
      end

      context 'when the user is a guest' do
        let(:current_user) { guest }

        it { expect_disallowed(:read_runner_cloud_provisioning_info) }
      end
    end
  end

  describe 'read_runner_gke_provisioning_info policy' do
    let(:current_user) { maintainer }

    it { expect_disallowed(:read_runner_gke_provisioning_info) }

    context 'when SaaS-only feature is available' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      context 'when the user is a maintainer' do
        let(:current_user) { maintainer }

        it { expect_allowed(:read_runner_gke_provisioning_info) }
      end

      context 'when the user is a guest' do
        let(:current_user) { guest }

        it { expect_disallowed(:read_runner_gke_provisioning_info) }
      end
    end
  end

  describe 'provision_cloud_runner policy' do
    let(:current_user) { maintainer }

    it { expect_disallowed(:provision_cloud_runner) }

    context 'when SaaS-only feature is available' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      context 'when the user is a maintainer' do
        let(:current_user) { maintainer }

        it { expect_allowed(:provision_cloud_runner) }
      end

      context 'when the user is a guest' do
        let(:current_user) { guest }

        it { expect_disallowed(:provision_cloud_runner) }
      end
    end
  end

  describe 'provision_gke_runner policy' do
    let(:current_user) { maintainer }

    it { expect_disallowed(:provision_gke_runner) }

    context 'when SaaS-only feature is available' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      context 'when the user is a maintainer' do
        let(:current_user) { maintainer }

        it { expect_allowed(:provision_gke_runner) }
      end

      context 'when the user is a guest' do
        let(:current_user) { guest }

        it { expect_disallowed(:provision_gke_runner) }
      end
    end
  end

  describe 'read_jobs_statistics' do
    let(:current_user) { developer }

    it { expect_disallowed(:read_jobs_statistics) }

    context 'when runner performance insights feature is available' do
      before do
        stub_licensed_features(runner_performance_insights_for_namespace: true)
      end

      it { expect_disallowed(:read_jobs_statistics) }

      context 'when user is a maintainer' do
        let(:current_user) { maintainer }

        it { expect_allowed(:read_jobs_statistics) }
      end
    end
  end

  describe 'read_runner_usage' do
    where(:licensed, :current_user, :enable_admin_mode, :clickhouse_configured, :expected) do
      true  | ref(:admin)      | true  | true  | true
      false | ref(:maintainer) | false | true  | false
      true  | ref(:maintainer) | false | false | false
      true  | ref(:maintainer) | false | true  | true
      true  | ref(:auditor)    | false | true  | false
      true  | ref(:developer)  | false | true  | false
    end

    with_them do
      before do
        stub_licensed_features(runner_performance_insights_for_namespace: licensed)

        enable_admin_mode!(admin) if enable_admin_mode

        allow(::Gitlab::ClickHouse).to receive(:configured?).and_return(clickhouse_configured)
      end

      it 'matches expectation' do
        if expected
          expect_allowed(:read_runner_usage)
        else
          expect_disallowed(:read_runner_usage)
        end
      end
    end
  end

  describe 'web_hooks' do
    let(:current_user) { maintainer }

    it { expect_disallowed(:read_web_hook, :admin_web_hook) }

    context 'when user is an owner' do
      let(:current_user) { owner }

      it { expect_allowed(:read_web_hook, :admin_web_hook) }
    end
  end

  describe 'enable_secret_push_protection' do
    using RSpec::Parameterized::TableSyntax

    where(:current_user, :licensed, :match_expected_result) do
      ref(:owner)            | true  | be_allowed(:enable_secret_push_protection)
      ref(:maintainer)       | true  | be_allowed(:enable_secret_push_protection)
      ref(:security_manager) | true  | be_allowed(:enable_secret_push_protection)
      ref(:developer)        | true  | be_disallowed(:enable_secret_push_protection)
      ref(:owner)            | false | be_disallowed(:enable_secret_push_protection)
      ref(:maintainer)       | false | be_disallowed(:enable_secret_push_protection)
      ref(:developer)        | false | be_disallowed(:enable_secret_push_protection)
      ref(:security_manager) | false | be_disallowed(:enable_secret_push_protection)
    end

    with_them do
      before do
        stub_licensed_features(secret_push_protection: licensed)
      end

      it { is_expected.to match_expected_result }
    end

    describe 'when the group does not have the correct license' do
      let(:current_user) { owner }

      it { expect_disallowed(:enable_secret_push_protection) }
    end
  end

  describe 'admin_licensed_seat' do
    context 'when user is an owner' do
      let(:current_user) { owner }

      it { expect_allowed(:admin_licensed_seat) }
    end

    context 'when user is not an owner' do
      let(:current_user) { maintainer }

      it { expect_disallowed(:admin_licensed_seat) }
    end
  end

  describe 'bulk_admin_epic' do
    context 'when bulk_edit_feature_available is true' do
      before do
        stub_licensed_features(epics: true, group_bulk_edit: true)
      end

      context 'when user is planner or reporter' do
        where(role: %w[planner reporter])

        with_them do
          let(:current_user) { public_send(role) }

          it { expect_allowed(:bulk_admin_epic) }
        end
      end

      context 'when user is not reporter or better' do
        let(:current_user) { guest }

        it { expect_disallowed(:bulk_admin_epic) }
      end
    end

    context 'when bulk_edit_feature_available is false' do
      before do
        stub_licensed_features(epics: true, group_bulk_edit: false)
      end

      context 'when user is guest, planner or reporter' do
        where(role: %w[guest planner reporter])

        with_them do
          let(:current_user) { public_send(role) }

          it { expect_disallowed(:bulk_admin_epic) }
        end
      end
    end
  end

  describe 'generate_description' do
    context "when feature is authorized" do
      before do
        stub_licensed_features(epics: true)

        allow_next_instance_of(::Gitlab::Llm::FeatureAuthorizer) do |instance|
          allow(instance).to receive(:allowed?).and_return(true)
        end
      end

      context 'with planner+' do
        let(:current_user) { planner }

        context 'when user can create issue' do
          it { expect_allowed(:generate_description) }
        end
      end

      context 'with guest' do
        let(:current_user) { guest }

        it { expect_disallowed(:generate_description) }
      end
    end

    context "when feature is not authorized" do
      let(:current_user) { owner }

      before do
        allow_next_instance_of(::Gitlab::Llm::FeatureAuthorizer) do |instance|
          allow(instance).to receive(:allowed?).and_return(false)
        end
      end

      it { expect_disallowed(:generate_description) }
    end
  end

  describe 'access_ai_review_mr' do
    let(:current_user) { owner }

    where(:duo_features_enabled, :allowed_to_use, :enabled_for_user) do
      false  | false | be_disallowed(:access_ai_review_mr)
      true   | false | be_disallowed(:access_ai_review_mr)
      false  | true  | be_disallowed(:access_ai_review_mr)
      true   | true  | be_allowed(:access_ai_review_mr)
    end

    with_them do
      before do
        allow(group).to receive(:duo_features_enabled).and_return(duo_features_enabled)

        allow(current_user).to receive(:allowed_to_use?)
          .with(:review_merge_request, licensed_feature: :review_merge_request, root_namespace: group.root_ancestor)
          .and_return(allowed_to_use)
      end

      it { is_expected.to enabled_for_user }
    end
  end

  describe 'admin custom roles', :enable_admin_mode do
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:user) { create(:user) }

    subject { described_class.new(user, group) }

    where(:custom_admin_permission, :feature_available, :permissions, :allowed) do
      :read_admin_cicd   | false | [:read_group_metadata] | false
      :read_admin_cicd   | true  | [:read_group_metadata] | true
      :read_admin_groups | false | [:read_group_metadata] | false
      :read_admin_groups | true  | [:read_group_metadata] | true
    end

    with_them do
      before do
        create(:admin_member_role, custom_admin_permission, user: user)

        stub_licensed_features(custom_roles: feature_available)
      end

      it { is_expected.to(allowed ? be_allowed(*permissions) : be_disallowed(*permissions)) }
    end
  end

  describe 'admin_group_model_selection' do
    let(:is_saas) { true }
    let(:namespace_duo_enabled) { true }
    let(:with_self_hosted) { false }
    let(:amazon_q_enabled) { false }

    before do
      stub_saas_features(gitlab_com_subscriptions: is_saas)
      allow(::Ai::Setting).to receive(:self_hosted?).and_return(with_self_hosted)
      allow(::Ai::AmazonQ).to receive(:connected?).and_return(amazon_q_enabled)
      allow(group).to receive(:has_free_or_no_subscription?).and_return(false)

      group.namespace_settings.update!(duo_features_enabled: namespace_duo_enabled)
    end

    context 'when user can not admin the group' do
      let(:current_user) { maintainer }

      it { expect_disallowed(:admin_group_model_selection) }
    end

    context 'with sub-groups' do
      let(:current_user) { owner }
      let_it_be(:parent_group) { create(:group) }
      let_it_be_with_refind(:group) { create(:group, parent: parent_group) }

      it { expect_disallowed(:admin_group_model_selection) }
    end

    context 'when group has a free or no subscription' do
      let(:current_user) { owner }

      before do
        allow(group).to receive(:has_free_or_no_subscription?).and_return(true)
      end

      it { expect_disallowed(:admin_group_model_selection) }
    end

    context 'when user can admin the group' do
      let(:current_user) { owner }

      where(:amazon_q_enabled, :is_saas, :namespace_duo_enabled, :with_self_hosted, :enabled_for_user) do
        false | false | false | false | be_disallowed(:admin_group_model_selection)
        false | false | false | true  | be_disallowed(:admin_group_model_selection)
        false | true  | false | false | be_disallowed(:admin_group_model_selection)
        false | true  | false | true  | be_disallowed(:admin_group_model_selection)
        false | false | true  | false | be_disallowed(:admin_group_model_selection)
        false | true  | true  | true  | be_disallowed(:admin_group_model_selection)
        true  | true  | true  | false | be_disallowed(:admin_group_model_selection)
        false | true  | true  | false | be_allowed(:admin_group_model_selection)
      end

      with_them do
        it { is_expected.to enabled_for_user }
      end
    end
  end

  describe 'model_selection_allowlist' do
    let(:is_saas) { true }
    let(:namespace_duo_enabled) { true }
    let(:with_self_hosted) { false }
    let(:amazon_q_enabled) { false }

    before do
      stub_saas_features(gitlab_com_subscriptions: is_saas)
      allow(::Ai::Setting).to receive(:self_hosted?).and_return(with_self_hosted)
      allow(::Ai::AmazonQ).to receive(:connected?).and_return(amazon_q_enabled)
      allow(group).to receive(:has_free_or_no_subscription?).and_return(false)

      group.namespace_settings.update!(duo_features_enabled: namespace_duo_enabled)
    end

    context 'when user is a maintainer' do
      let(:current_user) { maintainer }

      it { expect_disallowed(:read_model_selection_allowlist, :update_model_selection_allowlist) }
    end

    context 'with sub-groups' do
      let(:current_user) { owner }
      let_it_be(:parent_group) { create(:group) }
      let_it_be_with_refind(:group) { create(:group, parent: parent_group) }

      it { expect_disallowed(:read_model_selection_allowlist, :update_model_selection_allowlist) }
    end

    context 'when group has a free or no subscription' do
      let(:current_user) { owner }

      before do
        allow(group).to receive(:has_free_or_no_subscription?).and_return(true)
      end

      it { expect_disallowed(:read_model_selection_allowlist, :update_model_selection_allowlist) }
    end

    context 'when user is an owner' do
      let(:current_user) { owner }

      where(:is_saas, :namespace_duo_enabled, :with_self_hosted, :amazon_q_enabled, :allowlist_accessible) do
        false | true  | false | false | false
        true  | false | false | false | false
        true  | true  | true  | false | false
        true  | true  | false | true  | false
        true  | true  | false | false | true
      end

      with_them do
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

  describe 'update_knowledge_graph_setting' do
    before do
      stub_saas_features(gitlab_com_subscriptions: true)
      stub_licensed_features(orbit: true)
      stub_feature_flags(knowledge_graph: true)
    end

    context 'when knowledge_graph feature flag is disabled' do
      let(:current_user) { owner }

      before do
        stub_feature_flags(knowledge_graph: false)
      end

      it { expect_disallowed(:update_knowledge_graph_setting) }
    end

    context 'when on self-managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      context 'when admin with admin mode', :enable_admin_mode do
        let(:current_user) { admin }

        it { expect_allowed(:update_knowledge_graph_setting) }
      end

      context 'when admin without admin mode' do
        let(:current_user) { admin }

        it { expect_disallowed(:update_knowledge_graph_setting) }
      end

      context 'when user is an owner' do
        let(:current_user) { owner }

        it { expect_allowed(:update_knowledge_graph_setting) }
      end

      context 'when user is a maintainer' do
        let(:current_user) { maintainer }

        it { expect_disallowed(:update_knowledge_graph_setting) }
      end

      context 'when user is a guest' do
        let(:current_user) { guest }

        it { expect_disallowed(:update_knowledge_graph_setting) }
      end

      context 'when orbit license is not available' do
        let(:current_user) { owner }

        before do
          stub_licensed_features(orbit: false)
        end

        it { expect_disallowed(:update_knowledge_graph_setting) }
      end

      context 'when group is not a root namespace' do
        let_it_be(:subgroup) { create(:group, :private, parent: group) }
        let(:current_user) { owner }

        subject { described_class.new(current_user, subgroup) }

        it { expect_disallowed(:update_knowledge_graph_setting) }
      end
    end

    context 'when on SaaS' do
      context 'when admin with admin mode', :enable_admin_mode do
        let(:current_user) { admin }

        it { expect_allowed(:update_knowledge_graph_setting) }
      end

      context 'when admin without admin mode' do
        let(:current_user) { admin }

        it { expect_disallowed(:update_knowledge_graph_setting) }
      end

      context 'when orbit license is not available' do
        let(:current_user) { owner }

        before do
          stub_licensed_features(orbit: false)
        end

        it { expect_disallowed(:update_knowledge_graph_setting) }
      end

      context 'when group is not a root namespace' do
        let_it_be(:subgroup) { create(:group, :private, parent: group) }
        let(:current_user) { owner }

        subject { described_class.new(current_user, subgroup) }

        it { expect_disallowed(:update_knowledge_graph_setting) }
      end

      context 'when orbit_enroll_namespace is disabled and group is not enrolled' do
        let(:current_user) { owner }

        before do
          stub_feature_flags(orbit_enroll_namespace: false)
        end

        it { expect_disallowed(:update_knowledge_graph_setting) }
      end

      context 'when orbit_enroll_namespace is disabled but group is already enrolled' do
        let(:current_user) { owner }

        before do
          stub_feature_flags(orbit_enroll_namespace: false)
          create(:knowledge_graph_enabled_namespace, namespace: group)
        end

        it { expect_allowed(:update_knowledge_graph_setting) }
      end

      context 'when all conditions are met' do
        context 'when user is an owner' do
          let(:current_user) { owner }

          it { expect_allowed(:update_knowledge_graph_setting) }
        end

        context 'when user is a maintainer' do
          let(:current_user) { maintainer }

          it { expect_disallowed(:update_knowledge_graph_setting) }
        end

        context 'when user is a guest' do
          let(:current_user) { guest }

          it { expect_disallowed(:update_knowledge_graph_setting) }
        end
      end
    end
  end

  describe 'update_ai_domain_settings' do
    context 'when group is a root group' do
      context 'when user is an owner' do
        let(:current_user) { owner }

        it { expect_allowed(:update_ai_domain_settings) }
      end

      context 'when user is a maintainer' do
        let(:current_user) { maintainer }

        it { expect_disallowed(:update_ai_domain_settings) }
      end

      context 'when user is a guest' do
        let(:current_user) { guest }

        it { expect_disallowed(:update_ai_domain_settings) }
      end
    end

    context 'when group has a parent (is a subgroup)' do
      subject { described_class.new(current_user, subgroup) }

      context 'when user is an owner' do
        let(:current_user) { owner }

        it { expect_disallowed(:update_ai_domain_settings) }
      end

      context 'when user is a maintainer' do
        let(:current_user) { maintainer }

        it { expect_disallowed(:update_ai_domain_settings) }
      end
    end
  end

  describe 'update_ai_tool_rule' do
    context 'when duo_features_enabled' do
      before do
        group.namespace_settings.update!(duo_features_enabled: true)
      end

      context 'when user is an owner' do
        let(:current_user) { owner }

        it { expect_allowed(:update_ai_tool_rule) }
      end

      context 'when user is a maintainer' do
        let(:current_user) { maintainer }

        it { expect_disallowed(:update_ai_tool_rule) }
      end

      context 'when user is a developer' do
        let(:current_user) { developer }

        it { expect_disallowed(:update_ai_tool_rule) }
      end
    end

    context 'when duo_features_enabled is false' do
      before do
        group.namespace_settings.update!(duo_features_enabled: false)
      end

      context 'when user is an owner' do
        let(:current_user) { owner }

        it { expect_disallowed(:update_ai_tool_rule) }
      end
    end
  end

  describe 'block_ai_catalog_mcp_server' do
    context 'when duo features and governance are enabled' do
      before do
        group.namespace_settings.update!(duo_features_enabled: true)
        stub_feature_flags(gitlab_duo_governance_settings: true)
      end

      context 'when user is an owner' do
        let(:current_user) { owner }

        it { expect_allowed(:block_ai_catalog_mcp_server) }
      end

      context 'when user is a maintainer' do
        let(:current_user) { maintainer }

        it { expect_disallowed(:block_ai_catalog_mcp_server) }
      end

      context 'when user is a developer' do
        let(:current_user) { developer }

        it { expect_disallowed(:block_ai_catalog_mcp_server) }
      end
    end

    context 'when duo_features_enabled is false' do
      before do
        group.namespace_settings.update!(duo_features_enabled: false)
        stub_feature_flags(gitlab_duo_governance_settings: true)
      end

      context 'when user is an owner' do
        let(:current_user) { owner }

        it { expect_disallowed(:block_ai_catalog_mcp_server) }
      end
    end

    context 'when gitlab_duo_governance_settings is disabled' do
      before do
        group.namespace_settings.update!(duo_features_enabled: true)
        stub_feature_flags(gitlab_duo_governance_settings: false)
      end

      context 'when user is an owner' do
        let(:current_user) { owner }

        it { expect_disallowed(:block_ai_catalog_mcp_server) }
      end
    end
  end

  describe 'duo_workflow' do
    let(:policy) { :duo_workflow }

    where(:stage_check_available, :duo_features_enabled, :current_user, :match_expected_result) do
      true  | true  | ref(:owner)      | be_allowed(:duo_workflow)
      true  | true  | ref(:maintainer) | be_allowed(:duo_workflow)
      true  | true  | ref(:developer)  | be_allowed(:duo_workflow)
      true  | true  | ref(:planner)    | be_disallowed(:duo_workflow)
      true  | true  | ref(:reporter)   | be_disallowed(:duo_workflow)
      true  | true  | ref(:guest)      | be_disallowed(:duo_workflow)
      false | true  | ref(:owner)      | be_disallowed(:duo_workflow)
      false | true  | ref(:maintainer) | be_disallowed(:duo_workflow)
      false | true  | ref(:developer)  | be_disallowed(:duo_workflow)
      false | true  | ref(:planner)    | be_disallowed(:duo_workflow)
      false | true  | ref(:reporter)   | be_disallowed(:duo_workflow)
      false | true  | ref(:guest)      | be_disallowed(:duo_workflow)
      false | false | ref(:owner)      | be_disallowed(:duo_workflow)
      false | false | ref(:maintainer) | be_disallowed(:duo_workflow)
      false | false | ref(:developer)  | be_disallowed(:duo_workflow)
      false | false | ref(:planner)    | be_disallowed(:duo_workflow)
      false | false | ref(:reporter)   | be_disallowed(:duo_workflow)
      false | false | ref(:guest)      | be_disallowed(:duo_workflow)
      true  | false | ref(:owner)      | be_disallowed(:duo_workflow)
      true  | false | ref(:maintainer) | be_disallowed(:duo_workflow)
      true  | false | ref(:developer)  | be_disallowed(:duo_workflow)
      true  | false | ref(:planner)    | be_disallowed(:duo_workflow)
      true  | false | ref(:reporter)   | be_disallowed(:duo_workflow)
      true  | false | ref(:guest)      | be_disallowed(:duo_workflow)
    end

    with_them do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group,
          :duo_workflow).and_return(stage_check_available)
        allow(group).to receive(:duo_features_enabled).and_return(duo_features_enabled)
        allow(current_user).to receive(:allowed_to_use?)
          .with(:duo_agent_platform, root_namespace: group.root_ancestor)
          .and_return(true)
      end

      it { is_expected.to match_expected_result }
    end

    context 'when user is not allowed to use duo_agent_platform' do
      before do
        allow(current_user).to receive(:allowed_to_use?)
          .with(:duo_agent_platform, root_namespace: group.root_ancestor)
          .and_return(false)
      end

      let(:current_user) { developer }

      it { expect_disallowed(:duo_workflow) }
    end

    context 'when user is nil' do
      let(:current_user) { nil }

      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :duo_workflow).and_return(true)
        allow(group).to receive(:duo_features_enabled).and_return(true)
      end

      it { expect_disallowed(:duo_workflow) }
    end

    context 'when user is a composite identity service account' do
      let_it_be(:scoped_user) { create(:user) }
      let_it_be(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }

      before do
        group.add_developer(service_account)
        group.add_developer(scoped_user)
        allow(group).to receive(:duo_features_enabled).and_return(true)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :duo_workflow).and_return(true)
        allow(scoped_user).to receive(:allowed_to_use)
          .and_return(Ai::UserAuthorizable::Response.new(allowed?: true, namespace_ids: [], authorized_by_duo_core: false))

        identity = instance_double(::Gitlab::Auth::Identity, linked?: true, scoped_user: scoped_user)
        allow(::Gitlab::Auth::Identity).to receive(:currently_linked).and_return(identity)
      end

      it 'evaluates duo_workflow permission against the scoped human user' do
        policy = described_class.new(service_account, group)

        expect(policy.allowed?(:duo_workflow)).to be(true)
      end

      context 'when the scoped user does not have permission' do
        before do
          allow(scoped_user).to receive(:allowed_to_use)
            .and_return(Ai::UserAuthorizable::Response.new(allowed?: false, namespace_ids: [], authorized_by_duo_core: false))
        end

        it 'denies duo_workflow' do
          policy = described_class.new(service_account, group)

          expect(policy.allowed?(:duo_workflow)).to be(false)
        end
      end
    end

    context 'when two users share a policy cache on the same group' do
      let_it_be(:non_authorized_developer) { create(:user) }

      before do
        group.add_developer(non_authorized_developer)
        allow(group).to receive(:duo_features_enabled).and_return(true)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :duo_workflow).and_return(true)
        allow(developer).to receive(:allowed_to_use?).with(:duo_agent_platform, root_namespace: group.root_ancestor).and_return(true)
        allow(non_authorized_developer).to receive(:allowed_to_use?).with(:duo_agent_platform, root_namespace: group.root_ancestor).and_return(false)
      end

      it 'does not use cached policy for non-authorized user', :aggregate_failures do
        shared_cache = {}
        authorized_policy = described_class.new(developer, group, cache: shared_cache)
        unauthorized_policy = described_class.new(non_authorized_developer, group, cache: shared_cache)

        expect(authorized_policy.allowed?(:duo_workflow)).to be(true)
        expect(unauthorized_policy.allowed?(:duo_workflow)).to be(false)
      end
    end
  end

  describe 'admin_duo_workflow' do
    let(:policy) { :admin_duo_workflow }

    context 'when duo_features is not enabled for the group' do
      before do
        group.namespace_settings.update!(duo_features_enabled: false)
      end

      where(:role) do
        %i[guest planner reporter developer maintainer owner]
      end

      with_them do
        let(:current_user) { public_send(role) }

        it { expect_disallowed(policy) }
      end
    end

    context 'when duo_features is enabled for the group' do
      before do
        group.namespace_settings.update!(duo_features_enabled: true)

        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :duo_workflow).and_return(true)
      end

      context 'when stage check says workflow is not available' do
        before do
          allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :duo_workflow).and_return(false)
        end

        where(:role) do
          %i[guest planner reporter developer maintainer owner]
        end

        with_them do
          let(:current_user) { public_send(role) }

          it { expect_disallowed(policy) }
        end
      end

      context 'when stage check says workflow is available' do
        before do
          allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :duo_workflow).and_return(true)
        end

        context 'when user cannot use duo_agent_platform' do
          where(:role, :allowed) do
            :guest      | false
            :planner    | false
            :reporter   | false
            :developer  | false
            :maintainer | false
            :owner      | true
          end

          with_them do
            let(:current_user) { public_send(role) }

            it { expect_disallowed(policy) }
          end
        end

        context 'when user can use duo_agent_platform' do
          before do
            allow(current_user).to receive(:allowed_to_use?).and_return(true)
          end

          where(:role, :allowed) do
            :guest      | false
            :planner    | false
            :reporter   | false
            :developer  | false
            :maintainer | false
            :owner      | true
          end

          with_them do
            let(:current_user) { public_send(role) }

            it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
          end
        end
      end
    end
  end

  describe 'summarize_comments' do
    subject(:policy) { described_class.new(current_user, group) }

    before do
      stub_licensed_features(epics: true)
    end

    context 'when user is nil' do
      let(:current_user) { nil }

      it { expect_disallowed(:summarize_comments) }
    end

    context 'when user is logged in' do
      using RSpec::Parameterized::TableSyntax

      let_it_be(:user) { create(:user) }
      let(:current_user) { user }

      where(:authorizer_allowed, :can_read_group, :expected) do
        true  | true  | true
        true  | false | false
        false | true  | false
        false | false | false
      end

      with_them do
        let(:authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }

        before do
          allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(authorizer)
          allow(authorizer).to receive(:allowed?).and_return(authorizer_allowed)

          group.add_guest(user) if can_read_group
        end

        it { is_expected.to public_send("be_#{expected ? 'allowed' : 'disallowed'}", :summarize_comments) }
      end

      context 'when verifying FeatureAuthorizer parameters' do
        let(:authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }

        before do
          allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(authorizer)
          allow(authorizer).to receive(:allowed?).and_return(true)
          group.add_guest(user)
        end

        it 'creates FeatureAuthorizer with correct parameters' do
          expect(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).with(
            container: group,
            feature_name: :summarize_comments,
            user: user
          ).and_return(authorizer)

          policy.allowed?(:summarize_comments)
        end
      end
    end
  end

  describe 'security inventory' do
    context 'when security inventory is available' do
      before do
        stub_licensed_features(security_inventory: true)
      end

      context 'when user is security manager' do
        let(:current_user) { security_manager }

        it { expect_allowed(:read_security_inventory) }
      end

      context 'when user is developer' do
        let(:current_user) { developer }

        it { expect_allowed(:read_security_inventory) }
      end

      context 'when user is reporter' do
        let(:current_user) { reporter }

        it { expect_disallowed(:read_security_inventory) }
      end
    end

    context 'when security inventory is not available' do
      before do
        stub_licensed_features(security_inventory: false)
      end

      context 'when user is developer' do
        let(:current_user) { developer }

        it { expect_disallowed(:read_security_inventory) }
      end
    end
  end

  describe 'security attributes' do
    context 'when security attributes are available' do
      before do
        stub_licensed_features(security_attributes: true)
      end

      context 'when user is maintainer' do
        let(:current_user) { maintainer }

        it { expect_allowed(:admin_security_attributes) }
        it { expect_allowed(:read_security_attribute) }
      end

      context 'when user is developer' do
        let(:current_user) { developer }

        it { expect_disallowed(:admin_security_attributes) }
        it { expect_allowed(:read_security_attribute) }
      end

      context 'when user is security manager' do
        let(:current_user) { security_manager }

        it { expect_allowed(:admin_security_attributes) }
        it { expect_allowed(:read_security_attribute) }
      end

      context 'when user is reporter' do
        let(:current_user) { reporter }

        it { expect_disallowed(:admin_security_attributes) }
        it { expect_disallowed(:read_security_attribute) }
      end

      context 'when user is planner' do
        let(:current_user) { planner }

        it { expect_disallowed(:admin_security_attributes) }
        it { expect_disallowed(:read_security_attribute) }
      end

      context 'when user is guest' do
        let(:current_user) { guest }

        it { expect_disallowed(:admin_security_attributes) }
        it { expect_disallowed(:read_security_attribute) }
      end
    end

    context 'when security attributes are not available' do
      before do
        stub_licensed_features(security_attributes: false)
      end

      context 'when user is maintainer' do
        let(:current_user) { maintainer }

        it { expect_disallowed(:admin_security_attributes) }
        it { expect_disallowed(:read_security_attribute) }
      end

      context 'when user is security manager' do
        let(:current_user) { security_manager }

        it { expect_disallowed(:admin_security_attributes) }
        it { expect_disallowed(:read_security_attribute) }
      end
    end
  end

  it_behaves_like 'sets Security Configuration Profiles permissions for the group'

  describe 'AI catalog abilities' do
    let(:ai_catalog_available) { true }
    let(:flows_available) { true }
    let(:third_party_flows_available) { true }
    let(:foundational_flows_available) { true }
    let(:duo_features_enabled) { true }

    shared_examples 'no permissions when StageCheck :ai_catalog is false' do
      let(:ai_catalog_available) { false }
      let(:duo_features_enabled) { false }

      before do
        group.namespace_settings.lock_duo_features_enabled = true
      end

      it { expect_disallowed(:create_ai_catalog_flow_item_consumer) }
      it { expect_disallowed(:read_ai_catalog_item_consumer) }
      it { expect_disallowed(:admin_ai_catalog_item_consumer) }
      it { expect_disallowed(:create_ai_catalog_flow_item_consumer) }
      it { expect_disallowed(:read_ai_catalog_flow) }
      it { expect_disallowed(:create_ai_catalog_third_party_flow_item_consumer) }
      it { expect_disallowed(:read_ai_catalog_third_party_flow) }
      it { expect_disallowed(:create_ai_catalog_agent_item_consumer) }
    end

    shared_examples 'no flow permissions when StageCheck :ai_catalog_flows is false' do
      let(:flows_available) { false }

      it { expect_disallowed(:create_ai_catalog_flow_item_consumer) }
      it { expect_disallowed(:read_ai_catalog_flow) }
    end

    shared_examples 'no third party flow permissions when StageCheck :ai_catalog_third_party_flows is false' do
      let(:third_party_flows_available) { false }

      it { expect_disallowed(:create_ai_catalog_third_party_flow_item_consumer) }
      it { expect_disallowed(:read_ai_catalog_third_party_flow) }
    end

    shared_examples 'no foundational flow permissions when StageCheck :foundational_flows is false' do
      let(:foundational_flows_available) { false }

      it { expect_disallowed(:read_ai_foundational_flow) }
      it { expect_disallowed(:create_ai_foundational_flow_item_consumer) }
    end

    shared_examples 'no permissions when Duo features are not available' do
      let(:duo_features_enabled) { false }

      before do
        group.namespace_settings.lock_duo_features_enabled = true
      end

      it { expect_disallowed(:admin_ai_catalog_item_consumer) }
      it { expect_disallowed(:read_ai_catalog_item_consumer) }
      it { expect_disallowed(:create_ai_catalog_flow_item_consumer) }
      it { expect_disallowed(:read_ai_catalog_flow) }
      it { expect_disallowed(:create_ai_catalog_third_party_flow_item_consumer) }
      it { expect_disallowed(:read_ai_catalog_third_party_flow) }
      it { expect_disallowed(:create_ai_catalog_agent_item_consumer) }
    end

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
        .with(group, :ai_catalog).and_return(ai_catalog_available)
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group,
        :ai_catalog_flows).and_return(flows_available)
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
        .with(group, :ai_catalog_third_party_flows).and_return(third_party_flows_available)
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
        .with(group, :foundational_flows).and_return(foundational_flows_available)
      group.namespace_settings.duo_features_enabled = duo_features_enabled
    end

    context 'when maintainer' do
      let(:current_user) { maintainer }

      it { expect_allowed(:admin_ai_catalog_item_consumer) }
      it { expect_allowed(:read_ai_catalog_item_consumer) }
      it { expect_allowed(:create_ai_catalog_flow_item_consumer) }
      it { expect_allowed(:read_ai_catalog_flow) }
      it { expect_allowed(:create_ai_catalog_third_party_flow_item_consumer) }
      it { expect_allowed(:read_ai_catalog_third_party_flow) }
      it { expect_allowed(:read_ai_foundational_flow) }
      it { expect_allowed(:create_ai_foundational_flow_item_consumer) }
      it { expect_allowed(:create_ai_catalog_agent_item_consumer) }

      it_behaves_like 'no permissions when StageCheck :ai_catalog is false'
      it_behaves_like 'no flow permissions when StageCheck :ai_catalog_flows is false'
      it_behaves_like 'no third party flow permissions when StageCheck :ai_catalog_third_party_flows is false'
      it_behaves_like 'no foundational flow permissions when StageCheck :foundational_flows is false'
      it_behaves_like 'no permissions when Duo features are not available'

      context 'when duo_custom_flows_enabled is false' do
        before do
          group.root_ancestor.namespace_settings.update!(duo_custom_flows_enabled: false)
        end

        it { expect_disallowed(:create_ai_catalog_flow_item_consumer) }
      end

      context 'when duo_external_agents_enabled is false' do
        before do
          allow(group.root_ancestor).to receive(:duo_external_agents_enabled).and_return(false)
        end

        it { expect_disallowed(:create_ai_catalog_third_party_flow_item_consumer) }
      end

      context 'when duo_custom_agents_enabled is false' do
        before do
          group.root_ancestor.namespace_settings.update!(duo_custom_agents_enabled: false)
        end

        it { expect_disallowed(:create_ai_catalog_agent_item_consumer) }
      end
    end

    context 'when developer' do
      let(:current_user) { developer }

      it { expect_disallowed(:admin_ai_catalog_item_consumer) }
      it { expect_allowed(:read_ai_catalog_item_consumer) }
      it { expect_disallowed(:create_ai_catalog_flow_item_consumer) }
      it { expect_allowed(:read_ai_catalog_flow) }
      it { expect_disallowed(:create_ai_catalog_third_party_flow_item_consumer) }
      it { expect_allowed(:read_ai_catalog_third_party_flow) }
      it { expect_allowed(:read_ai_foundational_flow) }
      it { expect_disallowed(:create_ai_catalog_agent_item_consumer) }

      it_behaves_like 'no permissions when StageCheck :ai_catalog is false'
      it_behaves_like 'no flow permissions when StageCheck :ai_catalog_flows is false'
      it_behaves_like 'no third party flow permissions when StageCheck :ai_catalog_third_party_flows is false'
      it_behaves_like 'no foundational flow permissions when StageCheck :foundational_flows is false'
      it_behaves_like 'no permissions when Duo features are not available'
    end

    context 'when guest' do
      let(:current_user) { guest }

      it { expect_disallowed(:admin_ai_catalog_item_consumer) }
      it { expect_allowed(:read_ai_catalog_item_consumer) }
      it { expect_disallowed(:create_ai_catalog_flow_item_consumer) }
      it { expect_disallowed(:read_ai_catalog_flow) }
      it { expect_disallowed(:create_ai_catalog_third_party_flow_item_consumer) }
      it { expect_disallowed(:read_ai_catalog_third_party_flow) }
      it { expect_disallowed(:create_ai_catalog_agent_item_consumer) }
    end

    context 'when anonymous' do
      let(:current_user) { anonymous }

      it { expect_disallowed(:admin_ai_catalog_item_consumer) }
      it { expect_disallowed(:read_ai_catalog_item_consumer) }
      it { expect_disallowed(:create_ai_catalog_flow_item_consumer) }
      it { expect_disallowed(:read_ai_catalog_flow) }
      it { expect_disallowed(:create_ai_catalog_third_party_flow_item_consumer) }
      it { expect_disallowed(:read_ai_catalog_third_party_flow) }
      it { expect_disallowed(:create_ai_catalog_agent_item_consumer) }
    end

    context 'when non_group_member' do
      let_it_be(:current_user) { non_group_member }

      it { expect_disallowed(:admin_ai_catalog_item_consumer) }
      it { expect_disallowed(:read_ai_catalog_item_consumer) }
      it { expect_disallowed(:create_ai_catalog_flow_item_consumer) }
      it { expect_disallowed(:read_ai_catalog_flow) }
      it { expect_disallowed(:create_ai_catalog_third_party_flow_item_consumer) }
      it { expect_disallowed(:read_ai_catalog_third_party_flow) }
      it { expect_disallowed(:create_ai_catalog_agent_item_consumer) }

      context 'when maintainer of a project in the group' do
        let_it_be(:project) { create(:project, maintainers: current_user, group: group) }

        it { expect_disallowed(:admin_ai_catalog_item_consumer) }
        it { expect_allowed(:read_ai_catalog_item_consumer) }
        it { expect_disallowed(:create_ai_catalog_flow_item_consumer) }
        it { expect_allowed(:read_ai_catalog_flow) }
        it { expect_allowed(:read_ai_foundational_flow) }
        it { expect_disallowed(:create_ai_catalog_third_party_flow_item_consumer) }
        it { expect_disallowed(:read_ai_catalog_third_party_flow) }
        it { expect_disallowed(:create_ai_catalog_agent_item_consumer) }
      end

      context 'when developer of a project in the group' do
        let_it_be(:project) { create(:project, developers: current_user, group: group) }

        it { expect_disallowed(:admin_ai_catalog_item_consumer) }
        it { expect_disallowed(:read_ai_catalog_item_consumer) }
        it { expect_disallowed(:create_ai_catalog_flow_item_consumer) }
        it { expect_disallowed(:read_ai_catalog_flow) }
        it { expect_disallowed(:create_ai_catalog_third_party_flow_item_consumer) }
        it { expect_disallowed(:read_ai_catalog_third_party_flow) }
        it { expect_disallowed(:create_ai_catalog_agent_item_consumer) }
      end

      context 'when maintainer of a project not in the group' do
        let_it_be(:project) { create(:project, maintainers: current_user) }

        it { expect_disallowed(:admin_ai_catalog_item_consumer) }
        it { expect_disallowed(:read_ai_catalog_item_consumer) }
        it { expect_disallowed(:create_ai_catalog_flow_item_consumer) }
        it { expect_disallowed(:read_ai_catalog_flow) }
        it { expect_disallowed(:create_ai_catalog_third_party_flow_item_consumer) }
        it { expect_disallowed(:read_ai_catalog_third_party_flow) }
        it { expect_disallowed(:create_ai_catalog_agent_item_consumer) }
      end
    end

    describe 'group-based access control' do
      let(:current_user) { maintainer }

      let_it_be(:membership_rule) do
        create(
          :ai_instance_accessible_entity_rules,
          :duo_agent_platform
        )
      end

      it 'calls allowed_to_use_through_namespace? with correct root_namespace parameter' do
        expect(current_user).to receive(:allowed_to_use_through_namespace?).with(
          :ai_catalog,
          group.root_ancestor
        ).and_return(true)

        expect_allowed(:read_ai_catalog_item_consumer)
      end

      context 'when catalog is available for user' do
        before do
          membership_rule.through_namespace.add_guest(current_user)
        end

        it 'enables the catalog permissions' do
          expect_allowed(:admin_ai_catalog_item_consumer)
          expect_allowed(:read_ai_catalog_item_consumer)
          expect_allowed(:create_ai_catalog_flow_item_consumer)
          expect_allowed(:read_ai_catalog_flow)
          expect_allowed(:create_ai_catalog_third_party_flow_item_consumer)
          expect_allowed(:read_ai_catalog_third_party_flow)
          expect_allowed(:create_ai_catalog_agent_item_consumer)
        end
      end

      context 'when catalog is not available for user' do
        it 'disables the catalog permissions' do
          expect_disallowed(:admin_ai_catalog_item_consumer)
          expect_disallowed(:read_ai_catalog_item_consumer)
          expect_disallowed(:create_ai_catalog_flow_item_consumer)
          expect_disallowed(:read_ai_catalog_flow)
          expect_disallowed(:create_ai_catalog_third_party_flow_item_consumer)
          expect_disallowed(:read_ai_catalog_third_party_flow)
          expect_disallowed(:create_ai_catalog_agent_item_consumer)
        end
      end
    end
  end

  describe 'provision_ai_catalog ability' do
    let(:ai_catalog_available) { true }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
        .with(group, :ai_catalog).and_return(ai_catalog_available)
    end

    shared_examples 'provision_ai_catalog allowed for maintainer+' do
      context 'when maintainer' do
        let(:current_user) { maintainer }

        it { expect_allowed(:provision_ai_catalog) }
      end

      context 'when owner' do
        let(:current_user) { owner }

        it { expect_allowed(:provision_ai_catalog) }
      end
    end

    shared_examples 'provision_ai_catalog disallowed for non-maintainers' do
      context 'when developer' do
        let(:current_user) { developer }

        it { expect_disallowed(:provision_ai_catalog) }
      end

      context 'when guest' do
        let(:current_user) { guest }

        it { expect_disallowed(:provision_ai_catalog) }
      end

      context 'when anonymous' do
        let(:current_user) { anonymous }

        it { expect_disallowed(:provision_ai_catalog) }
      end

      context 'when planner' do
        let(:current_user) { planner }

        it { expect_disallowed(:provision_ai_catalog) }
      end

      context 'when security_manager' do
        let(:current_user) { security_manager }

        it { expect_disallowed(:provision_ai_catalog) }
      end
    end

    context 'when duo_features_enabled is true (on by default)' do
      before do
        group.namespace_settings.update!(duo_features_enabled: true, lock_duo_features_enabled: false)
      end

      it_behaves_like 'provision_ai_catalog allowed for maintainer+'
      it_behaves_like 'provision_ai_catalog disallowed for non-maintainers'
    end

    context 'when duo_features_enabled is false and not locked (off by default)' do
      before do
        group.namespace_settings.update!(duo_features_enabled: false, lock_duo_features_enabled: false)
      end

      it_behaves_like 'provision_ai_catalog allowed for maintainer+'
      it_behaves_like 'provision_ai_catalog disallowed for non-maintainers'
    end

    context 'when duo_features_enabled is locked to false (never on)' do
      before do
        group.namespace_settings.update!(duo_features_enabled: false, lock_duo_features_enabled: true)
      end

      context 'when maintainer' do
        let(:current_user) { maintainer }

        it { expect_disallowed(:provision_ai_catalog) }
      end

      context 'when owner' do
        let(:current_user) { owner }

        it { expect_disallowed(:provision_ai_catalog) }
      end

      it_behaves_like 'provision_ai_catalog disallowed for non-maintainers'
    end

    context 'when namespace_settings is nil' do
      before do
        allow(group).to receive(:namespace_settings).and_return(nil)
      end

      it_behaves_like 'provision_ai_catalog allowed for maintainer+'
      it_behaves_like 'provision_ai_catalog disallowed for non-maintainers'
    end
  end

  describe 'create_ai_catalog_item_consumer ability' do
    let(:ai_catalog_available) { true }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
        .with(group, :ai_catalog).and_return(ai_catalog_available)
    end

    shared_examples 'create_ai_catalog_item_consumer allowed for maintainer+' do
      context 'when maintainer' do
        let(:current_user) { maintainer }

        it { expect_allowed(:create_ai_catalog_item_consumer) }
      end

      context 'when owner' do
        let(:current_user) { owner }

        it { expect_allowed(:create_ai_catalog_item_consumer) }
      end
    end

    shared_examples 'create_ai_catalog_item_consumer disallowed for non-maintainers' do
      context 'when developer' do
        let(:current_user) { developer }

        it { expect_disallowed(:create_ai_catalog_item_consumer) }
      end

      context 'when guest' do
        let(:current_user) { guest }

        it { expect_disallowed(:create_ai_catalog_item_consumer) }
      end

      context 'when anonymous' do
        let(:current_user) { anonymous }

        it { expect_disallowed(:create_ai_catalog_item_consumer) }
      end

      context 'when planner' do
        let(:current_user) { planner }

        it { expect_disallowed(:create_ai_catalog_item_consumer) }
      end

      context 'when security_manager' do
        let(:current_user) { security_manager }

        it { expect_disallowed(:create_ai_catalog_item_consumer) }
      end
    end

    context 'when duo_features_enabled is true (on by default)' do
      before do
        group.namespace_settings.update!(duo_features_enabled: true, lock_duo_features_enabled: false)
      end

      it_behaves_like 'create_ai_catalog_item_consumer allowed for maintainer+'
      it_behaves_like 'create_ai_catalog_item_consumer disallowed for non-maintainers'
    end

    context 'when duo_features_enabled is false and not locked (off by default)' do
      before do
        group.namespace_settings.update!(duo_features_enabled: false, lock_duo_features_enabled: false)
      end

      it_behaves_like 'create_ai_catalog_item_consumer allowed for maintainer+'
      it_behaves_like 'create_ai_catalog_item_consumer disallowed for non-maintainers'
    end

    context 'when duo_features_enabled is locked to false (never on)' do
      before do
        group.namespace_settings.update!(duo_features_enabled: false, lock_duo_features_enabled: true)
      end

      context 'when maintainer' do
        let(:current_user) { maintainer }

        it { expect_disallowed(:create_ai_catalog_item_consumer) }
      end

      context 'when owner' do
        let(:current_user) { owner }

        it { expect_disallowed(:create_ai_catalog_item_consumer) }
      end

      it_behaves_like 'create_ai_catalog_item_consumer disallowed for non-maintainers'
    end

    context 'when namespace_settings is nil' do
      before do
        allow(group).to receive(:namespace_settings).and_return(nil)
      end

      it_behaves_like 'create_ai_catalog_item_consumer allowed for maintainer+'
      it_behaves_like 'create_ai_catalog_item_consumer disallowed for non-maintainers'
    end
  end

  secrets_manager_write_permissions = %i[
    create_secret
    update_secret
    delete_secret
    provision_secrets_manager
    deprovision_secrets_manager
    update_secrets_permission
    delete_secrets_permission
  ].freeze

  # Reads that surface the Secrets Manager status/entitlement so the UI can render
  # the current state (and upgrade/trial CTA). These stay available regardless of
  # entitlement; only secret-data reads and writes are entitlement-gated.
  secrets_manager_surface_permissions = %i[
    read_group_secrets_manager_status
    read_secrets_manager
  ].freeze

  # Mints a JWT for reading straight from OpenBao (the non-CI/CD REST access-token
  # endpoint). Follows the stricter CI-pipeline carve-out (grace only), not the
  # broader Web/GraphQL one.
  secrets_manager_direct_read_permissions = %i[
    create_secrets_manager_api_jwt
  ].freeze

  shared_examples 'handling secrets manager permission' do
    # The condition delegates to Availability.for_group? (licensed? && enabled).
    # enabled_for_group? combinations are covered in availability_spec.rb; here we
    # stub it plus the license and assert the policy reacts to both dimensions.
    context 'when SM availability is satisfied' do
      before do
        stub_licensed_features(native_secrets_management: true)
        allow(::SecretsManagement::Availability).to receive(:enabled_for_group?).with(group).and_return(true)
      end

      # Keep the baseline role tests on the pre-entitlement path. The
      # entitlement-aware flag is on by default in the test environment, so
      # disable it explicitly here and exercise it in its own context below.
      context 'when the entitlement-aware policy is disabled' do
        before do
          stub_feature_flags(secrets_manager_paid_experience: false)
        end

        it 'allows or disallows the permission based on role' do
          if allowed
            expect_allowed(permission)
          else
            expect_disallowed(permission)
          end
        end

        context 'when the native_secrets_management license is not available' do
          before do
            stub_licensed_features(native_secrets_management: false)
          end

          it { expect_disallowed(permission) }
        end
      end

      context 'when the entitlement-aware policy is enabled' do
        before do
          stub_feature_flags(secrets_manager_paid_experience: true)
        end

        [
          [:ineligible, nil],
          [:blocked, :trial_expired],
          [:blocked, :credits_exhausted],
          [:blocked, :on_demand_disabled],
          [:blocked, :grace],
          [:blocked, :subscription_grace_period_expired],
          [:trial_eligible, nil],
          [:trial, nil],
          [:paid, nil],
          [:offline_paid, nil]
        ].each do |state, blocked_reason|
          label = blocked_reason ? "#{state} (#{blocked_reason})" : state.to_s

          context "when the entitlement state is #{label}" do
            before do
              entitlement = ::SecretsManagement::Entitlement.new(state: state, blocked_reason: blocked_reason)
              allow(::SecretsManagement::Entitlement).to receive(:for).and_return(entitlement)
            end

            it 'enforces the entitlement on top of the role' do
              surface_permission = secrets_manager_surface_permissions.include?(permission)
              write_permission = secrets_manager_write_permissions.include?(permission)
              direct_read_permission = secrets_manager_direct_read_permissions.include?(permission)
              entitlement_permits =
                if surface_permission
                  true
                elsif direct_read_permission
                  state != :ineligible && (state != :blocked || blocked_reason == :grace)
                else
                  case state
                  when :ineligible then false
                  # `blocked` has the same read/write split as `trial_eligible`.
                  when :trial_eligible, :blocked then !write_permission
                  else true
                  end
                end

              if allowed && entitlement_permits
                expect_allowed(permission)
              else
                expect_disallowed(permission)
              end
            end
          end
        end
      end
    end

    context 'when SM availability is not satisfied' do
      before do
        stub_licensed_features(native_secrets_management: true)
        allow(::SecretsManagement::Availability).to receive(:enabled_for_group?).with(group).and_return(false)
      end

      it 'disallows the permission' do
        expect_disallowed(permission)
      end
    end
  end

  describe 'provision_secrets_manager' do
    let(:permission) { :provision_secrets_manager }

    where(:current_user, :allowed) do
      ref(:anonymous)  | false
      ref(:guest)      | false
      ref(:planner)    | false
      ref(:reporter)   | false
      ref(:developer)  | false
      ref(:maintainer) | false
      ref(:owner)      | true

      ref(:auditor)    | false
      ref(:admin)      | true
    end

    with_them :enable_admin_mode do
      it_behaves_like 'handling secrets manager permission'
    end
  end

  describe 'deprovision_secrets_manager' do
    let(:permission) { :deprovision_secrets_manager }

    where(:current_user, :allowed) do
      ref(:anonymous)  | false
      ref(:guest)      | false
      ref(:planner)    | false
      ref(:reporter)   | false
      ref(:developer)  | false
      ref(:maintainer) | false
      ref(:owner)      | true

      ref(:auditor)    | false
      ref(:admin)      | true
    end

    with_them :enable_admin_mode do
      it_behaves_like 'handling secrets manager permission'
    end
  end

  describe 'delete_secrets_permission' do
    let(:permission) { :delete_secrets_permission }

    where(:current_user, :allowed) do
      ref(:anonymous)  | false
      ref(:guest)      | false
      ref(:planner)    | false
      ref(:reporter)   | false
      ref(:developer)  | false
      ref(:maintainer) | false
      ref(:owner)      | true

      ref(:auditor)    | false
      ref(:admin)      | true
    end

    with_them :enable_admin_mode do
      it_behaves_like 'handling secrets manager permission'
    end
  end

  describe 'update_secrets_permission' do
    let(:permission) { :update_secrets_permission }

    where(:current_user, :allowed) do
      ref(:anonymous)  | false
      ref(:guest)      | false
      ref(:planner)    | false
      ref(:reporter)   | false
      ref(:developer)  | false
      ref(:maintainer) | false
      ref(:owner)      | true

      ref(:auditor)    | false
      ref(:admin)      | true
    end

    with_them :enable_admin_mode do
      it_behaves_like 'handling secrets manager permission'
    end
  end

  describe 'read_secrets_manager' do
    let(:permission) { :read_secrets_manager }

    where(:current_user, :allowed) do
      ref(:anonymous)  | false
      ref(:guest)      | false
      ref(:planner)    | false
      ref(:reporter)   | false
      ref(:developer)  | false
      ref(:maintainer) | true
      ref(:owner)      | true

      ref(:auditor)    | false
      ref(:admin)      | true
    end

    with_them :enable_admin_mode do
      it_behaves_like 'handling secrets manager permission'
    end
  end

  describe 'read_group_secrets_manager_status' do
    let(:permission) { :read_group_secrets_manager_status }

    where(:current_user, :allowed) do
      ref(:anonymous)  | false
      ref(:guest)      | false
      ref(:planner)    | false
      ref(:reporter)   | true
      ref(:developer)  | true
      ref(:maintainer) | true
      ref(:owner)      | true

      ref(:auditor)    | false
      ref(:admin)      | true
    end

    with_them :enable_admin_mode do
      it_behaves_like 'handling secrets manager permission'
    end
  end

  describe 'read_secrets_permission' do
    let(:permission) { :read_secrets_permission }

    where(:current_user, :allowed) do
      ref(:anonymous)  | false
      ref(:guest)      | false
      ref(:planner)    | false
      ref(:reporter)   | false
      ref(:developer)  | false
      ref(:maintainer) | true
      ref(:owner)      | true

      ref(:auditor)    | false
      ref(:admin)      | true
    end

    with_them :enable_admin_mode do
      it_behaves_like 'handling secrets manager permission'
    end
  end

  %i[read_secret create_secret update_secret delete_secret create_secrets_manager_api_jwt].each do |permission|
    describe permission.to_s do
      let(:permission) { permission }

      where(:group_visibility, :current_user, :allowed) do
        :private  | ref(:owner)      | true
        :private  | ref(:maintainer) | true
        :private  | ref(:developer)  | true
        :private  | ref(:reporter)   | true
        :private  | ref(:planner)    | false
        :private  | ref(:guest)      | false
        :private  | ref(:anonymous)  | false
        :private  | ref(:admin)      | false
        :public   | ref(:owner)      | true
        :public   | ref(:maintainer) | true
        :public   | ref(:developer)  | true
        :public   | ref(:reporter)   | true
        :public   | ref(:planner)    | false
        :public   | ref(:guest)      | false
        :public   | ref(:anonymous)  | false
        :public   | ref(:admin)      | false
      end

      with_them do
        before do
          group.update!(visibility_level: Gitlab::VisibilityLevel.string_options[group_visibility])
        end

        it_behaves_like 'handling secrets manager permission'
      end
    end
  end

  describe 'trial_eligible entitlement on a subgroup' do
    subject { described_class.new(owner, subgroup) }

    before do
      stub_licensed_features(native_secrets_management: true)
      allow(::SecretsManagement::Availability).to receive(:enabled_for_group?).with(subgroup).and_return(true)
      stub_feature_flags(secrets_manager_paid_experience: true)
      entitlement = ::SecretsManagement::Entitlement.new(state: :trial_eligible)
      allow(::SecretsManagement::Entitlement).to receive(:for).and_return(entitlement)
    end

    %i[read_secret read_secrets_manager read_secrets_permission read_group_secrets_manager_status].each do |permission|
      it "disallows #{permission}" do
        expect_disallowed(permission)
      end
    end

    context 'when the root group is enrolled in the beta cohort' do
      before do
        create(:secrets_manager_namespace_enrollment, namespace: group, beta: true)
      end

      %i[read_secret read_secrets_manager read_secrets_permission read_group_secrets_manager_status]
        .each do |permission|
        it "allows #{permission}" do
          expect_allowed(permission)
        end
      end

      it 'still disallows writes' do
        expect_disallowed(:create_secret)
      end

      context 'when the beta program has ended' do
        before do
          entitlement = ::SecretsManagement::Entitlement.new(state: :trial_eligible, beta_program_ended: true)
          allow(::SecretsManagement::Entitlement).to receive(:for).and_return(entitlement)
        end

        it 'keeps read visibility' do
          expect_allowed(:read_secret, :read_secrets_manager, :read_group_secrets_manager_status)
        end

        it 'still denies the direct-read JWT' do
          expect_disallowed(:create_secrets_manager_api_jwt)
        end
      end
    end

    context 'when the root group enrollment is not beta' do
      before do
        create(:secrets_manager_namespace_enrollment, namespace: group, beta: false)
      end

      it 'disallows reads' do
        expect_disallowed(:read_secret)
      end
    end
  end

  describe 'trial_eligible entitlement after the beta cutoff' do
    subject { described_class.new(owner, group) }

    before do
      stub_licensed_features(native_secrets_management: true)
      allow(::SecretsManagement::Availability).to receive(:enabled_for_group?).with(group).and_return(true)
      stub_feature_flags(secrets_manager_paid_experience: true)
      entitlement = ::SecretsManagement::Entitlement.new(state: :trial_eligible, beta_program_ended: true)
      allow(::SecretsManagement::Entitlement).to receive(:for).and_return(entitlement)
    end

    it 'disallows the direct-read JWT (REST access-token endpoint)' do
      expect_disallowed(:create_secrets_manager_api_jwt)
    end

    it 'still allows Rails-brokered reads' do
      expect_allowed(:read_secret)
    end
  end

  # Policy conditions deliberately do not emit denial telemetry: they are pure
  # predicates re-run on speculative `can?` checks and GraphQL type
  # authorization. Emission happens at the entry points instead (GraphQL write
  # concern, CI runner payload gate, service gate).
  describe 'secrets manager entitlement denial telemetry' do
    let(:policy) { described_class.new(owner, group) }
    let(:entitlement) { ::SecretsManagement::Entitlement.new(state: :blocked, blocked_reason: :trial_expired) }

    before do
      stub_licensed_features(native_secrets_management: true)
      allow(::SecretsManagement::Availability).to receive(:enabled_for_group?).with(group).and_return(true)
      stub_feature_flags(secrets_manager_paid_experience: true)
      allow(::SecretsManagement::Entitlement).to receive(:for).and_return(entitlement)
    end

    it 'does not emit denial telemetry from policy conditions' do
      expect(::SecretsManagement::Entitlement::DenialTelemetry).not_to receive(:track)

      policy.allowed?(:create_secret)
      policy.allowed?(:read_secret)
    end
  end

  shared_examples 'handling secrets manager enrollment permission' do
    # Group-level enrollment is SaaS-only and requires the license + namespace FF.
    context 'when on GitLab.com', :saas do
      before do
        stub_licensed_features(native_secrets_management: true)
        stub_feature_flags(secrets_manager_namespace_enrollment: group)
      end

      it 'allows or disallows the permission based on role' do
        if allowed
          expect_allowed(permission)
        else
          expect_disallowed(permission)
        end
      end

      context 'when the namespace enrollment feature flag is disabled' do
        before do
          stub_feature_flags(secrets_manager_namespace_enrollment: false)
        end

        it 'disallows the permission' do
          expect_disallowed(permission)
        end
      end

      context 'when the license is not available' do
        before do
          stub_licensed_features(native_secrets_management: false)
        end

        it 'disallows the permission' do
          expect_disallowed(permission)
        end
      end

      context 'when the group is a non-root subgroup' do
        let(:subgroup) { create(:group, :private, parent: group) }
        let(:subgroup_policy) { described_class.new(current_user, subgroup) }

        it 'disallows the permission on the subgroup' do
          expect(subgroup_policy.allowed?(permission)).to be(false)
        end
      end
    end

    context 'when not on GitLab.com' do
      it 'disallows the permission (group-level enrollment is SaaS-only)' do
        expect_disallowed(permission)
      end
    end
  end

  describe 'create_secrets_manager_enrollment' do
    let(:permission) { :create_secrets_manager_enrollment }

    where(:current_user, :allowed) do
      ref(:anonymous)  | false
      ref(:guest)      | false
      ref(:planner)    | false
      ref(:reporter)   | false
      ref(:developer)  | false
      ref(:maintainer) | false
      ref(:owner)      | true

      ref(:auditor)    | false
      ref(:admin)      | true
    end

    with_them :enable_admin_mode do
      it_behaves_like 'handling secrets manager enrollment permission'
    end
  end

  describe 'delete_secrets_manager_enrollment' do
    let(:permission) { :delete_secrets_manager_enrollment }

    where(:current_user, :allowed) do
      ref(:anonymous)  | false
      ref(:guest)      | false
      ref(:planner)    | false
      ref(:reporter)   | false
      ref(:developer)  | false
      ref(:maintainer) | false
      ref(:owner)      | true

      ref(:auditor)    | false
      ref(:admin)      | true
    end

    with_them :enable_admin_mode do
      it_behaves_like 'handling secrets manager enrollment permission'
    end
  end

  describe 'read_secrets_manager_enrollment' do
    let(:permission) { :read_secrets_manager_enrollment }

    where(:current_user, :allowed) do
      ref(:anonymous)  | false
      ref(:guest)      | false
      ref(:planner)    | false
      ref(:reporter)   | false
      ref(:developer)  | false
      ref(:maintainer) | false
      ref(:owner)      | true

      ref(:auditor)    | false
      ref(:admin)      | true
    end

    with_them :enable_admin_mode do
      it_behaves_like 'handling secrets manager enrollment permission'
    end
  end

  describe 'auditors' do
    let_it_be(:group) { create(:group, :private) }
    let(:user) { auditor }

    subject { described_class.new(user, group) }

    before do
      create_current_license_without_expiration(plan: License::ULTIMATE_PLAN)
    end

    context 'for read_* permissions' do
      let(:excluded_permissions) do
        [
          :read_advanced_dependency_management,
          :read_ai_foundational_flow,
          :read_ai_catalog_mcp_server,
          :read_ai_catalog_flow,
          :read_ai_catalog_third_party_flow,
          :read_ai_catalog_item_consumer,
          :read_ai_tool_rule,
          :read_avatar,
          :read_badge,
          :read_ci_cd_analytics,
          :read_ci_namespace_settings,
          :read_code,
          :read_composer_package,
          :read_confidential_epic,
          :read_counts,
          :read_crm_contact,
          :read_crm_organization,
          :read_custom_attribute,
          :read_customizable_dashboards,
          :read_dedicated_hosted_runner_usage,
          :read_deploy_token,
          :read_descendant_group,
          :read_design_activity,
          :read_enterprise_ai_analytics,
          :read_epic_award_emoji,
          :read_epic_discussion,
          :read_epic_discussion_note,
          :read_epic_iid,
          :read_epic_issue,
          :read_epic_label_event,
          :read_epic_link,
          :read_epic_link_relation,
          :read_epic_note,
          :read_epic_note_award_emoji,
          :read_epic_relation,
          :read_epic_state_event,
          :read_group_activity_analytics,
          :read_group_analytics_dashboards,
          :read_group_coverage_reports,
          :read_group_credentials_inventory,
          :read_group_saml_identity,
          :read_group_scim_identity,
          :read_group_secrets_manager_status,
          :read_secrets_manager,
          :read_secrets_manager_enrollment,
          :read_secrets_permission,
          :read_harbor_registry,
          :read_internal_note,
          :read_issue_statistic,
          :read_jobs_statistics,
          :read_limit_alert,
          :read_markdown_upload,
          :read_member,
          :read_member_access_request,
          :read_member_role,
          :read_model_selection_allowlist,
          :read_merge_request,
          :read_milestone_issue,
          :read_milestone_merge_request,
          :read_namespace_cluster_agent_mapping,
          :read_namespace_via_membership,
          :read_note,
          :read_npm_package_tag,
          :read_observability_portal,
          :read_package,
          :read_pro_ai_analytics,
          :read_project,
          :read_prometheus,
          :read_pypi_package,
          :read_release,
          :read_resource_access_tokens,
          :read_runner_cloud_provisioning_info,
          :read_runner_gke_provisioning_info,
          :read_runner_usage,
          :read_runners_registration_token,
          :read_saved_replies,
          :read_secret,
          :read_security_attribute,
          :read_security_configuration,
          :read_security_inventory,
          :read_security_orchestration_policy_project,
          :read_security_scan_profiles,
          :read_service_account,
          :read_shared_project,
          :read_statistics,
          :read_subgroup,
          :read_subgroup_epic,
          :read_subscription_usage,
          :read_timelog_category,
          :read_usage_quotas,
          :read_web_hook,
          :read_wiki_page_meta_note,
          :read_work_item_setting,
          :read_virtual_registry
        ]
      end

      let(:read_permissions) { described_class.ability_map.map.keys.select { |k| k.to_s.start_with?('read_') } }
      let(:expected_permissions) { read_permissions - excluded_permissions }

      it 'allows the permission', :aggregate_failures do
        expect_allowed(*expected_permissions)
      end
    end
  end

  describe 'subgroup/project-provisioned service account restrictions' do
    let_it_be(:service_account) { create(:user, :service_account, owner_of: group) }

    subject { described_class.new(service_account, group) }

    before do
      stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
    end

    it_behaves_like 'subgroup/project-provisioned service account restriction', :create_service_account
  end
end
