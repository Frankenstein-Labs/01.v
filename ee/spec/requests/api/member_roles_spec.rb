# frozen_string_literal: true

require "spec_helper"

RSpec.describe API::MemberRoles, :api, feature_category: :system_access do
  include ApiHelpers
  include AdminModeHelper

  let_it_be(:admin) { create(:admin) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:user) { create(:user) }

  let_it_be(:group_with_member_roles) { create(:group, owners: owner) }
  let_it_be(:group_with_no_member_roles) { create(:group, owners: owner) }

  let_it_be(:member_role_1) do
    create(:member_role, :read_dependency, namespace: group_with_member_roles)
  end

  let_it_be(:member_role_2) { create(:member_role, :read_code, namespace: group_with_member_roles) }

  let_it_be(:instance_member_role) { create(:member_role, :read_code, :instance) }

  let(:group) { group_with_member_roles }
  let(:current_user) { nil }

  # for role creation endpoint (needed for shared examples to work for both regular and admin roles)
  let(:default_role_name) { 'Guest - custom' }
  let(:role_name) { 'Guest + read_code' }
  let(:role_description) { 'My custom guest role' }
  let(:role_permission) { 'read_code' }
  let(:expected_json_response) do
    {
      "name" => role_name,
      "description" => role_description,
      role_permission => true,
      "group_id" => group_id
    }
  end

  before do
    stub_licensed_features(custom_roles: true)
  end

  shared_examples "it requires a valid license" do
    context "when licensed feature is unavailable" do
      let(:current_user) { owner }

      before do
        stub_licensed_features(custom_roles: false)
      end

      it "returns forbidden error" do
        subject

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  shared_examples "it is available only on self-managed" do
    context "when on SaaS" do
      let(:current_user) { owner }

      before do
        stub_saas_mode
      end

      it "returns 400 error" do
        subject

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context "when on self-managed", :enable_admin_mode do
      let(:current_user) { admin }

      before do
        stub_self_managed_mode
      end

      it "returns 200" do
        subject

        expect(response).to have_gitlab_http_status(:success)
      end
    end
  end

  shared_examples "it is available only on SaaS" do
    context "when on SaaS" do
      let(:current_user) { owner }

      before do
        stub_saas_mode
      end

      it "returns success" do
        subject

        expect(response).to have_gitlab_http_status(:success)
      end
    end

    context "when on self-managed" do
      let(:current_user) { admin }

      let(:docs_link) do
        Rails.application.routes.url_helpers.help_page_url('update/deprecations.md',
          anchor: 'deprecate-custom-role-creation-for-group-owners-on-self-managed')
      end

      before do
        stub_self_managed_mode
      end

      it "returns 400 error with deprecation message" do
        subject

        expect(response).to have_gitlab_http_status(:bad_request)

        expect(json_response['message']).to eq(
          "400 Bad request - Group-level custom roles are deprecated on self-managed instances. " \
          "See #{docs_link}"
        )
      end
    end
  end

  shared_examples 'creating regular role failures' do
    let(:current_user) { authorized_user }

    context "when params are invalid" do
      let(:params) { { base_access_level: 1 } }

      it "returns a 400 error", :aggregate_failures do
        create_member_role

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to match(/base_access_level does not have a valid value/)
      end
    end

    context "when required param (base_access_level) is missing" do
      let(:params) { { role_permission => true } }

      it "returns a 400 error", :aggregate_failures do
        create_member_role

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to match(/base_access_level is missing/)
      end
    end
  end

  describe "GET /groups/:id/member_roles", :saas do
    subject(:get_member_roles) { get api("/groups/#{group.id}/member_roles", current_user) }

    let(:authorized_user) { owner }
    let(:expected_member_roles) do
      [
        hash_including(
          "id" => member_role_1.id,
          "name" => member_role_1.name,
          "description" => member_role_1.description,
          "base_access_level" => ::Gitlab::Access::DEVELOPER,
          "read_dependency" => true,
          "group_id" => group.id
        ),
        hash_including(
          "id" => member_role_2.id,
          "name" => member_role_2.name,
          "description" => member_role_2.description,
          "base_access_level" => ::Gitlab::Access::DEVELOPER,
          "read_code" => true,
          "group_id" => group.id
        )
      ]
    end

    it_behaves_like "getting member roles"
    it_behaves_like "it is available only on SaaS"

    context "when group does not have any associated member_roles" do
      let(:current_user) { owner }
      let(:group) { group_with_no_member_roles }

      it "returns empty array as response", :aggregate_failures do
        get_member_roles

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to(match([]))
      end
    end

    it_behaves_like 'authorizing granular token permissions', :read_member_role do
      let(:user) { owner }
      let(:boundary_object) { group }
      let(:request) { get api("/groups/#{group.id}/member_roles", personal_access_token: pat) }
    end
  end

  describe "GET /member_roles" do
    subject(:get_member_roles) { get api("/member_roles", current_user) }

    let(:authorized_user) { admin }
    let(:expected_member_roles) do
      [
        hash_including(
          "id" => instance_member_role.id,
          "name" => instance_member_role.name,
          "description" => instance_member_role.description,
          "base_access_level" => ::Gitlab::Access::DEVELOPER,
          "read_code" => true,
          "group_id" => nil
        )
      ]
    end

    before do
      stub_self_managed_mode
      enable_admin_mode!(admin)
    end

    it_behaves_like "getting member roles"
    it_behaves_like "it is available only on self-managed"
    it_behaves_like 'authorizing granular token permissions', :read_member_role do
      let(:user) { admin }
      let(:boundary_object) { :instance }
      let(:request) { get api("/member_roles", personal_access_token: pat) }
    end
  end

  describe "POST /groups/:id/member_roles", :saas do
    subject(:create_member_role) { post api("/groups/#{group.id}/member_roles", current_user), params: params }

    let(:authorized_user) { owner }
    let(:member_roles) { group.member_roles }
    let(:group_id) { group.id }
    let(:params) do
      {
        'name' => role_name,
        'base_access_level' => ::Gitlab::Access::GUEST,
        role_permission => true,
        'description' => role_description
      }
    end

    let(:expeted_json_response) do
      {
        "name" => role_name,
        "description" => role_description,
        "base_access_level" => ::Gitlab::Access::GUEST,
        role_permission => true,
        "group_id" => group_id
      }
    end

    it_behaves_like "creating member role"
    it_behaves_like 'creating regular role failures'
    it_behaves_like "it is available only on SaaS"

    context "when group is not a root group" do
      let(:group) { create(:group, parent: group_with_member_roles) }
      let(:current_user) { owner }

      it "returns a 400 error", :aggregate_failures do
        create_member_role

        expect(response).to have_gitlab_http_status(:bad_request)

        expect(json_response['message']).to match(/Namespace must be top-level namespace/)
      end
    end

    it_behaves_like 'authorizing granular token permissions', :create_member_role do
      let(:user) { owner }
      let(:boundary_object) { group }
      let(:request) { post api("/groups/#{group.id}/member_roles", personal_access_token: pat), params: params }
    end
  end

  describe "POST /member_roles" do
    subject(:create_member_role) { post api("/member_roles", current_user), params: params }

    let(:authorized_user) { admin }
    let(:member_roles) { MemberRole }
    let(:group_id) { nil }
    let(:params) do
      {
        'name' => role_name,
        base_access_level: ::Gitlab::Access::GUEST,
        role_permission => true,
        'description' => role_description
      }
    end

    before do
      stub_self_managed_mode
      enable_admin_mode!(admin)
    end

    it_behaves_like "creating member role"
    it_behaves_like "it is available only on self-managed"
    it_behaves_like 'authorizing granular token permissions', :create_member_role do
      let(:user) { admin }
      let(:boundary_object) { :instance }
      let(:request) { post api("/member_roles", personal_access_token: pat), params: params }
    end
  end

  describe "DELETE /groups/:id/member_roles/:member_role_id", :saas do
    subject(:delete_member_role) { delete api("/groups/#{group.id}/member_roles/#{member_role_id}", current_user) }

    let(:authorized_user) { owner }
    let(:member_roles) { group.member_roles }
    let(:member_role_id) { member_role_1.id }

    before do
      stub_saas_mode
    end

    it_behaves_like "deleting member role"
    it_behaves_like "it is available only on SaaS"
    it_behaves_like 'authorizing granular token permissions', :delete_member_role do
      let(:user) { owner }
      let(:boundary_object) { group }
      let(:request) { delete api("/groups/#{group.id}/member_roles/#{member_role_id}", personal_access_token: pat) }
    end
  end

  describe "DELETE /member_roles/:member_role_id" do
    subject(:delete_member_role) { delete api("/member_roles/#{member_role_id}", current_user) }

    let(:authorized_user) { admin }
    let(:member_roles) { MemberRole }
    let(:member_role_id) { instance_member_role.id }

    before do
      stub_self_managed_mode
      enable_admin_mode!(admin)
    end

    it_behaves_like "deleting member role"
    it_behaves_like "it is available only on self-managed"
    it_behaves_like 'authorizing granular token permissions', :delete_member_role do
      let(:user) { admin }
      let(:boundary_object) { :instance }
      let(:request) { delete api("/member_roles/#{member_role_id}", personal_access_token: pat) }
    end
  end

  private

  def stub_saas_mode
    stub_saas_features(gitlab_com_subscriptions: true)
  end

  def stub_self_managed_mode
    stub_saas_features(gitlab_com_subscriptions: false)
  end
end
