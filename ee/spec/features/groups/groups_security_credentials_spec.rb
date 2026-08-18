# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups::Security::Credentials', :saas, feature_category: :user_management do
  include Features::ResponsiveTableHelpers

  let_it_be(:group) { create(:group, :private) }

  let(:group_id) { group.to_param }

  context 'licensed' do
    before do
      allow_next_instance_of(Gitlab::Auth::GroupSaml::SsoEnforcer) do |sso_enforcer|
        allow(sso_enforcer).to receive(:active_session?).and_return(true)
      end

      stub_licensed_features(credentials_inventory: true, group_saml: true)
    end

    context 'when there are no enterprise users' do
      let_it_be(:user) { create(:user) }

      before do
        group.add_owner(user)
        sign_in(user)
      end

      it 'displays no PAT credentials' do
        visit group_security_credentials_path(group_id: group_id)

        expect(page).to have_content('No credentials found')
      end

      it 'displays no SSH Key credentials' do
        visit group_security_credentials_path(group_id: group_id, filter: 'ssh_keys')

        expect(page).to have_content('No credentials found')
      end

      it 'displays no resource access tokens credentials' do
        visit group_security_credentials_path(group_id: group_id, filter: 'resource_access_tokens')

        expect(page).to have_content('No credentials found')
      end
    end

    context 'when there are enterprise users' do
      let_it_be(:enterprise_user) { create(:enterprise_user, enterprise_group: group, name: 'abc') }

      before do
        group.add_owner(enterprise_user)
        sign_in(enterprise_user)
      end

      context 'links', :js do
        before do
          visit group_security_credentials_path(group_id: group_id)
        end

        it 'has Credentials Inventory link in sidebar' do
          within_testid('super-sidebar') do
            expect(page).to have_link('Credentials', href: group_security_credentials_path(group_id: group_id))
          end
        end

        context 'tabs' do
          it 'contains the relevant filter tabs' do
            expect(page).to have_link('Personal access tokens', href: group_security_credentials_path(group_id: group_id, filter: 'personal_access_tokens'))
            expect(page).to have_link('SSH keys', href: group_security_credentials_path(group_id: group_id, filter: 'ssh_keys'))
            expect(page).to have_link('Project and group access tokens', href: group_security_credentials_path(group_id: group_id, filter: 'resource_access_tokens'))
            expect(page).not_to have_link('GPG keys', href: group_security_credentials_path(group_id: group_id, filter: 'gpg_keys'))
          end
        end
      end

      context 'filtering' do
        context 'by personal access tokens' do
          let(:credentials_path) { group_security_credentials_path(group_id: group_id, filter: 'personal_access_tokens') }

          it_behaves_like 'credentials inventory personal access tokens'
        end

        context 'by SSH keys' do
          let(:credentials_path) { group_security_credentials_path(group_id: group_id, filter: 'ssh_keys') }

          it_behaves_like 'credentials inventory SSH keys'
        end

        context 'by GPG keys' do
          before do
            visit group_security_credentials_path(group_id: group_id, filter: 'gpg_keys')
          end

          it 'returns a 404 not found response' do
            expect(page.status_code).to eq(404)
          end
        end

        context 'by resource access tokens', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/507348' do
          let(:credentials_path) do
            group_security_credentials_path(group_id: group_id, filter: 'resource_access_tokens')
          end

          it_behaves_like 'credentials inventory resource access tokens'
        end
      end
    end
  end

  context 'unlicensed' do
    let_it_be(:enterprise_user) { create(:enterprise_user, enterprise_group: group, name: 'abc') }

    before do
      group.add_owner(enterprise_user)
      sign_in(enterprise_user)

      stub_licensed_features(credentials_inventory: false)
    end

    it 'returns 400' do
      visit group_security_credentials_path(group_id: group_id)

      expect(page.status_code).to eq(404)
    end
  end
end
