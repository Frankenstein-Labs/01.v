# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Ci::GoogleCloud::GenerateBuildEnvironmentVariablesService, '#execute', feature_category: :secrets_management do
  let_it_be_with_refind(:project) { create(:project) }
  let_it_be_with_refind(:project_integration) do
    create(:google_cloud_platform_workload_identity_federation_integration, project: project)
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:rsa_key) { OpenSSL::PKey::RSA.generate(3072) }
  let_it_be(:rsa_key_data) { rsa_key.to_s }

  let(:build) { build_stubbed(:ci_build, project: project, user: user) }
  let(:service) { described_class.new(build) }

  subject(:execute) { service.execute }

  before do
    stub_application_setting(ci_jwt_signing_key: rsa_key_data)
    stub_saas_features(google_cloud_support: true)
  end

  it 'returns variables containing valid config.json', :aggregate_failures do
    expect(execute).to contain_exactly(
      a_hash_including(key: 'GOOGLE_APPLICATION_CREDENTIALS', file: true, masked: true),
      a_hash_including(key: 'CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE', file: true, masked: true)
    )

    expect(Gitlab::Json.parse(execute.first[:value])).to match(
      'type' => 'external_account',
      'audience' => project_integration.identity_provider_resource_name,
      'subject_token_type' => 'urn:ietf:params:oauth:token-type:jwt',
      'token_url' => 'https://sts.googleapis.com/v1/token',
      'credential_source' => {
        'url' => 'https://auth.gcp.gitlab.com/token',
        'headers' => { 'Authorization' => a_string_matching(/Bearer [0-9a-zA-Z_\-.]+/) },
        'format' => { 'type' => 'json', 'subject_token_field_name' => 'token' }
      })
    expect(execute.pluck(:value)).to all(eq(execute.first[:value]))
  end

  it 'creates a config with expected JWT token' do
    config = Gitlab::Json.parse(execute.first[:value])
    authorization = config.dig(*%w[credential_source headers Authorization])
    encoded_token = authorization.split(' ').last
    payload, _ = ::JWT.decode(encoded_token, rsa_key, true, { algorithm: 'RS256' })

    expect(payload).to match(a_hash_including(
      'namespace_id' => project.namespace_id.to_s,
      'project_id' => project.id.to_s,
      'user_id' => user.id.to_s,
      'aud' => 'https://auth.gcp.gitlab.com',
      'target_audience' => project_integration.identity_provider_resource_name
    ))
  end

  context 'when project is configured with a custom sub claim' do
    before do
      project.update!(ci_id_token_sub_claim_components: %w[project_id ref_type ref])
    end

    it 'honors the configured sub claim components' do
      config = Gitlab::Json.parse(execute.first[:value])
      authorization = config.dig(*%w[credential_source headers Authorization])
      encoded_token = authorization.split(' ').last
      payload, _ = ::JWT.decode(encoded_token, rsa_key, true, { algorithm: 'RS256' })

      expect(payload['sub']).to eq("project_id:#{project.id}:ref_type:branch:ref:#{build.ref}")
    end
  end

  context 'when integration is not present' do
    before do
      project_integration.destroy!
    end

    it { is_expected.to eq([]) }
  end

  context 'when integration is inactive' do
    before do
      project_integration.update_column(:active, false)
    end

    it { is_expected.to eq([]) }
  end
end
