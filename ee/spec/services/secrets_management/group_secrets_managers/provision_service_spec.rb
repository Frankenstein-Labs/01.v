# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecretsManagers::ProvisionService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:secrets_manager) { create(:group_secrets_manager, group: group) }
  let(:service) { described_class.new(secrets_manager, user) }

  subject(:result) { service.execute }

  before do
    stub_feature_flags(secrets_manager_paid_experience: false)
  end

  describe '#execute' do
    it_behaves_like 'a secrets manager entitlement gate' do
      let(:gated_action) { 'provisioned' }
    end

    it 'enables the secret engine for the group and activates the secret manager', :aggregate_failures do
      expect(result).to be_success

      expect(secrets_manager.reload).to be_active

      expect_kv_secret_engine_to_be_mounted(
        secrets_manager.full_group_namespace_path,
        secrets_manager.ci_secrets_mount_path
      )
      expect_jwt_auth_engine_to_be_mounted(
        secrets_manager.full_group_namespace_path,
        secrets_manager.ci_auth_mount
      )
      expect_jwt_auth_engine_to_be_mounted(
        secrets_manager.full_group_namespace_path,
        secrets_manager.user_auth_mount
      )
    end

    it 'configures JWT CEL pipeline auth role with correct settings', :aggregate_failures do
      expect(result).to be_success

      client = secrets_manager_client.with_namespace(secrets_manager.full_group_namespace_path)
      jwt_role = client.read_jwt_cel_role(secrets_manager.ci_auth_mount, secrets_manager.ci_auth_role)

      expect(jwt_role).to be_present
      expect(jwt_role["bound_audiences"]).to include(SecretsManagement::GroupSecretsManager.jwt_audience)
      expect(jwt_role["name"]).to eq(secrets_manager.ci_auth_role)
      expect(jwt_role["cel_program"]).to eq(secrets_manager.pipeline_auth_cel_program(group.id).deep_stringify_keys)
    end

    it 'configures JWT CEL user auth role with correct settings', :aggregate_failures do
      expect(result).to be_success

      client = secrets_manager_client.with_namespace(secrets_manager.full_group_namespace_path)
      jwt_role = client.read_jwt_cel_role(
        secrets_manager.user_auth_mount,
        secrets_manager.user_auth_role
      )

      expect(jwt_role).to be_present
      expect(jwt_role["bound_audiences"]).to include(SecretsManagement::GroupSecretsManager.jwt_audience)
      expect(jwt_role["name"]).to eq(secrets_manager.user_auth_role)
      expect(jwt_role["cel_program"]).to eq(secrets_manager.user_auth_cel_program(group.id).deep_stringify_keys)
    end

    it 'configures JWT CEL API auth role with correct settings', :aggregate_failures do
      expect(result).to be_success

      client = secrets_manager_client.with_namespace(secrets_manager.full_group_namespace_path)
      jwt_role = client.read_jwt_cel_role(
        secrets_manager.api_auth_mount,
        secrets_manager.api_auth_role
      )

      expect(jwt_role).to be_present
      expect(jwt_role["bound_audiences"]).to include(SecretsManagement::GroupSecretsManager.jwt_audience)
      expect(jwt_role["name"]).to eq(secrets_manager.api_auth_role)
      expect(jwt_role["cel_program"]).to eq(secrets_manager.api_auth_cel_program(group.id).deep_stringify_keys)
    end

    it 'creates owner policy with correct permissions', :aggregate_failures do
      expect(result).to be_success

      policy_name = secrets_manager.policy_name_for_principal(
        principal_type: 'Role',
        principal_id: Gitlab::Access.sym_options_with_owner[:owner]
      )

      expect_policy_to_exist(secrets_manager.full_group_namespace_path, policy_name)

      client = secrets_manager_client.with_namespace(secrets_manager.full_group_namespace_path)
      policy = client.get_policy(policy_name)
      expect(policy).to be_present

      # Verify policy grants correct permissions on secret paths
      data_path = secrets_manager.ci_full_path('*')
      metadata_path = secrets_manager.ci_metadata_full_path('*')
      detailed_metadata_path = secrets_manager.detailed_metadata_path('*')

      # Check that policy has capabilities for the expected paths
      expect(policy.paths[data_path].capabilities).to include('create', 'update', 'delete', 'list', 'scan')
      expect(policy.paths[data_path].capabilities).not_to include('read')
      expect(policy.paths[metadata_path].capabilities).to include('create', 'update', 'delete', 'read', 'list',
        'scan')
      expect(policy.paths[detailed_metadata_path].capabilities).to include('list')
    end

    it_behaves_like 'an operation requiring an exclusive group secret operation lease', 120.seconds

    context 'when group has a parent' do
      let_it_be_with_reload(:parent_group) { create(:group) }

      before do
        group.parent = parent_group
        group.save!
      end

      after do
        # `let_it_be_with_reload` reloads from DB; reset parent so later
        # contexts in the same file don't observe this mutation.
        group.update!(parent: nil)
      end

      shared_examples_for 'handling groups with parent' do
        it 'creates namespaces and mounts engines successfully' do
          expect(result).to be_success

          expect(secrets_manager.reload).to be_active

          expect_kv_secret_engine_to_be_mounted(
            secrets_manager.full_group_namespace_path,
            secrets_manager.ci_secrets_mount_path
          )
        end
      end

      context 'and group parent has no existing namespace' do
        it_behaves_like 'handling groups with parent'
      end

      context 'and group parent has existing namespace' do
        before do
          parent_secrets_manager = create(:group_secrets_manager, group: parent_group)
          described_class.new(parent_secrets_manager, user).execute
        end

        it_behaves_like 'handling groups with parent'
      end
    end

    context 'when the secrets manager is already active' do
      before do
        secrets_manager.activate!
      end

      it 'completes successfully without changing the status' do
        expect(result).to be_success
        expect(secrets_manager.reload).to be_active

        # Verify the engines are still mounted
        expect_kv_secret_engine_to_be_mounted(
          secrets_manager.full_group_namespace_path,
          secrets_manager.ci_secrets_mount_path
        )
        expect_jwt_auth_engine_to_be_mounted(
          secrets_manager.full_group_namespace_path,
          secrets_manager.ci_auth_mount
        )
      end
    end

    context 'when the root namespace has already been enabled' do
      before do
        secrets_manager_client.enable_namespace(secrets_manager.org_path)
        org_client = secrets_manager_client.with_namespace(secrets_manager.org_path)
        org_client.enable_namespace(secrets_manager.root_namespace_path)
      end

      it 'still activates the secrets manager and creates the JWT' do
        expect(result).to be_success

        expect(secrets_manager.reload).to be_active

        expect_kv_secret_engine_to_be_mounted(
          secrets_manager.full_group_namespace_path,
          secrets_manager.ci_secrets_mount_path
        )
        expect_jwt_auth_engine_to_be_mounted(
          secrets_manager.full_group_namespace_path,
          secrets_manager.ci_auth_mount
        )
      end
    end

    context 'when the group namespace has already been enabled' do
      before do
        secrets_manager_client.enable_namespace(secrets_manager.org_path)
        org_client = secrets_manager_client.with_namespace(secrets_manager.org_path)
        org_client.enable_namespace(secrets_manager.root_namespace_path)
        namespace_client = secrets_manager_client.with_namespace(
          [secrets_manager.org_path, secrets_manager.root_namespace_path].join('/')
        )
        namespace_client.enable_namespace(secrets_manager.group_path)
      end

      it 'still activates the secrets manager and creates the JWT' do
        expect(result).to be_success

        expect(secrets_manager.reload).to be_active

        expect_kv_secret_engine_to_be_mounted(
          secrets_manager.full_group_namespace_path,
          secrets_manager.ci_secrets_mount_path
        )
        expect_jwt_auth_engine_to_be_mounted(
          secrets_manager.full_group_namespace_path,
          secrets_manager.ci_auth_mount
        )
      end
    end

    context 'when the secrets engine has already been enabled' do
      before do
        secrets_manager_client.enable_namespace(secrets_manager.org_path)
        org_client = secrets_manager_client.with_namespace(secrets_manager.org_path)
        org_client.enable_namespace(secrets_manager.root_namespace_path)
        namespace_client = secrets_manager_client.with_namespace(
          [secrets_manager.org_path, secrets_manager.root_namespace_path].join('/')
        )
        namespace_client.enable_namespace(secrets_manager.group_path)

        client = secrets_manager_client.with_namespace(secrets_manager.full_group_namespace_path)
        client.enable_secrets_engine(
          secrets_manager.ci_secrets_mount_path,
          described_class::SECRETS_ENGINE_TYPE
        )
      end

      it 'still activates the secrets manager and creates the JWT' do
        expect(result).to be_success

        expect(secrets_manager.reload).to be_active

        expect_kv_secret_engine_to_be_mounted(
          secrets_manager.full_group_namespace_path,
          secrets_manager.ci_secrets_mount_path
        )
        expect_jwt_auth_engine_to_be_mounted(
          secrets_manager.full_group_namespace_path,
          secrets_manager.ci_auth_mount
        )
      end
    end

    context 'when the auth engine has already been enabled' do
      before do
        secrets_manager_client.enable_namespace(secrets_manager.org_path)
        org_client = secrets_manager_client.with_namespace(secrets_manager.org_path)
        org_client.enable_namespace(secrets_manager.root_namespace_path)
        namespace_client = secrets_manager_client.with_namespace(
          [secrets_manager.org_path, secrets_manager.root_namespace_path].join('/')
        )
        namespace_client.enable_namespace(secrets_manager.group_path)

        client = secrets_manager_client.with_namespace(secrets_manager.full_group_namespace_path)
        client.enable_auth_engine(secrets_manager.ci_auth_mount, secrets_manager.ci_auth_type)
      end

      it 'still activates the secrets manager and creates the KV mount' do
        expect(result).to be_success

        expect(secrets_manager.reload).to be_active

        expect_kv_secret_engine_to_be_mounted(
          secrets_manager.full_group_namespace_path,
          secrets_manager.ci_secrets_mount_path
        )
        expect_jwt_auth_engine_to_be_mounted(
          secrets_manager.full_group_namespace_path,
          secrets_manager.ci_auth_mount
        )

        client = secrets_manager_client.with_namespace(secrets_manager.full_group_namespace_path)
        expect { client.read_jwt_cel_role(secrets_manager.ci_auth_mount, secrets_manager.ci_auth_role) }
          .not_to raise_error
      end
    end

    context 'when both the secrets engine and auth engine already exist' do
      before do
        secrets_manager_client.enable_namespace(secrets_manager.org_path)
        org_client = secrets_manager_client.with_namespace(secrets_manager.org_path)
        org_client.enable_namespace(secrets_manager.root_namespace_path)
        namespace_client = secrets_manager_client.with_namespace(
          [secrets_manager.org_path, secrets_manager.root_namespace_path].join('/')
        )
        namespace_client.enable_namespace(secrets_manager.group_path)

        client = secrets_manager_client.with_namespace(secrets_manager.full_group_namespace_path)
        client.enable_secrets_engine(
          secrets_manager.ci_secrets_mount_path,
          described_class::SECRETS_ENGINE_TYPE
        )

        client.enable_auth_engine(
          secrets_manager.ci_auth_mount,
          secrets_manager.ci_auth_type
        )
      end

      it 'still activates the secrets manager and configures JWT CEL roles' do
        expect(result).to be_success
        expect(secrets_manager.reload).to be_active

        # Check that pipeline JWT CEL role was properly configured
        client = secrets_manager_client.with_namespace(secrets_manager.full_group_namespace_path)
        jwt_role = client.read_jwt_cel_role(secrets_manager.ci_auth_mount, secrets_manager.ci_auth_role)
        expect(jwt_role).to be_present

        # Verify the CEL program is configured
        expect(jwt_role["cel_program"]).to eq(secrets_manager.pipeline_auth_cel_program(group.id).deep_stringify_keys)
        expect(jwt_role["bound_audiences"]).to include(SecretsManagement::GroupSecretsManager.jwt_audience)
      end
    end

    context 'when the auth engines were enabled but left unconfigured by an interrupted attempt' do
      before do
        secrets_manager_client.enable_namespace(secrets_manager.org_path)
        org_client = secrets_manager_client.with_namespace(secrets_manager.org_path)
        org_client.enable_namespace(secrets_manager.root_namespace_path)
        namespace_client = secrets_manager_client.with_namespace(
          [secrets_manager.org_path, secrets_manager.root_namespace_path].join('/')
        )
        namespace_client.enable_namespace(secrets_manager.group_path)

        client = secrets_manager_client.with_namespace(secrets_manager.full_group_namespace_path)
        client.enable_auth_engine(secrets_manager.ci_auth_mount, secrets_manager.ci_auth_type)
        client.enable_auth_engine(secrets_manager.user_auth_mount, secrets_manager.user_auth_type)
      end

      it 'writes the JWT config for both auth mounts on retry', :aggregate_failures do
        expect(result).to be_success
        expect(secrets_manager.reload).to be_active

        expect_jwt_auth_engine_to_be_configured(
          secrets_manager.full_group_namespace_path,
          secrets_manager.ci_auth_mount
        )
        expect_jwt_auth_engine_to_be_configured(
          secrets_manager.full_group_namespace_path,
          secrets_manager.user_auth_mount
        )
      end
    end
  end
end
