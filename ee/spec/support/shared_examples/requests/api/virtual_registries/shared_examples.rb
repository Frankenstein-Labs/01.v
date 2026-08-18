# frozen_string_literal: true

RSpec.shared_examples 'disabled virtual_registry feature flag' do |registry_type, status: :unauthorized|
  before do
    feature_flag = registry_type == :container ? :container_virtual_registries : :"#{registry_type}_virtual_registry"
    stub_feature_flags(feature_flag => false)
  end

  it_behaves_like 'returning response status', status
end

RSpec.shared_examples 'virtual registry disabled dependency proxy' do
  before do
    stub_config(dependency_proxy: { enabled: false })
  end

  it_behaves_like 'returning response status', :not_found
end

RSpec.shared_examples 'virtual registry not authenticated user' do
  let(:headers) { {} }

  it_behaves_like 'returning response status', :unauthorized
end

RSpec.shared_examples 'maven virtual registry feature not licensed' do
  before do
    stub_licensed_features(packages_virtual_registry: false)
  end

  it_behaves_like 'returning response status', :not_found
end

RSpec.shared_examples 'npm virtual registry feature not licensed' do
  before do
    stub_licensed_features(packages_virtual_registry: false)
  end

  it_behaves_like 'returning response status', :not_found
end

RSpec.shared_examples 'virtual registries setting enabled is false' do
  before do
    allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(build_stubbed(
      :virtual_registries_setting, :disabled, group: group))
  end

  it_behaves_like 'returning response status', :not_found
end

RSpec.shared_examples 'an authenticated virtual registry REST API' do |with_successful_status: :ok|
  using RSpec::Parameterized::TableSyntax

  where(:token, :sent_as, :status) do
    :personal_access_token | :header        | with_successful_status
    :personal_access_token | :bearer_header | with_successful_status
    :personal_access_token | :query_param   | with_successful_status

    :job_token             | :header        | with_successful_status
    :job_token             | :query_param   | with_successful_status

    :oauth_token           | :bearer_header | with_successful_status
    :oauth_token           | :query_param   | with_successful_status

    :deploy_token          | :header        | :unauthorized
  end

  with_them do
    let(:headers) { token_header(token, sent_as: sent_as) }
    let(:url) do
      base_url = super()
      base_url += "?#{token_query_param(token).to_query}" if sent_as == :query_param
      base_url
    end

    it_behaves_like 'returning response status', params[:status]
  end
end

RSpec.shared_examples 'virtual registry invalid oauth token' do
  context 'with an expired oauth token in the bearer header' do
    let(:headers) { { 'Authorization' => "Bearer #{expired_oauth_token.plaintext_token}" } }

    it_behaves_like 'returning response status', :unauthorized
  end

  context 'with a revoked oauth token in the bearer header' do
    let(:headers) { { 'Authorization' => "Bearer #{revoked_oauth_token_plaintext}" } }

    it_behaves_like 'returning response status', :unauthorized
  end

  context 'with an oauth token with insufficient scope in the bearer header' do
    let(:headers) { { 'Authorization' => "Bearer #{wrong_scope_oauth_token.plaintext_token}" } }

    it_behaves_like 'returning response status', :forbidden
  end
end

RSpec.shared_examples 'container virtual registry feature not licensed' do
  before do
    stub_licensed_features(container_virtual_registry: false)
  end

  it_behaves_like 'returning response status', :not_found
end

RSpec.shared_examples 'virtual registry not available' do |registry_type|
  it_behaves_like 'virtual registry disabled dependency proxy'
  it_behaves_like 'virtual registry not authenticated user'
  it_behaves_like 'virtual registries setting enabled is false'
  it_behaves_like "#{registry_type} virtual registry feature not licensed"
  it_behaves_like 'disabled virtual_registry feature flag', registry_type
end

RSpec.shared_examples 'virtual registry custom role read access' do
  let_it_be(:custom_role_user, freeze: false) { create(:user) }
  let_it_be(:member_role, freeze: false) do
    create(:member_role, :minimal_access, read_virtual_registry: true, namespace: group)
  end

  let_it_be(:custom_role_membership, freeze: false) do
    create(:group_member, :minimal_access, user: custom_role_user, source: group, member_role: member_role)
  end

  let_it_be(:custom_role_pat) { create(:personal_access_token, user: custom_role_user) }

  let(:custom_role_token) { custom_role_pat.token }
  let(:headers) { { 'PRIVATE-TOKEN' => custom_role_token } }

  before do
    stub_licensed_features(custom_roles: true, packages_virtual_registry: true, container_virtual_registry: true)
    ::Authz::UserGroupMemberRoles::UpdateForGroupService.new(custom_role_membership).execute
  end

  it_behaves_like 'returning response status', :ok

  context 'when the group is private' do
    before do
      group.reset.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
    end

    it_behaves_like 'returning response status', :ok
  end
end

RSpec.shared_examples 'virtual registry non member user access' do |registry_factory:, upstream_factory:|
  using RSpec::Parameterized::TableSyntax

  context 'with a non member user' do
    # We use `let` instead of `let_it_be` for user, group, and registry because:
    #
    # 1. We need a fresh group with a specific visibility level for each test case.
    #    Previously this shared example modified the shared `let_it_be(:group)` with
    #    `update!`, which persisted changes across examples causing test pollution.
    #
    # 2. The registry must belong to the fresh group for the access checks to work.
    #
    # 3. The user must be a non-member of the group (not added to the fresh group).
    let(:non_member_user) { create(:user) }
    let(:user) { non_member_user }

    where(:group_access_level, :status) do
      'PUBLIC'   | :not_found
      'INTERNAL' | :not_found
      'PRIVATE'  | :not_found
    end

    with_them do
      let(:group) { create(:group, visibility_level: Gitlab::VisibilityLevel.const_get(group_access_level, false)) }
      let(:registry) { create(registry_factory, group: group) }
      let(:upstream) { create(upstream_factory, registries: [registry]) }

      it_behaves_like 'returning response status', params[:status]
    end
  end
end
