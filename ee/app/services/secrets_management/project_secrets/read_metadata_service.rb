# frozen_string_literal: true

module SecretsManagement
  module ProjectSecrets
    class ReadMetadataService < ProjectBaseService
      def execute(name, include_rotation_info: true)
        return secrets_manager_inactive_response unless project.secrets_manager&.active?
        return invalid_name_response unless /\A[a-zA-Z0-9_]+\z/.match?(name)

        secret_metadata = user_client.read_secret_metadata(
          project.secrets_manager.ci_secrets_mount_path,
          project.secrets_manager.ci_data_path(name)
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

        project_secret = ProjectSecret.new(
          name: name,
          project: project,
          description: custom_metadata["description"],
          environment: custom_metadata["environment"],
          branch: custom_metadata["branch"],
          metadata_version: secret_metadata["current_metadata_version"],
          create_started_at: secret_metadata["created_time"],
          create_completed_at: custom_metadata["create_completed_at"],
          update_started_at: custom_metadata["update_started_at"],
          update_completed_at: custom_metadata["update_completed_at"]
        )

        if include_rotation_info
          current_version = project_secret.metadata_version

          project_secret.rotation_info =
            ProjectSecretRotationInfo.for_secret(project, project_secret.name, current_version) ||
            ProjectSecretRotationInfo.for_secret(project, project_secret.name, current_version - 1)
        end

        ServiceResponse.success(payload: { secret: project_secret })
      end

      def not_found_response
        ServiceResponse.error(message: 'Project secret does not exist.', reason: :not_found)
      end

      def invalid_name_response
        ServiceResponse.error(message: "Name can contain only letters, digits and '_'.")
      end
    end
  end
end
