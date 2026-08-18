# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::Organizations::DashboardController, :enable_admin_mode, feature_category: :organization do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user) }
  let_it_be(:role) { create(:admin_member_role, :read_admin_users, user: user) }

  before do
    stub_licensed_features(custom_roles: true)
    sign_in(user)
  end

  describe 'GET /o/:organization_path/admin', :without_current_organization do
    context 'when user has a custom admin role' do
      it 'denies access' do
        get organization_admin_root_path(organization)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
