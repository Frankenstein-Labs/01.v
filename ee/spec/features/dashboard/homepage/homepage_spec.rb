# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Dashboard - Home', :js, feature_category: :notifications do
  let_it_be(:user) { create(:user) }

  before do
    stub_feature_flags(personal_homepage: true)
    sign_in user
  end

  describe 'visiting the root route' do
    it_behaves_like 'dashboard SAML reauthentication banner' do
      let_it_be(:page_path) { home_dashboard_path }
      let_it_be(:match_filter_params) { false }
    end

    context 'when testing self-managed admin onboarding behavior' do
      let_it_be(:admin_user) { create(:user, admin: true) }

      before do
        stub_saas_features(admin_homepage: false)
      end

      context 'when admin has no authorized projects', :enable_admin_mode do
        it 'shows onboarding page instead of personal homepage' do
          sign_out user
          sign_in admin_user
          visit root_path

          expect(page).to have_testid('welcome-title-content')
          expect(page).to have_content("Welcome to GitLab, #{admin_user.first_name}!")
          expect(page).to have_content('Ready to get started with GitLab?')

          expect(page).to have_testid('new-project-button')
          expect(page).to have_content('Create a project')
          expect(page).to have_content('Configure GitLab')
        end
      end

      context 'when admin has authorized projects', :enable_admin_mode do
        let_it_be(:project) { create(:project, developers: admin_user) }

        it 'redirects to personal homepage' do
          sign_out user
          sign_in admin_user
          visit root_path

          expect(page).not_to have_testid('welcome-title-content')
          expect(page).to have_content(admin_user.name)
          expect(page).to have_testid('greeting-message')
        end
      end

      context 'when non-admin user visits self-managed instance' do
        it 'always redirects to personal homepage regardless of project count' do
          visit root_path

          expect(page).not_to have_testid('welcome-title-content')
        end
      end
    end
  end
end
