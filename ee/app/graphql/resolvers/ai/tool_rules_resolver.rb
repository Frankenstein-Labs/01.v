# frozen_string_literal: true

module Resolvers
  module Ai
    class ToolRulesResolver < BaseResolver
      include LooksAhead

      authorize :read_ai_tool_rule
      authorize_granular_token permissions: :read_ai_tool_rule, boundary_argument: :full_path, boundary_type: :group

      type Types::Ai::ToolRuleType.connection_type, null: true

      argument :full_path, GraphQL::Types::ID,
        required: true,
        description: 'Full path of the root namespace to fetch tool rules for.'

      argument :project_path, GraphQL::Types::ID,
        required: false,
        description: 'Full path of the project to fetch effective tool rules for. ' \
          'When provided, returns the merged effective rules for the project, ' \
          'applying most-restrictive-wins across namespace and project rules.'

      argument :search, GraphQL::Types::String,
        required: false,
        description: 'Case-insensitive text search on tool name or display name.'

      argument :action_type, Types::Ai::ToolActionTypeEnum,
        required: false,
        description: 'Filter tools by action type.'

      def resolve_with_lookahead(full_path:, project_path: nil, search: nil, action_type: nil)
        namespace = authorized_find!(full_path: full_path)
        project = project_path ? ::Project.find_by_full_path(project_path) : nil

        raise_resource_not_available_error! if project && !Ability.allowed?(current_user, :read_project, project)

        if project && project.root_namespace.id != namespace.id
          raise_resource_not_available_error! "Project does not belong to the namespace"
        end

        service = ::Ai::ToolRules::ResolutionService.new(
          namespace: namespace,
          surface: :web,
          project: project
        )

        effective_rules = service.effective_rules
        search_term = search&.downcase
        normalized_action_type = action_type&.to_sym

        ::Ai::ToolRules::Registry.all_tool_names.filter_map do |tool_name|
          build_tool_hash(tool_name, effective_rules, search_term, normalized_action_type)
        end
      end

      private

      def find_object(full_path:, **_kwargs)
        namespace = ::Namespace.find_by_full_path(full_path)
        namespace&.root? ? namespace : nil
      end

      def build_tool_hash(tool_name, effective_rules, search_term, normalized_action_type)
        privilege_group = ::Ai::ToolRules::Registry::PRIVILEGE_GROUP_FOR[tool_name]
        tool_action_type = ::Ai::ToolRules::Registry.action_type_for[tool_name]

        return if normalized_action_type && tool_action_type != normalized_action_type

        display_name = ::Ai::ToolRules::ToolPresenter.display_name_for(tool_name)
        return if search_term.present? && tool_name.exclude?(search_term) &&
          display_name.downcase.exclude?(search_term)

        rule = effective_rules[tool_name]
        effective_default = ::Ai::ToolRules::Registry.default_permission_for(group_name: privilege_group)

        {
          id: tool_name,
          name: display_name,
          action_type: tool_action_type,
          category: ::Ai::ToolRules::Registry::CATEGORY_FOR_GROUP[privilege_group],
          source: ::Ai::ToolRules::Registry.source_for(tool_name),
          web_access: rule&.web_access || effective_default,
          local_access: rule&.local_access || effective_default,
          background_access: rule&.background_access || ::Ai::ToolRules::Permissions.background_effective(effective_default)
        }
      end
    end
  end
end
