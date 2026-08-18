# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/users/_user_type.html.haml', feature_category: :user_management do
  let_it_be(:user) { build(:user) }
  let_it_be(:is_current_user) { false }

  before do
    assign(:user, user)
  end

  def render
    super(partial: 'admin/users/user_type', locals: { is_current_user: is_current_user })
  end

  context 'when rendering' do
    before do
      render
    end

    it 'renders frontend placeholder' do
      manage_roles_path = admin_application_settings_roles_and_permissions_path

      expect(rendered).to have_selector "#js-user-type[data-user-type='regular']"
      expect(rendered).to have_selector "#js-user-type[data-is-current-user='false']"
      expect(rendered).to have_selector "#js-user-type[data-license-allows-auditor-user='true']"
      expect(rendered).to have_selector "#js-user-type[data-manage-roles-path='#{manage_roles_path}']"
    end

    it 'renders loading icon' do
      expect(rendered).to have_selector '#js-user-type .gl-spinner-container.gl-mb-6.gl-inline-block'
      expect(rendered).to have_selector '.gl-spinner-md'
    end

    context 'when user is assigned an admin role' do
      let(:user_member_role) { build_stubbed(:user_member_role) }

      before do
        allow(user).to receive(:user_member_role).and_return(user_member_role)
        allow(user_member_role).to receive_messages(member_role_id: 12, ldap: true)

        render
      end

      it 'renders frontend placeholder with admin role data' do
        role_data = { id: user_member_role.member_role.id, name: user_member_role.member_role.name,
                      ldap: user_member_role.ldap }

        expect(rendered).to have_selector "#js-user-type[data-admin-role='#{role_data.to_json}']"
      end
    end

    context 'when the user is not assigned an admin role' do
      before do
        allow(user).to receive(:user_member_role).and_return(nil)

        render
      end

      it 'renders frontend placeholder without admin role data' do
        expect(rendered).not_to have_selector "#js-user-type[data-admin-role]"
      end
    end
  end

  context 'when auditor_user license is available' do
    before do
      stub_licensed_features(auditor_user: true)
      render
    end

    it 'renders frontend placeholder' do
      expect(rendered).to have_selector "#js-user-type[data-license-allows-auditor-user='true']"
    end
  end

  context 'when user is current user' do
    let_it_be(:is_current_user) { true }

    before do
      render
    end

    it 'renders frontend placeholder' do
      expect(rendered).to have_selector "#js-user-type[data-is-current-user='true']"
    end
  end
end
