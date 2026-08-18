# frozen_string_literal: true

module Mutations
  module Ai
    class UpdateAiToolRule < BaseMutation
      graphql_name 'UpdateAiToolRule'
      description 'Updates the permission settings for an AI tool rule.'
      authorize :update_ai_tool_rule
      authorize_granular_token permissions: :update_ai_tool_rule, boundary_argument: :full_path, boundary_type: :group

      argument :background_access, Types::Ai::BackgroundToolPermissionEnum,
        required: false,
        experiment: { milestone: '19.3' },
        description: 'Permission mode for the background-flow surface.'
      argument :full_path, GraphQL::Types::ID,
        required: true,
        description: 'Full path of the root namespace to update the tool rule for.'
      argument :local_access, Types::Ai::ToolPermissionEnum,
        required: false,
        description: 'Permission mode for local or IDE surface.'
      argument :project_path, GraphQL::Types::ID,
        required: false,
        description: 'Full path of the project to update the tool rule for. ' \
          'When provided, creates a project-level rule that can only be ' \
          'stricter than the namespace rule.'
      argument :tool_id, GraphQL::Types::String,
        required: true,
        description: 'Tool name string identifying the tool to update. For example, "create_issue".'
      argument :web_access, Types::Ai::ToolPermissionEnum,
        required: false,
        description: 'Permission mode for web surface.'

      field :tool_rule,
        Types::Ai::ToolRuleType,
        null: true,
        description: 'Updated tool rule after mutation.'

      def resolve(full_path:, tool_id:, project_path: nil, web_access: nil, local_access: nil, background_access: nil)
        namespace = find_namespace(full_path)
        raise_resource_not_available_error! unless namespace

        if project_path.present?
          project = authorized_find!(project_path: project_path)
          raise_resource_not_available_error! unless project.root_namespace.id == namespace.id
        else
          raise_resource_not_available_error! unless current_user.can?(:update_ai_tool_rule, namespace)
        end

        unless ::Ai::ToolRules::Registry.all_tool_names.include?(tool_id)
          raise ::Gitlab::Graphql::Errors::ArgumentError, "#{tool_id} is not a known tool name"
        end

        rule = ::Ai::ToolRule.find_or_initialize_for_namespace(
          namespace_id: namespace.id,
          tool_name: tool_id,
          project_id: project&.id
        )

        result = ::Ai::ToolRules::UpsertService.new(rule, current_user, {
          web_access: web_access,
          local_access: local_access,
          background_access: background_access
        }).execute

        if result.success?
          rule = result.payload
          group = ::Ai::ToolRules::Registry::PRIVILEGE_GROUP_FOR[rule.tool_name]
          {
            tool_rule: {
              id: rule.tool_name,
              name: ::Ai::ToolRules::ToolPresenter.display_name_for(rule.tool_name),
              action_type: ::Ai::ToolRules::Registry.action_type_for[rule.tool_name],
              category: ::Ai::ToolRules::Registry::CATEGORY_FOR_GROUP[group],
              source: ::Ai::ToolRules::Registry.source_for(rule.tool_name),
              web_access: rule.web_access,
              local_access: rule.local_access,
              background_access: rule.background_access
            },
            errors: []
          }
        else
          { tool_rule: nil, errors: result.errors }
        end
      end

      private

      def find_object(full_path: nil, project_path: nil, **_kwargs)
        if project_path.present?
          ::Project.find_by_full_path(project_path)
        else
          find_namespace(full_path)
        end
      end

      def find_namespace(full_path)
        namespace = ::Namespace.find_by_full_path(full_path)
        namespace&.root? ? namespace : nil
      end
    end
  end
end
