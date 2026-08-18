# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with read_admin_users', :enable_admin_mode, feature_category: :user_management do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:permission) { :read_admin_users }
  let_it_be(:role) { create(:member_role, permission) }
  let_it_be(:membership) { create(:user_member_role, user: current_user, member_role: role) }

  before do
    stub_licensed_features(custom_roles: true)
    sign_in(current_user)
  end

  describe Admin::UsersController do
    let_it_be(:other_user) { create(:user, :with_namespace) }

    it "GET #index" do
      get admin_users_path

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template(:index)
    end

    it "GET #show" do
      get admin_user_path(other_user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template(:show)
    end

    it "GET #projects" do
      get projects_admin_user_path(other_user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'GET #new' do
      get new_admin_user_path

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'GET #edit' do
      get edit_admin_user_path(other_user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'POST #create' do
      post admin_users_path, params: { user: attributes_for(:user) }

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'PATCH #update' do
      patch admin_user_path(other_user), params: { user: attributes_for(:user) }

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'PUT #update' do
      put admin_user_path(other_user), params: { user: attributes_for(:user) }

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'DELETE #destroy' do
      delete admin_user_path(other_user)

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe Admin::DashboardController do
    describe "#index" do
      it 'user has access via a custom role' do
        get admin_root_path

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:index)
      end
    end
  end
end
