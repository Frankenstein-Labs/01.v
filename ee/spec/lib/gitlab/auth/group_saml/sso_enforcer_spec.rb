# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::GroupSaml::SsoEnforcer, feature_category: :system_access do
  let(:saml_provider) { build_stubbed(:saml_provider, enforced_sso: true) }
  let(:user) { nil }
  let(:session) { {} }

  before do
    stub_licensed_features(group_saml: true)
  end

  around do |example|
    session['warden.user.user.key'] = [[user.id], user.authenticatable_salt] if user.is_a?(User)

    Gitlab::Session.with_session(session) do
      example.run
    end
  end

  subject(:enforcer) { described_class.new(saml_provider, user: user) }

  describe '#update_session' do
    it 'stores that a session is active for the given provider' do
      expect { enforcer.update_session }.to change { session[:active_group_sso_sign_ins] }
    end

    it 'stores the current time for later comparison', :freeze_time do
      enforcer.update_session

      expect(session[:active_group_sso_sign_ins][saml_provider.id]).to eq DateTime.now
    end
  end

  describe '#active_session?' do
    it 'returns false if nothing has been stored' do
      expect(enforcer).not_to be_active_session
    end

    it 'returns true if a sign in has been recorded' do
      enforcer.update_session

      expect(enforcer).to be_active_session
    end

    it 'returns false if the sign in predates the session timeout' do
      enforcer.update_session

      days_after_timeout = Gitlab::Auth::GroupSaml::SsoEnforcer::DEFAULT_SESSION_TIMEOUT + 2.days
      travel_to(days_after_timeout.from_now) do
        expect(enforcer).not_to be_active_session
      end
    end

    context 'when a session timeout is specified' do
      subject(:enforcer) { described_class.new(saml_provider, user: user, session_timeout: 1.hour) }

      it 'returns true within timeout' do
        enforcer.update_session

        expect(enforcer).to be_active_session
      end

      it 'returns false after timeout elapses' do
        enforcer.update_session

        travel_to(2.hours.from_now) do
          expect(enforcer).not_to be_active_session
        end
      end
    end
  end

  describe '#access_restricted?' do
    context 'when sso enforcement is enabled' do
      context 'when there is no active saml session' do
        it 'returns true' do
          expect(enforcer).to be_access_restricted
        end
      end

      context 'when there is active saml session' do
        context 'when the session timeout is the default' do
          before do
            enforcer.update_session
          end

          it 'returns false' do
            expect(enforcer).not_to be_access_restricted
          end
        end

        context 'when a session timeout is specified' do
          subject(:enforcer) { described_class.new(saml_provider, user: user, session_timeout: 1.hour) }

          it 'returns true within timeout' do
            enforcer.update_session

            expect(enforcer).not_to be_access_restricted
          end

          it 'returns false after timeout elapses' do
            enforcer.update_session

            travel_to(2.hours.from_now) do
              expect(enforcer).to be_access_restricted
            end
          end
        end
      end

      context 'when user is an admin' do
        let(:user) { create(:user, :admin) }

        context 'when admin mode enabled', :enable_admin_mode do
          it 'returns false' do
            expect(enforcer).not_to be_access_restricted
          end
        end

        context 'when admin mode disabled' do
          it 'returns true' do
            expect(enforcer).to be_access_restricted
          end
        end
      end

      context 'when user is an auditor' do
        let(:user) { create(:user, :auditor) }

        it 'returns false' do
          expect(enforcer).not_to be_access_restricted
        end
      end
    end

    context 'when saml_provider is nil' do
      let(:saml_provider) { nil }

      it 'returns false' do
        expect(enforcer).not_to be_access_restricted
      end
    end

    context 'when sso enforcement is disabled' do
      let(:saml_provider) { build_stubbed(:saml_provider, enforced_sso: false) }

      it 'returns false' do
        expect(enforcer).not_to be_access_restricted
      end
    end

    context 'when saml_provider is disabled' do
      let(:saml_provider) { build_stubbed(:saml_provider, enforced_sso: true, enabled: false) }

      it 'returns false' do
        expect(enforcer).not_to be_access_restricted
      end
    end
  end

  describe '.access_restricted?' do
    context 'when user can read all resources' do
      let(:user) { create(:user, :admin) }
      let(:saml_provider) { create(:saml_provider, enabled: true, enforced_sso: true) }
      let(:group) { saml_provider.group }

      before do
        group.add_developer(user)
        create(:group_saml_identity, saml_provider: saml_provider, user: user)
      end

      # Admin/Auditor users are never SSO-restricted. The early return is
      # a performance optimization to avoid loading the SAML provider
      # and instantiating the enforcer
      it 'returns false early without evaluating SAML provider' do
        expect(described_class).not_to receive(:new)

        expect(described_class.access_restricted?(user: user, resource: group)).to be(false)
      end
    end

    context 'when SAML SSO is enabled for resource' do
      using RSpec::Parameterized::TableSyntax

      let(:saml_provider) { create(:saml_provider, enabled: true, enforced_sso: false) }
      let(:identity) { create(:group_saml_identity, saml_provider: saml_provider) }
      let(:root_group) { saml_provider.group }
      let(:subgroup) { create(:group, parent: root_group) }
      let(:shared_group) { create(:group) }
      let(:project) { create(:project, group: subgroup) }
      let(:member_with_identity) { identity.user }
      let(:member_without_identity) { create(:user) }
      let(:member_project) { create(:user) }
      let(:member_subgroup) { create(:user) }
      let(:member_shared) { create(:user) }
      let(:non_member) { create(:user) }
      let(:not_signed_in_user) { nil }
      let(:deploy_token) { create(:deploy_token) }

      before do
        create(:group_group_link, shared_group: root_group, shared_with_group: shared_group)

        stub_licensed_features(minimal_access_role: true, group_saml: true)

        root_group.add_developer(member_with_identity)
        root_group.add_developer(member_without_identity)
        subgroup.add_developer(member_subgroup)
        project.add_developer(member_project)
        shared_group.add_developer(member_shared)
      end

      shared_examples 'SSO Enforced' do
        it 'returns true' do
          params = { user: user, resource: resource }
          params[:skip_owner_check] = skip_owner_check if skip_owner_check

          expect(described_class.access_restricted?(**params)).to be(true)
        end
      end

      shared_examples 'SSO Not enforced' do
        it 'returns false' do
          params = { user: user, resource: resource }
          params[:skip_owner_check] = skip_owner_check if skip_owner_check

          expect(described_class.access_restricted?(**params)).to be(false)
        end
      end

      # See https://docs.gitlab.com/ee/user/group/saml_sso/#sso-enforcement
      where(:resource, :resource_visibility_level, :enforced_sso?, :user, :user_is_resource_owner?, :skip_owner_check, :user_with_saml_session?, :user_is_admin?, :enable_admin_mode?, :user_is_auditor?, :shared_examples) do
        # Project/Group visibility: Private; Enforce SSO setting: Off

        ref(:root_group) | 'private' | false | ref(:member_with_identity)    | false | nil  | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:root_group) | 'private' | false | ref(:member_with_identity)    | true  | nil  | false | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:root_group) | 'private' | false | ref(:member_with_identity)    | true  | true | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:root_group) | 'private' | false | ref(:member_with_identity)    | false | nil  | true  | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:root_group) | 'private' | false | ref(:member_with_identity)    | false | nil  | false | true | false | nil  | 'SSO Enforced'
        ref(:root_group) | 'private' | false | ref(:member_with_identity)    | false | nil  | false | true | true  | nil  | 'SSO Not enforced'
        ref(:root_group) | 'private' | false | ref(:member_with_identity)    | false | nil  | false | nil  | nil   | true | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | false | ref(:member_with_identity)    | false | nil  | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'private' | false | ref(:member_with_identity)    | true  | nil  | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'private' | false | ref(:member_with_identity)    | false | nil  | true  | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | false | ref(:member_with_identity)    | false | nil  | false | true | false | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'private' | false | ref(:member_with_identity)    | false | nil  | false | true | true  | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | false | ref(:member_with_identity)    | false | nil  | false | nil  | nil   | true | 'SSO Not enforced'
        ref(:project)    | 'private' | false | ref(:member_with_identity)    | false | nil  | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:project)    | 'private' | false | ref(:member_with_identity)    | true  | nil  | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:project)    | 'private' | false | ref(:member_with_identity)    | false | nil  | true  | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:project)    | 'private' | false | ref(:member_with_identity)    | false | nil  | false | true | false | nil  | 'SSO Enforced'
        ref(:project)    | 'private' | false | ref(:member_with_identity)    | false | nil  | false | true | true  | nil  | 'SSO Not enforced'
        ref(:project)    | 'private' | false | ref(:member_with_identity)    | false | nil  | false | nil  | nil   | true | 'SSO Not enforced'

        ref(:root_group) | 'private' | false | ref(:member_without_identity) | false | nil  | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | false | ref(:member_without_identity) | false | nil  | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:project)    | 'private' | false | ref(:member_without_identity) | false | nil  | nil   | nil  | nil   | nil  | 'SSO Not enforced'

        ref(:root_group) | 'private' | false | ref(:non_member)              | nil   | nil  | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:root_group) | 'private' | false | ref(:non_member)              | nil   | nil  | nil   | true | false | nil  | 'SSO Not enforced'
        ref(:root_group) | 'private' | false | ref(:non_member)              | nil   | nil  | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:root_group) | 'private' | false | ref(:non_member)              | nil   | nil  | nil   | nil  | nil   | true | 'SSO Not enforced'
        ref(:root_group) | 'private' | false | ref(:not_signed_in_user)      | nil   | nil  | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:root_group) | 'private' | false | ref(:deploy_token)            | nil   | nil  | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | false | ref(:non_member)              | nil   | nil  | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | false | ref(:non_member)              | nil   | nil  | nil   | true | false | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | false | ref(:non_member)              | nil   | nil  | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | false | ref(:non_member)              | nil   | nil  | nil   | nil  | nil   | true | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | false | ref(:not_signed_in_user)      | nil   | nil  | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | false | ref(:deploy_token)            | nil   | nil  | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:project)    | 'private' | false | ref(:non_member)              | nil   | nil  | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:project)    | 'private' | false | ref(:non_member)              | nil   | nil  | nil   | true | false | nil  | 'SSO Not enforced'
        ref(:project)    | 'private' | false | ref(:non_member)              | nil   | nil  | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:project)    | 'private' | false | ref(:non_member)              | nil   | nil  | nil   | nil  | nil   | true | 'SSO Not enforced'
        ref(:project)    | 'private' | false | ref(:not_signed_in_user)      | nil   | nil  | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:project)    | 'private' | false | ref(:deploy_token)            | nil   | nil  | nil   | nil  | nil   | nil  | 'SSO Not enforced'

        # Project/Group visibility: Private; Enforce SSO setting: On

        ref(:root_group) | 'private' | true  | ref(:member_with_identity)    | false | nil  | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:root_group) | 'private' | true  | ref(:member_with_identity)    | true  | nil  | false | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:root_group) | 'private' | true  | ref(:member_with_identity)    | true  | true | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:root_group) | 'private' | true  | ref(:member_with_identity)    | false | nil  | true  | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:root_group) | 'private' | true  | ref(:member_with_identity)    | false | nil  | false | true | false | nil  | 'SSO Enforced'
        ref(:root_group) | 'private' | true  | ref(:member_with_identity)    | false | nil  | false | true | true  | nil  | 'SSO Not enforced'
        ref(:root_group) | 'private' | true  | ref(:member_with_identity)    | false | nil  | false | nil  | nil   | true | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | true  | ref(:member_with_identity)    | false | nil  | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'private' | true  | ref(:member_with_identity)    | true  | nil  | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'private' | true  | ref(:member_with_identity)    | false | nil  | true  | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | true  | ref(:member_with_identity)    | false | nil  | false | true | false | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'private' | true  | ref(:member_with_identity)    | false | nil  | false | true | true  | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | true  | ref(:member_with_identity)    | false | nil  | false | nil  | nil   | true | 'SSO Not enforced'
        ref(:project)    | 'private' | true  | ref(:member_with_identity)    | false | nil  | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:project)    | 'private' | true  | ref(:member_with_identity)    | true  | nil  | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:project)    | 'private' | true  | ref(:member_with_identity)    | false | nil  | true  | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:project)    | 'private' | true  | ref(:member_with_identity)    | false | nil  | false | true | false | nil  | 'SSO Enforced'
        ref(:project)    | 'private' | true  | ref(:member_with_identity)    | false | nil  | false | true | true  | nil  | 'SSO Not enforced'
        ref(:project)    | 'private' | true  | ref(:member_with_identity)    | false | nil  | false | nil  | nil   | true | 'SSO Not enforced'

        ref(:root_group) | 'private' | true  | ref(:member_without_identity) | false | nil  | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:root_group) | 'private' | true  | ref(:member_without_identity) | true  | nil  | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:root_group) | 'private' | true  | ref(:member_without_identity) | true  | true | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:root_group) | 'private' | true  | ref(:member_without_identity) | false | nil  | nil   | true | false | nil  | 'SSO Enforced'
        ref(:root_group) | 'private' | true  | ref(:member_without_identity) | false | nil  | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:root_group) | 'private' | true  | ref(:member_without_identity) | false | nil  | nil   | nil  | nil   | true | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | true  | ref(:member_without_identity) | false | nil  | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'private' | true  | ref(:member_without_identity) | true  | nil  | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'private' | true  | ref(:member_without_identity) | false | nil  | nil   | true | false | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'private' | true  | ref(:member_without_identity) | false | nil  | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | true  | ref(:member_without_identity) | false | nil  | nil   | nil  | nil   | true | 'SSO Not enforced'
        ref(:project)    | 'private' | true  | ref(:member_without_identity) | false | nil  | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:project)    | 'private' | true  | ref(:member_without_identity) | true  | nil  | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:project)    | 'private' | true  | ref(:member_without_identity) | false | nil  | nil   | true | false | nil  | 'SSO Enforced'
        ref(:project)    | 'private' | true  | ref(:member_without_identity) | false | nil  | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:project)    | 'private' | true  | ref(:member_without_identity) | false | nil  | nil   | nil  | nil   | true | 'SSO Not enforced'

        ref(:root_group) | 'private' | true  | ref(:member_project) | false | nil  | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:root_group) | 'private' | true  | ref(:member_project) | false | nil  | nil   | true | false | nil  | 'SSO Enforced'
        ref(:root_group) | 'private' | true  | ref(:member_project) | false | nil  | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:root_group) | 'private' | true  | ref(:member_project) | false | nil  | nil   | nil  | nil   | true | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | true  | ref(:member_project) | false | nil  | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'private' | true  | ref(:member_project) | false | nil  | nil   | true | false | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'private' | true  | ref(:member_project) | false | nil  | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | true  | ref(:member_project) | false | nil  | nil   | nil  | nil   | true | 'SSO Not enforced'
        ref(:project)    | 'private' | true  | ref(:member_project) | false | nil  | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:project)    | 'private' | true  | ref(:member_project) | false | nil  | nil   | true | false | nil  | 'SSO Enforced'
        ref(:project)    | 'private' | true  | ref(:member_project) | false | nil  | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:project)    | 'private' | true  | ref(:member_project) | false | nil  | nil   | nil  | nil   | true | 'SSO Not enforced'

        ref(:root_group) | 'private' | true  | ref(:non_member)              | nil   | nil  | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:root_group) | 'private' | true  | ref(:non_member)              | nil   | nil  | nil   | true | false | nil  | 'SSO Enforced'
        ref(:root_group) | 'private' | true  | ref(:non_member)              | nil   | nil  | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:root_group) | 'private' | true  | ref(:non_member)              | nil   | nil  | nil   | nil  | nil   | true | 'SSO Not enforced'
        ref(:root_group) | 'private' | true  | ref(:not_signed_in_user)      | nil   | nil  | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:root_group) | 'private' | true  | ref(:deploy_token)            | nil   | nil  | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | true  | ref(:non_member)              | nil   | nil  | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'private' | true  | ref(:non_member)              | nil   | nil  | nil   | true | false | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'private' | true  | ref(:non_member)              | nil   | nil  | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | true  | ref(:non_member)              | nil   | nil  | nil   | nil  | nil   | true | 'SSO Not enforced'
        ref(:subgroup)   | 'private' | true  | ref(:not_signed_in_user)      | nil   | nil  | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'private' | true  | ref(:deploy_token)            | nil   | nil  | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:project)    | 'private' | true  | ref(:non_member)              | nil   | nil  | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:project)    | 'private' | true  | ref(:non_member)              | nil   | nil  | nil   | true | false | nil  | 'SSO Enforced'
        ref(:project)    | 'private' | true  | ref(:non_member)              | nil   | nil  | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:project)    | 'private' | true  | ref(:non_member)              | nil   | nil  | nil   | nil  | nil   | true | 'SSO Not enforced'
        ref(:project)    | 'private' | true  | ref(:not_signed_in_user)      | nil   | nil  | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:project)    | 'private' | true  | ref(:deploy_token)            | nil   | nil  | nil   | nil  | nil   | nil  | 'SSO Not enforced'

        # Project/Group visibility: Public; Enforce SSO setting: Off

        ref(:root_group) | 'public'  | false | ref(:member_with_identity)    | false | nil   | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:root_group) | 'public'  | false | ref(:member_with_identity)    | true  | nil   | false | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:root_group) | 'public'  | false | ref(:member_with_identity)    | true  | true  | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:root_group) | 'public'  | false | ref(:member_with_identity)    | false | nil   | true  | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:root_group) | 'public'  | false | ref(:member_with_identity)    | false | nil   | false | true | false | nil  | 'SSO Enforced'
        ref(:root_group) | 'public'  | false | ref(:member_with_identity)    | false | nil   | false | true | true  | nil  | 'SSO Not enforced'
        ref(:root_group) | 'public'  | false | ref(:member_with_identity)    | false | nil   | false | nil  | nil   | true | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | false | ref(:member_with_identity)    | false | nil   | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'public'  | false | ref(:member_with_identity)    | true  | nil   | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'public'  | false | ref(:member_with_identity)    | false | nil   | true  | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | false | ref(:member_with_identity)    | false | nil   | false | true | false | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'public'  | false | ref(:member_with_identity)    | false | nil   | false | true | true  | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | false | ref(:member_with_identity)    | false | nil   | false | nil  | nil   | true | 'SSO Not enforced'
        ref(:project)    | 'public'  | false | ref(:member_with_identity)    | false | nil   | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:project)    | 'public'  | false | ref(:member_with_identity)    | true  | nil   | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:project)    | 'public'  | false | ref(:member_with_identity)    | false | nil   | true  | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:project)    | 'public'  | false | ref(:member_with_identity)    | false | nil   | false | true | false | nil  | 'SSO Enforced'
        ref(:project)    | 'public'  | false | ref(:member_with_identity)    | false | nil   | false | true | true  | nil  | 'SSO Not enforced'
        ref(:project)    | 'public'  | false | ref(:member_with_identity)    | false | nil   | false | nil  | nil   | true | 'SSO Not enforced'

        ref(:root_group) | 'public'  | false | ref(:member_without_identity) | false | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | false | ref(:member_without_identity) | false | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:project)    | 'public'  | false | ref(:member_without_identity) | false | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'

        ref(:root_group) | 'public'  | false | ref(:non_member)              | nil   | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:root_group) | 'public'  | false | ref(:not_signed_in_user)      | nil   | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:root_group) | 'public'  | false | ref(:deploy_token)            | nil   | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | false | ref(:non_member)              | nil   | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | false | ref(:not_signed_in_user)      | nil   | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | false | ref(:deploy_token)            | nil   | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:project)    | 'public'  | false | ref(:non_member)              | nil   | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:project)    | 'public'  | false | ref(:not_signed_in_user)      | nil   | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:project)    | 'public'  | false | ref(:deploy_token)            | nil   | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'

        # Project/Group visibility: Public; Enforce SSO setting: On

        ref(:root_group) | 'public'  | true  | ref(:member_with_identity)    | false | nil   | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_with_identity)    | true  | nil   | false | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_with_identity)    | true  | true  | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_with_identity)    | false | nil   | true  | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_with_identity)    | false | nil   | false | true | false | nil  | 'SSO Enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_with_identity)    | false | nil   | false | true | true  | nil  | 'SSO Not enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_with_identity)    | false | nil   | false | nil  | nil   | true | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_with_identity)    | false | nil   | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_with_identity)    | true  | nil   | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_with_identity)    | false | nil   | true  | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_with_identity)    | false | nil   | false | true | false | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_with_identity)    | false | nil   | false | true | true  | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_with_identity)    | false | nil   | false | nil  | nil   | true | 'SSO Not enforced'
        ref(:project)    | 'public'  | true  | ref(:member_with_identity)    | false | nil   | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:project)    | 'public'  | true  | ref(:member_with_identity)    | true  | nil   | false | nil  | nil   | nil  | 'SSO Enforced'
        ref(:project)    | 'public'  | true  | ref(:member_with_identity)    | false | nil   | true  | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:project)    | 'public'  | true  | ref(:member_with_identity)    | false | nil   | false | true | false | nil  | 'SSO Enforced'
        ref(:project)    | 'public'  | true  | ref(:member_with_identity)    | false | nil   | false | true | true  | nil  | 'SSO Not enforced'
        ref(:project)    | 'public'  | true  | ref(:member_with_identity)    | false | nil   | false | nil  | nil   | true | 'SSO Not enforced'

        ref(:root_group) | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_without_identity) | true  | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_without_identity) | true  | true  | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil   | true | false | nil  | 'SSO Enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil   | nil  | nil   | true | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_without_identity) | true  | nil   | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil   | true | false | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil   | nil  | nil   | true | 'SSO Not enforced'
        ref(:project)    | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:project)    | 'public'  | true  | ref(:member_without_identity) | true  | nil   | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:project)    | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil   | true | false | nil  | 'SSO Enforced'
        ref(:project)    | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:project)    | 'public'  | true  | ref(:member_without_identity) | false | nil   | nil   | nil  | nil   | true | 'SSO Not enforced'

        ref(:root_group) | 'public'  | true  | ref(:member_shared) | false | nil   | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_shared) | false | nil   | nil   | true | false | nil  | 'SSO Enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_shared) | false | nil   | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_shared) | false | nil   | nil   | nil  | nil   | true | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_shared) | false | nil   | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_shared) | false | nil   | nil   | true | false | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_shared) | false | nil   | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_shared) | false | nil   | nil   | nil  | nil   | true | 'SSO Not enforced'
        ref(:project)    | 'public'  | true  | ref(:member_shared) | false | nil   | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:project)    | 'public'  | true  | ref(:member_shared) | false | nil   | nil   | true | false | nil  | 'SSO Enforced'
        ref(:project)    | 'public'  | true  | ref(:member_shared) | false | nil   | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:project)    | 'public'  | true  | ref(:member_shared) | false | nil   | nil   | nil  | nil   | true | 'SSO Not enforced'

        ref(:root_group) | 'public'  | true  | ref(:member_project) | false | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_project) | false | nil   | nil   | true | false | nil  | 'SSO Not enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_project) | false | nil   | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_project) | false | nil   | nil   | nil  | nil   | true | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_project) | false | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_project) | false | nil   | nil   | true | false | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_project) | false | nil   | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_project) | false | nil   | nil   | nil  | nil   | true | 'SSO Not enforced'
        ref(:project)    | 'public'  | true  | ref(:member_project) | false | nil   | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:project)    | 'public'  | true  | ref(:member_project) | false | nil   | nil   | true | false | nil  | 'SSO Enforced'
        ref(:project)    | 'public'  | true  | ref(:member_project) | false | nil   | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:project)    | 'public'  | true  | ref(:member_project) | false | nil   | nil   | nil  | nil   | true | 'SSO Not enforced'

        ref(:root_group) | 'public'  | true  | ref(:member_subgroup) | false | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_subgroup) | false | nil   | nil   | true | false | nil  | 'SSO Not enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_subgroup) | false | nil   | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:root_group) | 'public'  | true  | ref(:member_subgroup) | false | nil   | nil   | nil  | nil   | true | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_subgroup) | false | nil   | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_subgroup) | false | nil   | nil   | true | false | nil  | 'SSO Enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_subgroup) | false | nil   | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:member_subgroup) | false | nil   | nil   | nil  | nil   | true | 'SSO Not enforced'
        ref(:project)    | 'public'  | true  | ref(:member_subgroup) | false | nil   | nil   | nil  | nil   | nil  | 'SSO Enforced'
        ref(:project)    | 'public'  | true  | ref(:member_subgroup) | false | nil   | nil   | true | false | nil  | 'SSO Enforced'
        ref(:project)    | 'public'  | true  | ref(:member_subgroup) | false | nil   | nil   | true | true  | nil  | 'SSO Not enforced'
        ref(:project)    | 'public'  | true  | ref(:member_subgroup) | false | nil   | nil   | nil  | nil   | true | 'SSO Not enforced'

        ref(:root_group) | 'public'  | true  | ref(:non_member)              | nil   | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:root_group) | 'public'  | true  | ref(:not_signed_in_user)      | nil   | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:root_group) | 'public'  | true  | ref(:deploy_token)            | nil   | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:non_member)              | nil   | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:not_signed_in_user)      | nil   | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:subgroup)   | 'public'  | true  | ref(:deploy_token)            | nil   | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:project)    | 'public'  | true  | ref(:non_member)              | nil   | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:project)    | 'public'  | true  | ref(:not_signed_in_user)      | nil   | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
        ref(:project)    | 'public'  | true  | ref(:deploy_token)            | nil   | nil   | nil   | nil  | nil   | nil  | 'SSO Not enforced'
      end

      with_them do
        context "when 'Enforce SSO-only authentication for web activity for this group' option is #{params[:enforced_sso?] ? 'enabled' : 'not enabled'}" do
          around do |example|
            session = {}

            session['warden.user.user.key'] = [[user.id], user.authenticatable_salt] if user.is_a?(User)

            # Deploy Tokens are considered sessionless
            session = nil if user.is_a?(DeployToken)

            Gitlab::Session.with_session(session) do
              example.run
            end
          end

          before do
            saml_provider.update!(enforced_sso: enforced_sso?)
          end

          context "when resource is #{params[:resource_visibility_level]}" do
            before do
              if resource.is_a?(Group) && resource_visibility_level == 'private'
                resource.descendants.update_all(visibility_level: Gitlab::VisibilityLevel.string_options[resource_visibility_level])
              end

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

              include_examples params[:shared_examples]
            end
          end
        end
      end

      context 'when in context of another user web activity' do
        let(:user) { create(:user) }
        let(:another_user) { create(:user) }

        before do
          saml_provider.update!(enforced_sso: true)
          project.update!(visibility_level: Gitlab::VisibilityLevel.string_options['private'])
        end

        around do |example|
          session = {}

          session['warden.user.user.key'] = [[another_user.id], another_user.authenticatable_salt]

          Gitlab::Session.with_session(session) do
            example.run
          end
        end

        it 'only applies to current_user', :aggregate_failures do
          expect(described_class.access_restricted?(user: another_user, resource: project)).to be(true)
          expect(described_class.access_restricted?(user: user, resource: project)).to be(false)
        end
      end
    end
  end

  describe '.access_restricted_groups' do
    let_it_be(:restricted_group) { create(:group, saml_provider: create(:saml_provider, enabled: true, enforced_sso: true)) }
    let_it_be(:restricted_subgroup) { create(:group, parent: restricted_group) }
    let_it_be(:restricted_group2) do
      create(:group, saml_provider: create(:saml_provider, enabled: true, enforced_sso: true))
    end

    let_it_be(:unrestricted_group) { create(:group) }
    let_it_be(:unrestricted_subgroup) { create(:group, parent: unrestricted_group) }
    let(:groups) { [restricted_subgroup, restricted_group2, unrestricted_group, unrestricted_subgroup] }

    it 'handles empty groups array' do
      expect(described_class.access_restricted_groups([])).to eq([])
    end

    it 'returns a list of SSO enforced root groups' do
      expect(described_class.access_restricted_groups(groups))
        .to match_array([restricted_group, restricted_group2])
    end

    it 'returns only unique root groups' do
      expect(described_class.access_restricted_groups(groups.push(restricted_group)))
        .to match_array([restricted_group, restricted_group2])
    end

    it 'avoids N+1 queries' do
      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        described_class.access_restricted_groups([restricted_group])
      end

      expect { described_class.access_restricted_groups(groups) }.not_to exceed_all_query_limit(control)
    end
  end

  describe '.sessions_time_remaining_for_expiry' do
    subject(:sessions_time_remaining_for_expiry) { described_class.sessions_time_remaining_for_expiry }

    it 'returns data for existing sessions' do
      freeze_time do
        described_class.new(saml_provider).update_session

        expect(sessions_time_remaining_for_expiry).to match_array(
          [
            {
              provider_id: saml_provider.id,
              time_remaining: described_class::DEFAULT_SESSION_TIMEOUT.to_f
            }
          ]
        )
      end
    end

    it 'returns empty array when no session data exists' do
      expect(sessions_time_remaining_for_expiry).to eq([])
    end

    it 'returns calculated data when sessions have been around for some time' do
      other_saml_provider = build_stubbed(:saml_provider)
      frozen_time = Time.utc(2024, 2, 2, 1, 44)

      travel_to(frozen_time) do
        described_class.new(saml_provider).update_session
      end

      travel_to(frozen_time + 4.hours) do
        described_class.new(other_saml_provider).update_session
      end

      travel_to(frozen_time + 6.hours) do
        expect(sessions_time_remaining_for_expiry).to match_array(
          [
            {
              provider_id: saml_provider.id,
              time_remaining: 18.hours.to_f
            },
            {
              provider_id: other_saml_provider.id,
              time_remaining: 22.hours.to_f
            }
          ]
        )
      end
    end

    context 'when session_not_on_or_after is specified' do
      it 'returns data for existing session based on session_not_on_or_after value' do
        freeze_time do
          session_not_on_or_after = (Time.zone.now + 4.hours).to_s
          described_class.new(saml_provider).update_session(session_not_on_or_after: session_not_on_or_after)

          expect(sessions_time_remaining_for_expiry).to match_array(
            [
              {
                provider_id: saml_provider.id,
                time_remaining: 4.hours.to_f
              }
            ]
          )
        end
      end

      it 'returns calculated time remaining on expiry based on session_not_on_or_after value' do
        other_saml_provider = build_stubbed(:saml_provider)
        frozen_time = Time.utc(2024, 2, 2, 1, 44)
        session_not_on_or_after_value = Time.zone.parse((frozen_time + 10.hours).to_s)
        other_session_not_on_or_after_value = Time.zone.parse((frozen_time + 15.hours).to_s)

        travel_to(frozen_time) do
          described_class.new(saml_provider).update_session(session_not_on_or_after: session_not_on_or_after_value)
        end

        travel_to(frozen_time + 4.hours) do
          described_class.new(other_saml_provider).update_session(session_not_on_or_after: other_session_not_on_or_after_value)
        end

        travel_to(frozen_time + 6.hours) do
          expect(sessions_time_remaining_for_expiry).to match_array(
            [
              {
                provider_id: saml_provider.id,
                time_remaining: 4.hours.to_f
              },
              {
                provider_id: other_saml_provider.id,
                time_remaining: 9.hours.to_f
              }
            ]
          )
        end
      end

      it 'overrides default timeout when session_not_on_or_after is specified' do
        frozen_time = Time.utc(2024, 2, 2, 1, 44)
        session_not_on_or_after_value = Time.zone.parse((frozen_time + 2.days).to_s)
        time_remaining_for_expiry_default_timeout = session_not_on_or_after_value - (frozen_time + 4.hours)

        travel_to(frozen_time) do
          described_class.new(saml_provider).update_session(session_not_on_or_after: session_not_on_or_after_value)
        end

        travel_to(frozen_time + 4.hours) do
          expect(sessions_time_remaining_for_expiry).to match_array(
            [
              {
                provider_id: saml_provider.id,
                time_remaining: time_remaining_for_expiry_default_timeout.to_f
              }
            ]
          )
        end
      end
    end
  end
end
