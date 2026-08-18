# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with read_admin_subscription custom role', :enable_admin_mode, feature_category: :system_access do
  let_it_be(:user) { create(:user) }
  let_it_be(:role) { create(:member_role, :read_admin_subscription) }
  let_it_be(:user_member_role) { create(:user_member_role, member_role: role, user: user) }

  before do
    stub_licensed_features(custom_roles: true)

    sign_in(user)
  end

  describe Admin::SubscriptionsController do
    describe "#show" do
      it 'user has access via a custom role' do
        get admin_subscription_path

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:show)
      end
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
