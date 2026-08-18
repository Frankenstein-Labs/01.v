# frozen_string_literal: true

module Types
  module Authz
    module ArtifactRegistry
      # A projection of one IAM relationship tuple returned by the lookup. The
      # rows come pre-authorized: IAM only returns assignments the caller may
      # see, and the resolver gates on the feature flag, so there is no
      # per-object ability to check here.
      # rubocop: disable Graphql/AuthorizeTypes -- reads are authorized upstream by IAM and the resolver
      class RoleAssignmentType < BaseObject
        graphql_name 'ArtifactRegistryRoleAssignment'
        description 'A direct role assignment. A user, the Artifact Registry role they hold, ' \
          'and the resource it is assigned on. Does not represent inherited access.'

        field :resource_id, GraphQL::Types::String,
          null: false,
          description: 'UUID of the Artifact Registry resource the role is assigned on.'

        field :role, ::Types::Authz::ArtifactRegistry::RoleEnum,
          null: true,
          description: 'Assigned Artifact Registry role.'

        field :assignee, ::Types::UserType,
          null: true,
          description: 'User the role is assigned to.'

        field :created_at, ::Types::TimeType,
          null: true,
          description: 'Time the assignment was created.'

        # `object` is the IAM relationship tuple; `object.object` is its resource.
        def resource_id
          object.object.id
        end

        def role
          ::Authz::ArtifactRegistry::Roles.name_for(object.role&.id)
        end

        def assignee
          # subject.id is a oneof: identity or principal. The lookup returns
          # identities today; a principal-shaped subject has no local user id,
          # so it surfaces as a nil assignee rather than an error.
          local_id = object.subject.identity&.local_id
          return unless local_id

          ::Gitlab::Graphql::Loaders::BatchModelLoader.new(::User, local_id).find
        end

        def created_at
          object.timestamp&.to_time
        end
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
