# frozen_string_literal: true

require "spec_helper"

RSpec.describe API::AdminMemberRoles, :api, feature_category: :permissions do
  include ApiHelpers
  include AdminModeHelper

  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }

  let_it_be(:member_role_1) { create(:member_role, :admin) }
  let_it_be(:member_role_2) { create(:member_role, :admin) }

  let(:member_role_id) { member_role_1.id }

  let(:current_user) { nil }
  let(:authorized_user) { admin }

  # for role creation endpoint (needed for shared examples to work for both regular and admin roles)
  let(:default_role_name) { 'Admin role - custom' }
  let(:role_name) { 'Role with read_admin_users' }
  let(:role_description) { 'My custom admin role' }
  let(:role_permission) { 'read_admin_users' }

  before do
    stub_licensed_features(custom_roles: true)
  end

  describe "GET /admin_member_roles" do
    subject(:get_member_roles) { get api("/admin_member_roles", current_user) }

    let(:expected_member_roles) do
      [
        hash_including(
          "id" => member_role_1.id,
          "name" => member_role_1.name,
          "description" => member_role_1.description,
          "read_admin_users" => true,
          "group_id" => nil
        ),
        hash_including(
          "id" => member_role_2.id,
          "name" => member_role_2.name,
          "description" => member_role_2.description,
          "read_admin_users" => true,
          "group_id" => nil
        )
      ]
    end

    before do
      enable_admin_mode!(admin)
    end

    it_behaves_like "getting member roles"
    it_behaves_like 'authorizing granular token permissions', :read_admin_member_role do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { get api("/admin_member_roles", personal_access_token: pat) }
    end
  end

  describe "POST /admin_member_roles" do
    subject(:create_member_role) { post api("/admin_member_roles", current_user), params: params }

    let(:member_roles) { MemberRole }
    let(:group_id) { nil }
    let(:params) do
      {
        'name' => role_name,
        role_permission => true,
        'description' => role_description
      }
    end

    let(:expected_json_response) do
      {
        "name" => role_name,
        "description" => role_description,
        role_permission => true,
        "group_id" => nil
      }
    end

    before do
      enable_admin_mode!(admin)
    end

    it_behaves_like "creating member role"
    it_behaves_like 'authorizing granular token permissions', :create_admin_member_role do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { post api("/admin_member_roles", personal_access_token: pat), params: params }
    end
  end

  describe "DELETE /admin_member_roles/:member_role_id" do
    subject(:delete_member_role) { delete api("/admin_member_roles/#{member_role_id}", current_user) }

    let(:member_roles) { MemberRole }

    before do
      enable_admin_mode!(admin)
    end

    it_behaves_like "deleting member role"
    it_behaves_like 'authorizing granular token permissions', :delete_admin_member_role do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { delete api("/admin_member_roles/#{member_role_id}", personal_access_token: pat) }
    end
  end
end
