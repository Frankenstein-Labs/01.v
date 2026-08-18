# frozen_string_literal: true

module Mutations
  module Analytics
    module KnowledgeGraph
      class OrbitUpdate < BaseMutation
        graphql_name 'OrbitUpdate'

        authorize_granular_token permissions: :update_knowledge_graph_setting, boundary_argument: :group_path,
          boundary_type: :group

        argument :group_path, GraphQL::Types::ID,
          required: true,
          description: 'Full path of the group to update.'

        argument :enabled, GraphQL::Types::Boolean,
          required: true,
          description: 'Whether to enable or disable the Knowledge Graph for the group.'

        field :group, ::Types::GroupType,
          null: true,
          description: 'Group after mutation.'

        def ready?(**args)
          raise_resource_not_available_error! unless ::Analytics::KnowledgeGraph.enabled_for?(current_user)

          unless ::Analytics::KnowledgeGraph::OrbitLicense.available_for?(current_user)
            raise_resource_not_available_error!
          end

          super
        end

        def resolve(group_path:, enabled:)
          group = ::Group.find_by_full_path(group_path)
          raise_resource_not_available_error! unless group

          result = ::Analytics::KnowledgeGraph::ToggleNamespaceService.new(
            group: group,
            current_user: current_user,
            enabled: enabled
          ).execute

          raise_resource_not_available_error! if result.error? && result.reason == :forbidden

          {
            group: result.success? ? group : nil,
            errors: result.success? ? [] : [result.message]
          }
        end
      end
    end
  end
end
