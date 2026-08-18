# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Password and authentication', feature_category: :system_access do
  include Spec::Support::Helpers::ModalHelpers

  let(:user) { create(:user, :with_namespace) }

  before do
    sign_in(user)
  end

  describe "Disconnect Group SAML", :js do
    let_it_be(:group) { create(:group, :private, name: 'Test Group') }
    let_it_be_with_reload(:saml_provider) { create(:saml_provider, group: group) }
    let_it_be(:unlink_label) { "SAML for Test Group" }

    def enable_group_saml
      stub_licensed_features(group_saml: true)
      allow(Devise).to receive(:omniauth_providers).and_return(%i[group_saml])
    end

    def create_linked_identity
      oauth = OmniAuth::AuthHash.new(
        provider: 'group_saml',
        uid: '1',
        info: { email: user.email },
        extra: {
          raw_info: OneLogin::RubySaml::Attributes.new({})
        }
      )
      identity_linker = Gitlab::Auth::GroupSaml::IdentityLinker.new(user, oauth, instance_double(Hash), saml_provider)
      allow(identity_linker).to receive(:valid_gitlab_initiated_request?).and_return(true)
      identity_linker.link
    end

    def expect_disconnect
      expect(page).to have_content unlink_label

      click_link "Disconnect SAML for Test Group"

      within_modal do
        modal_message = s_('Profiles|Disconnecting your SAML provider will remove your access from groups, ' \
          'subgroups and projects which require SAML authentication. Are you sure?')
        expect(page).to have_content(modal_message)
        click_button "Disconnect SAML for Test Group"
      end

      expect(page).to have_current_path profile_two_factor_auth_path, ignore_query: true
      expect(page).not_to have_content(unlink_label)
    end

    before do
      enable_group_saml
      create_linked_identity
    end

    it 'unlinks account' do
      visit profile_two_factor_auth_path

      expect_disconnect
    end

    it 'removes access to the group' do
      visit profile_two_factor_auth_path

      expect_disconnect

      visit group_path(group)
      expect(page).to have_content('Page not found')
    end

    context 'when group has disabled SAML' do
      before do
        saml_provider.update!(enabled: false)
      end

      it 'lets members distrust and unlink authentication' do
        visit profile_two_factor_auth_path

        expect_disconnect
      end
    end

    context 'when group trial has expired' do
      before do
        stub_licensed_features(group_saml: false)
      end

      it 'lets members distrust and unlink authentication' do
        visit profile_two_factor_auth_path

        expect_disconnect
      end
    end
  end
end
