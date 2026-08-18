# frozen_string_literal: true

module SecretsManagement
  module GroupSecrets
    class ReadMetadataService < GroupBaseService
      def execute(name, include_rotation_info: true)
        return secrets_manager_inactive_response unless group.secrets_manager&.active?
        return invalid_name_response unless /\A[a-zA-Z0-9_]+\z/.match?(name)

        secret_metadata = user_client.read_secret_metadata(
          group.secrets_manager.ci_secrets_mount_path,
          group.secrets_manager.ci_data_path(name)
        )

        if secret_metadata
          build_success_response(name, secret_metadata, include_rotation_info)
        else
          not_found_response
        end
      end

      private

      def build_success_response(name, secret_metadata, include_rotation_info)
        custom_metadata = secret_metadata["custom_metadata"] || {}

        group_secret = GroupSecret.new(
          name: name,
          group: group,
          description: custom_metadata["description"],
          environment: custom_metadata["environment"],
          protected: custom_metadata["protected"].to_s == 'true',
          metadata_version: secret_metadata["current_metadata_version"],
          create_started_at: secret_metadata["created_time"],
          create_completed_at: custom_metadata["create_completed_at"],
          update_started_at: custom_metadata["update_started_at"],
          update_completed_at: custom_metadata["update_completed_at"]
        )

        if include_rotation_info
          current_version = group_secret.metadata_version

          group_secret.rotation_info =
            GroupSecretRotationInfo.for_secret(group, group_secret.name, current_version) ||
            GroupSecretRotationInfo.for_secret(group, group_secret.name, current_version - 1)
        end

        group_secret.changes_applied

        ServiceResponse.success(payload: { secret: group_secret })
      end

      def not_found_response
        ServiceResponse.error(message: 'Group secret does not exist.', reason: :not_found)
      end

      def invalid_name_response
        ServiceResponse.error(message: "Name can contain only letters, digits and '_'.")
      end
    end
  end
end
