# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with read_virtual_registry custom role', :api, feature_category: :virtual_registry do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:user) { create(:user) }
  let_it_be(:role) do
    create(:member_role, :minimal_access, read_virtual_registry: true, namespace: group)
  end

  let_it_be(:membership) do
    create(:group_member, :minimal_access, member_role: role, user: user, source: group)
  end

  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group:) }
  let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user:) }

  before_all do
    ::Authz::UserGroupMemberRoles::UpdateForGroupService.new(membership).execute
  end

  before do
    stub_licensed_features(custom_roles: true, packages_virtual_registry: true)
    stub_config(dependency_proxy: { enabled: true })
    allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group)
      .and_return(build_stubbed(:virtual_registries_setting, group: group))
  end

  describe 'REST API endpoints' do
    describe 'GET /api/v4/groups/:id/-/virtual_registries/packages/maven/registries' do
      it 'can list virtual registries' do
        get api("/groups/#{group.id}/-/virtual_registries/packages/maven/registries", personal_access_token:)

        expect(response).to have_gitlab_http_status(:ok)
        expect(::Gitlab::Json.safe_parse(response.body)).to contain_exactly(registry.as_json)
      end
    end

    describe 'GET /api/v4/virtual_registries/packages/maven/registries/:id' do
      it 'can read a virtual registry' do
        get api("/virtual_registries/packages/maven/registries/#{registry.id}", personal_access_token:)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  context 'when user does not have the custom role' do
    let_it_be(:user_without_role) { create(:user) }
    let_it_be(:membership_without_role) do
      create(:group_member, :minimal_access, user: user_without_role, source: group)
    end

    let_it_be(:token_without_role) { create(:personal_access_token, user: user_without_role) }

    it 'cannot list virtual registries' do
      get api("/groups/#{group.id}/-/virtual_registries/packages/maven/registries",
        personal_access_token: token_without_role)

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end
end
