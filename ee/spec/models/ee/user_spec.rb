# frozen_string_literal: true

require 'spec_helper'

RSpec.describe User, feature_category: :system_access do
  include GitlabSubscriptions::SubscriptionHelpers
  include Ai::Catalog::FlowFactoryHelpers

  subject(:user) { described_class.new }

  it_behaves_like 'associations with defined deletion strategies'

  describe 'user creation' do
    describe 'with defaults' do
      it "applies defaults to user" do
        expect(user.group_view).to eq('details')
      end
    end
  end

  describe 'delegations' do
    it { is_expected.to delegate_method(:shared_runners_minutes_limit).to(:namespace) }
    it { is_expected.to delegate_method(:shared_runners_minutes_limit=).to(:namespace).with_arguments(133) }

    it do
      is_expected.to delegate_method(:onboarding_status_glm_content=).to(:user_detail).with_arguments('glm').allow_nil
    end

    it { is_expected.to delegate_method(:onboarding_status_glm_content).to(:user_detail).allow_nil }

    it do
      is_expected.to delegate_method(:onboarding_status_glm_source=).to(:user_detail).with_arguments('source').allow_nil
    end

    it { is_expected.to delegate_method(:onboarding_status_glm_source).to(:user_detail).allow_nil }
    it { is_expected.to delegate_method(:enterprise_group_associated_at).to(:user_detail) }

    it do
      is_expected.to delegate_method(:enterprise_group_associated_at=).to(:user_detail).with_arguments(Time.current)
    end

    it { is_expected.to delegate_method(:onboarding_status_step_url=).to(:user_detail).with_arguments('url').allow_nil }
    it { is_expected.to delegate_method(:onboarding_status_step_url).to(:user_detail).allow_nil }

    it { is_expected.to delegate_method(:onboarding_status_registration_objective).to(:user_detail).allow_nil }
    it { is_expected.to delegate_method(:onboarding_status_registration_objective=).to(:user_detail).with_arguments(1).allow_nil }
    it { is_expected.to delegate_method(:onboarding_status_registration_objective_name).to(:user_detail).allow_nil }

    it do
      is_expected
        .to delegate_method(:onboarding_status_registration_type=).to(:user_detail).with_arguments('_type_').allow_nil
    end

    it { is_expected.to delegate_method(:onboarding_status_registration_type).to(:user_detail).allow_nil }
    it { is_expected.to delegate_method(:onboarding_status_initial_registration_type).to(:user_detail).allow_nil }

    it { is_expected.to delegate_method(:onboarding_status_setup_for_company).to(:user_detail).allow_nil }
    it { is_expected.to delegate_method(:onboarding_status_setup_for_company=).to(:user_detail).with_arguments(:args).allow_nil }

    it do
      is_expected
        .to delegate_method(:onboarding_status_initial_registration_type=)
              .to(:user_detail).with_arguments('_type_').allow_nil
    end

    it do
      is_expected.to delegate_method(:onboarding_status_email_opt_in=).to(:user_detail).with_arguments(true).allow_nil
    end

    it { is_expected.to delegate_method(:onboarding_status_email_opt_in).to(:user_detail).allow_nil }
    it { is_expected.to delegate_method(:onboarding_status).to(:user_detail).allow_nil }
  end

  describe 'associations' do
    subject { build(:user) }

    it { is_expected.to have_one(:user_admin_role).class_name('Authz::UserAdminRole') }
    it { is_expected.to have_one(:admin_role).class_name('Authz::AdminRole') }
    it { is_expected.to have_one(:user_member_role).class_name('Users::UserMemberRole') }
    it { is_expected.to have_one(:member_role).class_name('MemberRole') }

    it { is_expected.to have_many(:vulnerability_feedback) }
    it { is_expected.to have_many(:path_locks).dependent(:destroy) }
    it { is_expected.to have_many(:users_security_dashboard_projects) }
    it { is_expected.to have_many(:security_dashboard_projects) }
    it { is_expected.to have_many(:board_preferences) }
    it { is_expected.to have_many(:boards_epic_user_preferences).class_name('Boards::EpicUserPreference') }
    it { is_expected.to have_many(:user_permission_export_uploads) }
    it { is_expected.to have_many(:oncall_participants).class_name('IncidentManagement::OncallParticipant') }
    it { is_expected.to have_many(:oncall_rotations).class_name('IncidentManagement::OncallRotation').through(:oncall_participants) }
    it { is_expected.to have_many(:oncall_schedules).class_name('IncidentManagement::OncallSchedule').through(:oncall_rotations) }
    it { is_expected.to have_many(:escalation_rules).class_name('IncidentManagement::EscalationRule') }
    it { is_expected.to have_many(:escalation_policies).class_name('IncidentManagement::EscalationPolicy').through(:escalation_rules) }
    it { is_expected.to have_many(:epic_board_recent_visits).inverse_of(:user) }
    it { is_expected.to have_many(:vulnerability_state_transitions).class_name('Vulnerabilities::StateTransition').with_foreign_key(:author_id).inverse_of(:author) }
    it { is_expected.to have_many(:deployment_approvals) }
    it { is_expected.to have_many(:namespace_bans).class_name('Namespaces::NamespaceBan') }
    it { is_expected.to have_many(:dependency_list_exports).class_name('Dependencies::DependencyListExport') }
    it { is_expected.to have_many(:elevated_members).class_name('Member') }
    it { is_expected.to have_many(:assigned_add_ons).class_name('GitlabSubscriptions::UserAddOnAssignment').inverse_of(:user).dependent(:destroy) }
    it { is_expected.to have_many(:country_access_logs).class_name('Users::CountryAccessLog').inverse_of(:user).dependent(:destroy) }
    it { is_expected.to have_many(:group_saml_identities).class_name('::Identity') }
    it { is_expected.to have_many(:group_saml_providers).through(:group_saml_identities).source(:saml_provider) }
    it { is_expected.to have_many(:requested_member_approvals).class_name('::GitlabSubscriptions::MemberManagement::MemberApproval').with_foreign_key(:requested_by_id) }
    it { is_expected.to have_many(:reviewed_member_approvals).class_name('::GitlabSubscriptions::MemberManagement::MemberApproval').with_foreign_key(:reviewed_by_id) }
    it { is_expected.to have_one(:pipl_user).class_name('ComplianceManagement::PiplUser') }
    it { is_expected.to have_many(:group_scim_identities).class_name('GroupScimIdentity').dependent(:destroy) }
    it { is_expected.to have_many(:instance_scim_identities).class_name('ScimIdentity').dependent(:destroy) }
    it { is_expected.to have_many(:scim_group_memberships).class_name('Authn::ScimGroupMembership') }
    it { is_expected.to have_many(:user_group_member_roles).class_name('Authz::UserGroupMemberRole') }
    it { is_expected.to have_many(:user_project_member_roles).class_name('Authz::UserProjectMemberRole') }
    it { is_expected.to have_many(:subscription_seat_assignments).class_name('GitlabSubscriptions::SeatAssignment') }
    it { is_expected.to have_many(:compromised_password_detections).class_name('Users::CompromisedPasswordDetection').inverse_of(:user) }
    it { is_expected.to have_many(:arkose_sessions).class_name('Users::ArkoseSession').inverse_of(:user) }
    it { is_expected.to have_many(:merge_requests_compliance_violations).class_name('MergeRequests::ComplianceViolation').inverse_of(:violating_user) }
    it { is_expected.to have_many(:ai_agent_identities).class_name('Ai::ExternalAgents::AgentIdentity').with_foreign_key(:user_id).dependent(:delete_all) }
    it { is_expected.to have_many(:ai_catalog_item_consumers).class_name('Ai::Catalog::ItemConsumer').with_foreign_key(:service_account_id).dependent(:nullify) }
    it { is_expected.to have_many(:ai_catalog_item_versions).class_name('Ai::Catalog::ItemVersion').with_foreign_key(:created_by_id).dependent(:nullify) }
    it { is_expected.to have_many(:ai_catalog_mcp_servers_users).class_name('Ai::Catalog::McpServersUser').dependent(:destroy) }
    it { is_expected.to have_many(:created_mcp_servers).class_name('Ai::Catalog::McpServer').with_foreign_key(:created_by_id).dependent(:nullify) }
    it { is_expected.to have_many(:cluster_agent_url_configurations).class_name('Clusters::Agents::UrlConfiguration').with_foreign_key(:created_by_user_id).dependent(:nullify) }
    it { is_expected.to have_many(:minimal_access_group_members).class_name('GroupMember') }
    it { is_expected.to have_many(:minimal_access_groups).class_name('Group').through(:minimal_access_group_members).source(:group) }
  end

  describe 'nested attributes' do
    it { is_expected.to respond_to(:namespace_attributes=) }
  end

  describe 'validations' do
    it 'does not allow a user to be both an auditor and an admin' do
      user = build(:user, :admin, :auditor)

      expect(user).to be_invalid
    end

    describe 'enterprise_user_email_change', :saas, :aggregate_failures do
      let(:new_email) { 'new-email@example.com' }

      before do
        stub_licensed_features(domain_verification: true)
      end

      context 'when user is not an enterprise user' do
        let(:user) { create(:user) }

        context 'when email is not changed' do
          it 'is not applied' do
            expect(user).not_to receive(:enterprise_user_email_change)

            expect(user).to be_valid
          end
        end

        context 'when email is changed' do
          it 'is not applied' do
            user.email = new_email

            expect(user).not_to receive(:enterprise_user_email_change)

            expect(user).to be_valid
          end
        end
      end

      context 'when user is an enterprise user' do
        let(:user) { create(:enterprise_user) }

        # Neither domain removal/expiration nor change in group plan disassociates related enterprise users from enterprise group
        # see https://gitlab.com/gitlab-org/gitlab/-/issues/406277.
        # However, in that case, the group will not be considered an owner of the existing emails of their enterprise users anymore.
        # To prevent making enterprise users of the group invalid in that case,
        # this validation should be only applied when an enterprise user's email is being changed.
        context 'when email is not changed' do
          it 'is not applied' do
            expect(user).not_to receive(:enterprise_user_email_change)

            expect(user).to be_valid
          end
        end

        context 'when email is changed' do
          context 'when new email is not owned by the enterprise group' do
            it 'is applied and makes user record invalid' do
              user.email = new_email

              expect(user).to receive(:enterprise_user_email_change).and_call_original

              expect(user).to be_invalid
              expect(user.errors.full_messages).to include("Email must be owned by the user's enterprise group")
            end

            context 'when skip_enterprise_user_email_change_restrictions! is enabled' do
              before do
                user.skip_enterprise_user_email_change_restrictions!
              end

              it 'is not applied' do
                user.email = new_email

                expect(user).not_to receive(:enterprise_user_email_change)

                expect(user).to be_valid
              end
            end

            context 'when new email has invalid format' do
              let(:new_email) { 'invalid_email_format' }

              it 'is applied and makes user record invalid' do
                user.email = new_email

                expect(user).to receive(:enterprise_user_email_change).and_call_original

                expect(user).to be_invalid
                expect(user.errors.full_messages).to include("Email must be owned by the user's enterprise group")
              end
            end

            context 'when new email has invalid format with spaces' do
              let(:new_email) { 'invalid email format' }

              it 'is applied and makes user record invalid' do
                user.email = new_email

                expect(user).to receive(:enterprise_user_email_change).and_call_original

                expect(user).to be_invalid
                expect(user.errors.full_messages).to include("Email must be owned by the user's enterprise group")
              end
            end

            context 'when new email is nil' do
              let(:new_email) { nil }

              it 'is applied and makes user record invalid' do
                user.email = new_email

                expect(user).to receive(:enterprise_user_email_change).and_call_original

                expect(user).to be_invalid
                expect(user.errors.full_messages).to include("Email must be owned by the user's enterprise group")
              end
            end
          end

          context 'when new email is owned by the enterprise group' do
            let(:enterprise_group_verified_domain) { create(:pages_domain, project: create(:project, group: user.user_detail.enterprise_group)) }
            let(:new_email) { "new-email@#{enterprise_group_verified_domain.domain}" }

            it 'is applied but does not make user record invalid' do
              user.email = new_email

              expect(user).to receive(:enterprise_user_email_change).and_call_original

              expect(user).to be_valid
            end
          end
        end
      end
    end

    describe 'composite_identity_enforced' do
      let(:user) { build(:user) }

      context 'when user is not a service account' do
        it 'is valid when composite_identity_enforced is false' do
          user.composite_identity_enforced = false

          expect(user).to be_valid
        end

        it 'is invalid when composite_identity_enforced is true' do
          user.composite_identity_enforced = true

          expect(user).to be_invalid
          expect(user.errors[:composite_identity_enforced]).to include('is not included in the list')
        end
      end

      context 'when user is a service account' do
        let(:user) { build(:user, :service_account) }

        it 'is valid when composite_identity_enforced is true' do
          user.composite_identity_enforced = true

          expect(user).to be_valid
        end

        it 'is valid when composite_identity_enforced is false' do
          user.composite_identity_enforced = false

          expect(user).to be_valid
        end
      end
    end
  end

  describe "scopes" do
    describe ".non_ldap" do
      it "retuns non-ldap user" do
        described_class.delete_all
        create(:user)
        ldap_user = create(:omniauth_user, provider: "ldapmain")
        create(:omniauth_user, provider: "gitlab")

        users = described_class.non_ldap

        expect(users.count).to eq(2)
        expect(users.detect { |user| user.username == ldap_user.username }).to be_nil
      end
    end

    describe '.excluding_guests_and_requests' do
      let!(:user_without_membership) { create(:user).id }
      let!(:project_guest_user)      { create(:project_member, :guest).user_id }
      let!(:project_reporter_user)   { create(:project_member, :reporter).user_id }
      let!(:group_guest_user)        { create(:group_member, :guest).user_id }
      let!(:group_reporter_user)     { create(:group_member, :reporter).user_id }
      let_it_be(:requested_user) { create(:group_member, :reporter, :access_request).user_id }

      it 'exclude users with a Guest role in a Project/Group' do
        user_ids = described_class.excluding_guests_and_requests.pluck(:id)

        expect(user_ids).to include(project_reporter_user)
        expect(user_ids).to include(group_reporter_user)

        expect(user_ids).not_to include(user_without_membership)
        expect(user_ids).not_to include(project_guest_user)
        expect(user_ids).not_to include(group_guest_user)
        expect(user_ids).not_to include(requested_user)
      end
    end

    describe 'with_invalid_expires_at_tokens' do
      it 'only includes users with invalid tokens' do
        valid_pat = create(:personal_access_token, expires_at: 7.days.from_now)
        invalid_pat = create(:personal_access_token, expires_at: 20.days.from_now)

        users_with_invalid_tokens = described_class.with_invalid_expires_at_tokens(15.days.from_now)

        expect(users_with_invalid_tokens).to contain_exactly(invalid_pat.user)
        expect(users_with_invalid_tokens).not_to include valid_pat.user
      end
    end

    describe '.guests_with_elevating_role' do
      let(:group) { create(:group) }
      let(:member_role_elevating) { create(:member_role, :billable, namespace: group) }
      let(:member_role_basic) { create(:member_role, :non_billable, namespace: group) }
      let(:expected_user) { create(:group_member, :guest, source: group, member_role: member_role_elevating).user }

      before do
        user = create(:user)
        [
          expected_user,
          create(:group_member, :developer, source: group).user,
          _elevated_guest_who_is_also_developer = create(:group_member, :guest, user: user, source: group, member_role: member_role_elevating).user,
          create(:group_member, :guest, source: group, member_role: member_role_basic).user,
          create(:group_member, :developer, user: user).user
        ].each do |user|
          Users::UpdateHighestMemberRoleService.new(user).execute
        end
      end

      it 'returns only guests with elevated role' do
        expect(MemberRole).to receive(:occupies_seat).at_least(:once).and_return(MemberRole.where(id: member_role_elevating.id))

        expect(described_class.guests_with_elevating_role).to contain_exactly(expected_user)
      end
    end

    describe '.managed_by' do
      let!(:group) { create(:group_with_managed_accounts) }
      let!(:managed_users) { create_list(:user, 2, managing_group: group) }

      it 'returns users managed by the specified group' do
        expect(described_class.managed_by(group)).to match_array(managed_users)
      end
    end

    describe '.unconfirmed_and_created_before' do
      it 'returns unconfirmed, active, human users who never signed in and were created before timestamp passed in' do
        cut_off_datetime = 7.days.ago
        _confirmed_user_created_before_cut_off = create(:user, confirmed_at: Time.current, created_at: cut_off_datetime - 1.day)
        _confirmed_user_created_after_cut_off = create(:user, confirmed_at: Time.current, created_at: cut_off_datetime + 1.day)
        _unconfirmed_user_created_after_cut_off = create(:user, :unconfirmed, created_at: cut_off_datetime + 1.day)
        _unconfirmed_bot_user_created_before_cut_off = create(:user, :bot, :unconfirmed, created_at: cut_off_datetime - 1.day)
        _deactivated_user_created_before_cut_off = create(:user, :unconfirmed, :deactivated, created_at: cut_off_datetime - 1.day)
        _unconfirmed_user_who_signed_in = create(:user, :unconfirmed, created_at: cut_off_datetime - 1.day, sign_in_count: 1)
        unconfirmed_user_created_before_cut_off = create(:user, :unconfirmed, created_at: cut_off_datetime - 1.day)

        expect(described_class.unconfirmed_and_created_before(cut_off_datetime)).to match_array(
          [unconfirmed_user_created_before_cut_off]
        )
      end
    end

    describe '.with_email_domain' do
      let(:email_domain) { 'example.GitLab.com' }

      it 'returns users with email domain that is equal to the specified domain' do
        user_with_the_specified_domain_1 = create(:user, email: "user_with_the_specified_domain_1@#{email_domain}")
        # to ensure the query is case-insensitive
        user_with_the_specified_domain_2 = create(:user, email: "user_with_the_specified_domain_2@#{email_domain}")
        user_with_the_specified_domain_2.update_column(:email, "user_with_the_specified_domain_2@#{email_domain.swapcase}")
        _user_with_subdomain_of_the_specified_domain = create(:user, email: "user_with_subdomain_of_the_specified_domain@subdomain.#{email_domain}")
        _user_with_domain_that_contains_the_specified_domain = create(:user, email: "user_with_domain_that_contains_the_specified_domain@subdomain.#{email_domain}.example.com")

        expect(described_class.with_email_domain(email_domain)).to match_array(
          [
            user_with_the_specified_domain_1,
            user_with_the_specified_domain_2
          ]
        )
      end
    end

    describe '.excluding_enterprise_users_of_group' do
      let_it_be(:group) { create(:group) }

      it 'excludes users that are enterprise users of the specified group' do
        create(:user, enterprise_group: group)
        enterprise_user_of_some_group = create(:enterprise_user)
        not_enterprise_user = create(:user, enterprise_group_id: nil)
        user_without_user_detail_record = create(:user)
        user_without_user_detail_record.user_detail.destroy!

        expect(described_class.excluding_enterprise_users_of_group(group)).to match_array(
          [
            enterprise_user_of_some_group,
            not_enterprise_user,
            user_without_user_detail_record
          ]
        )
      end
    end

    describe '.with_saml_provider' do
      let_it_be(:user) { create(:user) }
      let_it_be(:saml_provider) { create(:saml_provider) }

      subject(:with_saml_provider) { described_class.with_saml_provider(saml_provider) }

      it 'does not find users without a SAML identity' do
        expect(with_saml_provider).to be_empty
      end

      context 'when users have a SAML identity tied to the provider' do
        let_it_be(:saml_identity) { create(:group_saml_identity, user: user, saml_provider: saml_provider) }

        it 'finds the matching users' do
          expect(with_saml_provider).to match_array([user])
        end

        it 'does not find users with a different SAML provider' do
          provider = create(:saml_provider)

          expect(described_class.with_saml_provider(provider)).to be_empty
        end
      end
    end

    describe '.expired_sso_session_saml_providers_with_access_restricted' do
      let_it_be(:user) { create(:user) }
      let_it_be(:saml_provider) { create(:saml_provider) }

      before do
        allow(user).to receive(:expired_sso_session_saml_providers).and_return([saml_provider])
      end

      subject(:expired_sso_session_saml_providers_with_access_restricted) do
        user.expired_sso_session_saml_providers_with_access_restricted
      end

      context 'when SAML provider has access restricted' do
        before do
          allow_next_instance_of(::Gitlab::Auth::GroupSaml::SsoEnforcer) do |sso_enforcer|
            allow(sso_enforcer).to receive(:access_restricted?).and_return(true)
          end
        end

        it 'returns array including SAML provider' do
          expect(expired_sso_session_saml_providers_with_access_restricted).to include(saml_provider)
        end
      end

      context 'when SAML provider does not have access restricted' do
        before do
          allow_next_instance_of(::Gitlab::Auth::GroupSaml::SsoEnforcer) do |sso_enforcer|
            allow(sso_enforcer).to receive(:access_restricted?).and_return(false)
          end
        end

        it 'returns array excluding SAML provider' do
          expect(expired_sso_session_saml_providers_with_access_restricted).not_to include(saml_provider)
        end
      end
    end

    describe '.expired_sso_session_saml_providers' do
      let_it_be(:user) { create(:user) }
      let_it_be(:saml_provider1) { create(:saml_provider) }
      let_it_be(:saml_provider2) { create(:saml_provider) }

      subject(:expired_sso_session_saml_providers) { user.expired_sso_session_saml_providers }

      context 'for users without SAML identity' do
        it { is_expected.to be_empty }
      end

      context 'for users with SAML identity' do
        let_it_be(:identity1) { create(:group_saml_identity, user: user) }
        let_it_be(:identity2) { create(:group_saml_identity, user: user) }
        let_it_be(:saml_provider1) { identity1.saml_provider }
        let_it_be(:saml_provider2) { identity2.saml_provider }

        context 'when there are no active SAML sessions' do
          it 'returns all the SAML providers' do
            expect(expired_sso_session_saml_providers).to contain_exactly(saml_provider1, saml_provider2)
          end
        end

        context 'when there are an active SAML sessions', :freeze_time do
          it 'returns SAML providers with no session' do
            active_saml_sessions = { saml_provider1.id => Time.current }
            allow(::Gitlab::Auth::GroupSaml::SsoState).to receive(:active_saml_sessions).and_return(active_saml_sessions)

            expect(expired_sso_session_saml_providers).to contain_exactly(saml_provider2)
          end
        end

        context 'when there are expired SAML sessions', :freeze_time do
          it 'returns the expired SAML providers and SAML providers with no session' do
            active_saml_sessions = { saml_provider1.id => Time.current - 2.days }
            allow(::Gitlab::Auth::GroupSaml::SsoState).to receive(:active_saml_sessions).and_return(active_saml_sessions)

            expect(expired_sso_session_saml_providers).to contain_exactly(saml_provider1, saml_provider2)
          end
        end
      end
    end

    describe '.active_sso_sessions_saml_provider_ids', :freeze_time do
      subject(:active_sso_sessions_saml_provider_ids) { user.active_sso_sessions_saml_provider_ids }

      it 'returns provider ids of active SAML sessions' do
        active_saml_sessions = { 1 => Time.current, 2 => Time.current - 2.days }
        allow(::Gitlab::Auth::GroupSaml::SsoState).to receive(:active_saml_sessions).and_return(active_saml_sessions)

        expect(active_sso_sessions_saml_provider_ids).to contain_exactly(1)
      end
    end

    describe '.security_policy_bots_for_projects' do
      let_it_be(:security_policy_bot_1) { create(:user, :security_policy_bot) }
      let_it_be(:security_policy_bot_2) { create(:user, :security_policy_bot) }
      let_it_be(:project_1) { create(:project, guests: security_policy_bot_1) }
      let_it_be(:project_2) { create(:project, guests: security_policy_bot_2) }

      let(:projects) { [project_1, project_2] }

      subject { described_class.security_policy_bots_for_projects(projects) }

      it { is_expected.to contain_exactly(security_policy_bot_1, security_policy_bot_2) }
    end

    describe '.security_policy_bot_users_without_project_membership' do
      let_it_be(:security_policy_bot_with_project) { create(:user, :security_policy_bot) }
      let_it_be(:security_policy_bot_orphaned) { create(:user, :security_policy_bot) }
      let_it_be(:regular_user) { create(:user) }
      let_it_be(:project) { create(:project, guests: security_policy_bot_with_project) }

      subject { described_class.orphaned_security_policy_bots }

      it 'returns security policy bots without project memberships' do
        expect(subject).to contain_exactly(security_policy_bot_orphaned)
      end

      it 'excludes security policy bots with project memberships' do
        expect(subject).not_to include(security_policy_bot_with_project)
      end

      it 'excludes regular users' do
        expect(subject).not_to include(regular_user)
      end

      context 'when security policy bot has ghost user migration' do
        let_it_be(:security_policy_bot_with_migration) { create(:user, :security_policy_bot) }
        let_it_be(:ghost_user_migration) { create(:ghost_user_migration, user: security_policy_bot_with_migration) }

        it 'excludes security policy bots with ghost user migrations' do
          expect(subject).not_to include(security_policy_bot_with_migration)
        end
      end

      context 'when security policy bot has both project membership and ghost user migration' do
        let_it_be(:security_policy_bot_both) { create(:user, :security_policy_bot) }
        let_it_be(:project_2) { create(:project, guests: security_policy_bot_both) }

        before_all do
          create(:ghost_user_migration, user: security_policy_bot_both)
        end

        it 'excludes security policy bots with both project membership and ghost user migration' do
          expect(subject).not_to include(security_policy_bot_both)
        end
      end

      context 'with various bot types' do
        let_it_be(:automation_bot) { create(:user, user_type: :automation_bot) }
        let_it_be(:project_bot) { create(:user, :project_bot) }
        let_it_be(:alert_bot) { create(:user, user_type: :alert_bot) }

        it 'only includes security policy bots' do
          expect(subject).not_to include(automation_bot, project_bot, alert_bot)
        end
      end
    end

    describe '.with_admin_role' do
      let_it_be(:user_1) { create(:user) }
      let_it_be(:user_2) { create(:user) }
      let_it_be(:user_3) { create(:user) }

      let_it_be(:user_role_1) { create(:user_member_role, user: user_1) }
      let_it_be(:user_role_2) { create(:user_member_role, user: user_2) }

      it 'returns the users with specific admin role' do
        expect(described_class.with_admin_role(user_role_1.member_role.id)).to eq([user_1])
      end
    end
  end

  describe 'after_create' do
    describe '#perform_user_cap_check' do
      let(:new_user_signups_cap) { nil }
      let(:seat_control_user_cap) { false }

      before do
        allow(Gitlab::CurrentSettings).to receive(:new_user_signups_cap).and_return(new_user_signups_cap)
        allow(Gitlab::CurrentSettings).to receive(:seat_control_user_cap?).and_return(seat_control_user_cap)
      end

      context 'when user cap is not set' do
        it 'does not enqueue SetUserStatusBasedOnUserCapSettingWorker' do
          expect(SetUserStatusBasedOnUserCapSettingWorker).not_to receive(:perform_async)

          create(:user, state: 'blocked_pending_approval')
        end
      end

      context 'when user cap is set' do
        let(:new_user_signups_cap) { 3 }
        let(:seat_control_user_cap) { true }

        context 'when user signup cap has been reached' do
          let!(:users) { create_list(:user, 3) }

          it 'enqueues SetUserStatusBasedOnUserCapSettingWorker' do
            expect(SetUserStatusBasedOnUserCapSettingWorker).to receive(:perform_async).once

            create(:user, state: 'blocked_pending_approval')
          end

          context 'when the user is already active' do
            it 'does not enqueue SetUserStatusBasedOnUserCapSettingWorker' do
              expect(SetUserStatusBasedOnUserCapSettingWorker).not_to receive(:perform_async)

              create(:user, state: 'active')
            end
          end
        end

        context 'when user signup cap has not been reached' do
          let!(:users) { create_list(:user, 2) }

          it 'does not enqueue SetUserStatusBasedOnUserCapSettingWorker' do
            expect(SetUserStatusBasedOnUserCapSettingWorker).not_to receive(:perform_async)

            create(:user, state: 'blocked_pending_approval')
          end
        end
      end
    end

    describe '#associate_with_enterprise_group' do
      context 'when building user' do
        subject(:build_user) { build(:user) }

        it 'is not triggered' do
          expect_next_instance_of(User) do |user|
            expect(user).not_to receive(:associate_with_enterprise_group)
          end

          build_user
        end
      end

      context 'when updating user' do
        let!(:user) { create(:user) }

        subject(:update_user) { user.update!(name: 'New name') }

        it 'is not triggered' do
          expect(user).not_to receive(:associate_with_enterprise_group)

          update_user
        end
      end

      context 'when creating user' do
        subject(:create_user) { create(:user) }

        it 'is triggered' do
          expect_next_instance_of(User) do |user|
            expect(user).to receive(:associate_with_enterprise_group)
          end

          create_user
        end

        it 'schedules Groups::EnterpriseUsers::AssociateWorker' do
          allow(Groups::EnterpriseUsers::AssociateWorker).to receive(:perform_async)

          create_user

          expect(Groups::EnterpriseUsers::AssociateWorker).to have_received(:perform_async).with(create_user.id)
        end
      end
    end
  end

  describe 'after_update' do
    describe '#email_changed_hook' do
      context 'for a new user' do
        let(:user) { build(:user) }

        it 'is not triggered' do
          expect(user).not_to receive(:email_changed_hook)

          user.save!
        end
      end

      context 'for an existing user' do
        let(:user) { create(:user) }

        context 'when skip_reconfirmation is disabled' do
          context 'when email change is not confirmed' do
            it 'is not triggered' do
              expect(user).not_to receive(:email_changed_hook)

              user.update!(email: 'new-email@example.com')
            end
          end

          context 'when email change is confirmed' do
            it 'is triggered' do
              user.update!(email: 'new-email@example.com')

              expect(user).to receive(:email_changed_hook)
              user.confirm
            end
          end
        end

        context 'when skip_reconfirmation is enabled' do
          before do
            user.skip_reconfirmation!
          end

          context 'when email was not changed' do
            it 'is not triggered' do
              expect(user).not_to receive(:email_changed_hook)

              user.update!(name: 'New name')
            end
          end

          context 'when email was changed' do
            it 'is triggered' do
              expect(user).to receive(:email_changed_hook)

              user.update!(email: 'new-email@example.com')
            end

            context 'when user is not an enterprise user' do
              it 'does not schedule Groups::EnterpriseUsers::DisassociateWorker' do
                expect(Groups::EnterpriseUsers::DisassociateWorker).not_to receive(:perform_async)

                user.update!(email: 'new-email@example.com')
              end
            end

            context 'when user is an enterprise user' do
              let(:user) { create(:enterprise_user) }

              it 'schedules Groups::EnterpriseUsers::DisassociateWorker' do
                expect(Groups::EnterpriseUsers::DisassociateWorker).to receive(:perform_async).with(user.id)

                user.skip_enterprise_user_email_change_restrictions!
                user.update!(email: 'new-email@example.com')
              end
            end
          end
        end
      end
    end
  end

  describe '#dismiss_compromised_password_detection_alerts' do
    let(:user) { create(:user) }

    context 'when password is changed' do
      it 'calls Users::CompromisedPasswords::ResolveDetectionForUserService' do
        expect(::Users::CompromisedPasswords::ResolveDetectionForUserService).to receive(:new).with(user).and_call_original

        user.update!(password: described_class.random_password)
      end
    end

    context 'when password is not changed' do
      it 'does not call Users::CompromisedPasswords::ResolveDetectionForUserService' do
        expect(::Users::CompromisedPasswords::ResolveDetectionForUserService).not_to receive(:new)

        user.update!(name: 'New name')
      end
    end
  end

  describe '.find_by_smartcard_identity' do
    let!(:user) { create(:user) }
    let!(:smartcard_identity) { create(:smartcard_identity, user: user) }

    it 'returns the user' do
      expect(described_class.find_by_smartcard_identity(
        smartcard_identity.subject, smartcard_identity.issuer
      )).to eq(user)
    end
  end

  describe 'reactivating a deactivated user' do
    let(:user) { create(:user, name: 'John Smith') }

    context 'a deactivated user' do
      before do
        user.deactivate
      end

      it 'can be activated' do
        user.activate

        expect(user.active?).to be_truthy
      end

      context 'when user cap is reached' do
        before do
          allow(described_class).to receive(:user_cap_reached?).and_return true
        end

        it 'cannot be activated' do
          user.activate

          expect(user.active?).not_to be_truthy
          expect(user.blocked_pending_approval?).to be_truthy
        end
      end

      context 'when restricted access is enabled and no seats are available' do
        let_it_be(:group) { create(:group) }
        let_it_be(:other_user) { create(:user) }

        before do
          create(:group_member, :developer, group: group, user: user)
          create(:group_member, :developer, group: group, user: other_user)
          stub_licensed_features(seat_control: true)
          stub_application_setting(seat_control: ::EE::ApplicationSetting::SEAT_CONTROL_BLOCK_OVERAGES)
          billable_count = ::User.billable.where.not(id: user.id).count
          license = build(:license)
          allow(license).to receive(:seats).and_return(billable_count)
          allow(License).to receive(:current).and_return(license)
        end

        it 'blocks the user pending approval' do
          user.activate

          expect(user.active?).to be false
          expect(user.blocked_pending_approval?).to be true
        end

        context 'when the user only has minimal access memberships' do
          before do
            stub_licensed_features(seat_control: true, minimal_access_role: true)
            user.members.each(&:destroy!)
            create(:group_member, :minimal_access, group: group, user: user)
          end

          it 'allows activation' do
            user.activate

            expect(user.active?).to be true
          end
        end

        context 'when the user is a guest with an elevated custom role on Ultimate' do
          before do
            user.members.each(&:destroy!)
            member_role = create(:member_role, :billable, namespace: group)
            create(:group_member, :guest, group: group, user: user, member_role: member_role)
            billable_count = ::User.billable.where.not(id: user.id).count
            license = build(:license)
            allow(license).to receive_messages(
              exclude_guests_from_active_count?: true,
              seats: billable_count
            )
            allow(License).to receive(:current).and_return(license)
          end

          it 'blocks the user pending approval' do
            user.activate

            expect(user.active?).to be false
            expect(user.blocked_pending_approval?).to be true
          end
        end

        it 'enqueues NotifyDormantUserBlockedWorker' do
          expect(Users::NotifyDormantUserBlockedWorker).to receive(:perform_async).with(user.id)

          user.activate
        end

        context 'when seats are available' do
          before do
            license = build(:license)
            allow(license).to receive(:seats).and_return(1000)
            allow(License).to receive(:current).and_return(license)
          end

          it 'allows activation' do
            user.activate

            expect(user.active?).to be true
          end

          it 'does not enqueue NotifyDormantUserBlockedWorker' do
            expect(Users::NotifyDormantUserBlockedWorker).not_to receive(:perform_async)

            user.activate
          end
        end

        context 'when there is exactly one seat available for the reactivated user' do
          before do
            billable_count = ::User.billable.where.not(id: user.id).count
            license = build(:license)
            allow(license).to receive(:seats).and_return(billable_count + 1)
            allow(License).to receive(:current).and_return(license)
          end

          it 'allows activation' do
            user.activate

            expect(user.active?).to be true
          end
        end

        context 'when the feature flag is disabled' do
          before do
            stub_feature_flags(bso_minimal_access_fallback: false)
          end

          it 'allows activation' do
            user.activate

            expect(user.active?).to be true
          end
        end

        context 'when seat control is not set to block overages' do
          before do
            stub_application_setting(seat_control: ::EE::ApplicationSetting::SEAT_CONTROL_OFF)
          end

          it 'allows activation' do
            user.activate

            expect(user.active?).to be true
          end
        end

        context 'when there is no license' do
          before do
            allow(License).to receive(:current).and_return(nil)
          end

          it 'allows activation' do
            user.activate

            expect(user.active?).to be true
          end
        end

        context 'when the license has no seat restriction' do
          before do
            license = build(:license)
            allow(license).to receive(:seats).and_return(nil)
            allow(License).to receive(:current).and_return(license)
          end

          it 'allows activation' do
            user.activate

            expect(user.active?).to be true
          end
        end
      end

      context 'when on GitLab.com with restricted access enabled', :saas do
        let_it_be_with_refind(:enterprise_group) { create(:group) }
        let_it_be(:other_user) { create(:user) }
        let(:user) { create(:enterprise_user, enterprise_group: enterprise_group) }

        before do
          create(:group_member, :developer, group: enterprise_group, user: user)
          create(:group_member, :developer, group: enterprise_group, user: other_user)
          stub_licensed_features(seat_control: true, minimal_access_role: true)
          create(:gitlab_subscription, :ultimate, namespace: enterprise_group, seats: 1)
          enterprise_group.namespace_settings.update!(seat_control: :block_overages)
        end

        it 'blocks the enterprise user pending approval' do
          user.activate

          expect(user.active?).to be false
          expect(user.blocked_pending_approval?).to be true
        end

        it 'enqueues NotifyDormantUserBlockedWorker' do
          expect(Users::NotifyDormantUserBlockedWorker).to receive(:perform_async).with(user.id)

          user.activate
        end

        context 'when the user is not an enterprise user' do
          before do
            user.user_detail.update!(enterprise_group_id: nil)
          end

          it 'allows activation' do
            user.activate

            expect(user.active?).to be true
          end
        end

        context 'when seats are available' do
          before do
            enterprise_group.gitlab_subscription.update!(seats: 1000)
          end

          it 'allows activation' do
            user.activate

            expect(user.active?).to be true
          end

          it 'does not enqueue NotifyDormantUserBlockedWorker' do
            expect(Users::NotifyDormantUserBlockedWorker).not_to receive(:perform_async)

            user.activate
          end
        end

        context 'when there is exactly one seat available for the reactivated user' do
          before do
            billable_count = enterprise_group.billed_user_ids[:user_ids].size
            enterprise_group.gitlab_subscription.update!(seats: billable_count + 1)
          end

          it 'allows activation' do
            user.activate

            expect(user.active?).to be true
          end
        end

        context 'when the user only has minimal access memberships' do
          before do
            user.members.each(&:destroy!)
            create(:group_member, :minimal_access, group: enterprise_group, user: user)
          end

          it 'allows activation' do
            user.activate

            expect(user.active?).to be true
          end
        end

        context 'when the user is only billable in another hierarchy' do
          let_it_be(:other_group) { create(:group) }

          before do
            user.members.each(&:destroy!)
            create(:group_member, :guest, group: enterprise_group, user: user)
            create(:group_member, :developer, group: other_group, user: user)
          end

          it 'allows activation' do
            user.activate

            expect(user.active?).to be true
          end
        end

        context 'when restricted access is not enabled on the enterprise group' do
          before do
            enterprise_group.namespace_settings.update!(seat_control: :off)
          end

          it 'allows activation' do
            user.activate

            expect(user.active?).to be true
          end
        end

        context 'when the group has no paid subscription' do
          before do
            enterprise_group.gitlab_subscription.update!(hosted_plan: nil)
          end

          it 'allows activation' do
            user.activate

            expect(user.active?).to be true
          end
        end

        context 'when the subscription has no seat limit' do
          before do
            enterprise_group.gitlab_subscription.update!(seats: 0)
          end

          it 'allows activation' do
            user.activate

            expect(user.active?).to be true
          end
        end
      end
    end
  end

  describe 'the GitLab_Auditor_User add-on' do
    context 'creating an auditor user' do
      it "does not allow creating an auditor user if the addon isn't enabled" do
        stub_licensed_features(auditor_user: false)

        expect(build(:user, :auditor)).to be_invalid
      end

      it "does not allow creating an auditor user if no license is present" do
        allow(License).to receive(:current).and_return nil

        expect(build(:user, :auditor)).to be_invalid
      end

      it "allows creating an auditor user if the addon is enabled" do
        stub_licensed_features(auditor_user: true)

        expect(build(:user, :auditor)).to be_valid
      end

      it "allows creating a regular user if the addon isn't enabled" do
        stub_licensed_features(auditor_user: false)

        expect(build(:user)).to be_valid
      end
    end

    describe '#auditor?' do
      it "returns true for an auditor user if the addon is enabled" do
        stub_licensed_features(auditor_user: true)

        expect(build(:user, :auditor)).to be_auditor
      end

      it "returns false for an auditor user if the addon is not enabled" do
        stub_licensed_features(auditor_user: false)

        expect(build(:user, :auditor)).not_to be_auditor
      end

      it "returns false for an auditor user if a license is not present" do
        allow(License).to receive(:current).and_return nil

        expect(build(:user, :auditor)).not_to be_auditor
      end

      it "returns false for a non-auditor user even if the addon is present" do
        stub_licensed_features(auditor_user: true)

        expect(build(:user)).not_to be_auditor
      end
    end
  end

  describe '#access_level=' do
    let(:user) { build(:user) }

    before do
      # `auditor?` returns true only when the user is an auditor _and_ the auditor license
      # add-on is present. We aren't testing this here, so we can assume that the add-on exists.
      stub_licensed_features(auditor_user: true)
    end

    it "does not set 'auditor' for an invalid access level" do
      user.access_level = :invalid_access_level

      expect(user.auditor).to be false
    end

    it "does not set 'auditor' for admin level" do
      user.access_level = :admin

      expect(user.auditor).to be false
    end

    it "assigns the 'auditor' access level" do
      user.access_level = :auditor

      expect(user.access_level).to eq(:auditor)
      expect(user.admin).to be false
      expect(user.auditor).to be true
    end

    it "assigns the 'auditor' access level" do
      user.access_level = :regular

      expect(user.access_level).to eq(:regular)
      expect(user.admin).to be false
      expect(user.auditor).to be false
    end

    it "clears the 'admin' access level when a user is made an auditor" do
      user.access_level = :admin
      user.access_level = :auditor

      expect(user.access_level).to eq(:auditor)
      expect(user.admin).to be false
      expect(user.auditor).to be true
    end

    it "clears the 'auditor' access level when a user is made an admin" do
      user.access_level = :auditor
      user.access_level = :admin

      expect(user.access_level).to eq(:admin)
      expect(user.admin).to be true
      expect(user.auditor).to be false
    end

    it "doesn't clear existing 'auditor' access levels when an invalid access level is passed in" do
      user.access_level = :auditor
      user.access_level = :invalid_access_level

      expect(user.access_level).to eq(:auditor)
      expect(user.admin).to be false
      expect(user.auditor).to be true
    end
  end

  describe '#can_read_all_resources?' do
    it 'returns true for auditor user' do
      user = build(:user, :auditor)

      expect(user.can_read_all_resources?).to be_truthy
    end
  end

  describe '#can_admin_all_resources?' do
    it 'returns false for auditor user' do
      user = build(:user, :auditor)

      expect(user.can_admin_all_resources?).to be_falsy
    end
  end

  describe '#can_admin_all_namespaces?' do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace_a) { create(:group) }
    let_it_be(:namespace_b) { create(:group) }

    context 'when the user is an admin' do
      let_it_be(:user) { create(:user, :admin) }

      it 'returns true regardless of namespace membership', :enable_admin_mode do
        expect(user.can_admin_all_namespaces?([namespace_a, namespace_b])).to be(true)
      end
    end

    context 'when the user has owner access on all namespaces' do
      before do
        namespace_a.add_owner(user)
        namespace_b.add_owner(user)
      end

      it 'returns true' do
        expect(user.can_admin_all_namespaces?([namespace_a, namespace_b])).to be(true)
      end
    end

    context 'when the user lacks owner access on one namespace' do
      before do
        namespace_a.add_owner(user)
      end

      it 'returns false' do
        expect(user.can_admin_all_namespaces?([namespace_a, namespace_b])).to be(false)
      end
    end

    context 'when the namespaces list is empty' do
      it 'returns true' do
        expect(user.can_admin_all_namespaces?([])).to be(true)
      end
    end

    context 'when the namespaces list contains nil values' do
      before do
        namespace_a.add_owner(user)
      end

      it 'ignores nil and evaluates remaining namespaces' do
        expect(user.can_admin_all_namespaces?([nil, namespace_a])).to be(true)
      end
    end
  end

  describe '#forget_me!' do
    subject { create(:user) }

    it 'calls save on the user' do
      expect(subject).to receive(:save)

      subject.forget_me!
    end

    it 'does not call save when in a GitLab read-only instance' do
      allow(Gitlab::Database).to receive(:read_only?).and_return(true)

      expect(subject).not_to receive(:save)

      subject.forget_me!
    end
  end

  describe '#remember_me!' do
    subject { create(:user, remember_created_at: nil) }

    it 'updates remember_created_at' do
      subject.remember_me!

      expect(subject.reload.remember_created_at).not_to be_nil
    end

    it 'does not update remember_created_at when in a Geo read-only instance' do
      allow(Gitlab::Database).to receive(:read_only?).and_return(true)

      expect { subject.remember_me! }.not_to change { subject.remember_created_at }
    end
  end

  describe '#email_domain' do
    context 'when user email is nil' do
      let_it_be(:user) { build(:user, email: nil) }

      it 'returns nil' do
        expect(user.email_domain).to be_nil
      end
    end

    context 'when user email is empty string' do
      let_it_be(:user) { build(:user, email: '') }

      it 'returns nil' do
        expect(user.email_domain).to be_nil
      end
    end

    context 'when user email is invalid' do
      let_it_be(:user) { build(:user, email: 'invalid_email_format') }

      it 'returns nil' do
        expect(user.email_domain).to be_nil
      end
    end

    context 'when user email is valid' do
      let_it_be(:user) { build(:user, email: 'user-email@example.GitLab.com') }

      it 'returns email domain' do
        expect(user.email_domain).to eq('example.GitLab.com')
      end
    end
  end

  describe '#available_custom_project_templates' do
    let(:user) { create(:user) }

    it 'returns an empty relation if group is not set' do
      expect(user.available_custom_project_templates.empty?).to be_truthy
    end

    context 'when group with custom project templates is set' do
      let_it_be_with_reload(:group) { create(:group) }

      before do
        stub_ee_application_setting(custom_project_templates_group_id: group.id)
      end

      it 'returns an empty relation if group has no available project templates' do
        expect(group.projects.empty?).to be true
        expect(user.available_custom_project_templates.empty?).to be true
      end

      context 'when group has custom project templates' do
        let_it_be_with_reload(:private_project) { create :project, :private, namespace: group, name: 'private_project' }
        let_it_be_with_reload(:internal_project) { create :project, :internal, namespace: group, name: 'internal_project' }
        let_it_be_with_reload(:public_project) { create :project, :metrics_dashboard_enabled, :public, namespace: group, name: 'public_project' }
        let_it_be_with_reload(:public_project_two) { create :project, :metrics_dashboard_enabled, :public, namespace: group, name: 'public_project_second' }

        it 'returns public projects' do
          expect(user.available_custom_project_templates).to include public_project
        end

        it 'returns internal projects' do
          expect(user.available_custom_project_templates).to include internal_project
        end

        context 'returns private projects if user' do
          it 'is a member of the project' do
            expect(user.available_custom_project_templates).not_to include private_project

            private_project.add_developer(user)

            expect(user.available_custom_project_templates).to include private_project
          end

          it 'is a member of the group' do
            expect(user.available_custom_project_templates).not_to include private_project

            group.add_developer(user)

            expect(user.available_custom_project_templates).to include private_project
          end
        end

        it 'allows to search available project templates by name' do
          projects = user.available_custom_project_templates(search: 'publi')

          expect(projects.count).to eq 2
          expect(projects.first).to eq public_project
        end

        it 'filters by project ID' do
          projects = user.available_custom_project_templates(project_id: public_project.id)

          expect(projects.count).to eq 1
          expect(projects).to match_array([public_project])

          projects = user.available_custom_project_templates(project_id: [public_project.id, public_project_two.id])

          expect(projects.count).to eq 2
          expect(projects).to match_array([public_project, public_project_two])
        end

        it 'does not return inaccessible projects' do
          projects = user.available_custom_project_templates(project_id: private_project.id)

          expect(projects.count).to eq 0
        end
      end

      it 'returns project with disabled features' do
        public_project = create(:project, :public, :metrics_dashboard_enabled, namespace: group)
        disabled_issues_project = create(:project, :public, :metrics_dashboard_enabled, :issues_disabled, namespace: group)

        expect(user.available_custom_project_templates).to include public_project
        expect(user.available_custom_project_templates).to include disabled_issues_project
      end

      it 'does not return project with private issues' do
        accessible_project = create(:project, :public, :metrics_dashboard_enabled, namespace: group)
        restricted_features_project = create(:project, :public, :metrics_dashboard_enabled, :issues_private, namespace: group)

        expect(user.available_custom_project_templates).to include accessible_project
        expect(user.available_custom_project_templates).not_to include restricted_features_project
      end
    end
  end

  describe '#roadmap_layout' do
    context 'not set' do
      subject { build(:user, roadmap_layout: nil) }

      it 'returns default value' do
        expect(subject.roadmap_layout).to eq(EE::User::DEFAULT_ROADMAP_LAYOUT)
      end
    end

    context 'set' do
      subject { build(:user, roadmap_layout: 'quarters') }

      it 'returns set value' do
        expect(subject.roadmap_layout).to eq('quarters')
      end
    end
  end

  describe '#group_sso?' do
    subject(:user) { create(:user) }

    it 'is false without a saml_provider' do
      expect(subject.group_sso?(nil)).to be_falsey
      expect(subject.group_sso?(create(:group))).to be_falsey
    end

    context 'with linked identity' do
      let!(:identity) { create(:group_saml_identity, user: user) }
      let(:saml_provider) { identity.saml_provider }
      let(:group) { saml_provider.group }

      context 'without preloading' do
        it 'returns true' do
          expect(subject.group_sso?(group)).to be_truthy
        end

        it 'does not cause ActiveRecord to loop through identites' do
          create(:group_saml_identity, user: user)

          expect(Identity).not_to receive(:instantiate)

          subject.group_sso?(group)
        end
      end

      context 'when identities and saml_providers pre-loaded' do
        before do
          ActiveRecord::Associations::Preloader.new(records: [subject], associations: { group_saml_identities: :saml_provider }).call
        end

        it 'returns true' do
          expect(subject.group_sso?(group)).to be_truthy
        end

        it 'does not trigger additional database queries' do
          expect { subject.group_sso?(group) }.not_to exceed_query_limit(0)
        end
      end
    end
  end

  describe '.billable' do
    let_it_be(:bot_user) { create(:user, :bot) }
    let_it_be(:service_account) { create(:user, :service_account) }
    let_it_be(:regular_user) { create(:user) }
    let_it_be(:project_reporter_user) { create(:project_member, :reporter).user }
    let_it_be(:project_guest_user) { create(:project_member, :guest).user }
    let_it_be(:minimal_access_user) { create(:group_member, :minimal_access).user }
    let_it_be(:group) { create(:group) }
    let_it_be(:member_role_elevating) { create(:member_role, :billable, namespace: group) }
    let_it_be(:member_role_basic) { create(:member_role, :non_billable, namespace: group) }
    let_it_be(:guest_with_elevated_role) { create(:group_member, :guest, source: group, member_role: member_role_elevating).user }
    let_it_be(:guest_without_elevated_role) { create(:group_member, :guest, source: group, member_role: member_role_basic).user }
    let_it_be(:users_select) { 'SELECT "users".* FROM "users"' }
    let_it_be(:users_select_with_ignored_columns) { 'SELECT ("users"."\w+", )+("users"."\w+") FROM "users"' }
    let_it_be(:user_with_access_request) { create(:group_member, :access_request, source: group).user }

    let(:expected_sql_regexp) do
      Regexp.new(
        "(#{users_select} #{expected_where}|#{users_select_with_ignored_columns} #{expected_where})"
      )
    end

    subject(:users) { described_class.billable }

    context 'with guests' do
      let(:expected_where) do
        'WHERE "users"."state" = \'active\'
        AND
        "users"."user_type" IN \(0, 6, 4, 13\)
        AND
        "users"."user_type" IN \(0, 4, 5, 15, 17\)
        AND
        \(NOT EXISTS
          \(SELECT 1 FROM "members"
            WHERE "members"."user_id" = "users"."id" AND "members"."requested_at" IS NULL GROUP BY "members"."user_id"
            HAVING \(MAX\(access_level\) = 5\)\)\)'.squish
      end

      before do
        license = double('License', exclude_guests_from_active_count?: false, feature_available?: true)
        allow(License).to receive(:current) { license }
      end

      it 'validates the sql matches the specific index we have' do
        expect(users.to_sql.squish).to match(expected_sql_regexp),
          "query was changed. Please ensure query is covered with an index and adjust this test case"
      end

      it 'excludes minimal access users' do
        expect(users).not_to include(minimal_access_user)
      end

      it 'returns users' do
        expect(users).to include(project_reporter_user)
        expect(users).to include(project_guest_user)
        expect(users).to include(regular_user)
        expect(users).to include(guest_with_elevated_role)
        expect(users).to include(guest_without_elevated_role)
        expect(users).to include(user_with_access_request)

        expect(users).not_to include(bot_user)
        expect(users).not_to include(service_account)
      end

      context 'with minimal access membership and existing billable membership' do
        let(:mixed_memberships_user) { create(:user) }

        before do
          create(:group_member, :developer, user: mixed_memberships_user, source: create(:group))
          create(:group_member, :minimal_access, user: mixed_memberships_user, source: create(:group))
        end

        it 'includes users with MA in one group and developer in another group' do
          expect(users).to include(mixed_memberships_user)
        end
      end
    end

    context 'without guests' do
      let(:expected_where) do
        'WHERE "users"."state" = \'active\'
        AND
        "users"."user_type" IN \(0, 6, 4, 13\)
        AND
        "users"."user_type" IN \(0, 4, 5, 15, 17\)
        AND
        \(EXISTS \(SELECT 1 FROM "members"
          LEFT OUTER JOIN "member_roles" ON "member_roles"."id" = "members"."member_role_id"
          WHERE "members"."user_id" = "users"."id"
            AND \(\(members.access_level > 10\)
            OR "members"."access_level" = 10
            AND "member_roles"."occupies_seat" = TRUE\)
            AND "members"."requested_at" IS NULL\)\)'.squish # allow_cross_joins_across_databases
      end

      before do
        license = double('License', exclude_guests_from_active_count?: true, feature_available?: true)
        allow(License).to receive(:current) { license }
      end

      it 'validates the sql matches the specific index we have' do
        expect(users.to_sql.squish).to match(expected_sql_regexp),
          "query was changed. Please ensure query is covered with an index and adjust this test case"
      end

      it 'excludes users requesting access' do
        expect(users).not_to include(user_with_access_request)
      end

      it 'excludes minimal access users' do
        expect(users).not_to include(minimal_access_user)
      end

      context 'with elevating role' do
        it 'returns users with elevated roles' do
          expect(MemberRole).to receive(:occupies_seat).at_least(:once).and_return(MemberRole.where(id: member_role_elevating.id))

          expect(users).to include(guest_with_elevated_role)
          expect(users).not_to include(guest_without_elevated_role)
        end
      end

      context 'with minimal access membership and existing billable membership' do
        let(:mixed_memberships_user) { create(:user) }

        before do
          create(:group_member, :developer, user: mixed_memberships_user, source: create(:group))
          create(:group_member, :minimal_access, user: mixed_memberships_user, source: create(:group))
        end

        it 'includes users with MA in one group and developer in another group' do
          expect(users).to include(mixed_memberships_user)
        end
      end
    end
  end

  describe '.non_billable_users_for_billable_management' do
    let_it_be(:non_billable_role) { create(:member_role, :non_billable, :instance) }
    let_it_be(:billable_role) { create(:member_role, :billable, :instance) }

    let_it_be(:billable_member) do
      create(:group_member, access_level: Gitlab::Access::DEVELOPER)
    end

    let_it_be(:non_billable_member) do
      create(:group_member, access_level: Gitlab::Access::GUEST)
    end

    let_it_be(:non_billable_minimal_access_member) do
      create(:group_member, :minimal_access)
    end

    let_it_be(:bot_user) { create(:user, :bot) }

    let(:user_ids) do
      [
        non_billable_member.user_id, billable_member.user_id, bot_user.id, non_billable_minimal_access_member.user_id
      ]
    end

    let(:non_billable_user_ids) do
      [
        non_billable_member.user_id, non_billable_minimal_access_member.user_id
      ]
    end

    context 'when license includes guests in active count' do
      it 'returns no users' do
        expect(described_class.non_billable_users_for_billable_management(user_ids)).to be_empty
      end
    end

    context 'when license excludes guests in active count' do
      let_it_be(:ultimate) { create(:license, plan: License::ULTIMATE_PLAN) }

      before do
        allow(License).to receive(:current).and_return(ultimate)
      end

      it 'returns non billable users' do
        users = described_class.non_billable_users_for_billable_management(user_ids)

        expect(users.pluck(:id)).to match_array(non_billable_user_ids)
      end

      context 'with requested members' do
        it 'considers requested user as non billable' do
          requested_user_id = create(:group_member, :developer, :access_request).user_id
          user_ids << requested_user_id
          users = described_class.non_billable_users_for_billable_management(user_ids)

          expect(users.pluck(:id)).to match_array(non_billable_user_ids << requested_user_id)
        end
      end

      context 'with users in multiple groups' do
        let_it_be(:user) { create(:user) }
        let(:role_in_group1) { Gitlab::Access::GUEST }
        let(:role_in_group2) { Gitlab::Access::GUEST }

        let!(:guest_member) do
          create(:group_member, user: user, access_level: role_in_group1)
        end

        let!(:another_guest_member) do
          create(:group_member, user: user, access_level: role_in_group2)
        end

        let(:user_ids) { super() << user.id }

        shared_examples "skips user because user is billable" do
          it 'does not return billable user' do
            users = described_class.non_billable_users_for_billable_management(user_ids)
            expect(users.pluck(:id)).to match_array(non_billable_user_ids)
          end
        end

        shared_examples "returns user because user is non billable" do
          it 'returns user' do
            users = described_class.non_billable_users_for_billable_management(user_ids)

            expect(users.pluck(:id)).to match_array(non_billable_user_ids << user.id)
          end
        end

        context 'with both non billable roles' do
          it_behaves_like "returns user because user is non billable"
        end

        context 'with one billable role and one non billable role' do
          let(:role_in_group2) { Gitlab::Access::DEVELOPER }

          it_behaves_like "skips user because user is billable"
        end

        context 'with both billable roles' do
          let(:role_in_group1) { Gitlab::Access::DEVELOPER }
          let(:role_in_group2) { Gitlab::Access::DEVELOPER }

          it_behaves_like "skips user because user is billable"
        end

        context 'with elevation scenarios' do
          context 'with just one evelated role' do
            before do
              another_guest_member.update!(member_role: billable_role)
            end

            it_behaves_like "skips user because user is billable"
          end

          context 'with one evelated and one non elevated role' do
            let_it_be_with_reload(:third_guest_member) do
              create(:group_member, user: user, access_level: Gitlab::Access::GUEST)
            end

            before do
              another_guest_member.update!(member_role: billable_role)
              third_guest_member.update!(member_role: non_billable_role)
            end

            it_behaves_like "skips user because user is billable"
          end

          context 'with just non elevated role' do
            before do
              another_guest_member.update!(member_role: non_billable_role)
            end

            it_behaves_like "returns user because user is non billable"
          end
        end
      end
    end
  end

  describe '#pending_billable_invitations' do
    let_it_be(:user) { described_class.new(confirmed_at: Time.zone.now, email: 'test@example.com') }

    it 'returns pending billable invitations for the user' do
      invitation = create(:group_member, :guest, :invited, invite_email: user.email)

      expect(user.pending_billable_invitations).to eq([invitation])
    end

    it 'returns both project and group invitations' do
      project_invitation = create(:project_member, :maintainer, :invited, invite_email: user.email)
      group_invitation = create(:group_member, :developer, :invited, invite_email: user.email)

      expect(user.pending_billable_invitations).to contain_exactly(project_invitation, group_invitation)
    end

    context 'with an ultimate license' do
      before do
        license = create(:license, plan: License::ULTIMATE_PLAN)
        allow(License).to receive(:current).and_return(license)
      end

      it 'excludes pending non-billable invitations for the user' do
        create(:group_member, :guest, :invited, invite_email: user.email)
        developer_invitation = create(:group_member, :developer, :invited, invite_email: user.email)

        expect(user.pending_billable_invitations).to eq([developer_invitation])
      end
    end
  end

  describe '#group_managed_account?' do
    subject { user.group_managed_account? }

    context 'when user has managing group linked' do
      before do
        user.managing_group = Group.new
      end

      it { is_expected.to be true }
    end

    context 'when user has no linked managing group' do
      it { is_expected.to be false }
    end
  end

  describe '#password_required?' do
    shared_examples 'does not require password to be present' do
      it { expect(user).not_to validate_presence_of(:password) }
      it { expect(user).not_to validate_presence_of(:password_confirmation) }
    end

    context 'when user has managing group linked' do
      before do
        user.managing_group = Group.new
      end

      it_behaves_like 'does not require password to be present'
    end

    context 'when user is a service account user' do
      before do
        user.user_type = 'service_account'
      end

      it_behaves_like 'does not require password to be present'
    end
  end

  describe '#valid_password?' do
    subject(:validate_password) { user.valid_password?(password) }

    context 'when password authentication disabled by enterprise group' do
      let_it_be(:enterprise_group) { create(:group) }
      let_it_be(:saml_provider) { create(:saml_provider, group: enterprise_group, enabled: true, disable_password_authentication_for_enterprise_users: true) }

      let_it_be(:user) { create(:enterprise_user, enterprise_group: enterprise_group) }

      let(:password) { user.password }

      it { is_expected.to be(false) }
    end
  end

  describe '#allow_password_authentication?' do
    context 'when password authentication disabled by enterprise group' do
      let_it_be(:enterprise_group) { create(:group) }
      let_it_be(:saml_provider) { create(:saml_provider, group: enterprise_group, enabled: true, disable_password_authentication_for_enterprise_users: true) }

      let_it_be(:user) { create(:enterprise_user, enterprise_group: enterprise_group) }

      it 'is false' do
        expect(user.allow_password_authentication?).to be false
      end
    end
  end

  describe '#allow_password_authentication_for_web?' do
    context 'when user has managing group linked' do
      before do
        user.managing_group = build(:group)
      end

      it 'is false' do
        expect(user.allow_password_authentication_for_web?).to be false
      end
    end

    context 'when password authentication disabled by enterprise group' do
      let_it_be(:enterprise_group) { create(:group) }
      let_it_be(:saml_provider) { create(:saml_provider, group: enterprise_group, enabled: true, disable_password_authentication_for_enterprise_users: true) }

      let_it_be(:user) { create(:enterprise_user, enterprise_group: enterprise_group) }

      it 'is false' do
        expect(user.allow_password_authentication_for_web?).to be false
      end
    end
  end

  describe '#allow_password_authentication_for_git?' do
    context 'when user has managing group linked' do
      before do
        user.managing_group = build(:group)
      end

      it 'is false' do
        expect(user.allow_password_authentication_for_git?).to be false
      end
    end

    context 'when password authentication disabled by enterprise group' do
      let_it_be(:enterprise_group) { create(:group) }
      let_it_be(:saml_provider) { create(:saml_provider, group: enterprise_group, enabled: true, disable_password_authentication_for_enterprise_users: true) }

      let_it_be(:user) { create(:enterprise_user, enterprise_group: enterprise_group) }

      it 'is false' do
        expect(user.allow_password_authentication_for_git?).to be false
      end
    end
  end

  describe '#password_expired_if_applicable?' do
    let(:user) { build(:user, password_expires_at: password_expires_at) }

    subject { user.password_expired_if_applicable? }

    shared_examples 'password expired not applicable' do
      context 'when password_expires_at is not set' do
        let(:password_expires_at) { nil }

        it 'returns false' do
          is_expected.to be_falsey
        end
      end

      context 'when password_expires_at is in the past' do
        let(:password_expires_at) { 1.minute.ago }

        it 'returns false' do
          is_expected.to be_falsey
        end
      end

      context 'when password_expires_at is in the future' do
        let(:password_expires_at) { 1.minute.from_now }

        it 'returns false' do
          is_expected.to be_falsey
        end
      end
    end

    context 'when password_automatically_set is true' do
      context 'with a SCIM identity' do
        let_it_be(:scim_identity) { create(:scim_identity, active: true) }
        let_it_be(:user) { scim_identity.user }

        it_behaves_like 'password expired not applicable'
      end

      context 'with a SAML identity' do
        let_it_be(:saml_identity) { create(:group_saml_identity) }
        let_it_be(:user) { saml_identity.user }

        it_behaves_like 'password expired not applicable'
      end

      context 'with a smartcard identity' do
        let_it_be(:smartcard_identity) { create(:smartcard_identity) }
        let_it_be(:user) { smartcard_identity.user }

        it_behaves_like 'password expired not applicable'
      end
    end
  end

  describe '#allow_passkey_authentication?' do
    subject(:allow_passkey_authentication?) { user.allow_passkey_authentication? }

    context 'when GitLab.com' do
      context 'for enterprise users' do
        let_it_be(:enterprise_group) { create(:group) }
        let_it_be_with_reload(:saml_provider) { create(:saml_provider, group: enterprise_group, enabled: true) }

        let_it_be(:user) { create(:enterprise_user, enterprise_group: enterprise_group) }

        it { is_expected.to be_truthy }

        context 'when password authentication disabled by the enterprise group' do
          before do
            user.enterprise_group.saml_provider.update!(disable_password_authentication_for_enterprise_users: true)
          end

          it { is_expected.to be_falsey }
        end
      end
    end
  end

  describe '#password_authentication_disabled_by_enterprise_group?' do
    subject(:password_authentication_disabled_by_enterprise_group?) { user.password_authentication_disabled_by_enterprise_group? }

    let_it_be_with_refind(:user) { create(:user) }

    let_it_be(:root_group) { create(:group) }

    let_it_be(:root_group_with_saml_provider) { create(:group) }
    let_it_be_with_reload(:saml_provider) { create(:saml_provider, group: root_group_with_saml_provider) }

    using RSpec::Parameterized::TableSyntax

    where(:enterprise_group, :saml_enabled?, :disable_password_authentication_for_enterprise_users?, :result) do
      nil                                 | nil   | nil   | false
      ref(:root_group)                    | nil   | nil   | false
      ref(:root_group_with_saml_provider) | false | false | false
      ref(:root_group_with_saml_provider) | false | true  | false
      ref(:root_group_with_saml_provider) | true  | false | false
      ref(:root_group_with_saml_provider) | true  | true  | true
    end

    with_them do
      before do
        user.user_detail.update!(enterprise_group: enterprise_group)

        if enterprise_group&.saml_provider
          enterprise_group.saml_provider.update!(
            enabled: saml_enabled?,
            disable_password_authentication_for_enterprise_users: disable_password_authentication_for_enterprise_users?
          )
        end
      end

      it { is_expected.to eq(result) }
    end
  end

  describe '#enterprise_user_of_group?' do
    let_it_be(:group) { create(:group) }

    context 'when user is not an enterprise user' do
      before do
        user.user_detail.enterprise_group = nil
      end

      it 'returns false' do
        expect(user.enterprise_user_of_group?(group)).to be false
      end
    end

    context 'when user is an enterprise user of the group' do
      before do
        user.user_detail.enterprise_group = group
      end

      it 'returns true' do
        expect(user.enterprise_user_of_group?(group)).to be true
      end
    end

    context 'when user is an enterprise user of another group' do
      before do
        user.user_detail.enterprise_group = create(:group)
      end

      it 'returns false' do
        expect(user.enterprise_user_of_group?(group)).to be false
      end
    end
  end

  describe '#enterprise_user?' do
    let_it_be_with_refind(:user) { create(:user) }

    context 'when user is not an enterprise user' do
      before do
        user.user_detail.update!(enterprise_group: nil)
      end

      it 'returns false' do
        expect(user.enterprise_user?).to be false
      end
    end

    context 'when user is an enterprise user' do
      let_it_be(:group) { create(:group) }

      before do
        user.user_detail.update!(enterprise_group: group)
      end

      it 'returns true' do
        expect(user.enterprise_user?).to be true
      end

      context 'when the group is deleted' do
        before do
          group.destroy!
        end

        it 'returns false' do
          expect(user.reload.enterprise_user?).to be false
        end
      end
    end
  end

  describe '#using_license_seat?' do
    let(:user) { create(:user) }

    context 'when user is inactive' do
      before do
        user.block
      end

      it 'returns false' do
        expect(user.using_license_seat?).to be false
      end
    end

    context 'when user is active' do
      context 'when user is internal' do
        where(:internal_user_type) do
          described_class::INTERNAL_USER_TYPES
        end

        with_them do
          context 'when user has internal user type' do
            let(:user) { create(:user, user_type: internal_user_type) }

            it 'returns false' do
              expect(user.using_license_seat?).to be false
            end
          end
        end
      end

      context 'when user is not internal' do
        before do
          Users::UpdateHighestMemberRoleService.new(user).execute
        end

        context 'when license is nil (core/free/default)' do
          before do
            allow(License).to receive(:current).and_return(nil)
          end

          it 'returns false if license is nil (core/free/default)' do
            expect(user.using_license_seat?).to be false
          end
        end

        context 'user is guest' do
          let(:user) { create(:project_member, :guest).user }

          it 'returns false if license is ultimate' do
            create(:license, plan: License::ULTIMATE_PLAN)

            expect(user.using_license_seat?).to be false
          end

          it 'returns true if license is premium' do
            create(:license, plan: License::PREMIUM_PLAN)

            expect(user.using_license_seat?).to be true
          end
        end

        context 'user is minimal access' do
          let(:user) { create(:group_member, :minimal_access).user }

          it 'returns false if license is ultimate' do
            create(:license, plan: License::ULTIMATE_PLAN)

            expect(user.using_license_seat?).to be false
          end

          it 'returns false if license is premium' do
            create(:license, plan: License::PREMIUM_PLAN)

            expect(user.using_license_seat?).to be false
          end
        end

        context 'user does not have any memberships' do
          let(:user) { create(:user) }

          it 'returns false if license is ultimate' do
            create(:license, plan: License::ULTIMATE_PLAN)

            expect(user.using_license_seat?).to be false
          end

          it 'returns true if license is premium' do
            create(:license, plan: License::PREMIUM_PLAN)

            expect(user.using_license_seat?).to be true
          end
        end

        context 'user is admin without projects' do
          let(:user) { create(:user, admin: true) }

          it 'returns false if license is ultimate' do
            create(:license, plan: License::ULTIMATE_PLAN)

            expect(user.using_license_seat?).to be false
          end

          it 'returns true if license is premium' do
            create(:license, plan: License::PREMIUM_PLAN)

            expect(user.using_license_seat?).to be true
          end
        end

        context 'when the user is a service account' do
          let(:user) { create(:user, :service_account) }

          it 'returns false' do
            expect(user.using_license_seat?).to be(false)
          end
        end

        context 'when the user is an import user' do
          let(:user) { create(:user, :import_user) }

          it 'returns false' do
            expect(user.using_license_seat?).to be(false)
          end
        end
      end
    end
  end

  describe '#using_gitlab_com_seat?' do
    let_it_be_with_refind(:user) { create(:user) }
    let_it_be_with_refind(:namespace) { create(:group) }

    subject { user.using_gitlab_com_seat?(namespace) }

    context 'when Gitlab.com? is false' do
      before do
        allow(Gitlab).to receive(:com?).and_return(false)
      end

      it { is_expected.to be_falsey }
    end

    context 'when user is not active' do
      before do
        user.block!
      end

      it { is_expected.to be_falsey }
    end

    context 'when SaaS', :saas do
      context 'when namespace is nil' do
        let(:namespace) { nil }

        it { is_expected.to be_falsey }
      end

      context 'when namespace is on a free plan' do
        it { is_expected.to be_falsey }
      end

      context 'when namespace is on a ultimate plan' do
        let_it_be(:ultimate_plan, freeze: true) { create(:ultimate_plan) }

        before do
          # Use create_or_replace_subscription because adding members (various lines)
          # triggers Internal Events tracking, which auto-generates a FREE subscription
          create_or_replace_subscription(namespace.root_ancestor, hosted_plan: ultimate_plan)
        end

        context 'user is a guest' do
          before do
            namespace.add_guest(user)
          end

          it { is_expected.to be_falsey }
        end

        context 'user is not a guest' do
          before do
            namespace.add_developer(user)
          end

          it { is_expected.to be_truthy }
        end

        context 'when user is within project' do
          let_it_be(:group) { create(:group) }
          let_it_be(:namespace) { create(:project, namespace: group, developers: user) }

          it { is_expected.to be_truthy }
        end

        context 'when user is within subgroup' do
          let_it_be(:group) { create(:group) }
          let_it_be(:namespace) { create(:group, parent: group, developers: user) }

          it { is_expected.to be_truthy }
        end
      end

      context 'when namespace is on a plan that is not free or ultimate' do
        before do
          # Use create_or_replace_subscription because adding members (various lines)
          # triggers Internal Events tracking, which auto-generates a FREE subscription
          create_or_replace_subscription(namespace, hosted_plan: create(:premium_plan))
        end

        context 'user is a guest' do
          before do
            namespace.add_guest(user)
          end

          it { is_expected.to be_truthy }
        end

        context 'user is not a guest' do
          before do
            namespace.add_developer(user)
          end

          it { is_expected.to be_truthy }
        end
      end
    end
  end

  describe '#assigned_to_duo_enterprise?' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:user) { create(:user) }

    subject { user.assigned_to_duo_enterprise?(namespace) }

    context 'on SaaS', :saas do
      let_it_be(:namespace) { create(:group) }

      it { is_expected.to be(false) }

      context 'when user is assigned to a duo enterprise seat on namespace' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace) }

        before do
          create(
            :gitlab_subscription_user_add_on_assignment,
            user: user,
            add_on_purchase: subscription_purchase
          )
        end

        it { is_expected.to be(true) }
      end
    end

    context 'on self-managed' do
      it { is_expected.to be(false) }

      context 'when user is assigned to a duo enterprise seat on instance' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :self_managed) }

        before do
          create(
            :gitlab_subscription_user_add_on_assignment,
            user: user,
            add_on_purchase: subscription_purchase
          )
        end

        it { is_expected.to be(true) }
      end
    end
  end

  describe '#assigned_to_duo_pro?' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:user) { create(:user) }

    subject { user.assigned_to_duo_pro?(namespace) }

    context 'on SaaS', :saas do
      let_it_be(:namespace) { create(:group) }

      it { is_expected.to be(false) }

      context 'when user is assigned to a duo enterprise seat on namespace' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace) }

        before do
          create(
            :gitlab_subscription_user_add_on_assignment,
            user: user,
            add_on_purchase: subscription_purchase
          )
        end

        it { is_expected.to be(true) }
      end

      context 'when user is assigned to a duo pro seat on namespace' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: namespace) }

        before do
          create(
            :gitlab_subscription_user_add_on_assignment,
            user: user,
            add_on_purchase: subscription_purchase
          )
        end

        it { is_expected.to be(true) }
      end
    end

    context 'on self-managed' do
      it { is_expected.to be(false) }

      context 'when user is assigned to a duo enterprise seat on instance' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :self_managed) }

        before do
          create(
            :gitlab_subscription_user_add_on_assignment,
            user: user,
            add_on_purchase: subscription_purchase
          )
        end

        it { is_expected.to be(true) }
      end

      context 'when user is assigned to a duo pro seat on instance' do
        let(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro, :self_managed) }

        before do
          create(
            :gitlab_subscription_user_add_on_assignment,
            user: user,
            add_on_purchase: subscription_purchase
          )
        end

        it { is_expected.to be(true) }
      end
    end
  end

  describe '#can_access_admin_area?' do
    let_it_be_with_refind(:user_without_admin_role) { create(:user) }
    let_it_be_with_refind(:user_with_admin_role) { create(:user) }

    let_it_be(:admin_role) { create(:member_role, :admin) }
    let_it_be(:user_member_role) { create(:user_member_role, member_role: admin_role, user: user_with_admin_role) }

    context 'when custom_roles feature is available' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      context 'for user without admin custom permissions' do
        it 'returns false' do
          expect(user_without_admin_role.can_access_admin_area?).to be(false)
        end
      end

      context 'for user with admin custom permissions' do
        it 'returns true' do
          expect(user_with_admin_role.can_access_admin_area?).to be(true)
        end
      end
    end

    context 'when custom_roles feature is not available' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      context 'for user without admin custom permissions' do
        it 'returns false' do
          expect(user_without_admin_role.can_access_admin_area?).to be(false)
        end
      end

      context 'for user with admin custom permissions' do
        it 'returns false' do
          expect(user_with_admin_role.can_access_admin_area?).to be(false)
        end
      end
    end
  end

  describe '#authorized_groups' do
    let_it_be(:user) { create(:user) }
    let_it_be(:private_group) { create(:group, maintainers: user) }
    let_it_be(:minimal_access_group) { create(:group) }

    let_it_be(:project_group) { create(:group) }
    let_it_be(:project) { create(:project, group: project_group, maintainers: user) }

    before_all do
      create(:group_member, :minimal_access, user: user, source: minimal_access_group)
    end

    subject { user.authorized_groups }

    context 'with minimal access role feature unavailable' do
      it { is_expected.to contain_exactly private_group, project_group }
    end

    context 'with minimal access feature available' do
      before do
        stub_licensed_features(minimal_access_role: true)
      end

      context 'when the feature is turned on for all groups' do
        it { is_expected.to contain_exactly private_group, project_group, minimal_access_group }

        it 'ignores groups with minimal access if with_minimal_access=false' do
          expect(user.authorized_groups(with_minimal_access: false)).to contain_exactly(private_group, project_group)
        end
      end

      context 'when the feature is available for specific groups only', :saas do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
          create(:gitlab_subscription, :ultimate, namespace: minimal_access_group)
          create(:group_member, :minimal_access, user: user, source: create(:group))
        end

        it { is_expected.to contain_exactly private_group, project_group, minimal_access_group }
      end
    end
  end

  describe 'with two_factor authentication' do
    let_it_be_with_reload(:user) { create(:user) }

    describe '#all_expanded_groups' do
      #                group
      #        _______ (foo) _______
      #       |                     |
      #       |                     |
      # nested_group_1        nested_group_2
      # (bar)                 (barbaz)
      #       |                     |
      #       |                     |
      # nested_group_1_1      nested_group_2_1
      # (baz)                 (baz)
      #
      let_it_be_with_reload(:group) { create :group, name: 'foo' }
      let_it_be_with_reload(:nested_group_1) { create :group, parent: group, name: 'bar' }
      let_it_be_with_reload(:nested_group_1_1) { create :group, parent: nested_group_1, name: 'baz' }
      let_it_be_with_reload(:nested_group_2) { create :group, parent: group, name: 'barbaz' }
      let_it_be_with_reload(:nested_group_2_1) { create :group, parent: nested_group_2, name: 'baz' }

      subject(:expanded_groups) { user.all_expanded_groups }

      context 'with access roles' do
        context 'with a minimal access role' do
          it 'returns no group' do
            group.add_member(user, ::Gitlab::Access::MINIMAL_ACCESS)

            is_expected.to match_array []
          end

          context 'when :minimal_access_role is enabled' do
            before do
              stub_licensed_features(minimal_access_role: true)
            end

            context 'when added to top-level-group' do
              it 'returns all groups' do
                group.add_member(user, ::Gitlab::Access::MINIMAL_ACCESS)

                is_expected.to match_array [
                  group,
                  nested_group_1, nested_group_1_1,
                  nested_group_2, nested_group_2_1
                ]
              end
            end

            context 'when added to a sub-group' do
              it 'returns no group' do
                nested_group_2_1.add_member(user, ::Gitlab::Access::MINIMAL_ACCESS)

                is_expected.to match_array []
              end
            end

            context 'with pending access to a group (requested_at IS NOT NULL)' do
              it 'does not return groups where access is pending', :freeze_time do
                create(:group_member, :minimal_access, source: group, user: user, requested_at: Time.current)

                is_expected.to match_array []
              end
            end
          end
        end
      end
    end

    describe '#source_groups_of_two_factor_authentication_requirement' do
      subject(:two_factor_source_group) { user.source_groups_of_two_factor_authentication_requirement }

      context 'with access roles' do
        context 'with a minimal access role' do
          context 'when user is a direct member of a top-level-group requiring 2FA' do
            let!(:group) { create(:group, require_two_factor_authentication: true, minimal_access: user) }

            it 'returns no group' do
              is_expected.to be_empty
            end
          end

          context 'when user is a member of a sub-group, with a parent requires 2FA' do
            let!(:parent_group) { create(:group, require_two_factor_authentication: true) }
            let!(:group) { create :group, parent: parent_group, minimal_access: user }

            it 'returns no group' do
              is_expected.to be_empty
            end
          end

          context 'when :minimal_access_role is enabled' do
            before do
              stub_licensed_features(minimal_access_role: true)
            end

            context 'when user is a direct member of a top-level-group requiring 2FA' do
              let!(:group) { create(:group, require_two_factor_authentication: true, minimal_access: user) }

              it 'returns group requiring 2FA' do
                is_expected.to contain_exactly(group)
              end
            end

            context 'when user is a member of a sub-group, with a parent requires 2FA' do
              let!(:parent_group) { create(:group, require_two_factor_authentication: true) }
              let!(:group) { create :group, parent: parent_group, minimal_access: user }

              it 'returns no group' do
                is_expected.to be_empty
              end
            end
          end
        end
      end
    end

    describe '#update_two_factor_requirement' do
      subject(:update_two_factor_requirement) { user.update_two_factor_requirement }

      context 'with access roles' do
        context 'with a minimal access role' do
          context 'when user is a direct member of a top-level-group requiring 2FA' do
            let!(:group) do
              create(:group, require_two_factor_authentication: true, two_factor_grace_period: 23, minimal_access: user)
            end

            it 'does not update_two_factor_requirement' do
              expect { update_two_factor_requirement }.not_to change { user.require_two_factor_authentication_from_group }
            end

            it 'does not update the two_factor_grace_period' do
              expect { update_two_factor_requirement }.not_to change { user.two_factor_grace_period }
            end
          end

          context 'when user is a member of a sub-group, with a parent requires 2FA' do
            let!(:parent_group) { create(:group, require_two_factor_authentication: true, two_factor_grace_period: 23) }
            let!(:group) { create :group, parent: parent_group, minimal_access: user }

            it 'does not update_two_factor_requirement' do
              expect { update_two_factor_requirement }.not_to change { user.require_two_factor_authentication_from_group }
            end

            it 'does not update the two_factor_grace_period' do
              expect { update_two_factor_requirement }.not_to change { user.two_factor_grace_period }
            end
          end

          context 'when :minimal_access_role is enabled' do
            before do
              stub_licensed_features(minimal_access_role: true)
            end

            context 'when user is a direct member of a top-level-group requiring 2FA' do
              let!(:group) do
                create(:group, require_two_factor_authentication: true, two_factor_grace_period: 23, minimal_access: user)
              end

              it 'updates two_factor_requirement' do
                expect { update_two_factor_requirement }
                .to change { user.require_two_factor_authentication_from_group }.from(false).to(true)
              end

              context 'with user in another top-level-group with a lower 2FA grace period' do
                let!(:group2) do
                  create(:group, require_two_factor_authentication: true, two_factor_grace_period: 5, minimal_access: user)
                end

                it 'updates two_factor_requirement with the minimum grace period' do
                  expect { update_two_factor_requirement }.to change { user.two_factor_grace_period }.to(5)
                end
              end
            end

            context 'when user is a member of a sub-group, with a parent requires 2FA' do
              let!(:parent_group) { create(:group, require_two_factor_authentication: true, two_factor_grace_period: 23) }
              let!(:group) { create :group, parent: parent_group, minimal_access: user }

              it 'does not update_two_factor_requirement' do
                expect { update_two_factor_requirement }.not_to change { user.require_two_factor_authentication_from_group }
              end

              it 'does not update the two_factor_grace_period' do
                expect { update_two_factor_requirement }.not_to change { user.two_factor_grace_period }
              end
            end
          end
        end
      end
    end
  end

  describe '#active_for_authentication?' do
    subject { user.active_for_authentication? }

    let(:user) { create(:user) }

    context 'based on user type' do
      using RSpec::Parameterized::TableSyntax

      where(:user_type, :expected_result) do
        'service_user'      | true
        'visual_review_bot' | false
      end

      with_them do
        before do
          user.update!(user_type: user_type)
        end

        it { is_expected.to be expected_result }
      end
    end
  end

  context 'paid namespaces', :saas do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:ultimate_group) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be(:bronze_group) { create(:group_with_plan, plan: :bronze_plan) }
    let_it_be(:free_group) { create(:group_with_plan, plan: :free_plan) }
    let_it_be(:group_without_plan) { create(:group) }

    let(:user) { create(:user, namespace: create(:user_namespace)) }

    describe '#belongs_to_paid_namespace?' do
      context 'when the user has Reporter or higher on at least one paid group' do
        it 'returns true' do
          ultimate_group.add_reporter(user)
          bronze_group.add_guest(user)

          expect(user.belongs_to_paid_namespace?).to be(true)
        end
      end

      context 'when the user is only a Guest on paid groups' do
        it 'returns false' do
          ultimate_group.add_guest(user)
          bronze_group.add_guest(user)
          free_group.add_owner(user)

          expect(user.belongs_to_paid_namespace?).to be(false)
        end
      end

      context 'when the user is a Developer on a subgroup but only a Guest at the root of a paid group' do
        let_it_be(:subgroup) { create(:group, parent: ultimate_group) }

        before do
          ultimate_group.add_guest(user)
          subgroup.add_developer(user)
        end

        it 'returns false by default' do
          expect(user.belongs_to_paid_namespace?).to be(false)
        end

        it 'returns true when include_all_memberships is true' do
          expect(user.belongs_to_paid_namespace?(include_all_memberships: true)).to be(true)
        end
      end

      context 'when the user is a Developer on a subgroup under an unpaid root group' do
        let_it_be(:subgroup) { create(:group, parent: free_group) }

        before do
          subgroup.add_developer(user)
        end

        it 'returns false even when include_all_memberships is true' do
          expect(user.belongs_to_paid_namespace?(include_all_memberships: true)).to be(false)
        end
      end

      context 'when the user is a Developer only on a project in a paid namespace' do
        let_it_be(:project) { create(:project, group: ultimate_group) }

        before do
          project.add_developer(user)
        end

        it 'returns true when include_all_memberships is true' do
          expect(user.belongs_to_paid_namespace?(include_all_memberships: true)).to be(true)
        end
      end

      context 'when the user is only a Guest on a project in a paid namespace' do
        let_it_be(:project) { create(:project, group: ultimate_group) }

        before do
          project.add_guest(user)
        end

        it 'returns false by default' do
          expect(user.belongs_to_paid_namespace?).to be(false)
        end

        it 'returns true when include_all_memberships is true' do
          expect(user.belongs_to_paid_namespace?(include_all_memberships: true)).to be(true)
        end
      end

      context 'when the user is only a Guest on a subgroup of a paid namespace' do
        let_it_be(:subgroup) { create(:group, parent: ultimate_group) }

        before do
          subgroup.add_guest(user)
        end

        it 'returns false by default' do
          expect(user.belongs_to_paid_namespace?).to be(false)
        end

        it 'returns true when include_all_memberships is true' do
          expect(user.belongs_to_paid_namespace?(include_all_memberships: true)).to be(true)
        end
      end

      context 'when the user is not a member of any groups with plans' do
        it 'returns false' do
          group_without_plan.add_owner(user)

          expect(user.belongs_to_paid_namespace?).to be(false)
        end
      end

      context 'when passed a subset of plans' do
        it 'returns true', :aggregate_failures do
          bronze_group.add_reporter(user)

          expect(user.belongs_to_paid_namespace?(plans: [::Plan::BRONZE])).to be(true)
          expect(user.belongs_to_paid_namespace?(plans: [::Plan::ULTIMATE])).to be(false)
        end
      end

      context 'when passed a non-paid plan' do
        it 'returns false' do
          free_group.add_owner(user)

          expect(user.belongs_to_paid_namespace?(plans: [::Plan::ULTIMATE, ::Plan::FREE])).to be(false)
        end
      end

      context 'when passed exclude_trials: true' do
        let_it_be(:trial_group) do
          create(
            :group_with_plan,
            plan: :ultimate_plan,
            trial: true,
            trial_starts_on: Date.current,
            trial_ends_on: 1.day.from_now
          )
        end

        it 'returns false' do
          trial_group.add_owner(user)

          expect(user.belongs_to_paid_namespace?(exclude_trials: true)).to be(false)
        end
      end
    end

    context 'when passed a plan' do
      it 'calculates association for that plan' do
        bronze_group.add_reporter(user)

        expect(user.belongs_to_paid_namespace?(plans: [::Plan::BRONZE])).to be(true)
        expect(user.belongs_to_paid_namespace?(plans: [::Plan::ULTIMATE])).to be(false)
      end

      it 'calculates association to multiple plans' do
        free_group.add_owner(user)

        expect(user.belongs_to_paid_namespace?(plans: [::Plan::ULTIMATE, ::Plan::FREE])).to be(false)
      end
    end

    describe '#owns_paid_namespace?', :saas do
      context 'when the user is an owner of at least one paid group' do
        it 'returns true' do
          ultimate_group.add_owner(user)
          bronze_group.add_owner(user)

          expect(user.owns_paid_namespace?).to be(true)
        end
      end

      context 'when the user is only a Maintainer on paid groups' do
        it 'returns false' do
          ultimate_group.add_maintainer(user)
          bronze_group.add_maintainer(user)
          free_group.add_owner(user)

          expect(user.owns_paid_namespace?).to be(false)
        end
      end

      context 'when the user is not a member of any groups with plans' do
        it 'returns false' do
          group_without_plan.add_owner(user)

          expect(user.owns_paid_namespace?).to be(false)
        end
      end
    end
  end

  describe '#gitlab_employee?' do
    using RSpec::Parameterized::TableSyntax

    subject { user.gitlab_employee? }

    let_it_be(:gitlab_group) { create(:group, name: 'gitlab-com') }
    let_it_be(:random_group) { create(:group, name: 'random-group') }

    context 'based on group membership' do
      before do
        allow(Gitlab).to receive(:com?).and_return(is_com)
      end

      context 'when user belongs to gitlab-com group' do
        where(:is_com, :expected_result) do
          true  | true
          false | false
        end

        with_them do
          let(:user) { create(:user) }

          before do
            gitlab_group.add_member(user, Gitlab::Access::DEVELOPER)
          end

          it { is_expected.to be expected_result }
        end
      end

      context 'when user does not belongs to gitlab-com group' do
        where(:is_com, :expected_result) do
          true  | false
          false | false
        end

        with_them do
          let(:user) { create(:user) }

          before do
            random_group.add_member(user, Gitlab::Access::DEVELOPER)
          end

          it { is_expected.to be expected_result }
        end
      end
    end

    context 'based on user type' do
      before do
        allow(Gitlab).to receive(:com?).and_return(true)
        gitlab_group.add_member(user, Gitlab::Access::DEVELOPER)
      end

      context 'when user is a bot' do
        let(:user) { create(:user, user_type: :alert_bot) }

        it { is_expected.to be false }
      end

      context 'when user is ghost' do
        let(:user) { create(:user, :ghost) }

        it { is_expected.to be false }
      end
    end
  end

  describe '#gitlab_bot?' do
    subject { user.gitlab_bot? }

    let_it_be(:gitlab_group) { create(:group, name: 'gitlab-com') }
    let_it_be(:random_group) { create(:group, name: 'random-group') }

    context 'based on group membership' do
      context 'when user belongs to gitlab-com group' do
        let(:user) { create(:user, user_type: :alert_bot) }

        before do
          allow(Gitlab).to receive(:com?).and_return(true)
          gitlab_group.add_member(user, Gitlab::Access::DEVELOPER)
        end

        it { is_expected.to be true }
      end

      context 'when user does not belongs to gitlab-com group' do
        let(:user) { create(:user, user_type: :alert_bot) }

        before do
          allow(Gitlab).to receive(:com?).and_return(true)
          random_group.add_member(user, Gitlab::Access::DEVELOPER)
        end

        it { is_expected.to be false }
      end
    end

    context 'based on user type' do
      before do
        allow(Gitlab).to receive(:com?).and_return(true)
        gitlab_group.add_member(user, Gitlab::Access::DEVELOPER)
      end

      context 'when user is a bot' do
        let(:user) { create(:user, user_type: :alert_bot) }

        it { is_expected.to be true }
      end

      context 'when user is a human' do
        let(:user) { create(:user, user_type: :human) }

        it { is_expected.to be false }
      end

      context 'when user is ghost' do
        let(:user) { create(:user, :ghost) }

        it { is_expected.to be false }
      end
    end
  end

  describe '#gitlab_service_user?' do
    subject { user.gitlab_service_user? }

    let_it_be(:gitlab_group) { create(:group, name: 'gitlab-com') }
    let_it_be(:random_group) { create(:group, name: 'random-group') }

    context 'based on group membership' do
      context 'when user belongs to gitlab-com group' do
        let(:user) { create(:user, user_type: :service_user) }

        before do
          allow(Gitlab).to receive(:com?).and_return(true)
          gitlab_group.add_member(user, Gitlab::Access::DEVELOPER)
        end

        it { is_expected.to be true }
      end

      context 'when user does not belong to gitlab-com group' do
        let(:user) { create(:user, user_type: :service_user) }

        before do
          allow(Gitlab).to receive(:com?).and_return(true)
          random_group.add_member(user, Gitlab::Access::DEVELOPER)
        end

        it { is_expected.to be false }
      end
    end

    context 'based on user type' do
      using RSpec::Parameterized::TableSyntax

      where(:is_com, :user_type, :answer) do
        true  | :service_user     | true
        true  | :alert_bot        | false
        true  | :human            | false
        true  | :ghost            | false
        false | :service_user     | false
        false | :alert_bot        | false
        false | :human            | false
        false | :ghost            | false
      end

      with_them do
        before do
          allow(Gitlab).to receive(:com?).and_return(is_com)
        end

        let(:user) do
          user = create(:user, user_type: user_type)
          gitlab_group.add_member(user, Gitlab::Access::DEVELOPER)
          user
        end

        it "returns if the user is a GitLab-owned service user" do
          expect(subject).to be answer
        end
      end
    end
  end

  describe '#security_dashboard' do
    let(:user) { create(:user) }

    subject(:security_dashboard) { user.security_dashboard }

    it 'returns an instance of InstanceSecurityDashboard for the user' do
      expect(security_dashboard).to be_a(InstanceSecurityDashboard)
    end
  end

  describe '#find_or_init_board_epic_preference' do
    let_it_be(:user) { create(:user) }
    let_it_be(:board) { create(:board) }
    let_it_be(:epic) { create(:epic) }

    subject(:preference) { user.find_or_init_board_epic_preference(board_id: board.id, epic_id: epic.id) }

    it 'returns new board epic user preference' do
      expect(preference.persisted?).to be_falsey
      expect(preference.user).to eq(user)
    end

    context 'when preference already exists' do
      let_it_be(:epic_user_preference) { create(:epic_user_preference, board: board, epic: epic, user: user) }

      it 'returns the existing board' do
        expect(preference.persisted?).to be_truthy
        expect(preference).to eq(epic_user_preference)
      end
    end
  end

  describe '#can_remove_self?' do
    let(:user) { create(:user) }

    subject { user.can_remove_self? }

    context 'not on GitLab.com' do
      context 'when the password is not automatically set' do
        it { is_expected.to be true }
      end

      context 'when the password is automatically set' do
        before do
          user.password_automatically_set = true
        end

        it { is_expected.to be true }
      end
    end

    context 'on GitLab.com' do
      before do
        allow(::Gitlab).to receive(:com?).and_return(true)
      end

      context 'when the password is not automatically set' do
        it { is_expected.to be true }
      end

      context 'when the password is automatically set' do
        before do
          user.password_automatically_set = true
        end

        it { is_expected.to be false }
      end
    end
  end

  describe "#owns_group_without_trial" do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }

    subject { user.owns_group_without_trial? }

    it 'returns true if owns a group' do
      group.add_owner(user)

      is_expected.to be(true)
    end

    it 'returns false if is a member group' do
      group.add_maintainer(user)

      is_expected.to be(false)
    end

    it 'returns false if is not a member of any group' do
      is_expected.to be(false)
    end

    it 'returns false if owns a group with a plan on a trial with an end date', :saas do
      group_with_plan = create(
        :group_with_plan,
        name: 'trial group',
        plan: :premium_plan,
        trial: true,
        trial_starts_on: Date.current,
        trial_ends_on: 1.year.from_now
      )
      group_with_plan.add_owner(user)

      is_expected.to be(false)
    end
  end

  describe '.oncall_schedules' do
    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:participant) { create(:incident_management_oncall_participant, user: user) }
    let_it_be_with_reload(:schedule) { participant.rotation.schedule }

    it 'excludes removed participants' do
      participant.update!(is_removed: true)

      expect(user.oncall_schedules).to be_empty
    end

    it 'excludes duplicates' do
      create(:incident_management_oncall_rotation, schedule: schedule) do |rotation|
        create(:incident_management_oncall_participant, user: user, rotation: rotation)
      end

      expect(user.oncall_schedules).to contain_exactly(schedule)
    end
  end

  describe '.escalation_policies' do
    let_it_be_with_reload(:rule) { create(:incident_management_escalation_rule, :with_user) }
    let_it_be_with_reload(:policy) { rule.policy }
    let_it_be(:user) { rule.user }

    it 'excludes removed rules' do
      rule.update!(is_removed: true)

      expect(user.escalation_policies).to be_empty
    end

    it 'excludes duplicates' do
      create(:incident_management_escalation_rule, :with_user, :resolved, policy: policy, user: user)

      expect(user.escalation_policies).to contain_exactly(policy)
    end
  end

  describe '.user_cap_reached?' do
    using RSpec::Parameterized::TableSyntax

    subject { described_class.user_cap_reached? }

    where(:seat_control_user_cap, :billable_count, :user_cap_max, :result) do
      false | 2 | nil | false
      true  | 2 | 5   | false
      true  | 5 | 5   | true
      true  | 8 | 5   | true
    end

    with_them do
      before do
        allow(described_class).to receive_message_chain(:billable, :limit).and_return(Array.new(billable_count, instance_double('User')))
        allow(Gitlab::CurrentSettings).to receive(:new_user_signups_cap).and_return(user_cap_max)
        allow(Gitlab::CurrentSettings).to receive(:seat_control_user_cap?).and_return(seat_control_user_cap)
      end

      it { is_expected.to eq(result) }
    end
  end

  describe '.user_cap_max' do
    it 'is equal to new_user_signups_cap setting' do
      cap = 10
      stub_application_setting(new_user_signups_cap: cap)

      expect(described_class.user_cap_max).to eq(cap)
    end
  end

  describe '#blocked_auto_created_oauth_ldap_user?' do
    include LdapHelpers

    before do
      stub_ldap_setting(enabled: true)
    end

    context 'when the auto-creation of an omniauth user is blocked' do
      before do
        stub_omniauth_setting(block_auto_created_users: true)
      end

      context 'when the user is an omniauth user' do
        it 'is true' do
          omniauth_user = create(:omniauth_user)

          expect(omniauth_user.blocked_auto_created_oauth_ldap_user?).to be_truthy
        end
      end

      context 'when the user is not an omniauth user' do
        it 'is false' do
          user = build(:user)

          expect(user.blocked_auto_created_oauth_ldap_user?).to be_falsey
        end
      end

      context 'when the config for auto-creation of LDAP user is set' do
        let(:ldap_user) { create(:omniauth_user, :ldap) }
        let(:ldap_auto_create_blocked) { true }

        before do
          stub_ldap_config(block_auto_created_users: ldap_auto_create_blocked)
        end

        subject(:blocked_user?) { ldap_user.blocked_auto_created_oauth_ldap_user? }

        context 'when it blocks the creation of a LDAP user' do
          it { is_expected.to be_truthy }

          context 'when no provider is linked to the user' do
            let(:ldap_user) { create(:user) }

            it { is_expected.to be_falsey }
          end
        end

        context 'when it does not block the creation of a LDAP user' do
          let(:ldap_auto_create_blocked) { false }

          it { is_expected.to be_falsey }
        end

        context 'when LDAP is disabled' do
          before do
            stub_ldap_setting(enabled: false)
          end

          it { is_expected.to be_falsey }
        end
      end
    end
  end

  describe '#managed_by_group?', :saas do
    let_it_be(:group) { create(:group) }

    using RSpec::Parameterized::TableSyntax

    where(:domain_verification_available_for_group, :user_is_enterprise_user_of_the_group, :expected_value) do
      false | false | false
      false | true  | false
      true  | false | false
      true  | true  | true
    end

    with_them do
      before do
        stub_licensed_features(domain_verification: domain_verification_available_for_group)

        user.user_detail.enterprise_group_id = user_is_enterprise_user_of_the_group ? group.id : -42
      end

      it "returns #{params[:expected_value]}" do
        expect(user.managed_by_group?(group)).to eq expected_value
      end
    end

    context 'when group passed is nil' do
      it 'returns false' do
        expect(user.managed_by_group?(nil)).to be false
      end
    end
  end

  describe '#can_read_email_enterprise_user?', :saas do
    let_it_be(:group) { create(:group) }
    let_it_be(:unrelated_to_user_group) { create(:group) }

    let_it_be(:shared_with_group) { create(:group) }

    let_it_be(:share_group) do
      create(:group_group_link, shared_group: group, shared_with_group: shared_with_group, group_access: Gitlab::Access::OWNER)
    end

    let_it_be(:share_unrelated_to_user_group) do
      create(:group_group_link, shared_group: unrelated_to_user_group, shared_with_group: shared_with_group, group_access: Gitlab::Access::OWNER)
    end

    let_it_be(:current_user) { create(:user) }

    using RSpec::Parameterized::TableSyntax

    where(:domain_verification_available_for_group, :user_is_enterprise_user_of_the_group, :current_user_is_group_owner, :owner_via_invited_group, :expected_value) do
      false | false  | false | nil   | false
      false | false  | true  | false | false
      false | false  | true  | true  | false
      false | true   | false | nil   | false
      false | true   | true  | false | false
      false | true   | true  | true  | false
      true  | false  | false | nil   | false
      true  | false  | true  | false | false
      true  | false  | true  | true  | false
      true  | true   | false | nil   | false
      true  | true   | true  | false | true
      true  | true   | true  | true  | true
    end

    with_them do
      before do
        stub_licensed_features(domain_verification: domain_verification_available_for_group)

        user.user_detail.enterprise_group_id = user_is_enterprise_user_of_the_group ? group.id : -42

        if current_user_is_group_owner
          if owner_via_invited_group
            shared_with_group.add_owner(current_user)
          else
            group.add_owner(current_user)
            unrelated_to_user_group.add_owner(current_user)
          end
        else
          group.add_maintainer(current_user)
          unrelated_to_user_group.add_maintainer(current_user)
        end
      end

      it "returns #{params[:expected_value]}" do
        expect(user.can_read_email_enterprise_user?(current_user, group: group)).to eq expected_value
      end

      context 'when group is not explicitly passed' do
        it "automatically identifies enterprise_group and returns #{params[:expected_value]}" do
          expect(user.can_read_email_enterprise_user?(current_user)).to eq expected_value
        end
      end

      context 'when group passed is not related to the user' do
        it 'returns false' do
          expect(user.can_read_email_enterprise_user?(current_user, group: unrelated_to_user_group)).to be false
        end
      end
    end

    context 'when group passed is nil' do
      it 'returns false' do
        expect(user.can_read_email_enterprise_user?(current_user, group: nil)).to be false
      end
    end

    context 'when current_user passed is nil' do
      it 'returns false' do
        expect(user.can_read_email_enterprise_user?(nil, group: group)).to be false
      end
    end

    context 'when current_user and group passed are nil' do
      it 'returns false' do
        expect(user.can_read_email_enterprise_user?(nil, group: nil)).to be false
      end
    end
  end

  describe '#can_disable_two_factor_enterprise_user?', :saas do
    let_it_be(:group) { create(:group) }
    let_it_be(:unrelated_to_user_group) { create(:group) }

    let_it_be(:shared_with_group) { create(:group) }

    let_it_be(:share_group) do
      create(:group_group_link, shared_group: group, shared_with_group: shared_with_group, group_access: Gitlab::Access::OWNER)
    end

    let_it_be(:share_unrelated_to_user_group) do
      create(:group_group_link, shared_group: unrelated_to_user_group, shared_with_group: shared_with_group, group_access: Gitlab::Access::OWNER)
    end

    let_it_be(:current_user) { create(:user) }

    using RSpec::Parameterized::TableSyntax

    where(:domain_verification_available_for_group, :user_is_enterprise_user_of_the_group, :current_user_is_group_owner, :owner_via_invited_group, :expected_value) do
      false | false  | false | nil   | false
      false | false  | true  | false | false
      false | false  | true  | true  | false
      false | true   | false | nil   | false
      false | true   | true  | false | false
      false | true   | true  | true  | false
      true  | false  | false | nil   | false
      true  | false  | true  | false | false
      true  | false  | true  | true  | false
      true  | true   | false | nil   | false
      true  | true   | true  | false | true
      true  | true   | true  | true  | true
    end

    with_them do
      before do
        stub_licensed_features(domain_verification: domain_verification_available_for_group)

        user.user_detail.enterprise_group_id = user_is_enterprise_user_of_the_group ? group.id : -42

        if current_user_is_group_owner
          if owner_via_invited_group
            shared_with_group.add_owner(current_user)
          else
            group.add_owner(current_user)
            unrelated_to_user_group.add_owner(current_user)
          end
        else
          group.add_maintainer(current_user)
          unrelated_to_user_group.add_maintainer(current_user)
        end
      end

      it "returns #{params[:expected_value]}" do
        expect(user.can_disable_two_factor_enterprise_user?(current_user, group: group)).to eq expected_value
      end

      context 'when group is not explicitly passed' do
        it "automatically identifies enterprise_group and returns #{params[:expected_value]}" do
          expect(user.can_disable_two_factor_enterprise_user?(current_user)).to eq expected_value
        end
      end

      context 'when group passed is not related to the user' do
        it 'returns false' do
          expect(user.can_disable_two_factor_enterprise_user?(current_user, group: unrelated_to_user_group)).to be false
        end
      end
    end

    context 'when group passed is nil' do
      it 'returns false' do
        expect(user.can_disable_two_factor_enterprise_user?(current_user, group: nil)).to be false
      end
    end

    context 'when current_user passed is nil' do
      it 'returns false' do
        expect(user.can_disable_two_factor_enterprise_user?(nil, group: group)).to be false
      end
    end

    context 'when current_user and group passed are nil' do
      it 'returns false' do
        expect(user.can_disable_two_factor_enterprise_user?(nil, group: nil)).to be false
      end
    end
  end

  describe "#privatized_by_abuse_automation?" do
    let(:user) { build(:user, private_profile: true, name: 'ghost-123-456') }

    subject(:spam_check) { user.privatized_by_abuse_automation? }

    context 'when the user has a non private profile' do
      it 'returns false' do
        user.private_profile = false

        expect(spam_check).to be false
      end
    end

    context 'when the user name is not ghost-:id-:id like' do
      it 'returns false' do
        user.name = 'spam-is-not-cool'

        expect(spam_check).to be false
      end
    end

    context 'when the user name matches ghost-:id-:id' do
      context 'with extra chars at the beginning' do
        it 'returns false' do
          user.name = 'ABCghost-123-456'

          expect(spam_check).to be false
        end
      end

      context 'with extra chars at the end' do
        it 'returns false' do
          user.name = 'ghost-123-456XYZ'

          expect(spam_check).to be false
        end
      end

      context 'with extra chars at the beginning and the end' do
        it 'returns false' do
          user.name = 'ABCghost-123-456XYZ'

          expect(spam_check).to be false
        end
      end
    end

    context 'when the user has a private profile and the format is ghost-:id-:id' do
      it { is_expected.to be true }
    end
  end

  describe '#activate_based_on_user_cap?' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:user) { create(:user) }

    subject { user.activate_based_on_user_cap? }

    where(:blocked_auto_created_omniauth, :blocked_pending_approval, :user_cap_max_present, :result) do
      true  | true  | true  | false
      false | true  | true  | true
      true  | false | true  | false
      false | false | true  | false
      true  | true  | false | false
      false | true  | false | false
      true  | false | false | false
      false | false | false | false
    end

    with_them do
      before do
        allow(user).to receive(:blocked_auto_created_oauth_ldap_user?).and_return(blocked_auto_created_omniauth)
        allow(user).to receive(:blocked_pending_approval?).and_return(blocked_pending_approval)
        allow(described_class.user_cap_max).to receive(:present?).and_return(user_cap_max_present)
      end

      it { is_expected.to eq(result) }
    end
  end

  describe '.random_password' do
    let(:user) { build(:user) }

    shared_examples_for 'validating with random_password' do
      it 'is valid' do
        user.password = described_class.random_password
        expect(user).to be_valid
      end
    end

    context 'when password_complexity is not available' do
      it 'calls password_length once' do
        expect(described_class).to receive(:password_length).and_call_original

        expect(described_class.random_password.length).to be Devise.password_length.max
      end
    end

    context 'when password_complexity is available' do
      before do
        stub_licensed_features(password_complexity: true)
      end

      context 'without any password complexity polices' do
        it_behaves_like 'validating with random_password'
      end

      context 'when number is required' do
        before do
          stub_application_setting(password_number_required: true)
        end

        it_behaves_like 'validating with random_password'

        it 'is invalid' do
          user.password = 'qwertasdf'
          expect(user).not_to be_valid
        end
      end

      context 'when password complexity is required' do
        before do
          stub_application_setting(password_number_required: true)
          stub_application_setting(password_symbol_required: true)
        end

        it_behaves_like 'validating with random_password'
      end
    end

    context 'when password complexity is available through registration features' do
      before do
        stub_application_setting(usage_ping_features_enabled: true)
      end

      context 'without any password complexity polices' do
        it_behaves_like 'validating with random_password'
      end

      context 'when number is required' do
        before do
          stub_application_setting(password_number_required: true)
        end

        it_behaves_like 'validating with random_password'

        it 'is invalid' do
          user.password = 'qwertasdf'
          expect(user).not_to be_valid
        end

        context 'when password complexity is required' do
          before do
            stub_application_setting(password_symbol_required: true)
          end

          it_behaves_like 'validating with random_password'
        end
      end
    end
  end

  describe '.banned_from_namespace?' do
    let(:user) { build(:user) }
    let(:namespace) { build(:group) }

    subject { user.banned_from_namespace?(namespace) }

    context 'when namespace ban does not exist' do
      it { is_expected.to be(false) }
    end

    context 'when namespace ban exists' do
      before do
        create(:namespace_ban, namespace: namespace, user: user)
      end

      it { is_expected.to be(true) }
    end
  end

  it 'includes IdentityVerifiable' do
    expect(described_class).to include_module(IdentityVerifiable)
  end

  it 'includes Elastic::ApplicationVersionedSearch', feature_category: :global_search do
    expect(described_class).to include_module(Elastic::ApplicationVersionedSearch)
  end

  it 'includes Ai::Model' do
    expect(described_class).to include_module(Ai::Model)
  end

  describe 'Elastic::ApplicationVersionedSearch', :elastic, feature_category: :global_search do
    let_it_be_with_reload(:user) { create(:user) }
    let_it_be(:group) { create(:group) }

    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
    end

    context 'on create' do
      it 'always calls track' do
        expect(Elastic::ProcessBookkeepingService).to receive(:track!).once

        create(:user)
      end
    end

    context 'on delete' do
      it 'always calls track' do
        user = create(:user)

        expect(Elastic::ProcessBookkeepingService).to receive(:track!).once

        user.destroy!
      end
    end

    context 'on update' do
      context 'when an elastic field is updated' do
        it 'always calls track' do
          expect(Elastic::ProcessBookkeepingService).to receive(:track!).once

          user.update!(name: 'New Name')
        end
      end

      context 'when a non-elastic field is updated' do
        it 'does not call track' do
          expect(Elastic::ProcessBookkeepingService).not_to receive(:track!)

          user.update!(user_type: 'automation_bot')
        end
      end

      it 'invokes maintain_elasticsearch_update callback' do
        expect(user).to receive(:maintain_elasticsearch_update).once

        user.update!(name: 'New Name')
      end
    end

    context 'when a membership is created' do
      let_it_be(:group) { create(:group) }

      it 'always calls track' do
        expect(Elastic::ProcessBookkeepingService).to receive(:track!).once

        create(:group_member, :developer, source: group, user: user)
      end
    end

    context 'when a membership is deleted' do
      let_it_be(:membership) { create(:group_member, :developer, source: group, user: user) }

      it 'always calls track' do
        expect(Elastic::ProcessBookkeepingService).to receive(:track!).once

        membership.destroy!
      end
    end

    context 'when a membership is updated' do
      let_it_be_with_reload(:membership) { create(:group_member, :developer, source: group, user: user) }

      it 'does not call track' do
        expect(Elastic::ProcessBookkeepingService).not_to receive(:track!)

        membership.update!(notification_level: 2)
      end
    end
  end

  it 'overrides .use_separate_indices? to true', feature_category: :global_search do
    expect(described_class.use_separate_indices?).to be(true)
  end

  describe '#use_elasticsearch?', feature_category: :global_search do
    [true, false].each do |matcher|
      describe '#use_elasticsearch?' do
        before do
          stub_ee_application_setting(elasticsearch_search: matcher)
        end

        it 'is equal to elasticsearch_search setting' do
          expect(subject.use_elasticsearch?).to eq(matcher)
        end
      end
    end
  end

  describe '#elastic_reference', feature_category: :global_search do
    let(:user) { build_stubbed(:user) }

    it 'returns user reference string' do
      expect(user.elastic_reference).to eq("User|#{user.id}")
    end
  end

  describe '#maintaining_elasticsearch?', :elastic, feature_category: :global_search do
    subject { user.maintaining_elasticsearch? }

    context 'when elasticsearch_indexing is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true)
      end

      it { is_expected.to be(true) }
    end

    context 'when elasticsearch_indexing is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#delete_async', :saas do
    context 'when target user is the same as deleted_by' do
      let_it_be_with_reload(:user) { create(:user) }
      let_it_be(:delay_user_account_self_deletion_enabled) { true }

      subject { user.delete_async(deleted_by: user) }

      before do
        allow(user).to receive(:has_possible_spam_contributions?).and_return(true)
        stub_application_setting(delay_user_account_self_deletion: delay_user_account_self_deletion_enabled)
      end

      context 'when user is not a member of a namespace with a paid plan subscription (excluding trials)' do
        it 'schedules the user for deletion with delay' do
          expect(user).to receive(:belongs_to_paid_namespace?).with(exclude_trials: true).and_return(false)
          expect(DeleteUserWorker).to receive(:perform_in)
          expect(DeleteUserWorker).not_to receive(:perform_async)

          subject
        end
      end

      context 'when user is a member of a namespace with a paid plan subscription (excluding trials)' do
        it 'schedules user for deletion without delay' do
          expect(user).to receive(:belongs_to_paid_namespace?).with(exclude_trials: true).and_return(true)
          expect(DeleteUserWorker).to receive(:perform_async)
          expect(DeleteUserWorker).not_to receive(:perform_in)

          subject
        end
      end
    end
  end

  describe '#lock_access!' do
    let_it_be_with_reload(:user) { create(:user) }
    let_it_be(:gitlab_admin_bot) { Users::Internal.in_organization(user.organization).admin_bot }

    subject { user.lock_access! }

    before do
      stub_licensed_features(admin_audit_log: true)
    end

    it 'logs a user_access_locked audit event' do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(
          name: 'user_access_locked',
          author: gitlab_admin_bot,
          scope: user,
          target: user,
          message: 'User access locked'
        )
      ).and_call_original
      expect { subject }.to change { AuditEventReader.count }.by(1)
    end

    context 'when reason is known' do
      before do
        allow(user).to receive(:attempts_exceeded?).and_return(true)
      end

      it 'logs a user_access_locked audit event with the correct message' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(message: 'User access locked - excessive failed login attempts')
        )

        subject
      end

      context 'when reason is passed in as an option' do
        subject { user.lock_access!(reason: 'specified reason') }

        it 'logs a user_access_locked audit event with the correct message' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(message: 'User access locked - specified reason')
          )

          subject
        end
      end
    end

    context 'when user access is already locked' do
      before do
        user.lock_access!
      end

      it 'does not log an audit event' do
        expect { subject }.not_to change { AuditEventReader.count }
      end
    end
  end

  describe 'should_use_security_policy_bot_avatar?' do
    subject { user.should_use_security_policy_bot_avatar? }

    context 'when user is not a security policy bot' do
      it { is_expected.to be(false) }
    end

    context 'when user is a security policy bot' do
      let_it_be(:user) { create(:user, :security_policy_bot) }

      let_it_be(:project) { create(:project, guests: user) }

      it { is_expected.to be(true) }
    end
  end

  describe 'security_policy_bot_static_avatar_path' do
    let(:image_path) { ::Gitlab::Utils.append_path('http://localhost', avatar_file) }

    subject { user.security_policy_bot_static_avatar_path }

    shared_examples 'returns the default image' do
      let(:avatar_file) { ActionController::Base.helpers.image_path('bot_avatars/security-bot.png') }

      it 'returns the default image' do
        expect(subject).to eq(image_path)
      end
    end

    context 'when size parameter is provided' do
      subject { user.security_policy_bot_static_avatar_path(size) }

      context 'when the size is a valid avatar size' do
        using RSpec::Parameterized::TableSyntax
        where(:size) { Avatarable::USER_AVATAR_SIZES }

        with_them do
          let(:options) { { size: size } }
          let(:avatar_file) { ActionController::Base.helpers.image_path("bot_avatars/security-bot_#{size}.png") }

          it 'returns a image of the given size' do
            expect(subject).to eq(image_path)
          end
        end
      end

      context 'when the size is not a valid avatar size' do
        let(:size) { 1999 }

        it_behaves_like 'returns the default image'
      end
    end

    context 'when size parameter is not provided' do
      it_behaves_like 'returns the default image'
    end
  end

  describe '#security_policy_bot_project' do
    subject(:security_policy_bot_project) { user.security_policy_bot_project }

    let_it_be(:project, freeze: true) { create(:project) }

    context 'when bot has exactly one project membership' do
      let_it_be(:user, freeze: true) { create(:user, :security_policy_bot, guest_of: project) }

      it { is_expected.to eq(project) }
    end

    context 'when bot has no project memberships' do
      let_it_be(:user, freeze: true) { create(:user, :security_policy_bot) }

      it { is_expected.to be_nil }
    end

    context 'when bot has multiple project memberships' do
      let_it_be(:additional_project, freeze: true) { create(:project) }
      let_it_be(:user, freeze: true) { create(:user, :security_policy_bot) }
      let_it_be(:project_membership, freeze: true) do
        create(:project_member, :guest, user: user, project: project)
      end

      let_it_be(:additional_project_membership, freeze: true) do
        create(:project_member, :guest, user: user, project: additional_project)
      end

      it { is_expected.to be_nil }
    end

    context 'when user is not a security policy bot' do
      let_it_be(:user, freeze: true) { create(:user, guest_of: project) }

      it { is_expected.to be_nil }
    end
  end

  describe '#unlock_access!' do
    let_it_be_with_reload(:user) { create(:user) }

    subject { user.unlock_access! }

    before do
      stub_licensed_features(admin_audit_log: true)

      user.lock_access!
    end

    shared_examples 'logs a user_access_unlocked audit event with the correct author' do
      it 'logs a user_access_unlocked audit event with the correct author' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'user_access_unlocked',
            author: expected_author,
            scope: user,
            target: user,
            message: 'User access unlocked'
          )
        ).and_call_original

        expect { subject }.to change { AuditEventReader.count }.by(1)
      end
    end

    it_behaves_like 'logs a user_access_unlocked audit event with the correct author' do
      let(:expected_author) { user }
    end

    context 'when unlocked_by is specified' do
      it_behaves_like 'logs a user_access_unlocked audit event with the correct author' do
        let_it_be(:expected_author) { create(:user) }

        subject { user.unlock_access!(unlocked_by: expected_author) }
      end
    end

    context 'when user access is not locked' do
      let_it_be_with_reload(:active_user) { create(:user) }

      it 'does not log an audit event' do
        expect { active_user.unlock_access! }.not_to change { AuditEventReader.count }
      end
    end
  end

  describe '#registration_audit_details' do
    let!(:user) { create(:user, namespace: create(:user_namespace, namespace_settings: create(:namespace_settings))) }

    subject { user.registration_audit_details }

    it 'returns audit details hash' do
      details_hash = {
        id: user.id,
        username: user.username,
        name: user.name,
        email: user.email,
        access_level: user.access_level
      }

      expect(subject).to eql(details_hash)
    end
  end

  describe 'audits' do
    context 'audit events' do
      it 'audits the confirmation request' do
        user = create :user
        unconfirmed_email = 'first-unconfirmed-email@example.com'

        expect(::Gitlab::Audit::Auditor).to(receive(:audit).with(hash_including({
          author: user,
          scope: user,
          target: user,
          name: 'email_confirmation_sent',
          message: "Confirmation instructions sent to: #{unconfirmed_email}",
          additional_details: hash_including({
            current_email: user.email,
            target_type: 'Email',
            unconfirmed_email: unconfirmed_email
          })
        })).and_call_original)

        user.update!(email: unconfirmed_email)
      end
    end
  end

  describe '#skip_enterprise_user_email_change_restrictions?' do
    it 'returns false by default' do
      expect(user.skip_enterprise_user_email_change_restrictions?).to be_falsey
    end

    context 'when skip_enterprise_user_email_change_restrictions! is enabled' do
      it 'returns true' do
        user.skip_enterprise_user_email_change_restrictions!

        expect(user.skip_enterprise_user_email_change_restrictions?).to be_truthy
      end
    end
  end

  describe 'starred_projects' do
    let_it_be(:project) { create(:project) }
    let_it_be_with_reload(:user) { create(:user) }

    context 'when project is not maintaining elasticsearch' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it 'doest not call Elastic::ProcessBookkeepingService' do
        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!)
        user.toggle_star(project)
      end
    end

    context 'when project is maintaining elasticsearch' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true)
      end

      it 'calls Elastic::ProcessBookkeepingService' do
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(project).once
        user.toggle_star(project)
      end
    end

    context 'when user is inactive' do
      before do
        user.block
      end

      it 'doest not call Elastic::ProcessBookkeepingService' do
        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!)
        user.toggle_star(project)
      end
    end
  end

  describe '#external?' do
    subject { user.external? }

    context 'when external is true' do
      let(:user) { build(:user, external: true) }

      it { is_expected.to be(true) }
    end

    context 'when external is false' do
      let(:user) { build(:user, external: false) }

      it { is_expected.to be(false) }
    end

    context 'when user is security_policy_bot' do
      let(:user) { build(:user, :security_policy_bot, external: false) }

      it { is_expected.to be(true) }
    end
  end

  describe '#contributed_epic_groups' do
    subject { user.contributed_epic_groups }

    let(:user) { create(:user) }

    let!(:group_with_events) { create(:group) }
    let!(:group_without_events) { create(:group) }
    let!(:group_aimed_for_deletion) do
      create(:group).tap { |group| create(:group_deletion_schedule, group: group, deleting_user: user) }
    end

    before do
      [group_with_events, group_without_events, group_aimed_for_deletion].each { |group| group.add_maintainer(user) }

      create(
        :event, :epic_create_event,
        group: group_with_events,
        author: user,
        target: create(:epic, group: group_with_events)
      )

      create(
        :event, :epic_create_event,
        group: group_aimed_for_deletion,
        author: user,
        target: create(:epic, group: group_aimed_for_deletion)
      )
    end

    it 'returns groups not aimed for deletion where epic events occured' do
      expect(subject).to contain_exactly(group_with_events)
    end
  end

  describe '#contributed_note_groups' do
    subject { user.contributed_note_groups }

    let_it_be(:user) { create(:user) }

    let_it_be(:group_with_wiki) { create(:group) }
    let_it_be(:group_with_epic) { create(:group) }
    let_it_be(:group_aimed_for_deletion) do
      create(:group).tap { |group| create(:group_deletion_schedule, group: group, deleting_user: user) }
    end

    let_it_be_with_refind(:wiki_page_meta) { create(:wiki_page_meta, :for_wiki_page, container: group_with_wiki) }
    let_it_be(:wiki_note) { create(:note, author: user, project: nil, noteable: wiki_page_meta) }
    let_it_be(:epic_note) { create(:note, author: user, project: nil, noteable: create(:epic, group: group_with_epic)) }

    before do
      [group_with_wiki, group_with_epic, group_aimed_for_deletion].each { |group| group.add_maintainer(user) }

      create(
        :event,
        group: group_with_wiki,
        project: nil,
        author: user,
        target: wiki_note,
        action: :commented
      )

      create(
        :event,
        group: group_aimed_for_deletion,
        project: nil,
        author: user,
        target: wiki_note,
        action: :commented
      )

      create(
        :event,
        group: group_with_epic,
        project: nil,
        author: user,
        target: epic_note,
        action: :commented
      )
    end

    it 'returns groups not aimed for deletion where note events occured' do
      expect(subject).to contain_exactly(group_with_wiki, group_with_epic)
    end
  end

  describe '#ldap_sync_time' do
    let(:user) { build(:user) }

    before do
      stub_config(ldap: { sync_time: 10.hours })
    end

    it 'is equal to the configured value' do
      expect(user.ldap_sync_time).to eq(10.hours)
    end
  end

  describe '#has_current_license?' do
    let(:user) { build_stubbed :user }

    subject { user.has_current_license? }

    context 'when there is no license', :without_license do
      it { is_expected.to be_falsey }
    end

    context 'when there is a current license', :with_license do
      it { is_expected.to be_truthy }
    end
  end

  describe '#ci_available_runners' do
    using RSpec::Parameterized::TableSyntax

    subject(:ci_available_runners) { user.ci_available_runners }

    let_it_be_with_refind(:user) { create(:user) }
    let_it_be(:group_a) { create(:group, name: "group-a") }
    let_it_be(:group_aa) { create(:group, parent: group_a, name: "group-aa") }
    let_it_be(:group_aaa) { create(:group, parent: group_aa, name: "group-aaa") }
    let_it_be(:group_ab) { create(:group, parent: group_a, name: "group-ab") }
    let_it_be(:group_aba) { create(:group, parent: group_ab, name: "group-aba") }
    let_it_be(:group_b) { create(:group, name: "group-b") }

    let_it_be(:group_a_runner) { create(:ci_runner, :group, groups: [group_a], name: "a") }
    let_it_be(:group_aa_runner) { create(:ci_runner, :group, groups: [group_aa], name: "aa") }
    let_it_be(:group_aaa_runner) { create(:ci_runner, :group, groups: [group_aaa], name: "aaa") }
    let_it_be(:group_ab_runner) { create(:ci_runner, :group, groups: [group_ab], name: "ab") }
    let_it_be(:group_aba_runner) { create(:ci_runner, :group, groups: [group_aba], name: "aba") }
    let_it_be(:group_b_runner) { create(:ci_runner, :group, groups: [group_b], name: "b") }

    let_it_be(:admin_runners_a) { create(:member_role, :guest, :admin_runners, namespace: group_a) }
    let_it_be(:admin_runners_b) { create(:member_role, :guest, :admin_runners, namespace: group_b) }

    let_it_be(:project_a) { create(:project, group: group_a, name: "a") }
    let_it_be(:project_aa) { create(:project, group: group_aa, name: "aa") }
    let_it_be(:project_aaa) { create(:project, group: group_aaa, name: "aaa") }
    let_it_be(:project_ab) { create(:project, group: group_ab, name: "ab") }
    let_it_be(:project_aba) { create(:project, group: group_aba, name: "aba") }

    let_it_be(:project_a_runner) { create(:ci_runner, :project, projects: [project_a], name: "a") }
    let_it_be(:project_aa_runner) { create(:ci_runner, :project, projects: [project_aa], name: "aa") }
    let_it_be(:project_aaa_runner) { create(:ci_runner, :project, projects: [project_aaa], name: "aaa") }
    let_it_be(:project_ab_runner) { create(:ci_runner, :project, projects: [project_ab], name: "ab") }
    let_it_be(:project_aba_runner) { create(:ci_runner, :project, projects: [project_aba], name: "aba") }

    it { is_expected.to be_empty }

    context 'with static roles' do
      it { is_expected.to be_empty }

      where(:source, :role, :expected_runners) do
        ref(:group_a)   | :owner      | [ref(:group_a_runner), ref(:group_aa_runner), ref(:group_aaa_runner), ref(:group_ab_runner), ref(:group_aba_runner), ref(:project_a_runner), ref(:project_aa_runner), ref(:project_aaa_runner), ref(:project_ab_runner), ref(:project_aba_runner)]
        ref(:group_aa)  | :owner      | [ref(:group_aa_runner), ref(:group_aaa_runner), ref(:project_aa_runner), ref(:project_aaa_runner)]
        ref(:group_aaa) | :owner      | [ref(:group_aaa_runner), ref(:project_aaa_runner)]
        ref(:project_a) | :developer  | []
        ref(:project_a) | :guest      | []
        ref(:project_a) | :maintainer | [ref(:project_a_runner)]
        ref(:project_a) | :owner      | [ref(:project_a_runner)]
        ref(:project_a) | :reporter   | []
      end

      with_them do
        context "when the user is a #{params[:role]} of #{params[:source]}" do
          before do
            membership_type = source.is_a?(::Group) ? :group_member : :project_member
            create(membership_type, role, source: source, user: user)
          end

          it { is_expected.to match_array(expected_runners) }
        end
      end
    end

    context 'with custom roles' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      it { is_expected.to be_empty }

      where(:source, :role, :expected_runners) do
        ref(:group_a)   | ref(:admin_runners_a) | [ref(:group_a_runner), ref(:group_aa_runner), ref(:group_aaa_runner), ref(:group_ab_runner), ref(:group_aba_runner)]
        ref(:group_aa)  | ref(:admin_runners_a) | [ref(:group_aa_runner), ref(:group_aaa_runner)]
        ref(:group_aba) | ref(:admin_runners_a) | [ref(:group_aba_runner)]
      end

      with_them do
        context "with `#{params[:role]}` on #{params[:source]}" do
          before do
            create(:group_member, :guest, member_role: role, source: source, user: user)
          end

          it "returns the expected runners", pending: 'Related to: https://gitlab.com/gitlab-org/gitlab/-/issues/477585' do
            is_expected.to match_array(expected_runners)
          end
        end
      end

      context 'with other project memberships in the hierarchy' do
        before do
          project_a.add_guest(user)

          create(:group_member, :guest, member_role: admin_runners_a, source: group_aa, user: user)
        end

        it 'does not include ancestor groups of other project', pending: 'Related to: https://gitlab.com/gitlab-org/gitlab/-/issues/477585' do
          is_expected.to contain_exactly(group_aa_runner, group_aaa_runner)
        end
      end

      context "with another user a member of the `admin_runners` role in the same group hierarchy" do
        before do
          other_role = create(:member_role, :guest, :read_code, namespace: group_a)
          create(:group_member, :guest, member_role: other_role, source: group_a, user: user)

          other_user = create(:user)
          create(:group_member, :guest, member_role: admin_runners_a, source: group_a, user: other_user)
        end

        it { is_expected.to be_empty }
      end
    end
  end

  context 'normalized email reuse check' do
    let(:error_message) { 'Email is not allowed. Please enter a different email address and try again.' }
    let(:tumbled_email) { 'user+inbox1@test.com' }
    let(:normalized_email) { 'user@test.com' }

    subject(:new_user) { build(:user, email: tumbled_email).tap(&:valid?) }

    before do
      stub_application_setting(enforce_email_subaddress_restrictions: true)
      stub_const("::AntiAbuse::UniqueDetumbledEmailValidator::NORMALIZED_EMAIL_ACCOUNT_LIMIT", 1)
      create(:user, email: normalized_email)
    end

    context 'when the user has a gitlab.com email address' do
      let(:tumbled_email) { 'user+inbox1@gitlab.com' }
      let(:normalized_email) { 'user@gitlab.com' }

      context 'when running in saas', :saas do
        it 'does not add an error' do
          expect(new_user.errors).to be_empty
        end
      end

      context 'when not running in saas' do
        it 'adds a validation error' do
          expect(new_user.errors.full_messages).to include(error_message)
        end
      end
    end

    context 'when a saas user has a an email associated with a verified domain', :saas do
      let(:verified_domain) { 'verified.com' }
      let(:tumbled_email) { "user+inbox1@#{verified_domain}" }
      let(:normalized_email) { "user@#{verified_domain}" }

      context 'when the group is paid' do
        let_it_be(:ultimate_group) { create(:group_with_plan, plan: :ultimate_plan) }
        let_it_be(:ultimate_project) { create(:project, group: ultimate_group) }

        it 'does not add an error' do
          create(:pages_domain, domain: verified_domain, project: ultimate_project)

          expect(new_user.errors).to be_empty
        end
      end

      context 'when the root group is not paid' do
        let_it_be(:free_group) { create(:group) }
        let_it_be(:free_project) { create(:project, group: free_group) }

        it 'adds a validation error' do
          create(:pages_domain, domain: verified_domain, project: free_project)

          expect(new_user.errors.full_messages).to include(error_message)
        end
      end

      context 'when the root group does not exist' do
        let_it_be(:project) { create(:project) }

        it 'adds a validation error' do
          create(:pages_domain, domain: verified_domain, project: project)

          expect(new_user.errors.full_messages).to include(error_message)
        end
      end
    end

    context 'when user is on a self-managed instance' do
      it 'does not check domain verification' do
        expect(::PagesDomain).not_to receive(:verified)
      end
    end
  end

  describe '#destroy' do
    it_behaves_like 'create audits for user add-on assignments' do
      let(:entity) { user }
    end
  end

  describe '.filter_items' do
    context 'with auditors filter' do
      it 'returns only auditor users' do
        auditor_user = create(:user, :auditor)

        expect(described_class.filter_items('auditors')).to contain_exactly(auditor_user)
      end
    end
  end

  describe '#should_use_flipped_dashboard_mapping_for_rollout?' do
    let_it_be(:user) { create(:user) }

    before do
      stub_feature_flags(personal_homepage: true)
    end

    context 'when admin_homepage SaaS feature is disabled (self-managed)' do
      before do
        stub_saas_features(admin_homepage: false)
      end

      it 'returns true for users' do
        expect(user.should_use_flipped_dashboard_mapping_for_rollout?).to be true
      end
    end

    context 'when admin_homepage SaaS feature is enabled (GitLab.com)' do
      before do
        stub_saas_features(admin_homepage: true)
      end

      it 'returns true for users' do
        expect(user).to be_should_use_flipped_dashboard_mapping_for_rollout
      end

      it 'returns true for admins', :enable_admin_mode do
        admin_user = create(:admin)
        expect(admin_user).to be_should_use_flipped_dashboard_mapping_for_rollout
      end
    end
  end

  describe '#designated_account_manager' do
    let_it_be(:user) { create(:user) }

    subject { user.designated_account_manager }

    context 'when user has no designated beneficiaries' do
      it { is_expected.to be_nil }
    end

    context 'when user has only successor' do
      before do
        create(:designated_beneficiary, :successor, user: user)
      end

      it { is_expected.to be_nil }
    end

    context 'when user has manager' do
      let!(:manager) { create(:designated_beneficiary, :manager, user: user) }

      it { is_expected.to eq(manager) }
    end
  end

  describe '#designated_account_successor' do
    let_it_be(:user) { create(:user) }

    subject { user.designated_account_successor }

    context 'when user has no designated beneficiaries' do
      it { is_expected.to be_nil }
    end

    context 'when user has only manager' do
      before do
        create(:designated_beneficiary, :manager, user: user)
      end

      it { is_expected.to be_nil }
    end

    context 'when user has successor' do
      let!(:successor) { create(:designated_beneficiary, :successor, user: user) }

      it { is_expected.to eq(successor) }
    end
  end

  describe '#allow_user_to_create_group_and_project?', :sidekiq_inline do
    subject(:user) { create(:user) }

    let(:group) { create(:group) }
    let!(:license) { create(:license, plan: License::PREMIUM_PLAN) }

    before do
      group.add_guest(user)
      stub_application_setting(allow_project_creation_for_guest_and_below: false)
    end

    context 'with block seat overage and no seats available' do
      before do
        allow(License).to receive(:current).and_return(license)
        allow(license).to receive(:seats).and_return(1) # One billable user already exists

        stub_application_setting(seat_control: 2)
      end

      it { is_expected.not_to be_allow_user_to_create_group_and_project }
    end

    context 'with enabled configuration' do
      before do
        stub_application_setting(allow_project_creation_for_guest_and_below: true)
      end

      it { is_expected.to be_allow_user_to_create_group_and_project }
    end
  end

  describe '#owned_free_or_trial_groups_with_limit', :saas do
    let_it_be(:user) { create(:user) }

    context 'when user has owned free or trial groups' do
      let_it_be(:free_group) { create(:group_with_plan, plan: :free_plan, owners: user) }
      let_it_be(:trial_group) do
        create(:group_with_plan,
          plan: :ultimate_trial_plan,
          owners: user,
          trial: true,
          trial_starts_on: 1.day.ago,
          trial_ends_on: 30.days.from_now)
      end

      before_all do
        create(:group_with_plan, plan: :ultimate_plan, owners: user)
        create(:group_with_plan, plan: :free_plan, developers: user)
        create(:group_with_plan, plan: :free_plan)
      end

      context 'when the provided limit is more than total available groups' do
        it 'returns all free or trial groups' do
          outcome = user.owned_free_or_trial_groups_with_limit(5)
          expect(outcome).to match_array([free_group, trial_group])
          expect(outcome.size).to eq(2)
        end
      end

      context 'when the provided limit is less than total available groups' do
        it 'returns the limited number of free or trial groups' do
          outcome = user.owned_free_or_trial_groups_with_limit(1)
          expect(outcome).to match_array([free_group])
          expect(outcome.size).to eq(1)
        end
      end

      context 'when a group is scheduled for deletion' do
        it 'excludes the group scheduled for deletion' do
          create(
            :group_deletion_schedule,
            group: free_group,
            marked_for_deletion_on: 1.day.ago,
            deleting_user: user
          )

          outcome = user.owned_free_or_trial_groups_with_limit(5)

          expect(outcome).to match_array([trial_group])
        end
      end
    end
  end

  describe '#ssh_keys_disabled?' do
    let_it_be(:enterprise_group) { create(:group) }

    context 'when user is not associated with an enterprise group' do
      let(:user) { build(:user) }

      it 'returns false' do
        expect(user.ssh_keys_disabled?).to be(false)
      end
    end

    context 'when user is associated with an enterprise group' do
      let(:user) { build(:enterprise_user, enterprise_group: enterprise_group) }

      context 'when group does not disable SSH keys' do
        before do
          allow(enterprise_group).to receive(:disable_ssh_keys?).and_return(false)
        end

        it 'returns false' do
          expect(user.ssh_keys_disabled?).to be(false)
        end
      end

      context 'when group disables SSH keys' do
        before do
          allow(enterprise_group).to receive(:disable_ssh_keys?).and_return(true)
        end

        it 'returns true' do
          expect(user.ssh_keys_disabled?).to be(true)
        end
      end
    end
  end

  describe '#require_ssh_key?' do
    let_it_be(:enterprise_group) { create(:group) }

    context 'when user does not have SSH keys' do
      context 'when user is not associated with an enterprise group' do
        let(:user) { build(:user) }

        it 'returns true' do
          expect(user.require_ssh_key?).to be(true)
        end
      end

      context 'when user is associated with an enterprise group' do
        let(:user) { build(:enterprise_user, enterprise_group: enterprise_group) }

        context 'when group does not disable SSH keys' do
          before do
            allow(enterprise_group).to receive(:disable_ssh_keys?).and_return(false)
          end

          it 'returns true' do
            expect(user.require_ssh_key?).to be(true)
          end
        end

        context 'when group disables SSH keys' do
          before do
            allow(enterprise_group).to receive(:disable_ssh_keys?).and_return(true)
          end

          it 'returns false' do
            expect(user.require_ssh_key?).to be(false)
          end
        end
      end
    end
  end

  describe '#enforce_top_level_group_limit?', :saas_enforce_top_level_group_limits do
    let(:user) { create(:user) }

    subject { user.enforce_top_level_group_limit? }

    context 'when user was created after the cutoff date', time_travel_to: User::FREE_USER_TOP_LEVEL_GROUP_LIMIT_FROM_DATE + 1.day do
      context 'when the user has created the max number of groups' do
        before do
          create_list(:group, User::FREE_USER_TOP_LEVEL_GROUP_LIMIT, creator: user)
        end

        it { is_expected.to be(true) }

        context 'when the enforce_top_level_group_limits feature flag is disabled' do
          before do
            stub_feature_flags(enforce_top_level_group_limits: false)
          end

          it { is_expected.to be(false) }
        end

        context 'when not in SaaS' do
          before do
            stub_saas_features(enforce_top_level_group_limits: false)
          end

          it { is_expected.to be(false) }
        end
      end

      context 'when the user has not created the max number of groups' do
        before do
          create_list(:group, User::FREE_USER_TOP_LEVEL_GROUP_LIMIT - 1, creator: user)
        end

        it { is_expected.to be(false) }
      end
    end
  end

  describe '#exempt_from_top_level_group_limit?', :saas_enforce_top_level_group_limits do
    let_it_be(:user) { create(:user) }

    subject(:exempt_from_top_level_group_limit) { user.exempt_from_top_level_group_limit? }

    context 'when user was created before the cutoff date', time_travel_to: User::FREE_USER_TOP_LEVEL_GROUP_LIMIT_FROM_DATE - 1.day do
      let(:user) { create(:user) }

      it { is_expected.to be(true) }
    end

    context 'when user was created on the cutoff date', time_travel_to: User::FREE_USER_TOP_LEVEL_GROUP_LIMIT_FROM_DATE do
      let(:user) { create(:user) }

      it { is_expected.to be(true) }
    end

    context 'when user was created after the cutoff date', time_travel_to: User::FREE_USER_TOP_LEVEL_GROUP_LIMIT_FROM_DATE + 1.day do
      let(:user) { create(:user) }

      it { is_expected.to be(false) }

      context 'when user has the top_level_group_limit_exempt custom attribute' do
        before do
          create(
            :user_custom_attribute,
            key: UserCustomAttribute::TOP_LEVEL_GROUP_LIMIT_EXEMPT,
            value: 'true',
            user_id: user.id
          )
        end

        it { is_expected.to be(true) }
      end

      context 'when user is an enterprise user' do
        let(:user) { create(:enterprise_user) }

        it { is_expected.to be(true) }
      end

      context 'when user belongs to a paid namespace (excluding trials)', :saas do
        let!(:group) { create(:group_with_plan, plan: :ultimate_plan, developers: [user]) }

        it { is_expected.to be(true) }
      end
    end
  end
end
