# frozen_string_literal: true

require 'spec_helper'
RSpec.describe SecretsManagement::ProjectSecretsManagers::ProvisionService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:service) { described_class.new(secrets_manager, user) }

  subject(:result) { service.execute }

  before do
    stub_feature_flags(secrets_manager_paid_experience: false)
  end

  describe '#execute' do
    it_behaves_like 'a secrets manager entitlement gate' do
      let(:gated_action) { 'provisioned' }
    end

    it 'enables the secret engine for the project and activates the secret manager', :aggregate_failures do
      expect(result).to be_success

      expect(secrets_manager.reload).to be_active

      expect_kv_secret_engine_to_be_mounted(
        secrets_manager.full_project_namespace_path,
        secrets_manager.ci_secrets_mount_path
      )
      expect_jwt_auth_engine_to_be_mounted(
        secrets_manager.full_project_namespace_path,
        secrets_manager.ci_auth_mount
      )
    end

    it 'configures JWT CEL pipeline auth role with correct settings', :aggregate_failures do
      result

      client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
      jwt_role = client.read_jwt_cel_role(
        secrets_manager.ci_auth_mount,
        secrets_manager.ci_auth_role)

      expect(jwt_role).to be_present
      expect(jwt_role["bound_audiences"]).to include(SecretsManagement::ProjectSecretsManager.server_url)
      expect(jwt_role["name"]).to eq(secrets_manager.ci_auth_role)
      expect(jwt_role["cel_program"]).to eq(
        secrets_manager.pipeline_auth_cel_program(project.id.to_s).deep_stringify_keys
      )
    end

    it 'configures JWT CEL user auth role with correct settings', :aggregate_failures do
      result

      client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
      jwt_role = client.read_jwt_cel_role(
        secrets_manager.user_auth_mount,
        secrets_manager.user_auth_role)

      expect(jwt_role).to be_present
      expect(jwt_role["token_policies"]).to be_nil
      expect(jwt_role["bound_audiences"]).to include(SecretsManagement::ProjectSecretsManager.jwt_audience)
      expect(jwt_role["name"]).to eq(secrets_manager.user_auth_role)
      expect(jwt_role["cel_program"]).to eq(secrets_manager.user_auth_cel_program(project.id.to_s).deep_stringify_keys)
    end

    it 'configures JWT CEL API auth role with correct settings', :aggregate_failures do
      result

      client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
      jwt_role = client.read_jwt_cel_role(
        secrets_manager.api_auth_mount,
        secrets_manager.api_auth_role)

      expect(jwt_role).to be_present
      expect(jwt_role["bound_audiences"]).to include(SecretsManagement::ProjectSecretsManager.jwt_audience)
      expect(jwt_role["name"]).to eq(secrets_manager.api_auth_role)
      expect(jwt_role["cel_program"]).to eq(secrets_manager.api_auth_cel_program(project.id.to_s).deep_stringify_keys)
    end

    it_behaves_like 'an operation requiring an exclusive project secret operation lease', 120.seconds

    context 'when the secrets manager is already active' do
      before do
        secrets_manager.activate!
      end

      it 'completes successfully without changing the status' do
        expect(result).to be_success
        expect(secrets_manager.reload).to be_active

        # Verify the engines are still mounted
        expect_kv_secret_engine_to_be_mounted(
          secrets_manager.full_project_namespace_path,
          secrets_manager.ci_secrets_mount_path
        )
        expect_jwt_auth_engine_to_be_mounted(
          secrets_manager.full_project_namespace_path,
          secrets_manager.ci_auth_mount
        )
      end
    end

    context 'when the parent namespace has already been enabled' do
      before do
        clean_all_kv_secrets_engines
        clean_all_pipeline_jwt_engines
        clean_all_namespaces

        secrets_manager_client.enable_namespace(secrets_manager.org_path)
        org_client = secrets_manager_client.with_namespace(secrets_manager.org_path)
        org_client.enable_namespace(secrets_manager.namespace_path)
      end

      it 'still activates the secrets manager and creates the JWT' do
        expect(result).to be_success

        expect(secrets_manager.reload).to be_active

        expect_kv_secret_engine_to_be_mounted(
          secrets_manager.full_project_namespace_path,
          secrets_manager.ci_secrets_mount_path
        )
        expect_jwt_auth_engine_to_be_mounted(
          secrets_manager.full_project_namespace_path,
          secrets_manager.ci_auth_mount
        )
      end
    end

    context 'when the project namespace has already been enabled' do
      before do
        clean_all_kv_secrets_engines
        clean_all_pipeline_jwt_engines
        clean_all_namespaces

        secrets_manager_client.enable_namespace(secrets_manager.org_path)
        org_client = secrets_manager_client.with_namespace(secrets_manager.org_path)
        org_client.enable_namespace(secrets_manager.namespace_path)
        namespace_client = secrets_manager_client.with_namespace(
          [secrets_manager.org_path, secrets_manager.namespace_path].join('/')
        )
        namespace_client.enable_namespace(secrets_manager.project_path)
      end

      it 'still activates the secrets manager and creates the JWT' do
        expect(result).to be_success

        expect(secrets_manager.reload).to be_active

        expect_kv_secret_engine_to_be_mounted(
          secrets_manager.full_project_namespace_path,
          secrets_manager.ci_secrets_mount_path
        )
        expect_jwt_auth_engine_to_be_mounted(
          secrets_manager.full_project_namespace_path,
          secrets_manager.ci_auth_mount
        )
      end
    end

    context 'when the secrets engine has already been enabled' do
      before do
        clean_all_kv_secrets_engines
        clean_all_pipeline_jwt_engines
        clean_all_namespaces

        secrets_manager_client.enable_namespace(secrets_manager.org_path)
        org_client = secrets_manager_client.with_namespace(secrets_manager.org_path)
        org_client.enable_namespace(secrets_manager.namespace_path)
        namespace_client = secrets_manager_client.with_namespace(
          [secrets_manager.org_path, secrets_manager.namespace_path].join('/')
        )
        namespace_client.enable_namespace(secrets_manager.project_path)

        client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
        client.enable_secrets_engine(
          secrets_manager.ci_secrets_mount_path,
          described_class::SECRETS_ENGINE_TYPE
        )
      end

      it 'still activates the secrets manager and creates the JWT' do
        expect(result).to be_success

        expect(secrets_manager.reload).to be_active

        expect_kv_secret_engine_to_be_mounted(
          secrets_manager.full_project_namespace_path,
          secrets_manager.ci_secrets_mount_path
        )
        expect_jwt_auth_engine_to_be_mounted(
          secrets_manager.full_project_namespace_path,
          secrets_manager.ci_auth_mount
        )
      end
    end

    context 'when the auth engine has already been enabled' do
      before do
        clean_all_kv_secrets_engines
        clean_all_pipeline_jwt_engines
        clean_all_namespaces

        secrets_manager_client.enable_namespace(secrets_manager.org_path)
        org_client = secrets_manager_client.with_namespace(secrets_manager.org_path)
        org_client.enable_namespace(secrets_manager.namespace_path)
        namespace_client = secrets_manager_client.with_namespace(
          [secrets_manager.org_path, secrets_manager.namespace_path].join('/')
        )
        namespace_client.enable_namespace(secrets_manager.project_path)

        client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
        client.enable_auth_engine(secrets_manager.ci_auth_mount, secrets_manager.ci_auth_type)
      end

      it 'still activates the secrets manager and creates the KV mount' do
        expect(result).to be_success

        expect(secrets_manager.reload).to be_active

        expect_kv_secret_engine_to_be_mounted(
          secrets_manager.full_project_namespace_path,
          secrets_manager.ci_secrets_mount_path
        )
        expect_jwt_auth_engine_to_be_mounted(
          secrets_manager.full_project_namespace_path,
          secrets_manager.ci_auth_mount
        )

        client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
        expect { client.read_jwt_cel_role(secrets_manager.ci_auth_mount, secrets_manager.ci_auth_role) }
          .not_to raise_error
      end
    end

    context 'when both the secrets engine and auth engine already exist' do
      before do
        clean_all_kv_secrets_engines
        clean_all_pipeline_jwt_engines
        clean_all_namespaces

        secrets_manager_client.enable_namespace(secrets_manager.org_path)
        org_client = secrets_manager_client.with_namespace(secrets_manager.org_path)
        org_client.enable_namespace(secrets_manager.namespace_path)
        namespace_client = secrets_manager_client.with_namespace(
          [secrets_manager.org_path, secrets_manager.namespace_path].join('/')
        )
        namespace_client.enable_namespace(secrets_manager.project_path)

        client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
        client.enable_secrets_engine(
          secrets_manager.ci_secrets_mount_path,
          described_class::SECRETS_ENGINE_TYPE
        )

        client.enable_auth_engine(
          secrets_manager.ci_auth_mount,
          secrets_manager.ci_auth_type
        )
      end

      it 'activates the secrets manager and configures the JWT CEL role' do
        expect(result).to be_success
        expect(secrets_manager.reload).to be_active

        # Check that JWT CEL role was properly configured
        client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
        jwt_role = client.read_jwt_cel_role(secrets_manager.ci_auth_mount, secrets_manager.ci_auth_role)
        expect(jwt_role).to be_present
        expect(jwt_role["cel_program"]).to eq(
          secrets_manager.pipeline_auth_cel_program(project.id.to_s).deep_stringify_keys
        )
        expect(jwt_role["bound_audiences"]).to include(SecretsManagement::ProjectSecretsManager.jwt_audience)
      end

      it 'updates the bound_audience' do
        expect(result).to be_success
        expect(secrets_manager.reload).to be_active

        # Check that JWT role was properly configured
        jwt_role = secrets_manager_client.read_jwt_role('gitlab_rails_jwt', 'app')
        expect(jwt_role).to be_present

        # Verify the specifics of JWT role configuration
        expect(jwt_role["bound_audiences"]).to include('http://127.0.0.1:9800')
      end
    end

    context 'when the auth engines were enabled but left unconfigured by an interrupted attempt' do
      before do
        clean_all_kv_secrets_engines
        clean_all_pipeline_jwt_engines
        clean_all_namespaces

        secrets_manager_client.enable_namespace(secrets_manager.org_path)
        org_client = secrets_manager_client.with_namespace(secrets_manager.org_path)
        org_client.enable_namespace(secrets_manager.namespace_path)
        namespace_client = secrets_manager_client.with_namespace(
          [secrets_manager.org_path, secrets_manager.namespace_path].join('/')
        )
        namespace_client.enable_namespace(secrets_manager.project_path)

        client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
        client.enable_auth_engine(secrets_manager.ci_auth_mount, secrets_manager.ci_auth_type)
        client.enable_auth_engine(secrets_manager.user_auth_mount, secrets_manager.user_auth_type)
      end

      it 'writes the JWT config for both auth mounts on retry', :aggregate_failures do
        expect(result).to be_success
        expect(secrets_manager.reload).to be_active

        expect_jwt_auth_engine_to_be_configured(
          secrets_manager.full_project_namespace_path,
          secrets_manager.ci_auth_mount
        )
        expect_jwt_auth_engine_to_be_configured(
          secrets_manager.full_project_namespace_path,
          secrets_manager.user_auth_mount
        )
      end
    end
  end

  describe 'JWT CEL roles' do
    it 'authenticates via CEL and returns expected policies', :aggregate_failures do
      result

      jwt = sign_test_jwt(
        {
          project_id: project.id.to_s,
          groups: [101, 102, 103],
          user_id: user.id.to_s,
          sub: "user:#{user.username}",
          member_role_id: '7',
          role_id: 'deploy',
          secrets_manager_scope: 'user'
        }
      )

      client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
      resp = client.cel_login_jwt(
        mount_path: secrets_manager.user_auth_mount,
        role: secrets_manager.user_auth_role,
        jwt: jwt
      )

      expect(resp.dig('auth', 'client_token')).to be_present
      policies = resp.dig('auth', 'policies')
      expect(policies).to include(
        "users/direct/user_#{user.id}",
        "users/direct/member_role_7",
        "users/direct/group_101",
        "users/direct/group_102",
        "users/direct/group_103",
        "users/roles/deploy"
      )
    end

    context 'when project_id is wrong' do
      it 'fails to authenticate via CEL', :aggregate_failures do
        result

        jwt = sign_test_jwt(
          {
            project_id: (project.id + 1).to_s,
            user_id: user.id.to_s,
            sub: "user:#{user.username}",
            secrets_manager_scope: 'user',
            groups: [101, 102, 103]
          }
        )

        expect do
          client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
          client.cel_login_jwt(
            mount_path: secrets_manager.user_auth_mount,
            role: secrets_manager.user_auth_role,
            jwt: jwt
          )
        end.to raise_error(
          SecretsManagement::SecretsManagerClient::ApiError,
          "error executing cel program: " \
            "CEL role '#{secrets_manager.user_auth_role}' blocked authorization with message: " \
            "token project_id does not match role base"
        )
      end
    end

    context 'when user_id is missing' do
      it 'fails to authenticate via CEL', :aggregate_failures do
        result
        jwt = sign_test_jwt(
          {
            project_id: project.id.to_s,
            groups: [101, 102, 103],
            sub: "user:#{user.username}",
            secrets_manager_scope: 'user',
            user_id: ""
          }
        )
        expect do
          client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
          client.cel_login_jwt(
            mount_path: secrets_manager.user_auth_mount,
            role: secrets_manager.user_auth_role,
            jwt: jwt
          )
        end.to raise_error(
          SecretsManagement::SecretsManagerClient::ApiError,
          "error executing cel program: CEL role '#{secrets_manager.user_auth_role}' " \
            "blocked authorization with message: missing user_id"
        )
      end
    end

    context 'when sub is missing' do
      it 'fails to authenticate via CEL', :aggregate_failures do
        result
        jwt = sign_test_jwt(
          {
            project_id: project.id.to_s,
            groups: [101, 102, 103],
            user_id: user.id.to_s,
            secrets_manager_scope: 'user',
            sub: ""
          }
        )
        expect do
          client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
          client.cel_login_jwt(
            mount_path: secrets_manager.user_auth_mount,
            role: secrets_manager.user_auth_role,
            jwt: jwt
          )
        end.to raise_error(
          SecretsManagement::SecretsManagerClient::ApiError,
          /blocked authorization with message: missing subject/
        )
      end
    end

    context 'when sub is invalid' do
      it 'fails to authenticate via CEL', :aggregate_failures do
        result
        jwt = sign_test_jwt(
          {
            project_id: project.id.to_s,
            groups: [101, 102, 103],
            user_id: user.id.to_s,
            secrets_manager_scope: 'user',
            sub: "invalid-subject"
          }
        )
        expect do
          client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
          client.cel_login_jwt(
            mount_path: secrets_manager.user_auth_mount,
            role: secrets_manager.user_auth_role,
            jwt: jwt
          )
        end.to raise_error(
          SecretsManagement::SecretsManagerClient::ApiError,
          /blocked authorization with message: invalid subject for user authentication/
        )
      end
    end

    context 'when secrets_manager_scope is missing' do
      it 'fails to authenticate via CEL', :aggregate_failures do
        result
        jwt = sign_test_jwt(
          { project_id: project.id.to_s,
            groups: [101, 102, 103],
            user_id: user.id.to_s,
            sub: "user:#{user.username}",
            secrets_manager_scope: "" }
        )
        expect do
          client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
          client.cel_login_jwt(
            mount_path: secrets_manager.user_auth_mount,
            role: secrets_manager.user_auth_role,
            jwt: jwt
          )
        end.to raise_error(
          SecretsManagement::SecretsManagerClient::ApiError,
          /blocked authorization with message: missing secrets_manager_scope/
        )
      end
    end

    context 'when secrets_manager_scope is invalid' do
      it 'fails to authenticate via CEL', :aggregate_failures do
        result
        jwt = sign_test_jwt(
          { project_id: project.id.to_s,
            groups: [101, 102, 103],
            user_id: user.id.to_s,
            sub: "user:#{user.username}",
            secrets_manager_scope: "invalid-scope" }
        )
        expect do
          client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
          client.cel_login_jwt(
            mount_path: secrets_manager.user_auth_mount,
            role: secrets_manager.user_auth_role,
            jwt: jwt
          )
        end.to raise_error(
          SecretsManagement::SecretsManagerClient::ApiError,
          /blocked authorization with message: invalid secrets_manager_scope/
        )
      end
    end

    it 'assign groups more than 25 groups' do
      result

      many = (1..30).to_a
      jwt = sign_test_jwt(
        project_id: project.id.to_s,
        user_id: user.id.to_s,
        sub: "user:#{user.username}",
        secrets_manager_scope: 'user',
        groups: many
      )

      client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
      resp = client.cel_login_jwt(
        mount_path: secrets_manager.user_auth_mount,
        role: secrets_manager.user_auth_role,
        jwt: jwt
      )

      policies = resp.dig('auth', 'policies') || []

      group_policies = policies.grep(%r{\Ausers/direct/group_})
      expect(group_policies.size).to eq(30)
    end
  end

  describe 'JWT CEL pipeline roles' do
    before do
      result
    end

    it 'authenticates via CEL and returns expected policies', :aggregate_failures do
      jwt = sign_test_jwt(
        {
          project_id: project.id.to_s,
          user_id: user.id.to_s,
          sub: "project_path:#{project.full_path}",
          secrets_manager_scope: 'pipeline',
          namespace_id: project.namespace.id.to_s,
          correlation_id: 'test-correlation-id',
          ref_type: 'branch',
          ref: 'main',
          environment: 'production'
        }
      )

      client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
      resp = client.cel_login_jwt(
        mount_path: secrets_manager.ci_auth_mount,
        role: secrets_manager.ci_auth_role,
        jwt: jwt
      )

      expect(resp.dig('auth', 'client_token')).to be_present
      policies = resp.dig('auth', 'policies')
      expect(policies).to include('pipelines/global')
      expect(policies).to include("pipelines/env/#{project_hex('production')}")
      expect(policies).to include("pipelines/branch/#{project_hex('main')}")
      expect(policies).to include(
        "pipelines/combined/env/#{project_hex('production')}/branch/#{project_hex('main')}"
      )

      metadata = resp.dig('auth', 'metadata')
      expect(metadata['project_id']).to eq(project.id.to_s)
      expect(metadata['user_id']).to eq(user.id.to_s)
      expect(metadata['correlation_id']).to eq('test-correlation-id')
      expect(metadata['namespace_id']).to eq(project.namespace.id.to_s)
    end

    it 'returns only global policy when no environment or branch', :aggregate_failures do
      jwt = sign_test_jwt(
        {
          project_id: project.id.to_s,
          user_id: user.id.to_s,
          sub: "project_path:#{project.full_path}",
          secrets_manager_scope: 'pipeline',
          namespace_id: project.namespace.id.to_s,
          correlation_id: 'test-correlation-id'
        }
      )

      client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
      resp = client.cel_login_jwt(
        mount_path: secrets_manager.ci_auth_mount,
        role: secrets_manager.ci_auth_role,
        jwt: jwt
      )

      policies = resp.dig('auth', 'policies')
      expect(policies).to include('pipelines/global')
    end

    context 'when project_id does not match' do
      it 'fails to authenticate via CEL' do
        jwt = sign_test_jwt(
          {
            project_id: (project.id + 1).to_s,
            user_id: user.id.to_s,
            sub: "project_path:#{project.full_path}",
            secrets_manager_scope: 'pipeline'
          }
        )

        expect do
          client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
          client.cel_login_jwt(
            mount_path: secrets_manager.ci_auth_mount,
            role: secrets_manager.ci_auth_role,
            jwt: jwt
          )
        end.to raise_error(
          SecretsManagement::SecretsManagerClient::ApiError,
          /blocked authorization with message: token project_id does not match project/
        )
      end
    end

    context 'when subject is missing' do
      it 'fails to authenticate via CEL' do
        jwt = sign_test_jwt(
          {
            project_id: project.id.to_s,
            user_id: user.id.to_s,
            sub: '',
            secrets_manager_scope: 'pipeline'
          }
        )

        expect do
          client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
          client.cel_login_jwt(
            mount_path: secrets_manager.ci_auth_mount,
            role: secrets_manager.ci_auth_role,
            jwt: jwt
          )
        end.to raise_error(
          SecretsManagement::SecretsManagerClient::ApiError,
          /blocked authorization with message: missing subject/
        )
      end
    end

    context 'when subject is invalid for pipeline' do
      it 'fails to authenticate via CEL' do
        jwt = sign_test_jwt(
          {
            project_id: project.id.to_s,
            user_id: user.id.to_s,
            sub: "user:#{user.username}",
            secrets_manager_scope: 'pipeline'
          }
        )

        expect do
          client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
          client.cel_login_jwt(
            mount_path: secrets_manager.ci_auth_mount,
            role: secrets_manager.ci_auth_role,
            jwt: jwt
          )
        end.to raise_error(
          SecretsManagement::SecretsManagerClient::ApiError,
          /blocked authorization with message: invalid subject for pipeline authentication/
        )
      end
    end

    context 'when secrets_manager_scope is invalid' do
      it 'fails to authenticate via CEL' do
        jwt = sign_test_jwt(
          {
            project_id: project.id.to_s,
            user_id: user.id.to_s,
            sub: "project_path:#{project.full_path}",
            secrets_manager_scope: 'user'
          }
        )

        expect do
          client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
          client.cel_login_jwt(
            mount_path: secrets_manager.ci_auth_mount,
            role: secrets_manager.ci_auth_role,
            jwt: jwt
          )
        end.to raise_error(
          SecretsManagement::SecretsManagerClient::ApiError,
          /blocked authorization with message: invalid secrets_manager_scope/
        )
      end
    end

    context 'when user_id is missing' do
      it 'fails to authenticate via CEL' do
        jwt = sign_test_jwt(
          {
            project_id: project.id.to_s,
            user_id: '',
            sub: "project_path:#{project.full_path}",
            secrets_manager_scope: 'pipeline'
          }
        )

        expect do
          client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
          client.cel_login_jwt(
            mount_path: secrets_manager.ci_auth_mount,
            role: secrets_manager.ci_auth_role,
            jwt: jwt
          )
        end.to raise_error(
          SecretsManagement::SecretsManagerClient::ApiError,
          /blocked authorization with message: missing user_id/
        )
      end
    end
  end

  context 'when aud is wrong' do
    it 'is rejected by the JWT role (bound_audiences) before CEL', :aggregate_failures do
      result

      jwt = sign_test_jwt(
        {
          project_id: project.id.to_s,
          groups: [101, 102, 103],
          user_id: user.id.to_s,
          sub: "user:#{user.username}",
          aud: 'http://wrong.com/aud'
        }
      )

      expect do
        client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
        client.cel_login_jwt(
          mount_path: secrets_manager.user_auth_mount,
          role: secrets_manager.user_auth_role,
          jwt: jwt
        )
      end.to raise_error(
        SecretsManagement::SecretsManagerClient::ApiError,
        "error validating token: " \
          "invalid audience (aud) claim: audience claim " \
          "does not match any expected audience"
      )
    end
  end

  def sign_test_jwt(claims)
    iss = SecretsManagement::ProjectSecretsManager.jwt_issuer
    aud = SecretsManagement::ProjectSecretsManager.jwt_audience
    ttl = 600

    priv = OpenSSL::PKey::RSA.new(Gitlab::CurrentSettings.ci_jwt_signing_key)
    now  = Time.now.to_i
    payload = { iss: iss, aud: aud, iat: now, exp: now + ttl }.merge(claims)
    JWT.encode(payload, priv, 'RS256')
  end

  def project_hex(value)
    value.unpack1('H*')
  end
end
