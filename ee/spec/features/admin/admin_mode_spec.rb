# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin mode', :with_current_organization, :js, feature_category: :permissions do
  let_it_be(:user) { create(:user) }
  let_it_be(:role) { create(:admin_member_role, :read_admin_users, user: user) }

  context 'when using custom permissions' do
    context 'when custom_roles feature is available' do
      before do
        stub_licensed_features(custom_roles: true)

        sign_in(user)
      end

      context 'when application setting :admin_mode is enabled', :request_store do
        context 'when already signed into admin mode' do
          before do
            enter_admin_mode(user)
          end

          it 'can access admin dashboard without re-entering admin mode' do
            expect(page).to have_current_path(admin_root_path)
            visit root_dashboard_path

            expect(page).to have_link('Admin')
            click_link 'Admin'

            expect(page).to have_current_path(
              admin_root_path
            )
          end
        end
      end

      context 'when application setting :admin_mode is disabled' do
        before do
          stub_application_setting(admin_mode: false)
        end

        it 'can access admin dashboard without entering admin mode' do
          visit root_dashboard_path

          expect(page).to have_link('Admin')
          click_link 'Admin'

          expect(page).to have_current_path(admin_root_path)
        end
      end
    end

    context 'when custom_roles feature is not available' do
      before do
        stub_licensed_features(custom_roles: false)

        sign_in(user)
      end

      it 'shows no admin buttons' do
        visit root_dashboard_path

        expect(page).not_to have_link('Admin')
      end
    end
  end
end
