# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::AuthHelper, feature_category: :system_access do
  include LoginHelpers
  include EE::RegistrationsHelper

  describe "button_based_providers" do
    it 'excludes group_saml' do
      allow(helper).to receive(:auth_providers).and_return([:group_saml])
      expect(helper.button_based_providers).to eq([])
    end
  end

  describe "providers_for_base_controller" do
    it 'excludes group_saml' do
      allow(helper).to receive(:auth_providers).and_return([:group_saml])
      expect(helper.providers_for_base_controller).to eq([])
    end
  end

  describe 'form_based_auth_provider_has_active_class?' do
    it 'selects main LDAP server' do
      allow(helper).to receive(:auth_providers).and_return([:twitter, :ldapprimary, :ldapsecondary])
      expect(helper.form_based_auth_provider_has_active_class?(:twitter)).to be(false)
      expect(helper.form_based_auth_provider_has_active_class?(:ldapprimary)).to be(true)
      expect(helper.form_based_auth_provider_has_active_class?(:ldapsecondary)).to be(false)
    end
  end

  describe "form_based_providers" do
    context 'with smartcard_auth feature flag off' do
      before do
        stub_licensed_features(smartcard_auth: false)
        allow(helper).to receive(:smartcard_enabled?).and_call_original
      end

      it 'does not include smartcard provider' do
        allow(helper).to receive(:auth_providers).and_return([:twitter, :smartcard])
        expect(helper.form_based_providers).to be_empty
      end
    end

    context 'with smartcard_auth feature flag on' do
      before do
        stub_licensed_features(smartcard_auth: true)
        allow(helper).to receive(:smartcard_enabled?).and_return(true)
      end

      it 'includes smartcard provider' do
        allow(helper).to receive(:auth_providers).and_return([:twitter, :smartcard])
        expect(helper.form_based_providers).to eq %i[smartcard]
      end
    end
  end

  describe 'smartcard_enabled_for_ldap?' do
    let(:provider_name) { 'ldapmain' }
    let(:ldap_server_config) do
      {
        'provider_name' => provider_name,
        'attributes' => {},
        'encryption' => 'plain',
        'smartcard_auth' => smartcard_auth_status,
        'uid' => 'uid',
        'base' => 'dc=example,dc=com'
      }
    end

    before do
      allow(::Gitlab::Auth::Smartcard).to receive(:enabled?).and_return(true)
      allow(::Gitlab::Auth::Ldap::Config).to receive(:servers).and_return([ldap_server_config])
    end

    context 'LDAP server with optional smartcard auth' do
      let(:smartcard_auth_status) { 'optional' }

      it 'returns true' do
        expect(smartcard_enabled_for_ldap?(provider_name, required: false)).to be(true)
      end

      it 'returns false with required flag' do
        expect(smartcard_enabled_for_ldap?(provider_name, required: true)).to be(false)
      end
    end

    context 'LDAP server with required smartcard auth' do
      let(:smartcard_auth_status) { 'required' }

      it 'returns true' do
        expect(smartcard_enabled_for_ldap?(provider_name, required: false)).to be(true)
      end

      it 'returns true with required flag' do
        expect(smartcard_enabled_for_ldap?(provider_name, required: true)).to be(true)
      end
    end

    context 'LDAP server with disabled smartcard auth' do
      let(:smartcard_auth_status) { false }

      it 'returns false' do
        expect(smartcard_enabled_for_ldap?(provider_name, required: false)).to be(false)
      end

      it 'returns false with required flag' do
        expect(smartcard_enabled_for_ldap?(provider_name, required: true)).to be(false)
      end
    end

    context 'no matching LDAP server' do
      let(:smartcard_auth_status) { 'optional' }

      it 'returns false' do
        expect(smartcard_enabled_for_ldap?('nonexistent')).to be(false)
      end
    end
  end

  describe 'smartcard_login_button_category' do
    let(:provider_name) { 'ldapmain' }
    let(:ldap_server_config) do
      {
        'provider_name' => provider_name,
        'attributes' => {},
        'encryption' => 'plain',
        'smartcard_auth' => smartcard_auth_status,
        'uid' => 'uid',
        'base' => 'dc=example,dc=com'
      }
    end

    subject { smartcard_login_button_category(provider_name) }

    before do
      allow(::Gitlab::Auth::Smartcard).to receive(:enabled?).and_return(true)
      allow(::Gitlab::Auth::Ldap::Config).to receive(:servers).and_return([ldap_server_config])
    end

    context 'when smartcard auth is optional' do
      let(:smartcard_auth_status) { 'optional' }

      it 'returns the correct button category' do
        expect(subject).to eq(:secondary)
      end
    end

    context 'when smartcard auth is required' do
      let(:smartcard_auth_status) { 'required' }

      it 'returns the correct button category' do
        expect(subject).to eq(:primary)
      end
    end
  end

  describe '#password_rule_list' do
    context 'when password complexity feature is not available' do
      it 'returns nil' do
        expect(password_rule_list(true)).to be_nil
      end
    end

    context 'when password complexity feature is available' do
      before do
        stub_licensed_features(password_complexity: true)
      end

      context 'without any rules' do
        it 'returns an empty array' do
          expect(password_rule_list(false)).to be_empty
        end
      end

      context 'with one rule' do
        before do
          stub_application_setting(password_number_required: true)
        end

        it 'returns only one rule' do
          expect(password_rule_list(false)).to match_array([:number])
        end
      end

      context 'with basic rules' do
        it 'returns basic list' do
          expect(password_rule_list(true)).to match_array([:length, :common, :user_info])
        end
      end

      context 'with all rules' do
        before do
          stub_application_setting(password_number_required: true)
          stub_application_setting(password_symbol_required: true)
          stub_application_setting(password_lowercase_required: true)
          stub_application_setting(password_uppercase_required: true)
        end

        it 'returns all rules' do
          expect(password_rule_list(true))
            .to match_array([:length, :common, :user_info, :number, :symbol, :lowercase, :uppercase])
        end
      end
    end
  end

  describe '#google_tag_manager_enabled?' do
    let(:is_gitlab_com) { true }
    let(:user) { nil }

    before do
      allow(Gitlab).to receive(:com?).and_return(is_gitlab_com)
      allow(helper).to receive(:current_user).and_return(user)
      stub_config(extra: { 'google_tag_manager_nonce_id' => 'key' })
    end

    subject(:google_tag_manager_enabled) { helper.google_tag_manager_enabled? }

    context 'when not on gitlab.com' do
      let(:is_gitlab_com) { false }

      it { is_expected.to be(false) }
    end

    context 'on gitlab.com and a key set without a current user' do
      it { is_expected.to be_truthy }
    end

    context 'when no key is set' do
      before do
        stub_config(extra: {})
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#google_tag_manager_id' do
    subject(:google_tag_manager_id) { helper.google_tag_manager_id }

    before do
      stub_config(extra: { google_tag_manager_nonce_id: 'nonce', google_tag_manager_id: 'gtm' })
    end

    context 'when google tag manager is disabled' do
      before do
        allow(helper).to receive(:google_tag_manager_enabled?).and_return(false)
      end

      it { is_expected.to be_falsey }
    end

    context 'when google tag manager is enabled' do
      before do
        allow(helper).to receive(:google_tag_manager_enabled?).and_return(true)
      end

      it { is_expected.to eq('nonce') }
    end
  end

  describe '#saml_group_sync_enabled?' do
    subject { helper.saml_group_sync_enabled? }

    let(:groups_enabled_saml_provider) do
      {
        name: 'saml',
        groups_attribute: 'groups',
        external_groups: ['ExternGroups'],
        args: {}
      }
    end

    let(:groups_disabled_saml_provider) do
      {
        name: 'saml',
        groups_attribute: nil,
        external_groups: ['ExternGroups'],
        args: {}
      }
    end

    let(:group_saml_provider) { Hash[name: 'group_saml'] }

    before do
      stub_licensed_features(saml_group_sync: true)
      stub_omniauth_config(providers: [current_provider])
      allow(Devise).to receive(:omniauth_providers).and_return([current_provider[:name].to_sym])
    end

    context 'when enabled' do
      let(:current_provider) { groups_enabled_saml_provider }

      it { is_expected.to be(true) }
    end

    context 'when enabled for group_saml provider' do
      let(:current_provider) { group_saml_provider }

      it { is_expected.to be(true) }
    end

    context 'when not enabled' do
      let(:current_provider) { groups_disabled_saml_provider }

      it { is_expected.to be(false) }
    end

    context 'when saml_group_sync feature is not enabled' do
      let(:current_provider) { groups_enabled_saml_provider }

      before do
        stub_licensed_features(saml_group_sync: false)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#admin_service_accounts_data' do
    before do
      allow(helper).to receive_messages(
        expires_at_field_data: { max_date: '2022-03-02',
                                 min_date: '2022-03-02' }
      )
    end

    it 'returns data for the service accounts UI' do
      expect(helper.admin_service_accounts_data('dummy_user')).to match(a_hash_including({
        base_path: '/admin/application_settings/service_accounts',
        service_accounts: {
          enabled: 'true',
          path: '/api/v4/service_accounts',
          edit_path: '/api/v4/service_accounts',
          delete_path: '/api/v4/users',
          docs_path: '/help/user/profile/service_accounts.md'
        },
        access_token: {
          max_date: '2022-03-02',
          min_date: '2022-03-02',
          available_scopes: '[]',
          create: '/api/v4/users/:id/personal_access_tokens',
          revoke: '/api/v4/personal_access_tokens',
          rotate: '/api/v4/personal_access_tokens',
          show: '/api/v4/personal_access_tokens?user_id=:id'
        }
      }))
    end
  end

  describe '#groups_service_accounts_data', :freeze_time do
    let(:settings) { build(:namespace_settings, service_access_tokens_expiration_enforced: false) }
    let(:group) do
      build_stubbed(:group, path: 'my-group-path', id: 4, namespace_settings: settings)
    end

    context 'when user can create service accounts' do
      before do
        allow(helper).to receive(:can?).with('dummy_user', :create_service_account, group).and_return(true)
      end

      it 'returns data for the service accounts UI with enabled as true' do
        expect(helper.groups_service_accounts_data(group, 'dummy_user')).to match(a_hash_including({
          base_path: '/groups/my-group-path/-/settings/service_accounts',
          service_accounts: {
            enabled: 'true',
            path: '/api/v4/groups/4/service_accounts',
            edit_path: '/api/v4/groups/4/service_accounts',
            delete_path: '/api/v4/groups/4/service_accounts',
            docs_path: '/help/user/profile/service_accounts.md'
          },
          access_token: {
            min_date: 1.day.from_now.iso8601,
            available_scopes: '[]',
            create: '/api/v4/groups/4/service_accounts/:id/personal_access_tokens',
            revoke: '/api/v4/groups/4/service_accounts/:id/personal_access_tokens',
            rotate: '/api/v4/groups/4/service_accounts/:id/personal_access_tokens',
            show: '/api/v4/groups/4/service_accounts/:id/personal_access_tokens'
          }
        }))
      end
    end

    context 'when user cannot create service accounts' do
      before do
        allow(helper).to receive(:can?).with('dummy_user', :create_service_account, group).and_return(false)
      end

      it 'returns data for the service accounts UI with enabled as false' do
        result = helper.groups_service_accounts_data(group, 'dummy_user')
        expect(result[:service_accounts][:enabled]).to eq('false')
      end
    end
  end

  describe '#projects_service_accounts_data', :freeze_time do
    let_it_be(:settings, freeze: false) { build(:namespace_settings, service_access_tokens_expiration_enforced: false) }
    let_it_be(:group, freeze: false) { build_stubbed(:group, path: 'my-group-path', namespace_settings: settings) }
    let_it_be(:project) { build_stubbed(:project, path: 'my-project-path', id: 5, namespace: group) }
    let_it_be(:user) { build_stubbed(:user) }

    before do
      allow(project).to receive(:root_namespace).and_return(group)
      allow(helper).to receive(:current_user).and_return(user)
    end

    context 'when user can create service accounts' do
      before do
        allow(helper).to receive(:can?).with(anything, :create_service_account, project).and_return(true)
      end

      it 'returns data for the service accounts UI with enabled as true' do
        expect(helper.projects_service_accounts_data(project, 'dummy_user')).to match(a_hash_including({
          base_path: "/#{group.path}/#{project.path}/-/settings/service_accounts",
          service_accounts: {
            enabled: 'true',
            path: "/api/v4/projects/#{project.id}/service_accounts",
            edit_path: "/api/v4/projects/#{project.id}/service_accounts",
            delete_path: "/api/v4/projects/#{project.id}/service_accounts",
            docs_path: '/help/user/profile/service_accounts.md'
          },
          access_token: {
            min_date: 1.day.from_now.iso8601,
            available_scopes: '[]',
            create: "/api/v4/projects/#{project.id}/service_accounts/:id/personal_access_tokens",
            revoke: "/api/v4/projects/#{project.id}/service_accounts/:id/personal_access_tokens",
            rotate: "/api/v4/projects/#{project.id}/service_accounts/:id/personal_access_tokens",
            show: "/api/v4/projects/#{project.id}/service_accounts/:id/personal_access_tokens"
          }
        }))
      end
    end

    context 'when user cannot create service accounts' do
      before do
        allow(helper).to receive(:can?).with(anything, :create_service_account, project).and_return(false)
      end

      it 'returns data for the service accounts UI with enabled as false' do
        result = helper.projects_service_accounts_data(project, 'dummy_user')
        expect(result[:service_accounts][:enabled]).to eq('false')
      end
    end
  end

  describe 'service account token expiry helpers' do
    using RSpec::Parameterized::TableSyntax

    where(:enforced, :expected) do
      true  | true
      false | false
    end

    with_them do
      describe '#admin_sa_token_expiry_enforced?' do
        before do
          stub_application_setting(service_access_tokens_expiration_enforced: enforced)
        end

        it 'reads service_access_tokens_expiration_enforced from application settings' do
          expect(helper.admin_sa_token_expiry_enforced?).to eq(expected)
        end
      end

      describe '#group_sa_token_expiry_enforced?' do
        let(:settings) { build(:namespace_settings, service_access_tokens_expiration_enforced: enforced) }
        let(:group) { build_stubbed(:group, namespace_settings: settings) }

        it 'reads service_access_tokens_expiration_enforced from the group namespace settings' do
          expect(helper.group_sa_token_expiry_enforced?(group)).to eq(expected)
        end
      end

      describe '#project_sa_token_expiry_enforced?' do
        let(:settings) { build(:namespace_settings, service_access_tokens_expiration_enforced: enforced) }
        let(:root_namespace) { build_stubbed(:group, namespace_settings: settings) }
        let(:project) { build_stubbed(:project) }

        before do
          allow(project).to receive(:root_namespace).and_return(root_namespace)
        end

        it 'reads service_access_tokens_expiration_enforced from the project root namespace settings' do
          expect(helper.project_sa_token_expiry_enforced?(project)).to eq(expected)
        end
      end
    end
  end
end
