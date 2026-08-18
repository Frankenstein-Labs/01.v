# frozen_string_literal: true

module SecretsManagement
  module UserPermissions
    # Resolves the effective OpenBao capabilities for a user on a secrets manager resource.
    #
    # Uses the user-scoped client (CEL login with ProjectUserJwt / GroupUserJwt) to call
    # `sys/capabilities-self`, letting OpenBao compute the union of all applicable principal
    # policies (user, member-role, group, role).
    #
    # This method is called both by the controller (`check_read_capability!`) and by the
    # GraphQL `userPermissions` resolver, which are two separate HTTP requests, so the
    # result is not shared between them today. A cross-request cache (`Rails.cache`,
    # short TTL) is tracked in https://gitlab.com/gitlab-org/gitlab/-/issues/605467.
    #
    # Path mapping (mirrors update_service_helpers.rb):
    #   - readMetadata  from `list` on the detailed-metadata path (detailed_metadata_path('*')),
    #     the path the secrets list service actually reads
    #   - createSecrets from `create` on the data path (ci_full_path('*'))
    #   - updateSecrets from `update` on the data path (ci_full_path('*'))
    #   - deleteSecrets from `delete` on the data path (ci_full_path('*'))
    #
    # `read_value` is intentionally not resolved here: it lives on a separate
    # `api_jwt` mount/policy (see !240364) that this user-scoped client does not
    # authenticate against. Its GraphQL exposure is tracked in #602726.
    #
    # Any OpenBao error is rescued and returns all-false (fail closed).
    #
    # Returns a hash with boolean values for each capability:
    #   { "read_metadata" => bool, "create" => bool, "update" => bool, "delete" => bool }
    class EffectiveCapabilitiesService
      EXPOSED_CAPABILITIES = %w[read_metadata create update delete].freeze

      # @param secrets_manager [SecretsManagement::BaseSecretsManager]
      # @param current_user [User]
      # @param resource [Project, Group] the project or group owning the secrets manager
      def initialize(secrets_manager:, current_user:, resource:)
        @secrets_manager = secrets_manager
        @current_user = current_user
        @resource = resource
      end

      # @return [Hash<String, Boolean>] e.g. { "read_metadata" => true, "create" => false, ... }
      def execute
        data_path = secrets_manager.ci_full_path('*')
        detailed_metadata_path = secrets_manager.detailed_metadata_path('*')

        response = user_scoped_client.capabilities_self(paths: [data_path, detailed_metadata_path])

        # OpenBao returns the per-path capability map under the "data" envelope.
        # (Non-namespaced responses also mirror it at the top level, but namespaced
        # ones only populate "data", so always read from there.)
        per_path = response&.dig("data") || {}
        data_caps = Array(per_path[data_path])
        detailed_metadata_caps = Array(per_path[detailed_metadata_path])

        reads_permitted = entitlement_permits_reads?
        writes_permitted = entitlement_permits_writes?

        {
          'read_metadata' => detailed_metadata_caps.include?('list') && reads_permitted,
          'create' => data_caps.include?('create') && writes_permitted,
          'update' => data_caps.include?('update') && writes_permitted,
          'delete' => data_caps.include?('delete') && writes_permitted
        }
      rescue SecretsManagement::SecretsManagerClient::ApiError,
        SecretsManagement::SecretsManagerClient::ConnectionError,
        SecretsManagement::SecretsManagerClient::ServiceUnavailableError,
        SecretsManagement::SecretsManagerClient::AuthenticationError
        all_false
      end

      private

      attr_reader :secrets_manager, :current_user, :resource

      # @return [SecretsManagerClient] a client authenticated as the current user via CEL login
      def user_scoped_client
        raise Gitlab::AbstractMethodError
      end

      def all_false
        EXPOSED_CAPABILITIES.index_with { false }
      end

      # Mirror the mutation-side entitlement gate in `EnforcesWriteEntitlement` so
      # the booleans exposed on `userPermissions` reflect what the resolvers and
      # mutations will actually accept.
      def entitlement_permits_reads?
        return true unless entitlement_aware?

        entitlement.permits_read?
      end

      def entitlement_permits_writes?
        return true unless entitlement_aware?

        entitlement.permits_writes?
      end

      def entitlement_aware?
        ::Feature.enabled?(:secrets_manager_paid_experience, resource.root_ancestor)
      end

      # `Entitlement.for` is request-cached (SafeRequestStore), so resolving it
      # for both the read and write gates costs one lookup.
      def entitlement
        root_namespace = ::SecretsManagement::Entitlement.root_namespace_for(resource)
        ::SecretsManagement::Entitlement.for(root_namespace, user: current_user)
      end
    end
  end
end
