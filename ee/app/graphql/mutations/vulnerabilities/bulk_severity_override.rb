# frozen_string_literal: true

module Mutations
  module Vulnerabilities
    class BulkSeverityOverride < BaseMutation
      graphql_name 'vulnerabilitiesSeverityOverride'
      authorize :admin_vulnerability

      argument :vulnerability_ids,
        [::Types::GlobalIDType[::Vulnerability]],
        required: true,
        validates: { length: { minimum: 1, maximum: ::Vulnerabilities::BulkSeverityOverrideService::MAX_BATCH } },
        description: "IDs of the vulnerabilities for which severity needs to be changed (maximum " \
          "#{::Vulnerabilities::BulkSeverityOverrideService::MAX_BATCH} entries)."

      argument :severity, Types::VulnerabilitySeverityEnum,
        required: true,
        description: 'New severity value for the severities.'

      argument :comment,
        GraphQL::Types::String,
        required: true,
        description: "Comment why vulnerability severity was changed (maximum 50,000 characters)."

      field :vulnerabilities, [Types::VulnerabilityType],
        null: false,
        description: 'Vulnerabilities after severity change.',
        scopes: [:api, :read_api, :ai_workflows]

      def self.authorization_scopes
        [:api, :ai_workflows]
      end

      def resolve(vulnerability_ids: [], severity: nil, comment: nil)
        ids = vulnerability_ids.map(&:model_id).uniq

        response = ::Vulnerabilities::BulkSeverityOverrideService.new(
          current_user,
          ids,
          comment,
          severity
        ).execute

        {
          vulnerabilities: response[:vulnerabilities] || [],
          errors: response.success? ? [] : [response.message]
        }
      rescue Gitlab::Access::AccessDeniedError
        raise_resource_not_available_error!
      end
    end
  end
end
