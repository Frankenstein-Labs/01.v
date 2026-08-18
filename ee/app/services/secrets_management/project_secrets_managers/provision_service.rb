# frozen_string_literal: true

module SecretsManagement
  module ProjectSecretsManagers
    class ProvisionService < ProjectBaseService
      SECRETS_ENGINE_TYPE = 'kv-v2'
      OWNER_PRINCIPAL_ID = Gitlab::Access.sym_options_with_owner[:owner]
      OWNER_PRINCIPAL_TYPE = "Role"
      OWNER_PERMISSIONS = %w[create update delete read list scan].freeze

      def initialize(secrets_manager, current_user)
        super(secrets_manager.project, current_user)

        @secrets_manager = secrets_manager
      end

      def execute
        entitlement_error = validate_entitlement(action: 'provisioned')
        return entitlement_error if entitlement_error

        with_exclusive_lease_for(project, lease_timeout: 120.seconds.to_i) do
          execute_provision
        end
      end

      private

      attr_reader :secrets_manager

      def execute_provision
        enable_namespaces
        enable_secret_store
        enable_auth
        create_owner_policy

        activate_secrets_manager
        ServiceResponse.success(payload: { project_secrets_manager: secrets_manager })
      end

      def enable_namespaces
        # Level 1: organization namespace. May already exist if other
        # groups/projects in the same org have a secrets manager.
        base_secrets_manager_client.enable_namespace(secrets_manager.org_path)

        # Level 2: root group namespace under the org. May already exist if
        # there's a sibling project/group with a secrets manager.
        org_secrets_manager_client.enable_namespace(secrets_manager.namespace_path)

        # Level 3: project namespace. Should be new at provision time, but
        # OpenBao does not differentiate first creation from subsequent calls.
        namespace_secrets_manager_client.enable_namespace(secrets_manager.project_path)
      end

      def enable_secret_store
        project_secrets_manager_client.enable_secrets_engine(secrets_manager.ci_secrets_mount_path, SECRETS_ENGINE_TYPE)
      rescue SecretsManagerClient::ApiError => e
        raise e unless e.message.include?('path is already in use')

        # This scenario may happen in a rare event that the API call to enable the engine succeeds
        # but the actual column update failed due to unexpected reasons (e.g. network hiccups) that
        # will also fail the job. So on job retry, we want to ignore this message and continue
        # with the column update.
      end

      def enable_auth
        # configure pipeline auth
        enable_auth_engine(secrets_manager.ci_auth_mount, secrets_manager.ci_auth_type)
        configure_jwt(secrets_manager.ci_auth_mount)
        configure_pipeline_auth

        # configure user auth
        enable_auth_engine(secrets_manager.user_auth_mount, secrets_manager.user_auth_type)
        configure_jwt(secrets_manager.user_auth_mount)
        configure_user_auth_cel

        # configure non-CI API auth
        configure_api_auth
      end

      def enable_auth_engine(auth_mount, auth_type)
        project_secrets_manager_client.enable_auth_engine(
          auth_mount,
          auth_type,
          allow_existing: true
        )
      end

      def configure_jwt(auth_mount)
        # We use the OIDC discovery URL to configure this JWT mount so that
        # OpenBao can automatically update its copy of the issuer. However,
        # if we're running under a spec, we'll use a hard-coded JKS instead
        # so that we don't need a full Puma instance running.

        issuer_base_url = ProjectSecretsManager.jwt_issuer
        issuer_key = Gitlab::CurrentSettings.ci_jwt_signing_key
        project_secrets_manager_client.configure_jwt(auth_mount, issuer_base_url, issuer_key)
      end

      def configure_user_auth_cel
        project_secrets_manager_client.update_jwt_cel_role(
          secrets_manager.user_auth_mount,
          secrets_manager.user_auth_role,
          cel_program: secrets_manager.user_auth_cel_program(secrets_manager.project.id),
          bound_audiences: bound_audiences
        )
      end

      def configure_api_auth
        ApiAuthConfigurator.new(
          client: project_secrets_manager_client,
          secrets_manager: secrets_manager,
          resource_id: project.id
        ).configure
      end

      def configure_pipeline_auth
        project_secrets_manager_client.update_jwt_cel_role(
          secrets_manager.ci_auth_mount,
          secrets_manager.ci_auth_role,
          cel_program: secrets_manager.pipeline_auth_cel_program(secrets_manager.project.id),
          bound_audiences: bound_audiences
        )
      end

      def create_owner_policy
        policy_name = secrets_manager.policy_name_for_principal(
          principal_type: OWNER_PRINCIPAL_TYPE,
          principal_id: OWNER_PRINCIPAL_ID
        )

        policy = SecretsManagement::AclPolicy.new(policy_name)
        update_policy_paths(policy, OWNER_PERMISSIONS)
        project_secrets_manager_client.set_policy(policy)
      end

      def update_policy_paths(policy, permissions)
        data_path = secrets_manager.ci_full_path('*')
        metadata_path = secrets_manager.ci_metadata_full_path('*')
        detailed_metadata_path = secrets_manager.detailed_metadata_path('*')

        # Add capabilities for managing secrets
        permissions.each do |permission|
          policy.add_capability(data_path, permission) if permission != 'read'
          policy.add_capability(metadata_path, permission)
        end
        policy.add_capability(detailed_metadata_path, 'list')
      end

      def activate_secrets_manager
        return if secrets_manager.active?

        secrets_manager.activate!
      end

      def bound_audiences
        [SecretsManagement::ProjectSecretsManager.jwt_audience]
      end
    end
  end
end
