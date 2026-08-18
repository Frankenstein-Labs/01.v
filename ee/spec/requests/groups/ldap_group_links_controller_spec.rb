# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::LdapGroupLinksController, feature_category: :user_management do
  let_it_be(:owner) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:group) { create(:group, owners: owner, maintainers: maintainer) }

  before do
    allow(Gitlab.config.ldap).to receive(:enabled).and_return(true)
  end

  shared_examples 'returns 404' do
    it 'returns 404' do
      make_request

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'GET #index' do
    subject(:make_request) { get group_ldap_group_links_path(group) }

    context 'when signed in as owner' do
      before do
        sign_in(owner)
      end

      it 'returns 200' do
        make_request

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when allow_group_owners_to_manage_ldap is disabled' do
        before do
          stub_ee_application_setting(allow_group_owners_to_manage_ldap: false)
        end

        it_behaves_like 'returns 404'
      end
    end

    context 'when signed in as maintainer' do
      before do
        sign_in(maintainer)
      end

      it_behaves_like 'returns 404'
    end

    context 'with an anonymous user' do
      it_behaves_like 'returns 404'
    end
  end

  describe 'POST #create' do
    let(:ldap_group_link_params) do
      { ldap_group_link: { cn: 'my-group', group_access: Gitlab::Access::DEVELOPER, provider: 'ldapmain' } }
    end

    subject(:make_request) { post group_ldap_group_links_path(group), params: ldap_group_link_params }

    context 'when signed in as owner' do
      before do
        sign_in(owner)
      end

      it 'creates the LDAP group link' do
        expect { make_request }.to change { group.ldap_group_links.count }.by(1)
      end

      context 'when allow_group_owners_to_manage_ldap is disabled' do
        before do
          stub_ee_application_setting(allow_group_owners_to_manage_ldap: false)
        end

        it_behaves_like 'returns 404'

        it 'does not create the LDAP group link' do
          expect { make_request }.not_to change { group.ldap_group_links.count }
        end
      end
    end

    context 'when signed in as maintainer' do
      before do
        sign_in(maintainer)
      end

      it_behaves_like 'returns 404'

      it 'does not create the LDAP group link' do
        expect { make_request }.not_to change { group.ldap_group_links.count }
      end
    end
  end

  describe 'DELETE #destroy' do
    let_it_be(:ldap_group_link) { create(:ldap_group_link, group: group) }

    subject(:make_request) { delete group_ldap_group_link_path(group, ldap_group_link) }

    context 'when signed in as owner' do
      before do
        sign_in(owner)
      end

      it 'destroys the LDAP group link' do
        expect { make_request }.to change { group.ldap_group_links.count }.by(-1)
      end

      context 'when it was the last link for that provider' do
        let_it_be(:member_user) { create(:user) }
        let_it_be_with_reload(:orphaned_member) do
          create(:group_member, :developer, group: group, user: member_user, ldap: true)
        end

        let_it_be(:identity) { create(:identity, user: member_user, provider: 'ldapmain') }

        it 'resets the ldap flag for members orphaned by the removal' do
          expect { make_request }.to change { orphaned_member.reload.ldap? }.from(true).to(false)
        end
      end

      context 'when other links remain for that provider' do
        let_it_be(:other_ldap_group_link) { create(:ldap_group_link, group: group, cn: 'other-group') }
        let_it_be(:member_user) { create(:user) }
        let_it_be_with_reload(:remaining_member) do
          create(:group_member, :developer, group: group, user: member_user, ldap: true)
        end

        let_it_be(:identity) { create(:identity, user: member_user, provider: 'ldapmain') }

        it 'does not reset the ldap flag' do
          expect { make_request }.not_to change { remaining_member.reload.ldap? }
        end
      end

      context 'when the link has no provider column value set' do
        let_it_be(:null_provider_group) { create(:group, owners: owner) }
        let_it_be(:null_provider_link) { create(:ldap_group_link, group: null_provider_group, provider: nil) }
        let_it_be(:member_user) { create(:user) }
        let_it_be_with_reload(:orphaned_member) do
          create(:group_member, :developer, group: null_provider_group, user: member_user, ldap: true)
        end

        let_it_be(:identity) { create(:identity, user: member_user, provider: 'ldapmain') }

        subject(:make_request) { delete group_ldap_group_link_path(null_provider_group, null_provider_link) }

        it 'resets the ldap flag using the fallback provider' do
          expect { make_request }.to change { orphaned_member.reload.ldap? }.from(true).to(false)
        end
      end

      context 'when allow_group_owners_to_manage_ldap is disabled' do
        before do
          stub_ee_application_setting(allow_group_owners_to_manage_ldap: false)
        end

        it_behaves_like 'returns 404'

        it 'does not destroy the LDAP group link' do
          expect { make_request }.not_to change { group.ldap_group_links.count }
        end
      end
    end

    context 'when signed in as maintainer' do
      before do
        sign_in(maintainer)
      end

      it_behaves_like 'returns 404'

      it 'does not destroy the LDAP group link' do
        expect { make_request }.not_to change { group.ldap_group_links.count }
      end
    end
  end
end
