# frozen_string_literal: true

module SecretsManagement
  class PipelineJwt < Gitlab::Ci::JwtV2
    private

    def predefined_claims
      super.merge(
        secrets_manager_scope: 'pipeline',
        project_group_ids: project_group_ids
      )
    end

    def project_group_ids
      source_project.group&.self_and_ancestors&.pluck(:id)&.map(&:to_s) || []
    end
  end
end
