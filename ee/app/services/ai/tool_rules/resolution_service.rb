# frozen_string_literal: true

module Ai
  module ToolRules
    class ResolutionService
      PRIVILEGE_GROUP_TO_CONSTANT = {
        read_only_gitlab: ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB,
        read_only_files: ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_FILES,
        read_write_gitlab: ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
        read_write_files: ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
        run_commands: ::Ai::DuoWorkflows::Workflow::AgentPrivileges::RUN_COMMANDS,
        use_git: ::Ai::DuoWorkflows::Workflow::AgentPrivileges::USE_GIT,
        run_mcp_tools: ::Ai::DuoWorkflows::Workflow::AgentPrivileges::RUN_MCP_TOOLS
      }.freeze

      # Most restrictive wins: deny > ask > allow > nil (fallback)
      PERMISSION_RESTRICTIVENESS = {
        Permissions::DENY => 2,
        Permissions::ASK => 1,
        Permissions::ALLOW => 0
      }.freeze

      def initialize(namespace:, surface: :web, project: nil)
        @namespace = namespace
        @surface = surface
        @project = project
      end

      def execute
        rules = effective_rules

        agent_privileges = []
        pre_approved_agent_privileges = []
        pre_approved_tools = []
        denied_tools = []
        ask_tools = []

        PRIVILEGE_GROUP_TO_CONSTANT.each do |group, constant|
          fallback = fallback_permission(group)
          denied_tools.concat(explicitly_configured_tools_for_group(group, rules, Permissions::DENY))
          pre_approved_tools.concat(explicitly_configured_tools_for_group(group, rules, Permissions::ALLOW))
          ask_tools.concat(explicitly_configured_tools_for_group(group, rules, Permissions::ASK))

          case resolve_group(group, rules, fallback)
          when :deny
            next
          when :ask
            agent_privileges << constant
          when :allow
            agent_privileges << constant
            pre_approved_agent_privileges << constant
            pre_approved_tools.concat(allowed_tools_for_group(group, rules, fallback))
          end
        end

        agent_privileges << ::Ai::DuoWorkflows::Workflow::AgentPrivileges::START_FLOWS
        pre_approved_agent_privileges << ::Ai::DuoWorkflows::Workflow::AgentPrivileges::START_FLOWS

        ServiceResponse.success(payload: {
          agent_privileges: agent_privileges,
          pre_approved_agent_privileges: pre_approved_agent_privileges,
          pre_approved_tools: ::Ai::ToolRules::Registry.to_mcp_tool_names(pre_approved_tools.uniq),
          denied_tools: ::Ai::ToolRules::Registry.to_mcp_tool_names(denied_tools.uniq),
          ask_tools: ::Ai::ToolRules::Registry.to_mcp_tool_names(ask_tools.uniq)
        })
      end

      # Where a project rule exists, most restrictive wins, projects can only escalate,
      # never loosen a namespace-level policy.
      def effective_rules
        namespace_rules = ::Ai::ToolRule.for_namespace(@namespace.id).index_by(&:tool_name)
        project_rules = @project ? ::Ai::ToolRule.for_project(@project.id).index_by(&:tool_name) : {}
        merge_rules(namespace_rules, project_rules)
      end

      private

      # Merges namespace and project rules, applying most-restrictive-wins per tool.
      # Note: Hash#merge with a block only fires for keys present in both hashes.
      # Keys only in project_rules (no matching namespace rule) are added as-is from the project.
      def merge_rules(namespace_rules, project_rules)
        return namespace_rules if project_rules.empty?

        namespace_rules.merge(project_rules) do |_tool_name, ns_rule, proj_rule|
          most_restrictive_rule(ns_rule, proj_rule)
        end
      end

      # Returns the more restrictive of two rules for the current surface.
      # Projects cannot loosen a namespace-level policy.
      def most_restrictive_rule(ns_rule, proj_rule)
        ns_permission = ns_rule.access_for(@surface)
        proj_permission = proj_rule.access_for(@surface)

        # If namespace has no value for this surface, project rule can set it freely.
        return proj_rule if ns_permission.nil?

        # If project has no value for this surface, keep the namespace rule.
        return ns_rule if proj_permission.nil?

        ns_score = PERMISSION_RESTRICTIVENESS[ns_permission.to_s]
        proj_score = PERMISSION_RESTRICTIVENESS[proj_permission.to_s]

        proj_score > ns_score ? proj_rule : ns_rule
      end

      def resolve_group(group, rules, fallback)
        permissions = ::Ai::ToolRules::Registry::PRIVILEGE_GROUP_MAPPING
          .fetch(group, [])
          .filter_map do |tool_name|
            rule = rules[tool_name]
            next unless rule

            rule.access_for(@surface)
          end

        return fallback if permissions.empty?
        return :deny if permissions.include?(Permissions::DENY)
        return :ask if permissions.include?(Permissions::ASK)

        :allow
      end

      def fallback_permission(group)
        permission = ::Ai::ToolRules::Registry.default_permission_for(group_name: group)

        # On the background surface an unset permission resolves to `allow` (via
        # background_effective) so existing pipelines keep working and admins opt in
        # with explicit rules. Reached only when the background-governance flag is on.
        permission = ::Ai::ToolRules::Permissions.background_effective(permission) if background_surface?

        permission.to_sym
      end

      def background_surface?
        @surface.to_s == ::Ai::ToolRules::GovernanceSurface::BACKGROUND.to_s
      end

      def allowed_tools_for_group(group, rules, fallback)
        ::Ai::ToolRules::Registry::PRIVILEGE_GROUP_MAPPING.fetch(group, []).select do |tool_name|
          rule = rules[tool_name]
          permission = rule ? rule.access_for(@surface) : fallback.to_s

          # No value for this surface falls back to the group default, so enforcement
          # matches the displayed default and another surface's rule can't demote it here.
          permission = fallback.to_s if permission.nil?

          permission == Permissions::ALLOW
        end
      end

      def explicitly_configured_tools_for_group(group, rules, permission)
        ::Ai::ToolRules::Registry::PRIVILEGE_GROUP_MAPPING.fetch(group, []).select do |tool_name|
          rule = rules[tool_name]
          next false unless rule

          rule.access_for(@surface) == permission
        end
      end
    end
  end
end
