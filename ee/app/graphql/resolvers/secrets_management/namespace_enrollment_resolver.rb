# frozen_string_literal: true

module Resolvers
  module SecretsManagement
    class NamespaceEnrollmentResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource
      include ResolvesGroup
      include ::SecretsManagement::ResolverErrorHandling

      type ::Types::SecretsManagement::EnrollmentType, null: true
      description 'Check Secrets Manager enrollment for a namespace.'

      argument :namespace_path,
        GraphQL::Types::ID,
        required: true,
        description: 'Full path of the namespace.'

      authorize :read_secrets_manager_enrollment

      def resolve(namespace_path:)
        group = authorized_find!(group_path: namespace_path)
        return unless group.root?

        ::SecretsManagement::NamespaceEnrollment.find_by_namespace_id(group.id)
      end

      private

      def find_object(group_path:)
        resolve_group(full_path: group_path)
      end
    end
  end
end
