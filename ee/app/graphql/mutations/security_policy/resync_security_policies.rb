# frozen_string_literal: true

module Mutations
  module SecurityPolicy
    class ResyncSecurityPolicies < BaseMutation
      graphql_name 'ResyncSecurityPolicies'
      description 'Triggers a resynchronization of security policies linked to the given project or group (`full_path`)'

      include FindsProjectOrGroupForSecurityPolicies

      authorize :update_security_orchestration_policy_project

      argument :full_path, GraphQL::Types::String,
        required: true,
        description: 'Full path of the project or group.'

      argument :relationship, Types::SecurityOrchestration::RelationshipTypeEnum,
        required: false,
        description: 'Relationship of the policies to resync.',
        default_value: :direct

      def resolve(args)
        project_or_group = authorized_find!(**args)

        result = ::Security::SecurityOrchestrationPolicies::ResyncPoliciesService.new(
          container: project_or_group,
          current_user: current_user,
          params: { relationship: args[:relationship] }
        ).execute

        {
          errors: result[:status] == :success ? [] : [result[:message]]
        }
      end
    end
  end
end
