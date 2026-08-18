# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Member Roles', feature_category: :permissions do
  include ListboxHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:custom_role) { create(:member_role, namespace: group) }
  let_it_be(:owner) { create(:user, owner_of: group) }

  let(:name) { 'My custom role' }
  let(:description) { 'My role description' }
  let(:access_level) { 'Developer' }

  before do
    stub_licensed_features(custom_roles: true)
    sign_in(owner)
  end

  def create_role(access_level, name, description)
    click_link s_('MemberRole|New role')
    wait_for_requests

    fill_in 'Name', with: name
    fill_in 'Description', with: description
    select_from_listbox access_level, from: 'Select a role'

    page.find('label', text: 'Manage vulnerabilities').click

    click_button s_('MemberRole|Create role')
    expect(page).to have_content(name)
  end

  shared_examples 'creates a new custom role' do
    it 'and displays it' do
      create_role(access_level, name, description)

      created_member_role = MemberRole.find_by(name: name)

      expect(created_member_role).not_to be_nil

      expect(page).to have_content("#{created_member_role.name} Custom member role #{created_member_role.description}")
    end
  end

  shared_examples 'deletes a custom role' do
    context 'when no user is assigned to the role' do
      it 'deletes the custom role' do
        page.all('td .gl-disclosure-dropdown').last.click
        click_button s_('MemberRole|Delete role')

        wait_for_requests

        click_button s_('MemberRole|Delete role')

        wait_for_requests

        expect(page).to have_content(s_('MemberRole|Role successfully deleted.'))
      end
    end

    context 'when a user is assigned to the role' do
      before do
        create(:group_member, :developer, group: group, member_role: custom_role)

        page.refresh
      end

      it 'disables the delete role button' do
        page.all('td .gl-disclosure-dropdown').last.click
        expect(page).to have_button s_('MemberRole|Delete role'), disabled: true
      end
    end
  end

  context 'when on SaaS', :js, :saas do
    before do
      stub_saas_features(gitlab_com_subscriptions: true)

      visit group_settings_roles_and_permissions_path(group)
    end

    it_behaves_like 'creates a new custom role'
    it_behaves_like 'deletes a custom role'
  end

  context 'when on self-managed' do
    before do
      stub_saas_features(gitlab_com_subscriptions: false)
    end

    it 'renders 404' do
      visit group_settings_roles_and_permissions_path(group)

      expect(page).to have_gitlab_http_status(:not_found)
    end
  end
end
