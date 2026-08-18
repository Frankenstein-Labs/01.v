# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Members > List members', feature_category: :groups_and_projects do
  include Features::MembersHelpers
  include Features::InviteMembersModalHelpers

  let_it_be(:user1) { create(:user, name: 'John Doe') }
  let_it_be(:user2) { create(:user, name: 'Mary Jane') }
  let_it_be(:user3) { create(:user, name: 'Wally West') }
  let_it_be(:group) { create(:group) }

  context 'with Group SAML identity linked for a user' do
    let_it_be(:saml_provider) { create(:saml_provider) }

    let(:group) { saml_provider.group }

    before do
      sign_in(user1)

      group.add_owner(user1)
      group.add_guest(user2)
      create(:identity, saml_provider: saml_provider, user: user2)

      group.add_guest(user3)
      create(:identity, saml_provider: saml_provider, user: user3)
    end

    it 'shows user with a SSO status badge', :js do
      visit group_group_members_path(group)

      expect(second_row).to have_content('SAML')
      expect(third_row).to have_content('SAML')
    end

    context 'when group is in a sub group' do
      let(:sub_group) { create(:group, parent: group) }

      before do
        # adding user2 as developer will make it a direct member to subgroup
        sub_group.add_developer(user2)
      end

      it 'shows user2 with a SSO status badge & a direct membership type', :js do
        visit group_group_members_path(sub_group)

        expect(second_row).to have_content('SAML').and have_content('Direct')
      end

      it 'shows user3 with a SSO status badge & an inherited membership type', :js do
        visit group_group_members_path(sub_group)

        expect(third_row).to have_content('SAML').and have_content('Inherited')
      end

      context 'when a project is in the subgroup' do
        let(:project) { create(:project, namespace: sub_group) }

        before do
          project.add_developer(user3)
        end

        it 'retains the SSO status badges & direct membership types from its group', :js do
          visit group_group_members_path(project.namespace)

          expect(second_row).to have_content('SAML').and have_content('Direct')
          expect(third_row).to have_content('SAML').and have_content('Inherited')
        end
      end
    end
  end

  context 'when user has a "Group Managed Account"' do
    let(:managed_group) { create(:group_with_managed_accounts) }
    let(:managed_user) { create(:user, :group_managed, managing_group: managed_group) }

    before do
      managed_group.add_guest(managed_user)
    end

    it 'shows user with "Managed Account" badge', :js do
      visit group_group_members_path(managed_group)

      expect(first_row).to have_content('Managed Account')
    end
  end

  context 'with SAML and enforced SSO' do
    let_it_be(:saml_provider) { create(:saml_provider, group: group, enabled: true, enforced_sso: true) }
    let_it_be(:user3) { create(:user, name: 'Amy with different SAML provider') }
    let_it_be(:user4) { create(:user, name: 'Bob without SAML') }
    let_it_be(:session) { { active_group_sso_sign_ins: { saml_provider.id => DateTime.now } } }

    before do
      stub_licensed_features(group_saml: true)
      allow(Gitlab::Session).to receive(:current).and_return(session)
      sign_in(user1)
    end

    before_all do
      create(:identity, provider: 'group_saml1', saml_provider_id: saml_provider.id, user: user1)
      create(:identity, provider: 'group_saml1', saml_provider_id: saml_provider.id, user: user2)
      create(:identity, user: user3)
      group.add_owner(user1)
    end

    it 'returns only users with SAML in autocomplete', :js do
      visit group_group_members_path(group)

      click_on 'Invite members'

      page.within invite_modal_selector do
        find(member_dropdown_selector).set(user1.name)

        expect(page).to have_content(user1.name)
        expect(page).not_to have_content(user3.name)
        expect(page).not_to have_content(user4.name)

        find(member_dropdown_selector).set(user2.name)

        expect(page).to have_content(user2.name)
        expect(page).not_to have_content(user3.name)
        expect(page).not_to have_content(user4.name)
      end
    end
  end

  context 'when over free user limit', :with_trial_types, :saas do
    let(:role) { :owner }
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group_with_plan, :private, plan: :free_plan) }

    subject(:visit_page) { visit group_group_members_path(group) }

    before do
      group.add_member(user, role)
      sign_in(user)
    end

    it_behaves_like 'over the free user limit alert'
  end

  context 'when user has a custom role', :js do
    let_it_be(:group) { create(:group) }
    let_it_be(:owner) { create(:user) }

    let_it_be(:group_member_role) { create(:member_role, :guest, namespace: group, name: 'guest plus') }
    let_it_be(:instance_member_role) { create(:member_role, :guest, :instance, name: 'guest plus (instance-level)') }

    before_all do
      create(:group_member, :guest, group: group, user: user1, member_role: group_member_role)
      create(:group_member, :guest, group: group, user: user2, member_role: instance_member_role)

      group.add_owner(owner)
      sign_in(owner)
    end

    before do
      stub_licensed_features(custom_roles: true)
    end

    it 'shows the group-level custom role is assigned to the user' do
      visit group_group_members_path(group)

      expect(find_member_row(user1)).to have_content('guest plus')
    end

    it 'shows the instance-level custom role is assigned to the user' do
      visit group_group_members_path(group)

      expect(find_member_row(user2)).to have_content('guest plus (instance-level)')
    end
  end
end
