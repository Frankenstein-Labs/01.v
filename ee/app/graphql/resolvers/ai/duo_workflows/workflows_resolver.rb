# frozen_string_literal: true

module Resolvers
  module Ai
    module DuoWorkflows
      class WorkflowsResolver < BaseResolver
        include Gitlab::Graphql::Authorize::AuthorizeResource
        include ::ResolvesIds

        type Types::Ai::DuoWorkflows::WorkflowType, null: false

        argument :project_path, GraphQL::Types::ID,
          required: false,
          description: 'Full path of the project that contains the flows.'

        argument :type, GraphQL::Types::String,
          required: false,
          description: 'Type of flow to filter by (for example, software_development or foundational_chat_agents).'

        argument :exclude_types, [GraphQL::Types::String],
          required: false,
          description: 'Types of flows to exclude (for example, ["software_development", "chat"]).'

        argument :sort, Types::Ai::DuoWorkflows::WorkflowSortEnum,
          description: 'Sort flows by the criteria.',
          required: false,
          default_value: :created_desc

        argument :environment, Types::Ai::DuoWorkflows::WorkflowEnvironmentEnum,
          description: 'Environment, for example, IDE or web.',
          required: false

        argument :workflow_id, Types::GlobalIDType[::Ai::DuoWorkflows::Workflow],
          required: false,
          description: 'Flow ID to filter by.'

        argument :ids, [Types::GlobalIDType[::Ai::DuoWorkflows::Workflow]],
          required: false,
          description: 'Filter flows by a list of IDs.'

        argument :search, GraphQL::Types::String,
          required: false,
          description: 'Flow title or goal to search for.'

        argument :status_group, Types::Ai::DuoWorkflows::WorkflowStatusGroupEnum,
          required: false,
          description: 'Status group to filter flow sessions by.'

        argument :updated_after, GraphQL::Types::ISO8601DateTime,
          required: false,
          description: 'Filters flows updated after a given date.'

        def resolve(**args)
          return [] unless current_user

          # Return empty array if type and exclude filters conflict
          return [] if conflicting_type_filters?(args)

          return resolve_single_workflow(args[:workflow_id]) if args[:workflow_id].present?

          # Coerce GIDs to numeric ids and only forward `ids:` to the finder
          # when a populated or empty array was supplied. An explicit `null`
          # is treated as "filter not provided" so it lines up with how
          # `required: false` GraphQL arguments behave when omitted.
          ids_arg = args.delete(:ids)
          args[:ids] = resolve_ids(ids_arg) if ids_arg

          workflows = ::Ai::DuoWorkflows::WorkflowsFinder.new(
            source: object,
            current_user: current_user,
            project_path: args[:project_path],
            type: args[:type],
            exclude_types: args[:exclude_types],
            environment: args[:environment],
            sort: args[:sort],
            search: args[:search],
            status_group: args[:status_group],
            updated_after: args[:updated_after],
            ids: args[:ids]
          ).results

          offset_pagination(workflows.with_preloaded_associations)
        end

        private

        def conflicting_type_filters?(args)
          exclude_types = args[:exclude_types] || []
          return false unless args[:type].present? && exclude_types.present?

          exclude_types.include?(args[:type])
        end

        def resolve_single_workflow(workflow_id)
          Gitlab::Graphql::Lazy.with_value(find_object(id: workflow_id)) do |workflow|
            if workflow.nil?
              raise_resource_not_available_error!(
                'Workflow not found',
                { code: ::Gitlab::Graphql::Ai::ErrorCodes::WORKFLOW_NOT_FOUND }
              )
            elsif !Ability.allowed?(current_user, :read_duo_workflow, workflow)
              if ::Gitlab::ApplicationRateLimiter.throttled?(:duo_workflow_unauthorized_access,
                scope: [current_user, workflow])
                raise_resource_not_available_error!('Too many requests.')
              end

              error_code = determine_permission_error_code
              raise_resource_not_available_error!(
                permission_error_message(error_code),
                { code: error_code }
              )
            else
              ::Ai::DuoWorkflows::Workflow.id_in([workflow.id])
            end
          end
        end

        def find_object(id:)
          GitlabSchema.find_by_gid(id)
        end

        def determine_permission_error_code
          # Check if user needs to select a default namespace
          # This occurs when user belongs to multiple namespaces but hasn't selected one
          default_namespace = current_user.user_preference.duo_default_namespace_with_fallback
          has_multiple_namespaces = current_user.user_preference.duo_default_namespace_candidates.count > 1

          if default_namespace.nil? && has_multiple_namespaces
            ::Gitlab::Graphql::Ai::ErrorCodes::NO_DEFAULT_NAMESPACE
          else
            ::Gitlab::Graphql::Ai::ErrorCodes::INSUFFICIENT_NAMESPACE_PERMISSIONS
          end
        end

        def permission_error_message(error_code)
          case error_code
          when ::Gitlab::Graphql::Ai::ErrorCodes::NO_DEFAULT_NAMESPACE
            "You don't have permission to access this workflow. Please select a default namespace."
          else
            "You don't have permission to access this workflow."
          end
        end
      end
    end
  end
end
