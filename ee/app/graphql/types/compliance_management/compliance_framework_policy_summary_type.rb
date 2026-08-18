# frozen_string_literal: true

# rubocop: disable Graphql/AuthorizeTypes -- accessible only via authenticated resolvers on ComplianceFrameworkType
module Types
  module ComplianceManagement
    class ComplianceFrameworkPolicySummaryType < Types::BaseObject
      graphql_name 'ComplianceFrameworkPolicySummary'
      description 'A security policy scoped to a compliance framework'

      field :name, GraphQL::Types::String,
        null: false,
        description: 'Name of the security policy.'

      field :type, GraphQL::Types::String,
        null: true,
        description: 'Type of the security policy.'

      field :source, ::Types::SecurityOrchestration::SecurityPolicySourceType,
        null: true,
        description: 'Source of the security policy.'

      def type
        # scan_result_policy is the legacy name; normalize to approval_policy
        object[:type] == 'scan_result_policy' ? 'approval_policy' : object[:type]
      end
    end
  end
end
# rubocop: enable Graphql/AuthorizeTypes
