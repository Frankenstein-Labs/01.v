# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::SecretsManagerClient, :gitlab_secrets_manager, feature_category: :secrets_management do
  let(:jwt) { SecretsManagement::TestJwt.new.encoded }
  let(:global_jwt) { SecretsManagement::TestJwt.new(scope: :global).encoded }
  let(:bad_jwt) { SecretsManagement::TestJwt.new(aud: "bad_aud").encoded }
  let(:role) { described_class::DEFAULT_JWT_ROLE }
  let(:client) { described_class.new(jwt: global_jwt, role: role) }

  shared_examples_for 'making an invalid API request' do
    it 'raises an error' do
      expect { subject }.to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
    end
  end

  describe '.configure' do
    # Store original configuration before tests
    let!(:original_host) { described_class.configuration.host }
    let!(:original_base_path) { described_class.configuration.base_path }

    after do
      # Reset the configuration to original settings
      described_class.configure do |config|
        config.host = original_host
        config.base_path = original_base_path
      end
    end

    it 'sets the configuration values' do
      described_class.configure do |config|
        config.host = 'http://test-host:8200'
        config.base_path = '/test-path/'
      end

      expect(described_class.configuration.host).to eq('http://test-host:8200')
      expect(described_class.configuration.base_path).to eq('/test-path/')
    end
  end

  describe '.expected_server_version' do
    it 'returns the content of GITLAB_OPENBAO_VERSION file' do
      path = Rails.root.join(described_class::SERVER_VERSION_FILE)
      version = path.read.chomp

      expect(described_class.expected_server_version).to eq(version)
    end
  end

  describe 'handling connection and authentication errors' do
    context 'when connection error occurs during API calls' do
      before do
        webmock_enable!(allow_localhost: false)

        # Then make the secrets engine request fail with connection error
        stub_request(:post, %r{#{described_class.configuration.host}/v1/sys/mounts})
          .to_raise(Errno::ECONNREFUSED)
      end

      after do
        # Reset WebMock to its previous state
        webmock_enable!(allow_localhost: true)
        WebMock.reset!
      end

      it 'raises ConnectionError for operations after authentication' do
        client = described_class.new(jwt: jwt, role: role)
        expect { client.enable_secrets_engine('test', 'kv-v2') }
          .to raise_error(described_class::ConnectionError)
      end
    end

    context 'when authentication error happens during API calls' do
      it 'raises AuthenticationError wrapping the connection error' do
        client = described_class.new(jwt: bad_jwt)
        expect { client.enable_secrets_engine('test', 'kv-v2') }
          .to raise_error(described_class::AuthenticationError, /error validating token/)
      end
    end
  end

  describe '#enable_secrets_engine' do
    let(:mount_path) { 'some/test/path' }
    let(:engine) { 'kv-v2' }

    it 'enables the secrets engine' do
      client.enable_secrets_engine(mount_path, engine)

      expect_kv_secret_engine_to_be_mounted("", mount_path)
    end

    context 'when OpenBao responds with a 5XX status code' do
      before do
        webmock_enable!(allow_localhost: false)

        stub_request(:post, "#{described_class.configuration.host}/v1/sys/mounts/#{mount_path}")
          .with(body: { type: engine })
          .to_return(status: 503, body: response_body, headers: {})
      end

      after do
        webmock_enable!(allow_localhost: true)
        WebMock.reset!
      end

      let(:response_body) { '' }

      it 'raises ServiceUnavailableError with Serivce unavailable message' do
        expect { client.enable_secrets_engine(mount_path, engine) }
          .to raise_error(described_class::ServiceUnavailableError, /OpenBao service unavailable/)
      end
    end

    context 'when OpenBao responds with a 4XX status code' do
      let(:headers) { {} }
      let(:status) { 400 }
      let(:response_headers) { {} }

      before do
        webmock_enable!(allow_localhost: false)

        stub_request(:post, "#{described_class.configuration.host}/v1/sys/mounts/#{mount_path}")
          .with(body: { type: engine })
          .to_return(status: status, body: response_body, headers: response_headers)
      end

      after do
        webmock_enable!(allow_localhost: true)
        WebMock.reset!
      end

      context 'when OpenBao response body does NOT have error message' do
        let(:response_body) { '' }

        it 'raises ApiError with default message' do
          expect { client.enable_secrets_engine(mount_path, engine) }
            .to raise_error(described_class::ApiError, /OpenBao API request failed/)
        end
      end

      context 'when OpenBao response body has error message' do
        let(:response_body) { { errors: ["Bad Request"] }.to_json }

        it 'raises ApiError wrapping the original Openbao error message' do
          expect { client.enable_secrets_engine(mount_path, engine) }
            .to raise_error(described_class::ApiError, /Bad Request/)
        end
      end

      context 'when OpenBao response body has empty error message' do
        let(:response_body) { { errors: [] }.to_json }

        it 'raises ApiError wrapping default error message' do
          expect { client.enable_secrets_engine(mount_path, engine) }
            .to raise_error(described_class::ApiError, /OpenBao API request failed/)
        end
      end

      context 'when OpenBao response body has no errors key' do
        let(:response_body) { { data: 'something' }.to_json }

        it 'raises ApiError with default message' do
          expect { client.enable_secrets_engine(mount_path, engine) }
            .to raise_error(described_class::ApiError, /OpenBao API request failed/)
        end
      end

      context 'when OpenBao response body is a JSON array' do
        let(:response_body) { [{ 'errors' => ['something'] }].to_json }

        it 'raises ApiError with default message' do
          expect { client.enable_secrets_engine(mount_path, engine) }
            .to raise_error(described_class::ApiError, /OpenBao API request failed/)
        end
      end

      context 'when OpenBao response body has a non-array errors value' do
        let(:response_body) { { errors: 'a plain string error' }.to_json }

        it 'raises ApiError with the error message' do
          expect { client.enable_secrets_engine(mount_path, engine) }
            .to raise_error(described_class::ApiError, /a plain string error/)
        end
      end

      context 'when OpenBao response body is an invalid JSON' do
        let(:response_body) { 'invalid JSON' }

        it 'raises ApiError with default message' do
          expect { client.enable_secrets_engine(mount_path, engine) }
            .to raise_error(described_class::ApiError, /OpenBao API request failed/)
        end
      end

      context 'when OpenBao responds with a 404 status code and authentication failure headers' do
        let(:response_body) { '' }
        let(:status) { 404 }
        let(:response_headers) do
          { 'X-Vault-Inline-Auth-Failed' => 'true' }
        end

        it 'raises AuthenticationError wrapping the connection error' do
          expect { client.enable_secrets_engine(mount_path, engine) }
            .to raise_error(described_class::AuthenticationError, /Failed to authenticate with OpenBao/)
        end
      end

      context 'when OpenBao responds with a 404 status code, authentication failure headers, and a JSON array body' do
        let(:response_body) { [1].to_json }
        let(:status) { 404 }
        let(:response_headers) do
          { 'X-Vault-Inline-Auth-Failed' => 'true', 'Content-Type' => 'application/json' }
        end

        it 'raises AuthenticationError with default message' do
          expect { client.enable_secrets_engine(mount_path, engine) }
            .to raise_error(described_class::AuthenticationError, /Failed to authenticate with OpenBao/)
        end
      end
    end
  end

  describe '#enable_auth_engine' do
    let(:mount_path) { 'auth/testing/pipeline_jwt' }
    let(:engine) { 'jwt' }

    it 'enables the secrets engine' do
      client.enable_auth_engine(mount_path, engine)

      expect_jwt_auth_engine_to_be_mounted("", mount_path)
    end

    context 'when the engine already exists' do
      before do
        client.enable_auth_engine(mount_path, engine)
      end

      it 'raises an error by default' do
        expect { client.enable_auth_engine(mount_path, engine) }
          .to raise_error(described_class::ApiError)
      end

      it 'returns true when allow_existing is true' do
        expect(client.enable_auth_engine(mount_path, engine, allow_existing: true)).to be true
      end
    end
  end

  describe '#disable_auth_engine' do
    let(:mount_path) { 'auth/testing/pipeline_jwt' }
    let(:engine) { 'jwt' }

    it 'disables the auth engine' do
      client.enable_auth_engine(mount_path, engine)
      expect_jwt_auth_engine_to_be_mounted("", mount_path)

      client.disable_auth_engine(mount_path)
      expect_jwt_auth_engine_not_to_be_mounted("", mount_path)
    end
  end

  describe '#disable_secrets_engine' do
    let(:mount_path) { 'some/test/path' }

    context 'when the secrets engine exists' do
      before do
        client.enable_secrets_engine(mount_path, 'kv-v2')
      end

      it 'disables the secrets engine' do
        expect_kv_secret_engine_to_be_mounted("", mount_path)

        client.disable_secrets_engine(mount_path)

        expect_kv_secret_engine_not_to_be_mounted("", mount_path)
      end
    end

    context 'when the secrets engine does not exist' do
      it 'does not raise an error' do
        expect { client.disable_secrets_engine('non/existent/path') }.not_to raise_error
      end
    end
  end

  describe '#configure_jwt' do
    let(:mount_path) { 'auth/testing/pipeline_jwt' }
    let(:server_url) { 'https://gitlab.example.com' }
    let(:jwk_signer) { Gitlab::CurrentSettings.ci_jwt_signing_key }

    before do
      client.enable_auth_engine(mount_path, 'jwt')
    end

    it 'configures the JWT auth method' do
      expect { client.configure_jwt(mount_path, server_url, jwk_signer) }.not_to raise_error

      # Verify we can create a role on the configured JWT backend
      expect do
        client.update_jwt_role(
          mount_path,
          'test-role',
          user_claim: 'project_id',
          role_type: 'jwt',
          bound_claims: { project_id: 123 },
          token_policies: ['test-policy']
        )
      end.not_to raise_error
    end
  end

  describe '#update_jwt_role and #read_jwt_role' do
    let(:mount_path) { 'auth/testing/pipeline_jwt' }
    let(:role_name) { 'test-role' }
    let(:server_url) { 'https://gitlab.example.com' }
    let(:jwk_signer) { Gitlab::CurrentSettings.ci_jwt_signing_key }

    let(:role_data) do
      {
        role_type: 'jwt',
        user_claim: 'project_id', # Required field
        bound_claims: { project_id: 123 },
        token_policies: ['test-policy']
      }
    end

    before do
      client.enable_auth_engine(mount_path, 'jwt')
      client.configure_jwt(mount_path, server_url, jwk_signer)
    end

    it 'creates and reads a JWT role' do
      # Create the role
      client.update_jwt_role(mount_path, role_name, **role_data)

      # Read the role back
      role = client.read_jwt_role(mount_path, role_name)

      # Verify the role data
      expect(role).to be_present
      expect(role['token_ttl']).to eq(900)
      expect(role['token_max_ttl']).to eq(900)
      expect(role['bound_claims']['project_id']).to eq(123)
      expect(role['token_policies']).to include('test-policy')
      expect(role['user_claim']).to eq('project_id')
    end

    it 'raises an error when reading a non-existent role' do
      expect { client.read_jwt_role(mount_path, 'non-existent-role') }
        .to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
    end
  end

  describe '#update_jwt_cel_role and #read_jwt_cel_role' do
    let(:mount_path) { 'auth/testing/pipeline_jwt' }
    let(:role_name) { 'test-role' }
    let(:server_url) { 'https://gitlab.example.com' }
    let(:jwk_signer) { Gitlab::CurrentSettings.ci_jwt_signing_key }
    let(:project_id) { 1234 }

    let(:role_data) do
      {
        bound_audiences: [server_url],
        cel_program: SecretsManagement::ProjectSecretsManager.new.user_auth_cel_program(project_id)
      }
    end

    before do
      client.enable_auth_engine(mount_path, 'jwt')
      client.configure_jwt(mount_path, server_url, jwk_signer)
    end

    it 'creates and reads a JWT role' do
      # Create the role
      client.update_jwt_cel_role(mount_path, role_name, **role_data)

      # Read the role back
      role = client.read_jwt_cel_role(mount_path, role_name)

      # Verify the role data
      expect(role).to be_present
      expect(role['bound_audiences']).to eq([server_url])
      expect(role['cel_program']).not_to be_empty
    end

    it 'raises an error when reading a non-existent role' do
      expect { client.read_jwt_cel_role(mount_path, 'non-existent-role') }
        .to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
    end
  end

  describe '#list_secrets' do
    let(:mount_path) { 'some/mount/path' }
    let(:other_mount_path) { 'other/mount/path' }
    let(:secrets_path) { 'secrets' }
    let(:target_mount_path) { mount_path }
    let(:target_secrets_path) { secrets_path }

    before do
      client.enable_secrets_engine(mount_path, 'kv-v2')
      client.enable_secrets_engine(other_mount_path, 'kv-v2')

      update_kv_secret_with_metadata(
        mount_path,
        "#{secrets_path}/DBPASS",
        'somevalue',
        environment: 'staging'
      )

      update_kv_secret_with_metadata(
        mount_path,
        "other_secrets/APIKEY",
        'somevalue',
        environment: 'staging'
      )

      update_kv_secret_with_metadata(
        other_mount_path,
        "#{secrets_path}/DEPLOYKEY",
        'somevalue',
        environment: 'staging'
      )
    end

    subject(:result) { client.list_secrets(target_mount_path, target_secrets_path) }

    it 'returns all matching secrets' do
      expect(result).to contain_exactly(
        a_hash_including(
          "key" => "DBPASS",
          "metadata" => a_hash_including(
            "current_version" => 1,
            "custom_metadata" => a_hash_including(
              "environment" => "staging"
            )
          )
        )
      )
    end

    context 'when mount path does not exist' do
      let(:target_mount_path) { 'something/else' }

      it_behaves_like 'making an invalid API request'
    end

    context 'when secrets path does not exist' do
      let(:target_secrets_path) { 'something/else' }

      it { is_expected.to eq([]) }
    end

    shared_context 'with stubbed detailed-metadata response' do |body|
      before do
        webmock_enable!(allow_localhost: false)

        stub_request(:get, "#{described_class.configuration.host}/v1/#{mount_path}/detailed-metadata/#{secrets_path}")
          .with(query: { list: 'true' })
          .to_return(status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      after do
        webmock_enable!(allow_localhost: true)
        WebMock.reset!
      end
    end

    context 'when OpenBao returns a response with no keys field' do
      include_context 'with stubbed detailed-metadata response', { data: {} }

      it 'raises ApiError' do
        expect { result }.to raise_error(described_class::ApiError, /missing keys field/)
      end
    end

    context 'when OpenBao returns a response with no key_info field' do
      include_context 'with stubbed detailed-metadata response', { data: { keys: ['DBPASS'] } }

      it 'raises ApiError' do
        expect { result }.to raise_error(described_class::ApiError, /missing key_info field/)
      end
    end

    context 'when block is given' do
      it 'yields each entry and returns in the list the returned value of each block' do
        result = client.list_secrets(mount_path, secrets_path) do |data|
          { new_data: data["key"] }
        end

        expect(result).to contain_exactly(new_data: "DBPASS")
      end
    end
  end

  describe '#count_secrets' do
    let(:mount_path) { 'some/mount/path' }
    let(:other_mount_path) { 'other/mount/path' }
    let(:secrets_path) { 'secrets' }
    let(:target_mount_path) { mount_path }
    let(:target_secrets_path) { secrets_path }

    before do
      client.enable_secrets_engine(mount_path, 'kv-v2')
      client.enable_secrets_engine(other_mount_path, 'kv-v2')

      update_kv_secret_with_metadata(
        mount_path,
        "#{secrets_path}/DBPASS",
        'somevalue',
        environment: 'staging'
      )

      update_kv_secret_with_metadata(
        mount_path,
        "other_secrets/APIKEY",
        'somevalue',
        environment: 'staging'
      )

      update_kv_secret_with_metadata(
        other_mount_path,
        "#{secrets_path}/DEPLOYKEY",
        'somevalue',
        environment: 'staging'
      )
    end

    subject(:result) { client.count_secrets(target_mount_path, target_secrets_path) }

    it 'returns the count of matching secrets' do
      expect(result).to eq(1)
    end

    context 'when mount path does not exist' do
      let(:target_mount_path) { 'something/else' }

      it_behaves_like 'making an invalid API request'
    end

    context 'when secrets path does not exist' do
      let(:target_secrets_path) { 'something/else' }

      it { is_expected.to eq(0) }
    end

    context 'when response has no keys' do
      before do
        allow(client).to receive(:make_request).and_call_original
        allow(client).to receive(:make_request)
          .with(
            :list,
            "#{mount_path}/metadata/#{secrets_path}",
            {},
            allow_not_found_response: true
          )
          .and_return({ "data" => {} })
      end

      it 'raises ApiError' do
        expect { result }.to raise_error(described_class::ApiError, /missing keys field/)
      end
    end

    context 'when limit is provided' do
      it 'passes the limit to the list request' do
        expect(client).to receive(:make_request)
          .with(
            :list,
            "#{mount_path}/metadata/#{secrets_path}",
            hash_including(limit: 1),
            allow_not_found_response: true
          )
          .and_call_original

        client.count_secrets(mount_path, secrets_path, limit: 1)
      end
    end
  end

  describe '#read_secret_metadata' do
    let(:existing_mount_path) { 'secrets' }
    let(:existing_secret_path) { 'DBPASS' }
    let(:mount_path) { existing_mount_path }
    let(:secret_path) { existing_secret_path }

    before do
      client.enable_secrets_engine(existing_mount_path, 'kv-v2')

      update_kv_secret_with_metadata(
        existing_mount_path,
        existing_secret_path,
        'somevalue',
        environment: 'staging'
      )
    end

    subject(:result) { client.read_secret_metadata(mount_path, secret_path) }

    context 'when the secret exists' do
      it 'returns the metadata' do
        expect(result).to match(
          a_hash_including(
            "custom_metadata" => a_hash_including(
              "environment" => "staging"
            )
          )
        )
      end
    end

    context 'when the mount path does not exist' do
      let(:mount_path) { 'something/else' }

      it_behaves_like 'making an invalid API request'
    end

    context 'when the secret does not exist' do
      let(:secret_path) { 'something/else' }

      it { is_expected.to be_nil }
    end
  end

  describe '#update_kv_secret' do
    let(:existing_mount_path) { 'some/test/path' }
    let(:mount_path) { existing_mount_path }
    let(:secret_path) { 'DBPASS' }
    let(:value) { 'somevalue' }
    let(:cas) { 0 }

    before do
      client.enable_secrets_engine(existing_mount_path, 'kv-v2')
    end

    subject(:call_api) { client.update_kv_secret(mount_path, secret_path, value, cas: cas) }

    context 'when the mount path exists' do
      context 'when the given secret path does not exist' do
        it 'creates the secret and the custom metadata' do
          call_api

          expect_kv_secret_to_have_value("", mount_path, secret_path, value)
        end

        it 'returns the response of the API call' do
          expect(call_api["data"]).to match(a_hash_including("version" => 1))
        end
      end

      context 'when the given secret path exists' do
        before do
          client.update_kv_secret(mount_path, secret_path, 'someexistingvalue')
        end

        context 'and given cas is 0' do
          it_behaves_like 'making an invalid API request'
        end

        context 'and given cas is not equal to the current version of the secret' do
          let(:cas) { 3 }

          it_behaves_like 'making an invalid API request'
        end

        shared_examples_for 'successful update' do
          it 'updates the secret value' do
            call_api

            expect_kv_secret_to_have_value("", mount_path, secret_path, value)
          end
        end

        context 'and given cas is equal to the current version of the secret' do
          let(:cas) { 1 }

          it_behaves_like 'successful update'
        end

        context 'and cas is not given' do
          let(:cas) { nil }

          it_behaves_like 'successful update'
        end
      end
    end

    context 'when the mount path does not exist' do
      let(:mount_path) { 'something/else' }

      it_behaves_like 'making an invalid API request'
    end
  end

  describe '#update_kv_secret_metadata' do
    let(:existing_mount_path) { 'some/test/path' }
    let(:mount_path) { existing_mount_path }
    let(:secret_path) { 'DBPASS' }
    let(:cas) { 0 }

    let(:custom_metadata) do
      {
        environment: 'staging'
      }
    end

    before do
      client.enable_secrets_engine(existing_mount_path, 'kv-v2')
    end

    subject(:call_api) { client.update_kv_secret_metadata(mount_path, secret_path, custom_metadata, metadata_cas: cas) }

    context 'when the mount path exists' do
      context 'when the given secret path does not exist' do
        it 'creates the secret and the custom metadata' do
          call_api

          expect_kv_secret_to_have_custom_metadata("", mount_path, secret_path, custom_metadata.stringify_keys)
        end
      end

      context 'when the given secret path exists' do
        before do
          client.update_kv_secret_metadata(mount_path, secret_path, { environment: 'prod' })
        end

        shared_examples_for 'updating custom metadata' do
          it 'updates the custom metadata' do
            call_api

            expect_kv_secret_to_have_custom_metadata("", mount_path, secret_path, custom_metadata.stringify_keys)
          end
        end

        context 'and the given metadata_cas matches the current version' do
          let(:cas) { 1 }

          it_behaves_like 'updating custom metadata'
        end

        context 'and no metadata_cas is given' do
          let(:cas) { nil }

          it_behaves_like 'updating custom metadata'
        end

        context 'and the given metadata_version does not match the current version' do
          it_behaves_like 'making an invalid API request'
        end
      end
    end

    context 'when the mount path does not exist' do
      let(:mount_path) { 'something/else' }

      it_behaves_like 'making an invalid API request'
    end
  end

  shared_context 'with policy management' do
    let(:name) { 'project_test' }

    let(:acl_policy) do
      SecretsManagement::AclPolicy.build_from_hash(
        name,
        {
          "path" => {
            "test/secrets/*" => {
              "capabilities" => ["create"],
              "required_parameters" => ["something_required"],
              "allowed_parameters" => {
                "something_allowed" => ["allowed_value"]
              },
              "denied_parameters" => {
                "something_denied" => ["denied_value"]
              }
            }
          }
        }
      )
    end
  end

  describe '#set_policy' do
    include_context 'with policy management'

    subject(:call_api) { client.set_policy(acl_policy) }

    it 'creates the policy' do
      call_api

      policy = client.get_policy(name)
      expect(policy.to_openbao_attributes).to match(
        acl_policy.to_openbao_attributes
      )
    end
  end

  describe '#list_policies' do
    let(:type) { nil }
    let(:test_ns) { "user_1234_test_list_policies" }
    let(:ns_client) { client.with_namespace(test_ns) }

    before do
      client.enable_namespace(test_ns)
    end

    subject(:result) { ns_client.list_policies(type: type) }

    context 'when no policies exist' do
      it 'returns an empty array' do
        expect(result).to eq([])
      end
    end

    context 'when policies exist' do
      before do
        # Create user policies
        ns_client.set_policy(SecretsManagement::AclPolicy.new("users/direct/user_123"))
        ns_client.set_policy(SecretsManagement::AclPolicy.new("users/direct/user_124"))
        ns_client.set_policy(SecretsManagement::AclPolicy.new("users/roles/50"))

        # Create pipeline policies
        ns_client.set_policy(SecretsManagement::AclPolicy.new("pipelines/global"))
        ns_client.set_policy(SecretsManagement::AclPolicy.new("pipelines/branch/6d61696e"))
      end

      context 'when type is not specified' do
        it 'returns all policies for the project' do
          expect(result).to be_an(Array)
          expect(result.size).to eq(5) # All policies

          policy_keys = result.pluck('key')
          expect(policy_keys).to contain_exactly(
            'users/direct/user_123',
            'users/direct/user_124',
            'users/roles/50',
            'pipelines/global',
            'pipelines/branch/6d61696e'
          )
        end
      end

      context 'when type is given' do
        let(:type) { :users }

        it 'returns only policies under the given type for the project' do
          expect(result).to be_an(Array)
          expect(result.size).to eq(3) # Only user policies

          policy_keys = result.pluck('key')
          expect(policy_keys).to contain_exactly(
            'users/direct/user_123',
            'users/direct/user_124',
            'users/roles/50'
          )
        end
      end

      context 'with a block' do
        it 'yields each policy data' do
          policies = []
          ns_client.list_policies(type: :users) do |policy_data|
            policies << policy_data['key']
          end

          expect(policies).to contain_exactly(
            'users/direct/user_123',
            'users/direct/user_124',
            'users/roles/50'
          )
        end
      end
    end
  end

  describe '#list_project_policies' do
    let(:project_id) { 123 }
    let(:type) { nil }

    subject(:result) { client.list_project_policies(project_id: project_id, type: type) }

    context 'when no policies exist' do
      it 'returns an empty array' do
        expect(result).to eq([])
      end
    end

    context 'when policies exist' do
      before do
        # Create user policies
        client.set_policy(SecretsManagement::AclPolicy.new("project_123/users/direct/user_123"))
        client.set_policy(SecretsManagement::AclPolicy.new("project_123/users/direct/user_124"))
        client.set_policy(SecretsManagement::AclPolicy.new("project_123/users/roles/50"))

        # Create pipeline policies
        client.set_policy(SecretsManagement::AclPolicy.new("project_123/pipelines/global"))
        client.set_policy(SecretsManagement::AclPolicy.new("project_123/pipelines/branch/6d61696e"))

        # Create a policy for a different project
        client.set_policy(SecretsManagement::AclPolicy.new("project_456/users/direct/user_789"))
      end

      context 'when type is not specified' do
        it 'returns all policies for the project' do
          expect(result).to be_an(Array)
          expect(result.size).to eq(5) # All project_123 policies

          policy_keys = result.pluck('key')
          expect(policy_keys).to contain_exactly(
            'project_123/users/direct/user_123',
            'project_123/users/direct/user_124',
            'project_123/users/roles/50',
            'project_123/pipelines/global',
            'project_123/pipelines/branch/6d61696e'
          )

          # Should not include policies from other projects
          expect(policy_keys).not_to include('project_456/users/direct/user_789')
        end
      end

      context 'when type is given' do
        let(:type) { :users }

        it 'returns only policies under the given type for the project' do
          expect(result).to be_an(Array)
          expect(result.size).to eq(3) # Only user policies

          policy_keys = result.pluck('key')
          expect(policy_keys).to contain_exactly(
            'project_123/users/direct/user_123',
            'project_123/users/direct/user_124',
            'project_123/users/roles/50'
          )
        end
      end

      context 'with a block' do
        it 'yields each policy data' do
          policies = []
          client.list_project_policies(project_id: project_id, type: :users) do |policy_data|
            policies << policy_data['key']
          end

          expect(policies).to contain_exactly(
            'project_123/users/direct/user_123',
            'project_123/users/direct/user_124',
            'project_123/users/roles/50'
          )
        end
      end
    end
  end

  describe '#get_policy' do
    include_context 'with policy management'

    subject(:result) { client.get_policy(name) }

    context 'when the policy exists' do
      before do
        client.set_policy(acl_policy)
      end

      it 'fetches the policy' do
        expect(result.to_openbao_attributes).to match(
          acl_policy.to_openbao_attributes
        )
      end
    end

    context 'when the policy does not exist' do
      it 'returns an empty policy object' do
        expect(result.to_openbao_attributes).to match(path: {})
      end
    end
  end

  describe '#delete_policy' do
    include_context 'with policy management'

    subject(:call_api) { client.delete_policy(name) }

    context 'when the policy exists' do
      before do
        client.set_policy(acl_policy)
      end

      it 'deletes the policy' do
        expect { call_api }.not_to raise_error

        policy = client.get_policy(name)
        expect(policy.to_openbao_attributes).to match(path: {})
      end
    end

    context 'when the policy does not exist' do
      it 'deletes nothing and fails silently' do
        expect { call_api }.not_to raise_error
      end
    end
  end

  describe '#capabilities_self' do
    # These tests exercise the real OpenBao capabilities-self endpoint using a
    # user-scoped CEL-authenticated client, following the same pattern as the
    # CEL authentication section above.
    let(:user_id) { '0' }
    let(:user_name) { 'caps_self_user' }
    let(:project_id) { '999' }
    let(:server_aud) { SecretsManagement::OpenbaoTestSetup::SERVER_ADDRESS_WITH_HTTP }
    let(:auth_mount) { "project_#{project_id}/users/direct/user_#{user_id}" }
    let(:user_jwt) do
      SecretsManagement::TestJwt.new(
        project_id: project_id,
        user_id: user_id,
        aud: server_aud,
        user_name: user_name,
        scope: :user
      ).encoded
    end

    let(:user_client) do
      described_class.new(jwt: user_jwt, role: role, auth_mount: auth_mount, use_cel_auth: true)
    end

    let(:mount_path) { 'caps/test/path' }
    let(:data_path) { "#{mount_path}/data/explicit/*" }
    let(:metadata_path) { "#{mount_path}/metadata/explicit/*" }

    before do
      allow(SecretsManagement::ProjectSecretsManager)
        .to receive(:server_url)
        .and_return(server_aud)

      client.enable_secrets_engine(mount_path, 'kv-v2')

      issuer = Gitlab.config.gitlab.url
      client.enable_auth_engine(auth_mount, 'jwt', allow_existing: true)
      client.configure_jwt(auth_mount, issuer, Gitlab::CurrentSettings.ci_jwt_signing_key)

      client.update_jwt_cel_role(
        auth_mount,
        role,
        cel_program: SecretsManagement::ProjectSecretsManager.new.user_auth_cel_program(project_id),
        bound_audiences: [server_aud]
      )
    end

    subject(:result) { user_client.capabilities_self(paths: [data_path, metadata_path]) }

    context 'when the user has no grant (no policy set)' do
      it 'returns deny for all requested paths' do
        expect(result[data_path]).to include('deny')
        expect(result[metadata_path]).to include('deny')
      end
    end

    context 'when the user has a read-only grant on the metadata path' do
      before do
        policy_name = "users/direct/user_#{user_id}"
        policy_body = {
          "path" => {
            metadata_path => { "capabilities" => %w[read list] }
          }
        }
        client.set_policy(SecretsManagement::AclPolicy.build_from_hash(policy_name, policy_body))
      end

      it 'returns read and list capabilities on the metadata path' do
        expect(result[metadata_path]).to include('read', 'list')
      end

      it 'returns deny on the data path (no grant)' do
        expect(result[data_path]).to include('deny')
      end
    end

    context 'when the user has a read+write+delete grant' do
      before do
        policy_name = "users/direct/user_#{user_id}"
        policy_body = {
          "path" => {
            data_path => { "capabilities" => %w[create update delete] },
            metadata_path => { "capabilities" => %w[read list] }
          }
        }
        client.set_policy(SecretsManagement::AclPolicy.build_from_hash(policy_name, policy_body))
      end

      it 'returns create, update, delete on the data path' do
        expect(result[data_path]).to include('create', 'update', 'delete')
      end

      it 'returns read and list on the metadata path' do
        expect(result[metadata_path]).to include('read', 'list')
      end

      it 'returns a per-path map keyed by each requested path' do
        expect(result).to have_key(data_path)
        expect(result).to have_key(metadata_path)
      end
    end

    context 'when a single path is requested' do
      subject(:single_result) { user_client.capabilities_self(paths: [metadata_path]) }

      before do
        policy_name = "users/direct/user_#{user_id}"
        policy_body = {
          "path" => {
            metadata_path => { "capabilities" => %w[read list] }
          }
        }
        client.set_policy(SecretsManagement::AclPolicy.build_from_hash(policy_name, policy_body))
      end

      it 'returns the per-path map for the single path' do
        expect(single_result[metadata_path]).to include('read', 'list')
      end

      it 'includes the back-compat capabilities key' do
        expect(single_result).to have_key('capabilities')
      end
    end

    context 'when capabilities are scoped to the correct secrets-manager namespace' do
      let(:other_mount_path) { 'other/caps/path' }
      let(:other_data_path) { "#{other_mount_path}/data/explicit/*" }

      before do
        client.enable_secrets_engine(other_mount_path, 'kv-v2')

        # Grant only on the primary mount, not the other one
        policy_name = "users/direct/user_#{user_id}"
        policy_body = {
          "path" => {
            data_path => { "capabilities" => %w[create update] }
          }
        }
        client.set_policy(SecretsManagement::AclPolicy.build_from_hash(policy_name, policy_body))
      end

      it 'grants capabilities only on the granted path, not on unrelated paths' do
        result_with_other = user_client.capabilities_self(paths: [data_path, other_data_path])

        expect(result_with_other[data_path]).to include('create', 'update')
        expect(result_with_other[other_data_path]).to include('deny')
      end
    end

    context 'when cleaning up the minted token' do
      it 'revokes the minted token after resolving capabilities' do
        expect(user_client).to receive(:revoke_self).and_call_original

        user_client.capabilities_self(paths: [data_path, metadata_path])
      end

      it 'does not raise when token revocation fails (best-effort cleanup)' do
        expect { user_client.send(:revoke_self, 'invalid-token') }.not_to raise_error
      end
    end
  end

  describe '#delete_kv_secret' do
    let(:existing_mount_path) { 'secrets' }
    let(:existing_secret_path) { 'DBPASS' }
    let(:mount_path) { existing_mount_path }
    let(:secret_path) { existing_secret_path }

    subject(:call_api) { client.delete_kv_secret(mount_path, secret_path) }

    before do
      client.enable_secrets_engine(existing_mount_path, 'kv-v2')

      update_kv_secret_with_metadata(
        existing_mount_path,
        existing_secret_path,
        'somevalue',
        environment: 'staging'
      )
    end

    context 'when the mount path exists' do
      context 'when the given secret path exists' do
        it 'deletes the secret permanently' do
          call_api

          expect_kv_secret_not_to_exist("", mount_path, secret_path)
        end
      end

      context 'when the given secret path does not exist' do
        let(:secret_path) { 'SOMETHING_ELSE' }

        it 'does not fail' do
          expect { call_api }.not_to raise_error
        end
      end
    end

    context 'when the mount path does not exist' do
      let(:mount_path) { 'something/else' }

      it_behaves_like 'making an invalid API request'
    end
  end

  describe '#delete_jwt_role' do
    let(:mount_path) { 'auth/testing/pipeline_jwt' }
    let(:role_name) { 'test-role' }
    let(:server_url) { 'https://gitlab.example.com' }
    let(:jwk_signer) { Gitlab::CurrentSettings.ci_jwt_signing_key }

    let(:role_data) do
      {
        role_type: 'jwt',
        user_claim: 'project_id',
        bound_claims: { project_id: 123 },
        token_policies: ['test-policy']
      }
    end

    subject(:result) { client.delete_jwt_role(mount_path, role_name) }

    context 'when the auth mount exists' do
      before do
        client.enable_auth_engine(mount_path, 'jwt')
        client.configure_jwt(mount_path, server_url, jwk_signer)
      end

      context 'when the role exists' do
        before do
          client.update_jwt_role(mount_path, role_name, **role_data)
        end

        it 'deletes the JWT role' do
          # Verify role exists first
          expect(client.read_jwt_role(mount_path, role_name)).to be_present

          expect { result }.not_to raise_error
          expect(result).to be_nil

          # Verify role does not exist anymore
          expect { client.read_jwt_role(mount_path, role_name) }
            .to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
        end
      end

      context 'when the role does not exist' do
        let(:role_name) { 'non-existent-role' }

        it 'fails silently' do
          expect { result }.not_to raise_error
          expect(result).to be_nil
        end
      end
    end

    context 'when the auth mount does not exist' do
      let(:mount_path) { 'auth/non-existent-mount' }

      it 'raises an error' do
        expect { result }.to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
      end
    end
  end

  describe '#delete_jwt_cel_role' do
    let(:mount_path) { 'auth/testing/pipeline_jwt' }
    let(:role_name) { 'test-role' }
    let(:server_url) { 'https://gitlab.example.com' }
    let(:jwk_signer) { Gitlab::CurrentSettings.ci_jwt_signing_key }
    let(:project_id) { 1234 }

    let(:role_data) do
      {
        bound_audiences: [server_url],
        cel_program: SecretsManagement::ProjectSecretsManager.new.user_auth_cel_program(project_id)
      }
    end

    subject(:result) { client.delete_jwt_cel_role(mount_path, role_name) }

    context 'when the auth mount exists' do
      before do
        client.enable_auth_engine(mount_path, 'jwt')
        client.configure_jwt(mount_path, server_url, jwk_signer)
      end

      context 'when the role exists' do
        before do
          client.update_jwt_cel_role(mount_path, role_name, **role_data)
        end

        it 'deletes the JWT role' do
          # Verify role exists first
          expect(client.read_jwt_cel_role(mount_path, role_name)).to be_present

          expect { result }.not_to raise_error
          expect(result).to be_nil

          # Verify role does not exist anymore
          expect { client.read_jwt_cel_role(mount_path, role_name) }
            .to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
        end
      end

      context 'when the role does not exist' do
        let(:role_name) { 'non-existent-role' }

        it 'fails silently' do
          expect { result }.not_to raise_error
          expect(result).to be_nil
        end
      end
    end

    context 'when the auth mount does not exist' do
      let(:mount_path) { 'auth/non-existent-mount' }

      it 'raises an error' do
        expect { result }.to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
      end
    end
  end

  describe "CEL authentication" do
    let(:user_id) { '0' }
    let(:user_name) { 'user' }
    let(:project_id) { '123' }
    let(:server_aud) { SecretsManagement::OpenbaoTestSetup::SERVER_ADDRESS_WITH_HTTP }
    let(:auth_mount) { "project_#{project_id}/users/direct/user_#{user_id}" }
    let(:jwt) do
      SecretsManagement::TestJwt.new(
        project_id: project_id,
        user_id: user_id,
        aud: server_aud,
        user_name: user_name,
        scope: :user
      ).encoded
    end

    let(:user_client) { described_class.new(jwt: jwt, role: role, auth_mount: auth_mount, use_cel_auth: true) }

    before do
      allow(SecretsManagement::ProjectSecretsManager)
        .to receive(:server_url)
        .and_return(server_aud)
    end

    describe '#inline_auth_path' do
      it 'returns CEL login path instead of regular JWT login path' do
        expect(user_client.inline_auth_path).to eq("auth/#{auth_mount}/cel/login")
      end

      it 'differs from the default class auth path' do
        default_client = described_class.new(jwt: jwt, role: role, auth_mount: auth_mount)

        expect(user_client.inline_auth_path).to eq("auth/#{auth_mount}/cel/login")
        expect(default_client.inline_auth_path).to eq("auth/#{auth_mount}/login")
        expect(user_client.inline_auth_path).not_to eq(default_client.inline_auth_path)
      end
    end

    describe 'CEL mounted requests' do
      let(:mount_path) { 'some/test/path' }
      let(:other_mount_path) { 'other/mount/path' }
      let(:engine) { 'kv-v2' }
      let(:secrets_path) { 'secrets' }

      before do
        client.enable_secrets_engine(mount_path, 'kv-v2')
        client.enable_secrets_engine(other_mount_path, 'kv-v2')

        update_kv_secret_with_metadata(
          mount_path,
          "#{secrets_path}/DBPASS",
          'somevalue',
          environment: 'staging'
        )

        issuer = Gitlab.config.gitlab.url
        client.enable_auth_engine(auth_mount, 'jwt', allow_existing: true)
        client.configure_jwt(auth_mount, issuer, Gitlab::CurrentSettings.ci_jwt_signing_key)

        client.update_jwt_cel_role(
          auth_mount,
          role,
          cel_program: SecretsManagement::ProjectSecretsManager.new.user_auth_cel_program(project_id),
          bound_audiences: [server_aud]
        )

        policy_name = "users/direct/user_#{user_id}"
        policy_body = {
          "path" => {
            # list on detailed-metadata and read on metadata is enough for list_secrets
            "#{mount_path}/detailed-metadata/*" => { "capabilities" => ["list"] },
            "#{mount_path}/metadata/*" => { "capabilities" => ["read"] }
          }
        }
        client.set_policy(
          SecretsManagement::AclPolicy.build_from_hash(policy_name, policy_body)
        )
      end

      it 'lists secrets' do
        result = user_client.list_secrets(mount_path, secrets_path) do |data|
          { new_data: data["key"] }
        end

        expect(result).to contain_exactly(new_data: "DBPASS")
      end

      # Mirrors the persisted (non-inline) login the capabilities check uses:
      # a clean connection with no inline-auth headers, posting the jwt to the
      # CEL login path. The minted token's lease_duration reflects the TTL the
      # CEL program sets via pb.Auth lease_options.
      def cel_login(login_jwt)
        conn = Faraday.new(
          url: URI.join(described_class.configuration.host, described_class.configuration.base_path)
        ) do |f|
          f.request :json
          f.response :json
        end

        conn.post("auth/#{auth_mount}/cel/login", { role: role, jwt: login_jwt })
      end

      it 'defaults the minted token TTL to 5 minutes' do
        response = cel_login(jwt)

        expect(response.body.dig("auth", "lease_duration")).to eq(300)
      end

      it 'honors a secrets_manager_token_ttl claim for the minted token TTL' do
        response = cel_login(user_jwt_with_ttl(600))

        expect(response.body.dig("auth", "lease_duration")).to eq(600)
      end

      it 'falls back to the 5 minute default for a non-positive claim' do
        response = cel_login(user_jwt_with_ttl(0))

        expect(response.body.dig("auth", "lease_duration")).to eq(300)
      end

      def user_jwt_with_ttl(ttl)
        SecretsManagement::TestJwt.new(
          project_id: project_id,
          user_id: user_id,
          aud: server_aud,
          user_name: user_name,
          scope: :user,
          token_ttl: ttl
        ).encoded
      end
    end

    describe '#init_rotate_recovery' do
      subject(:init_rotate_recovery) { client.init_rotate_recovery }

      let(:response) { init_rotate_recovery }
      let(:mocked_response) { '{"request_id"=>"id", "data"=>{"keys"=>["key"]}}' }

      before do
        stub_request(:post, "#{described_class.configuration.host}/v1/sys/rotate/recovery/init")
          .to_return(body: mocked_response)
      end

      it 'configures the JWT auth method' do
        expect(response).to eq(mocked_response)
      end
    end

    describe '#cancel_rotate_recovery' do
      subject(:cancel_rotate_recovery) { client.cancel_rotate_recovery }

      let(:response) { cancel_rotate_recovery }
      let(:mocked_response) { '' }

      before do
        stub_request(:delete, "#{described_class.configuration.host}/v1/sys/rotate/recovery/cancel")
      end

      it 'sends DELETE and returns nil' do
        expect(response).to be_nil
      end
    end
  end

  describe '#parse_policy_metadata' do
    let(:policy_name) { 'test_policy' }

    context 'when policy JSON is present in raw_metadata' do
      let(:policy_hash) do
        {
          "path" => {
            "test/secrets/*" => {
              "capabilities" => %w[create read],
              "required_parameters" => ["something_required"],
              "allowed_parameters" => {
                "something_allowed" => ["allowed_value"]
              },
              "denied_parameters" => {
                "something_denied" => ["denied_value"]
              }
            }
          }
        }
      end

      let(:raw_metadata) do
        {
          "policy" => policy_hash.to_json
        }
      end

      it 'parses the policy JSON and returns an AclPolicy object' do
        result = client.send(:parse_policy_metadata, policy_name, raw_metadata)

        expect(result).to be_a(SecretsManagement::AclPolicy)
        expect(result.name).to eq(policy_name)

        attributes = result.to_openbao_attributes
        expect(attributes[:path]).to have_key("test/secrets/*")
        expect(attributes[:path]["test/secrets/*"]["capabilities"]).to contain_exactly("create", "read")
        expect(attributes[:path]["test/secrets/*"]["required_parameters"]).to contain_exactly("something_required")
        expect(attributes[:path]["test/secrets/*"]["allowed_parameters"]).to eq({
          "something_allowed" => ["allowed_value"]
        })
        expect(attributes[:path]["test/secrets/*"]["denied_parameters"]).to eq({
          "something_denied" => ["denied_value"]
        })
      end
    end

    context 'when policy JSON is nil in raw_metadata' do
      let(:raw_metadata) do
        {
          "policy" => nil
        }
      end

      it 'returns early without parsing JSON when policy_json is nil' do
        expect(Gitlab::Json).not_to receive(:parse)
        expect(SecretsManagement::AclPolicy).not_to receive(:build_from_hash)

        result = client.send(:parse_policy_metadata, policy_name, raw_metadata)

        expect(result).to be_a(SecretsManagement::AclPolicy)
        expect(result.name).to eq(policy_name)
        expect(result.to_openbao_attributes).to eq({ path: {} })
      end
    end

    context 'when policy key is missing from raw_metadata' do
      let(:raw_metadata) do
        {
          "other_key" => "some_value"
        }
      end

      it 'returns an empty AclPolicy object with the given name' do
        result = client.send(:parse_policy_metadata, policy_name, raw_metadata)

        expect(result).to be_a(SecretsManagement::AclPolicy)
        expect(result.name).to eq(policy_name)
        expect(result.to_openbao_attributes).to eq({ path: {} })
      end
    end

    context 'when raw_metadata is empty' do
      let(:raw_metadata) { {} }

      it 'returns an empty AclPolicy object with the given name' do
        result = client.send(:parse_policy_metadata, policy_name, raw_metadata)

        expect(result).to be_a(SecretsManagement::AclPolicy)
        expect(result.name).to eq(policy_name)
        expect(result.to_openbao_attributes).to eq({ path: {} })
      end
    end
  end

  describe '.server_available?' do
    let(:health_params) { { standbyok: true, sealedcode: 200, uninitcode: 200 } }

    context 'when OpenBao is healthy' do
      before do
        allow(client).to receive(:make_request).with(:get, "sys/health", health_params)
          .and_return({ "initialized" => true, "sealed" => false })
      end

      it 'returns true' do
        expect(client.server_available?).to be true
      end

      it 'does not log' do
        expect(Gitlab::AppLogger).not_to receive(:warn)

        client.server_available?
      end
    end

    context 'when OpenBao is on a standby node' do
      before do
        allow(client).to receive(:make_request).with(:get, "sys/health", health_params)
          .and_return({ "initialized" => true, "sealed" => false, "standby" => true })
      end

      it 'returns true' do
        expect(client.server_available?).to be true
      end
    end

    context 'when OpenBao is not initialized' do
      before do
        allow(client).to receive(:make_request).with(:get, "sys/health", health_params)
          .and_return({ "initialized" => false, "sealed" => false })
      end

      it 'returns false and logs the reason' do
        expect(Gitlab::AppLogger).to receive(:warn).with(
          hash_including(
            message: '[OpenBao] health check returned unhealthy',
            reason: 'not_initialized',
            initialized: false,
            sealed: false
          )
        )

        expect(client.server_available?).to be false
      end
    end

    context 'when OpenBao is sealed' do
      before do
        allow(client).to receive(:make_request).with(:get, "sys/health", health_params)
          .and_return({ "initialized" => true, "sealed" => true })
      end

      it 'returns false and logs the reason' do
        expect(Gitlab::AppLogger).to receive(:warn).with(
          hash_including(
            message: '[OpenBao] health check returned unhealthy',
            reason: 'sealed',
            initialized: true,
            sealed: true
          )
        )

        expect(client.server_available?).to be false
      end
    end

    context 'when health response is missing keys' do
      before do
        allow(client).to receive(:make_request).with(:get, "sys/health", health_params)
          .and_return({ "initialized" => true })
      end

      it 'returns false and treats missing sealed as sealed' do
        expect(Gitlab::AppLogger).to receive(:warn).with(
          hash_including(message: '[OpenBao] health check returned unhealthy', reason: 'sealed')
        )

        expect(client.server_available?).to be false
      end
    end

    context 'when API request raises ConnectionError' do
      before do
        allow(client).to receive(:make_request).with(:get, "sys/health", health_params)
          .and_raise(SecretsManagement::SecretsManagerClient::ConnectionError, 'cannot reach host')
      end

      it 'returns false and logs the error class' do
        expect(Gitlab::AppLogger).to receive(:warn).with(
          hash_including(
            message: '[OpenBao] health check failed',
            reason: 'SecretsManagement::SecretsManagerClient::ConnectionError',
            error: 'cannot reach host'
          )
        )

        expect(client.server_available?).to be false
      end
    end

    context 'when API request raises ApiError' do
      before do
        allow(client).to receive(:make_request).with(:get, "sys/health", health_params)
          .and_raise(SecretsManagement::SecretsManagerClient::ApiError, 'boom')
      end

      it 'returns false and logs the error class' do
        expect(Gitlab::AppLogger).to receive(:warn).with(
          hash_including(
            message: '[OpenBao] health check failed',
            reason: 'SecretsManagement::SecretsManagerClient::ApiError'
          )
        )

        expect(client.server_available?).to be false
      end
    end

    context 'when API request raises ServiceUnavailableError' do
      before do
        allow(client).to receive(:make_request).with(:get, "sys/health", health_params)
          .and_raise(SecretsManagement::SecretsManagerClient::ServiceUnavailableError, 'OpenBao service unavailable')
      end

      it 'returns false and logs the error class' do
        expect(Gitlab::AppLogger).to receive(:warn).with(
          hash_including(
            message: '[OpenBao] health check failed',
            reason: 'SecretsManagement::SecretsManagerClient::ServiceUnavailableError'
          )
        )

        expect(client.server_available?).to be false
      end
    end
  end
end
