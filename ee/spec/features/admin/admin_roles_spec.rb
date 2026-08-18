# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin roles', feature_category: :permissions do
  include ListboxHelpers

  let_it_be(:admin) { create(:admin) }

  before do
    stub_licensed_features(custom_roles: true)
  end

  describe 'when in admin mode', :enable_admin_mode do
    context 'when on self-managed', :js do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)

        sign_in(admin)

        visit admin_application_settings_roles_and_permissions_path
      end

      describe 'create' do
        it 'creates a custom admin role' do
          click_button s_('MemberRole|New role')
          click_link s_('MemberRole|Admin role')

          wait_for_requests

          name = 'My custom admin role'

          fill_in 'Name', with: name
          fill_in 'Description', with: 'My role description'

          page.find('label', text: 'View CI/CD').click

          click_button s_('MemberRole|Create role')
          expect(page).to have_content(name)

          created_admin_role = MemberRole.find_by(name: name)

          expect(created_admin_role).not_to be_nil

          expect(page).to have_content("#{created_admin_role.name} Custom admin role #{created_admin_role.description}")
        end
      end

      describe 'update' do
        before do
          create(:member_role, :admin, name: 'old name', description: 'old description')

          page.refresh
        end

        it 'updates a custom admin role' do
          expect(page).to have_content("old name Custom admin role old description")

          page.all('td .gl-disclosure-dropdown').last.click

          click_link s_('MemberRole|Edit role')

          wait_for_requests

          expect(page).to have_content(s_('MemberRole|Edit admin role'))

          fill_in 'Name', with: 'new name'
          fill_in 'Description', with: 'new description'

          click_button s_('MemberRole|Save role')

          expect(page).to have_content("new name Custom admin role new description")
        end
      end

      describe 'delete' do
        context 'when no user is assigned to the role' do
          before do
            create(:member_role, :admin)

            page.refresh
          end

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
            create(:admin_member_role, :read_admin_users)

            page.refresh
          end

          it 'disables the delete role button' do
            page.all('td .gl-disclosure-dropdown').last.click
            expect(page).to have_button s_('MemberRole|Delete role'), disabled: true
          end
        end
      end
    end

    context 'when on SaaS' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)

        sign_in(admin)
      end

      it 'renders the page' do
        visit admin_application_settings_roles_and_permissions_path

        expect(page).to have_gitlab_http_status(:ok)
      end
    end
  end
end
