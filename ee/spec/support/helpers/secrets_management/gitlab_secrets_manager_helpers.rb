# frozen_string_literal: true

module SecretsManagement
  module GitlabSecretsManagerHelpers
    def reset_openbao
      clean_all_kv_secrets_engines
      clean_all_pipeline_jwt_engines
      clean_all_user_jwt_engines
      clean_all_policies
      clean_all_namespaces
    end

    def clean_all_kv_secrets_engines
      client = secrets_manager_client
      client.each_secrets_engine do |path, info|
        next unless info["type"] == "kv"

        client.disable_secrets_engine(path)
      end
    end

    def clean_all_pipeline_jwt_engines
      client = secrets_manager_client
      client.each_auth_engine do |path, info|
        next unless info["type"] == "jwt"
        next unless path.include? "pipeline_jwt"

        client.disable_auth_engine(path)
      end
    end

    def clean_all_user_jwt_engines
      client = secrets_manager_client
      client.each_auth_engine do |path, info|
        next unless info["type"] == "jwt"
        next unless path.include? "user_jwt"

        client.disable_auth_engine(path)
      end
    end

    def clean_all_policies
      client = secrets_manager_client
      client.each_acl_policy do |name|
        next unless name.start_with? "project_"

        client.delete_policy(name)
      end
    end

    def clean_all_namespaces
      client = secrets_manager_client
      client.each_namespace do |path|
        next unless path.starts_with?("org_") || path.starts_with?("user_") || path.starts_with?("group_")

        ns_client = client

        path = path.delete_suffix('/')
        if path.include? '/'
          parent, _, child = path.rpartition('/')
          ns_client = client.with_namespace(parent)
          path = child
        end

        10.times do |n|
          result = ns_client.disable_namespace(path)
          next unless result.key?("data") && !result["data"].nil? &&
            result["data"].key?("status") && !result["data"]["status"].nil? &&
            result["data"]["status"] == "in-progress"

          sleep 0.1 * n
        end
      end
    end

    def provision_project_secrets_manager(secrets_manager, user, auto_enroll: true)
      enroll_instance_in_secrets_manager if auto_enroll
      ProjectSecretsManagers::ProvisionService.new(secrets_manager, user).execute
    end

    def deprovision_project_secrets_manager(secrets_manager, user)
      task = create(:project_secrets_manager_maintenance_task, :deprovision,
        project: secrets_manager.project,
        user: user
      )
      ProjectSecretsManagers::DeprovisionService.new(task, user).execute
    end

    def expect_kv_secret_engine_to_be_mounted(namespace_path, path)
      client = secrets_manager_client.with_namespace(namespace_path)
      expect { client.read_secrets_engine_configuration(path) }.not_to raise_error
    end

    def expect_kv_secret_engine_not_to_be_mounted(namespace_path, path)
      client = secrets_manager_client.with_namespace(namespace_path)
      expect { client.read_secrets_engine_configuration(path) }
        .to raise_error(SecretsManagerClient::ApiError)
    end

    def expect_kv_secret_to_have_value(namespace_path, mount_path, path, value)
      client = secrets_manager_client.with_namespace(namespace_path)
      stored_data = client.read_kv_secret_value(mount_path, path)
      expect(stored_data).to eq(value)
    end

    def expect_kv_secret_to_have_custom_metadata(namespace_path, mount_path, path, metadata)
      client = secrets_manager_client.with_namespace(namespace_path)
      stored_data = client.read_secret_metadata(mount_path, path)
      expect(stored_data["custom_metadata"]).to include(metadata)
    end

    def expect_kv_secret_not_to_have_custom_metadata(namespace_path, mount_path, path, metadata)
      client = secrets_manager_client.with_namespace(namespace_path)
      stored_data = client.read_secret_metadata(mount_path, path)
      expect(stored_data["custom_metadata"]).not_to include(metadata)
    end

    def expect_kv_secret_to_have_metadata_version(namespace_path, mount_path, path, version)
      client = secrets_manager_client.with_namespace(namespace_path)
      stored_data = client.read_secret_metadata(mount_path, path)
      expect(stored_data["current_metadata_version"]).to eq(version)
    end

    def expect_project_secret_not_to_exist(project, name, user = nil)
      user ||= create(:user)
      result = ProjectSecrets::ReadMetadataService.new(project, user).execute(name)
      expect(result).to be_error
      expect(result.message).to eq('Project secret does not exist.')
    end

    def expect_kv_secret_not_to_exist(namespace_path, mount_path, path)
      client = secrets_manager_client.with_namespace(namespace_path)
      expect(client.read_secret_metadata(mount_path, path)).to be_nil
      expect(client.read_kv_secret_value(mount_path, path)).to be_nil
    end

    def expect_jwt_auth_engine_to_be_mounted(namespace_path, path)
      client = secrets_manager_client.with_namespace(namespace_path)
      expect { client.read_auth_engine_configuration(path) }.not_to raise_error
    end

    def expect_jwt_auth_engine_not_to_be_mounted(namespace_path, path)
      client = secrets_manager_client.with_namespace(namespace_path)
      expect { client.read_auth_engine_configuration(path) }
        .to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
    end

    def expect_jwt_auth_engine_to_be_configured(namespace_path, path)
      client = secrets_manager_client.with_namespace(namespace_path)
      config = client.read_jwt_auth_config(path)
      expect(config&.dig("data", "jwt_validation_pubkeys")).to be_present
    end

    def secrets_manager_client
      jwt = TestJwt.new.encoded

      TestClient.new(jwt: jwt)
    end

    def create_project_secret(
      user:, project:, name:, branch:, environment:, value:, description: nil,
      rotation_interval_days: nil)
      result = ProjectSecrets::CreateService.new(project, user).execute(
        name: name,
        value: value,
        description: description,
        branch: branch,
        environment: environment,
        rotation_interval_days: rotation_interval_days
      )

      project_secret = result.payload[:secret]

      if project_secret.errors.any?
        raise "project secret creation failed with errors: #{project_secret.errors.full_messages.to_sentence}"
      end

      project_secret
    end

    def create_group_secret(
      user:, group:, name:, protected:, environment:, value:, description: nil,
      rotation_interval_days: nil)
      result = GroupSecrets::CreateService.new(group, user).execute(
        name: name,
        value: value,
        description: description,
        protected: protected,
        environment: environment,
        rotation_interval_days: rotation_interval_days
      )

      group_secret = result.payload[:secret]

      if group_secret.errors.any?
        raise "group secret creation failed with errors: #{group_secret.errors.full_messages.to_sentence}"
      end

      group_secret
    end

    def update_project_secrets_permission(user:, project:, principal:, actions:, expired_at: nil)
      result = SecretsManagement::ProjectSecretsPermissions::UpdateService.new(project, user).execute(
        principal_id: principal[:id],
        principal_type: principal[:type],
        actions: actions,
        expired_at: expired_at
      )

      secrets_permission = result.payload[:secrets_permission]

      if secrets_permission.errors.any?
        raise "secrets permission creation failed with errors: #{secrets_permission.errors.full_messages.to_sentence}"
      end

      secrets_permission
    end

    def update_group_secrets_permission(user:, group:, principal:, actions:, expired_at: nil)
      result = SecretsManagement::GroupSecretsPermissions::UpdateService.new(group, user).execute(
        principal_id: principal[:id],
        principal_type: principal[:type],
        actions: actions,
        expired_at: expired_at
      )

      secrets_permission = result.payload[:secrets_permission]

      if secrets_permission.errors.any?
        raise "secrets permission creation failed with errors: #{secrets_permission.errors.full_messages.to_sentence}"
      end

      secrets_permission
    end

    # Forces a user's existing grant to be expired in OpenBao. OpenBao enforces the
    # policy-path `expiration` against its own wall clock, which Rails time-travel
    # cannot move, and the update API rejects a past expiry. So we rewrite the
    # stored policy's expiration into the past directly.
    def expire_secrets_permission_grant!(namespace_path, user)
      client = secrets_manager_client.with_namespace(namespace_path)
      policy = client.get_policy("users/direct/user_#{user.id}")
      policy.paths.each_value { |path| path.expired_at = 1.hour.ago.utc.iso8601 }
      client.set_policy(policy)
    end

    def secret_rotation_info_for_project_secret(project, name, version = 1)
      ProjectSecretRotationInfo.for_secret(project, name, version)
    end

    def secret_rotation_info_for_group_secret(group, name, version = 1)
      GroupSecretRotationInfo.for_secret(group, name, version)
    end

    def update_kv_secret_with_metadata(mount_path, secret_path, value, custom_metadata)
      client.update_kv_secret(
        mount_path,
        secret_path,
        value
      )

      client.update_kv_secret_metadata(
        mount_path,
        secret_path,
        custom_metadata
      )
    end

    def expect_jwt_cel_role_to_exist(namespace_path, mount_path, role_name)
      client = secrets_manager_client.with_namespace(namespace_path)
      expect { client.read_jwt_cel_role(mount_path, role_name) }.not_to raise_error
    end

    def expect_jwt_cel_role_not_to_exist(namespace_path, mount_path, role_name)
      client = secrets_manager_client.with_namespace(namespace_path)
      expect { client.read_jwt_cel_role(mount_path, role_name) }
        .to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
    end

    def expect_policy_to_exist(namespace_path, policy_name)
      client = secrets_manager_client.with_namespace(namespace_path)
      expect(client.get_raw_policy(policy_name)).not_to be_nil,
        "Expected policy '#{policy_name}' to exist, but it was not found"
    end

    def expect_policy_not_to_exist(namespace_path, path)
      secrets_manager_client.with_namespace(namespace_path)
      expect(secrets_manager_client.get_raw_policy(path)).to be_nil
    end

    def expect_project_to_have_no_policies(project_namespace)
      if project_namespace.empty?
        project_policies = find_project_policies(project_namespace)
        expect(project_policies).to be_empty,
          "Expected project #{project.id} to have no policies, but found: #{project_policies.join(', ')}"
      else
        expect do
          project_policies = find_project_policies(project_namespace)
        end.to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
      end
    end

    def find_project_policies(project_namespace)
      project_policies = []

      client = secrets_manager_client.with_namespace(project_namespace)
      client.each_acl_policy do |policy_name|
        project_policies << policy_name unless policy_name == "default"
      end

      project_policies
    end

    def cancel_exclusive_project_secret_operation_lease(project)
      lease_key = "project_secret_operation:project_#{project.id}"
      uuid = Gitlab::ExclusiveLease.get_uuid(lease_key)
      Gitlab::ExclusiveLease.cancel(lease_key, uuid)
    end

    def cancel_exclusive_group_secret_operation_lease(group)
      lease_key = "group_secret_operation:group_#{group.id}"
      uuid = Gitlab::ExclusiveLease.get_uuid(lease_key)
      Gitlab::ExclusiveLease.cancel(lease_key, uuid)
    end

    def provision_group_secrets_manager(secrets_manager, user, auto_enroll: true)
      enroll_instance_in_secrets_manager if auto_enroll
      GroupSecretsManagers::ProvisionService.new(secrets_manager, user).execute
    end

    def deprovision_group_secrets_manager(secrets_manager, user)
      task = create(:group_secrets_manager_maintenance_task, :deprovision,
        group: secrets_manager.group,
        user: user,
        organization_id: secrets_manager.group.organization_id,
        root_namespace_id: secrets_manager.group.root_ancestor.id
      )
      GroupSecretsManagers::DeprovisionService.new(task, user).execute
    end

    def expect_group_to_have_no_policies(group_namespace)
      if group_namespace.empty?
        group_policies = find_group_policies(group_namespace)
        expect(group_policies).to be_empty,
          "Expected group to have no policies, but found: #{group_policies.join(', ')}"
      else
        expect do
          group_policies = find_group_policies(group_namespace)
        end.to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
      end
    end

    def find_group_policies(group_namespace)
      group_policies = []

      client = secrets_manager_client.with_namespace(group_namespace)
      client.each_acl_policy do |policy_name|
        group_policies << policy_name unless policy_name == "default"
      end

      group_policies
    end

    def expect_namespace_to_exist(namespace_path)
      expect { read_namespace(namespace_path) }
        .not_to raise_error
    end

    def expect_namespace_not_to_exist(namespace_path)
      expect { read_namespace(namespace_path) }
        .to raise_error(SecretsManagerClient::ApiError)
    end

    def read_namespace(namespace_path)
      namespaces = namespace_path.split('/')
      client = secrets_manager_client

      if namespaces.count > 1
        # Walk the hierarchy by entering each parent in turn, e.g.
        # "org_1/group_2/group_3" -> with_namespace("org_1/group_2").read_namespace("group_3")
        parent = namespaces[0..-2].join('/')
        client = client.with_namespace(parent)
      end

      client.read_namespace(namespaces.last)
    end
  end
end
