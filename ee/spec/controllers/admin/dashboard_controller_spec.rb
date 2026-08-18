# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::DashboardController, feature_category: :permissions do
  describe '#index' do
    it "allows an admin user to access the page" do
      sign_in(create(:user, :admin))

      get :index

      expect(response).to have_gitlab_http_status(:ok)
    end

    it "does not allow an auditor user to access the page" do
      sign_in(create(:user, :auditor))

      get :index

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "does not allow a regular user to access the page" do
      sign_in(create(:user))

      get :index

      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when using custom permissions' do
      let_it_be(:user) { create(:user) }

      before do
        sign_in(user)
      end

      subject(:admin_dashboard) { get :index }

      context 'when custom_roles feature is available' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        MemberRole.all_customizable_admin_permission_keys.each do |ability|
          context "with #{ability} ability" do
            before do
              create(:admin_member_role, ability, user: user)
            end

            it 'responds with success' do
              admin_dashboard

              expect(response).to have_gitlab_http_status(:ok)
            end
          end
        end
      end

      context 'when custom_roles feature is not available' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it 'responds with not found' do
          admin_dashboard

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
