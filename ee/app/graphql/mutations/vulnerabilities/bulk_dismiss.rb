# frozen_string_literal: true

module Mutations
  module Vulnerabilities
    class BulkDismiss < BaseMutation
      graphql_name 'VulnerabilitiesDismiss'
      authorize :admin_vulnerability

      argument :vulnerability_ids,
        [::Types::GlobalIDType[::Vulnerability]],
        required: true,
        validates: { length: { minimum: 1, maximum: ::Vulnerabilities::BulkDismissService::MAX_BATCH } },
        description: "IDs of the vulnerabilities to be dismissed (maximum " \
                     "#{::Vulnerabilities::BulkDismissService::MAX_BATCH} entries)."

      argument :comment,
        GraphQL::Types::String,
        required: false,
        description: "Comment why vulnerability was dismissed (maximum 50,000 characters)."

      argument :dismissal_reason,
        Types::Vulnerabilities::DismissalReasonEnum,
        required: false,
        description: 'Reason why vulnerability should be dismissed.'

      field :vulnerabilities, [Types::VulnerabilityType],
        null: false,
        description: 'Vulnerabilities after state change.'

      def resolve(vulnerability_ids: [], dismissal_reason: nil, comment: nil)
        ids = vulnerability_ids.map(&:model_id).uniq

        response = ::Vulnerabilities::BulkDismissService.new(
          current_user,
          ids,
          comment,
          dismissal_reason
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
