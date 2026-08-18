# frozen_string_literal: true

RSpec.shared_context 'for virtual registry api setup' do
  include WorkhorseHelpers
  include HttpBasicAuthHelpers

  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:project, freeze: false) { create(:project, namespace: group) }
  let_it_be(:user, freeze: false) { create(:user, owner_of: group) }
  let_it_be(:job, freeze: false) { create(:ci_build, :running, user: user, project: project) }
  let_it_be(:deploy_token, freeze: false) do
    create(:deploy_token, :group, groups: [group], read_virtual_registry: true)
  end

  let_it_be(:oauth_application, freeze: false) { create(:oauth_application, owner: user) }
  let_it_be(:oauth_token, freeze: false) do
    create(:oauth_access_token, application_id: oauth_application.id, resource_owner_id: user.id, scopes: [:api])
  end

  let_it_be(:expired_oauth_token, freeze: false) do
    create(
      :oauth_access_token,
      application_id: oauth_application.id,
      resource_owner_id: user.id,
      scopes: [:api],
      expires_in: 1,
      created_at: 1.hour.ago
    )
  end

  let_it_be(:revoked_oauth_token, freeze: false) do
    create(:oauth_access_token, application_id: oauth_application.id, resource_owner_id: user.id,
      scopes: [:api]).tap(&:revoke)
  end

  let_it_be(:revoked_oauth_token_plaintext, freeze: false) { revoked_oauth_token.plaintext_token }
  let_it_be(:wrong_scope_oauth_token, freeze: false) do
    create(:oauth_access_token, application_id: oauth_application.id, resource_owner_id: user.id, scopes: [:read_user])
  end

  let(:personal_access_token) { create(:personal_access_token, user: user) }
  let(:headers) { token_header(:personal_access_token, sent_as: :header) }

  before do
    stub_config(dependency_proxy: { enabled: true }) # not enabled by default
  end

  def token_header(token, sent_as: :header)
    case token
    when :personal_access_token
      header_name = 'PRIVATE-TOKEN'
      token_value = personal_access_token.token
    when :deploy_token
      header_name = 'Deploy-Token'
      token_value = deploy_token.token
    when :job_token
      header_name = 'Job-Token'
      token_value = job.token
    when :oauth_token
      # oauth tokens don't support a custom header.
      # they should always be sent with the bearer header.
      token_value = oauth_token.plaintext_token
    end

    case sent_as
    when :header
      { header_name => token_value }
    when :bearer_header
      { 'Authorization' => "Bearer #{token_value}" }
    end
  end

  def token_query_param(token)
    case token
    when :personal_access_token
      { private_token: personal_access_token.token }
    when :job_token
      { job_token: job.token }
    when :oauth_token
      { access_token: oauth_token.plaintext_token }
    end
  end

  def token_basic_auth(token)
    case token
    when :personal_access_token
      user_basic_auth_header(user, personal_access_token)
    when :deploy_token
      deploy_token_basic_auth_header(deploy_token)
    when :job_token
      job_basic_auth_header(job)
    end
  end
end

RSpec.shared_context 'for maven virtual registry api setup' do
  include_context 'for virtual registry api setup'

  let_it_be_with_reload(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }
  let_it_be_with_reload(:upstream) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }
  let_it_be_with_reload(:cache_entry) do
    create(:virtual_registries_packages_maven_cache_remote_entry, :with_download_metrics, upstream:)
  end

  before do
    stub_licensed_features(packages_virtual_registry: true)
    allow(VirtualRegistries::Setting).to receive(:find_for_group).with(any_args).and_return(build_stubbed(
      :virtual_registries_setting, group: group))
  end
end

RSpec.shared_context 'for container virtual registry api setup' do
  include_context 'for virtual registry api setup'

  let_it_be_with_reload(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be(:upstream, freeze: false) { create(:virtual_registries_container_upstream, registries: [registry]) }
  let_it_be_with_reload(:cache_entry) do
    create(:virtual_registries_container_cache_remote_entry, :with_download_metrics, upstream: upstream)
  end

  before do
    stub_licensed_features(container_virtual_registry: true)
  end
end

RSpec.shared_context 'for npm virtual registry api setup' do
  include_context 'for virtual registry api setup'

  let_it_be_with_reload(:registry) { create(:virtual_registries_packages_npm_registry, group: group) }
  let_it_be(:upstream, freeze: false) { create(:virtual_registries_packages_npm_upstream, registries: [registry]) }
  let_it_be_with_reload(:cache_entry) do
    create(:virtual_registries_packages_npm_cache_remote_entry, :with_download_metrics, upstream:)
  end

  before do
    stub_licensed_features(packages_virtual_registry: true)
    allow(VirtualRegistries::Setting)
      .to receive(:find_for_group)
      .with(any_args)
      .and_return(build_stubbed(:virtual_registries_setting, group: group))
  end
end
