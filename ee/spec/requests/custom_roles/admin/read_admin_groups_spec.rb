# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with read_admin_groups', :enable_admin_mode, feature_category: :permissions do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:permission) { :read_admin_groups }
  let_it_be(:role) { create(:admin_member_role, permission, user: current_user) }

  before do
    stub_licensed_features(custom_roles: true)
    sign_in(current_user)
  end

  shared_examples 'is accessible' do
    it 'is accessible' do
      request

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe Admin::GroupsController do
    describe "GET #index" do
      subject(:request) { get admin_groups_path }

      it_behaves_like 'is accessible'
    end

    describe "GET #show" do
      subject(:request) { get admin_group_path(create(:group)) }

      it_behaves_like 'is accessible'
    end
  end
end
