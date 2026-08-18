# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::GroupSaml::SessionEnforcer, feature_category: :system_access do
  include SessionHelpers

  shared_examples 'Git access not allowed' do
    it { is_expected.to be_access_restricted }
  end

  shared_examples 'Git access allowed' do
    it { is_expected.not_to be_access_restricted }
  end

  describe '#access_restricted?' do
    let_it_be_with_reload(:user) { create(:user) }
    let_it_be_with_reload(:bot) { create(:user, :bot) }
    let_it_be_with_reload(:svc_acct) { create(:user, :service_account) }
    let_it_be_with_reload(:root_group) { create(:group) }
    let_it_be_with_reload(:subgroup) { create(:group, parent: root_group) }
    let_it_be_with_reload(:project) { create(:project, group: subgroup) }
    let_it_be_with_reload(:proj_bot) { create(:user, :project_bot, maintainer_of: project) }

    let_it_be_with_reload(:saml_provider) { create(:saml_provider, enforced_sso: true, group: root_group) }
    let_it_be(:identity) { create(:group_saml_identity, saml_provider: saml_provider, user: user) }

    subject(:group_saml_session_enforcer) { described_class.new(user, root_group) }

    before do
      stub_licensed_features(group_saml: true)
    end

    context 'with setup', :clean_gitlab_redis_sessions do
      using RSpec::Parameterized::TableSyntax

      where(:group, :git_check_enforced?, :owner_of_resource?, :owner_of_root_group?, :usr, :active_session?,
        :user_is_admin?, :enable_admin_mode?, :user_is_auditor?, :shared_examples) do
        ref(:root_group) | false | nil   | nil   | ref(:user) | nil   | nil   | nil   | nil   | 'Git access allowed'
        ref(:root_group) | true  | false | nil   | ref(:user) | false | nil   | nil   | nil   | 'Git access not allowed'
        ref(:root_group) | true  | true  | nil   | ref(:user) | false | nil   | nil   | nil   | 'Git access not allowed'
        ref(:root_group) | true  | false | nil   | ref(:user) | true  | nil   | nil   | nil   | 'Git access allowed'

        ref(:subgroup)   | false | nil   | nil   | ref(:user) | nil   | nil   | nil   | nil   | 'Git access allowed'
        ref(:subgroup)   | true  | false | false | ref(:user) | false | nil   | nil   | nil   | 'Git access not allowed'
        ref(:subgroup)   | true  | true  | false | ref(:user) | false | nil   | nil   | nil   | 'Git access not allowed'
        ref(:subgroup)   | true  | true  | false | ref(:user) | true  | nil   | nil   | nil   | 'Git access allowed'
        ref(:subgroup)   | true  | false | true  | ref(:user) | false | nil   | nil   | nil   | 'Git access not allowed'
        ref(:subgroup)   | true  | false | true  | ref(:user) | true  | nil   | nil   | nil   | 'Git access allowed'

        # Auditor user
        ref(:root_group) | true  | false | nil   | ref(:user) | false | nil   | nil   | true  | 'Git access allowed'
        ref(:subgroup)   | true  | false | false | ref(:user) | false | nil   | nil   | true  | 'Git access allowed'

        # Admin user
        ref(:root_group) | true  | false | nil   | ref(:user) | false | true  | false | nil   | 'Git access not allowed'
        ref(:root_group) | true  | false | nil   | ref(:user) | true  | true  | false | nil   | 'Git access allowed'
        ref(:root_group) | true  | false | nil   | ref(:user) | false | true  | true  | nil   | 'Git access allowed'
        ref(:subgroup)   | true  | false | false | ref(:user) | false | true  | false | nil   | 'Git access not allowed'
        ref(:subgroup)   | true  | false | false | ref(:user) | true  | true  | false | nil   | 'Git access allowed'
        ref(:subgroup)   | true  | false | false | ref(:user) | false | true  | true  | nil   | 'Git access allowed'

        # Service Account Bot
        ref(:root_group) | true  | false | nil   | ref(:svc_acct) | false | nil   | nil   | nil   | 'Git access allowed'
        ref(:subgroup)   | true  | false | false | ref(:svc_acct) | false | nil   | nil   | nil   | 'Git access allowed'

        # Alert Bot
        ref(:root_group) | true  | false | nil   | ref(:bot) | false | nil   | nil   | nil   | 'Git access allowed'
        ref(:subgroup)   | true  | false | false | ref(:bot) | false | nil   | nil   | nil   | 'Git access allowed'

        # Project Bot
        ref(:root_group) | true  | false | nil   | ref(:proj_bot) | false | nil   | nil   | nil   | 'Git access allowed'
        ref(:subgroup)   | true  | false | false | ref(:proj_bot) | false | nil   | nil   | nil   | 'Git access allowed'
      end

      with_them do
        def sso_session_data
          { 'active_group_sso_sign_ins' => { saml_provider.id => 5.minutes.ago } }
        end

        before do
          group.root_ancestor.saml_provider.update!(git_check_enforced: git_check_enforced?)

          group.add_owner(usr) if owner_of_resource?
          group.root_ancestor.add_owner(usr) if owner_of_root_group?

          stub_session(session_data: sso_session_data, user_id: usr.id) if active_session?

          usr.update!(admin: true) if user_is_admin?
          usr.update!(auditor: true) if user_is_auditor?
        end

        context 'for user', enable_admin_mode: params[:enable_admin_mode?] do
          subject(:group_saml_session_enforcer) { described_class.new(usr, group) }

          it_behaves_like params[:shared_examples]
        end
      end
    end

    context 'when git check is enforced' do
      before do
        saml_provider.update!(git_check_enforced: true)
      end

      context 'with an active session', :clean_gitlab_redis_sessions do
        let(:session_time) { 5.minutes.ago }
        let(:stored_session) do
          { 'active_group_sso_sign_ins' => { saml_provider.id => session_time } }
        end

        before do
          stub_session(session_data: stored_session, user_id: user.id)
        end

        it_behaves_like 'Git access allowed'

        context 'with sub-group' do
          subject(:group_saml_session_enforcer) { described_class.new(user, subgroup) }

          it_behaves_like 'Git access allowed'
        end

        context 'with expired session' do
          let(:session_time) { 2.days.ago }

          it_behaves_like 'Git access not allowed'
        end

        context 'with two active sessions', :clean_gitlab_redis_sessions do
          let(:second_stored_session) do
            { 'active_group_sso_sign_ins' => { create(:saml_provider, enforced_sso: true).id => session_time } }
          end

          before do
            stub_session(session_data: second_stored_session, user_id: user.id)
          end

          it_behaves_like 'Git access allowed'
        end

        context 'with two active sessions for the same provider and one pre-sso', :clean_gitlab_redis_sessions do
          let(:second_stored_session) do
            { 'active_group_sso_sign_ins' => { saml_provider.id => 2.days.ago } }
          end

          let(:third_stored_session) do
            {}
          end

          before do
            stub_session(session_data: second_stored_session, user_id: user.id)
            stub_session(session_data: third_stored_session, user_id: user.id)
          end

          it_behaves_like 'Git access allowed'
        end

        context 'without group' do
          let(:root_group) { nil }

          it_behaves_like 'Git access allowed'
        end

        context 'without saml_provider' do
          let(:root_group) { create(:group) }

          it_behaves_like 'Git access allowed'
        end

        context 'with admin' do
          let(:user) { create(:user, :admin) }

          context 'when admin mode is enabled', :enable_admin_mode do
            it_behaves_like 'Git access allowed'
          end

          context 'when admin mode is disabled' do
            it_behaves_like 'Git access allowed'
          end
        end

        context 'with auditor' do
          let(:user) { create(:user, :auditor) }

          it_behaves_like 'Git access allowed'
        end

        context 'with group owner' do
          before_all do
            root_group.add_owner(user)
          end

          it_behaves_like 'Git access allowed'
        end
      end

      context 'without any session' do
        it_behaves_like 'Git access not allowed'

        context 'with admin' do
          let(:user) { create(:user, :admin) }

          context 'when admin mode is enabled', :enable_admin_mode do
            it_behaves_like 'Git access allowed'
          end

          context 'when admin mode is disabled' do
            it_behaves_like 'Git access not allowed'
          end
        end

        context 'with auditor' do
          let(:user) { create(:user, :auditor) }

          it_behaves_like 'Git access allowed'
        end

        context 'with group owner' do
          before_all do
            root_group.add_owner(user)
          end

          it_behaves_like 'Git access not allowed'

          context 'when group is a subgroup' do
            subject(:group_saml_session_enforcer) { described_class.new(user, subgroup) }

            it_behaves_like 'Git access not allowed'
          end
        end

        context 'with project bot' do
          let(:user) { create(:user, :project_bot) }

          it_behaves_like 'Git access allowed'
        end
      end
    end

    context 'when git check is not enforced' do
      before do
        saml_provider.update!(git_check_enforced: false)
      end

      context 'with an active session', :clean_gitlab_redis_sessions do
        let(:stored_session) do
          { 'active_group_sso_sign_ins' => { saml_provider.id => 5.minutes.ago } }
        end

        before do
          stub_session(session_data: stored_session, user_id: user.id)
        end

        it_behaves_like 'Git access allowed'
      end

      context 'without any session' do
        it_behaves_like 'Git access allowed'
      end
    end
  end
end
