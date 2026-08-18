# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EnforcesAdminAuthentication, feature_category: :system_access do
  describe '.authorize!' do
    controller(ApplicationController) do
      include EnforcesAdminAuthentication

      authorize! :read_admin_users, only: :index

      def index
        head :ok
      end
    end

    let_it_be(:user) { create(:user) }

    before do
      stub_licensed_features(custom_roles: true)
      sign_in(user)
    end

    context 'when the user is a regular user' do
      it 'renders a 404' do
        get :index

        expect(response).to have_gitlab_http_status(:not_found)
      end

      context 'when an ability grants access' do
        before do
          create(:admin_member_role, :read_admin_users, user: user)
        end

        context 'when in admin mode', :enable_admin_mode do
          it 'renders ok' do
            get :index

            expect(response).to have_gitlab_http_status(:ok)
          end
        end

        context 'when not in admin mode' do
          it 'renders redirect for re-authentication and does not set admin mode' do
            get :index

            expect(response).to redirect_to new_admin_session_path
            expect(assigns(:current_user_mode)&.admin_mode?).to be(false)
          end
        end
      end

      context 'when a the user has a different admin permission', :enable_admin_mode do
        before do
          create(:admin_member_role, :read_admin_subscription, user: user)
        end

        it 'renders a 404' do
          get :index

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
