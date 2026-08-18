# frozen_string_literal: true

module Ai
  module ToolRules
    module Registry
      # Tool names are sourced from Ai::Catalog::BuiltInTool.
      # Tools in the catalog that are not mapped to a privilege group are skipped, they will
      # not appear in the governance UI or be subject to enforcement.
      #
      # MAINTENANCE: When a new tool is added to Ai::Catalog::BuiltInToolDefinitions, add it
      # to the appropriate privilege group below. If it is intentionally ungovernable (e.g. an
      # internal planning tool), leave it unmapped and it will be skipped automatically.
      PRIVILEGE_GROUP_MAPPING = {
        read_only_gitlab: %w[
          list_issues
          get_issue
          get_job_logs
          get_merge_request
          gitlab_merge_request_search
          list_merge_request_diffs
          list_all_merge_request_notes
          get_pipeline_failing_jobs
          get_downstream_pipelines
          get_project
          gitlab_group_project_search
          gitlab_issue_search
          gitlab_milestone_search
          gitlab__user_search
          gitlab_blob_search
          gitlab_commit_search
          gitlab_wiki_blob_search
          gitlab_note_search
          get_epic
          list_epics
          list_issue_notes
          get_issue_note
          get_repository_file
          list_repository_tree
          list_epic_notes
          get_commit
          list_commits
          get_commit_diff
          get_commit_comments
          list_instance_audit_events
          list_group_audit_events
          list_project_audit_events
          get_work_item
          list_work_items
          get_work_item_notes
          get_work_item_statuses
          get_vulnerability_details
          evaluate_vuln_fp_status
          get_previous_session_context
          ci_linter
          get_current_user
          get_glql_schema
          run_glql_query
          build_review_merge_request_context
          get_security_finding_details
          list_security_findings
          ascp_list_scans
          ascp_list_components
          get_wiki_page
          gitlab_documentation_search
          gitlab_api_get
          gitlab_graphql
          list_vulnerabilities
          extract_lines_from_text
          get_epic_note
          get_merge_request_conflicts
        ].freeze,

        read_only_files: %w[
          read_file
          read_files
          find_files
          list_dir
          grep
        ].freeze,

        read_write_gitlab: %w[
          create_issue
          update_issue
          create_issue_note
          create_merge_request
          create_merge_request_note
          create_merge_request_diff_note
          update_merge_request
          create_epic
          update_epic
          create_commit
          create_branch
          create_work_item
          update_work_item
          create_work_item_note
          update_vulnerability_severity
          post_sast_fp_analysis_to_gitlab
          post_secret_fp_analysis_to_gitlab
          post_duo_code_review
          set_form_permissions
          ascp_create_scan
          ascp_create_component
          ascp_create_security_context
          dismiss_vulnerability
          confirm_vulnerability
          revert_to_detected_vulnerability
          create_vulnerability_issue
          link_vulnerability_to_issue
          link_vulnerability_to_merge_request
        ].freeze,

        read_write_files: %w[
          create_file_with_contents
          edit_file
          mkdir
          run_tests
        ].freeze,

        run_commands: %w[
          run_command
        ].freeze,

        use_git: %w[
          run_git_command
        ].freeze,

        run_mcp_tools: [].freeze
      }.freeze

      # Tools that are intentionally not subject to governance rules.
      # Add a tool here only if it should not appear in the admin UI.
      UNGOVERNED_TOOLS = %w[
        get_pipeline_errors
        set_task_status
        add_new_task
        create_plan
        get_plan
        update_task_description
        remove_task
        start_flow
      ].freeze

      # Mapping exception catalog tool names to their MCP tool names.
      #
      MCP_TOOL_NAME_FOR = {
        'create_issue' => 'create_work_item'
      }.freeze

      ACTION_TYPE_GROUPS = {
        read: %i[read_only_gitlab read_only_files].freeze,
        write: %i[read_write_gitlab read_write_files].freeze,
        destroy: %i[run_commands run_mcp_tools use_git].freeze
      }.freeze

      CATEGORY_FOR_GROUP = {
        read_only_gitlab: 'GitLab Read',
        read_only_files: 'Files',
        read_write_gitlab: 'GitLab Write',
        read_write_files: 'Files',
        run_commands: 'Commands',
        use_git: 'Git',
        run_mcp_tools: 'MCP'
      }.freeze

      PRIVILEGE_GROUP_FOR = PRIVILEGE_GROUP_MAPPING.each_with_object({}) do |(group, tools), h|
        tools.each { |tool_name| h[tool_name] = group }
      end.freeze

      # Groups auto-approved (`allow`) when a namespace has no explicit rule. Only
      # read-only GitLab reads qualify; read-only file tools (local filesystem) and all
      # write/destroy tools default to `ask` (least privilege).
      #
      # Intentionally diverges from the pre_approved_agent_privileges column default
      # (`{1,2}` = read_write_files + read_only_gitlab) -- do not re-sync.
      DEFAULT_PREAPPROVED_GROUPS = %i[read_only_gitlab].freeze

      class << self
        def catalog_tool_names
          @catalog_tool_names ||= ::Ai::Catalog::BuiltInTool.all.map(&:name).freeze
        end

        # Tools in the catalog but not in PRIVILEGE_GROUP_MAPPING are skipped.
        def all_tool_names
          @all_tool_names ||= catalog_tool_names.select { |name| PRIVILEGE_GROUP_FOR.key?(name) }.freeze
        end

        # Returns the default permission for a tool when no explicit rule exists.
        # For tools in DEFAULT_PREAPPROVED_GROUPS, returns Permissions::ALLOW.
        # For all other tools, returns Permissions::ASK.
        # When both `tool_name:` and `group_name:` are given, `group_name` takes precedence.
        def default_permission_for(tool_name: nil, group_name: nil)
          resolved_group = group_name || (tool_name && PRIVILEGE_GROUP_FOR[tool_name])
          return Permissions::ALLOW if resolved_group && DEFAULT_PREAPPROVED_GROUPS.include?(resolved_group)

          Permissions::ASK
        end

        # Reverse lookup: tool name -> action type symbol (:read, :write, or :destroy).
        def action_type_for
          @action_type_for ||= all_tool_names.each_with_object({}) do |tool_name, h|
            group = PRIVILEGE_GROUP_FOR[tool_name]
            ACTION_TYPE_GROUPS.each do |type, groups|
              h[tool_name] = type if groups.include?(group)
            end
          end.freeze
        end

        # Returns the source string for a given tool name.
        # 'mcp' for tools in the run_mcp_tools privilege group, 'gitlab' for all others.
        def source_for(tool_name)
          PRIVILEGE_GROUP_FOR[tool_name] == :run_mcp_tools ? 'mcp' : 'gitlab'
        end

        # Maps an array of catalog tool names to their MCP equivalents.
        # Tools without a known MCP name are silently dropped.
        def to_mcp_tool_names(catalog_names)
          catalog_names.map { |name| MCP_TOOL_NAME_FOR.fetch(name, name) }
        end
      end
    end
  end
end
