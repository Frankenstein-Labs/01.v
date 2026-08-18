# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Dashboard homepage', feature_category: :notifications do
  let_it_be(:user) { create(:user) }

  before do
    sign_in(user)
    stub_feature_flags(personal_homepage: true)
  end

  describe 'GET /' do
    context 'when testing self-managed admin onboarding behavior' do
      let_it_be(:admin_user) { create(:user, admin: true) }

      before do
        stub_saas_features(admin_homepage: false)
      end

      context 'when admin has no authorized projects', :enable_admin_mode do
        it 'redirects to projects dashboard' do
          sign_in(admin_user)

          get root_path

          expect(response).to redirect_to(dashboard_projects_path)
        end
      end

      context 'when admin has authorized projects', :enable_admin_mode do
        let_it_be(:project) { create(:project, developers: admin_user) }

        it 'renders personal homepage' do
          sign_in(admin_user)

          get root_path

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to render_template('root/index')
        end
      end

      context 'when non-admin user visits self-managed instance' do
        it 'renders personal homepage regardless of project count' do
          get root_path

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to render_template('root/index')
        end
      end
    end
  end
end
