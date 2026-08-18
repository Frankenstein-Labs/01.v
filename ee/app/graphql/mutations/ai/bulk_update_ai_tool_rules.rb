# frozen_string_literal: true

module Mutations
  module Ai
    class BulkUpdateAiToolRules < BaseMutation
      graphql_name 'BulkUpdateAiToolRules'
      description 'Bulk updates permission settings for multiple AI tool rules.'

      authorize :update_ai_tool_rule
      authorize_granular_token permissions: :update_ai_tool_rule, boundary_argument: :full_path, boundary_type: :group

      MAX_RULES = 100

      argument :full_path, GraphQL::Types::ID,
        required: true,
        description: 'Full path of the root namespace to update tool rules for.'

      argument :project_path, GraphQL::Types::ID,
        required: false,
        description: 'Full path of the project to update tool rules for. ' \
          'When provided, rules can only be stricter than the namespace rule.'

      argument :tool_rules, [Types::Ai::BulkToolRuleInputType],
        required: true,
        validates: { length: { minimum: 1, maximum: MAX_RULES } },
        description: "Tool rules to update (maximum #{MAX_RULES} entries)."

      field :results, [Types::Ai::BulkToolRuleResultType],
        null: false,
        description: 'Results for each tool rule update, including any per-item errors.'

      def resolve(full_path:, tool_rules:, project_path: nil)
        namespace = authorized_find!(full_path: full_path)

        project = project_path ? ::Project.find_by_full_path(project_path) : nil
        if project_path && (project.nil? || !Ability.allowed?(current_user, :read_project, project))
          raise_resource_not_available_error! "Project not accessible"
        end

        if project && project.root_namespace.id != namespace.id
          raise_resource_not_available_error! "Project does not belong to the namespace"
        end

        valid_inputs, error_results = partition_inputs(tool_rules)
        upsert_result = nil

        if valid_inputs.any?
          begin
            attributes = build_upsert_attributes(valid_inputs, namespace, project)
            upsert_result = ::Ai::ToolRule.upsert_all(
              attributes,
              unique_by: [:namespace_id, :project_id, :tool_name],
              returning: %w[tool_name],
              on_duplicate: Arel.sql(<<~SQL.squish)
                web_access = excluded.web_access,
                local_access = excluded.local_access,
                background_access = excluded.background_access,
                updated_at = excluded.updated_at
              SQL
            )

            emit_bulk_audit_event(namespace, project, valid_inputs)
          rescue ActiveRecord::StatementInvalid => e
            Gitlab::ErrorTracking.track_exception(e, namespace_id: namespace.id)

            failed_results = valid_inputs.map do |input|
              { tool_id: input[:tool_id], tool_rule: nil, errors: ['Failed to save rule'] }
            end

            return { results: failed_results + error_results, errors: ['Failed to save tool rules'] }
          end
        end

        success_results = build_success_results(valid_inputs, upsert_result)

        { results: success_results + error_results, errors: [] }
      end

      private

      def tool_ids(inputs)
        inputs.map { |i| i[:tool_id] } # rubocop:disable Rails/Pluck -- inputs is a Ruby array
      end

      def partition_inputs(tool_rules)
        valid = []
        errors = []

        tool_rules.each do |input|
          if input[:web_access].nil? && input[:local_access].nil? && input[:background_access].nil?
            errors << {
              tool_id: input[:tool_id],
              tool_rule: nil,
              errors: ["At least one of web_access, local_access, or background_access must be provided"]
            }
            next
          end

          if ::Ai::ToolRules::Registry.all_tool_names.include?(input[:tool_id])
            valid << input
          else
            errors << {
              tool_id: input[:tool_id],
              tool_rule: nil,
              errors: ["#{input[:tool_id]} is not a known tool name"]
            }
          end
        end

        [valid, errors]
      end

      def build_upsert_attributes(inputs, namespace, project)
        timestamp = Time.current
        inputs.map do |input|
          {
            namespace_id: namespace.id,
            project_id: project&.id,
            tool_name: input[:tool_id],
            web_access: input[:web_access],
            local_access: input[:local_access],
            background_access: input[:background_access],
            tool_source: ::Ai::ToolRules::Registry.source_for(input[:tool_id]),
            created_at: timestamp,
            updated_at: timestamp
          }
        end
      end

      def build_success_results(inputs, upsert_result)
        return [] if inputs.empty?
        return [] if upsert_result.nil?

        persisted_tool_names = upsert_result.map { |r| r['tool_name'] }.to_set # rubocop:disable Rails/Pluck -- upsert_result is an ActiveRecord::Result

        inputs.map do |input|
          unless persisted_tool_names.include?(input[:tool_id])
            next { tool_id: input[:tool_id], tool_rule: nil, errors: ['Failed to save rule'] }
          end

          group = ::Ai::ToolRules::Registry::PRIVILEGE_GROUP_FOR[input[:tool_id]]

          {
            tool_id: input[:tool_id],
            tool_rule: {
              id: input[:tool_id],
              name: ::Ai::ToolRules::ToolPresenter.display_name_for(input[:tool_id]),
              action_type: ::Ai::ToolRules::Registry.action_type_for[input[:tool_id]],
              category: ::Ai::ToolRules::Registry::CATEGORY_FOR_GROUP[group],
              source: ::Ai::ToolRules::Registry.source_for(input[:tool_id]),
              web_access: input[:web_access]&.to_s,
              local_access: input[:local_access]&.to_s,
              background_access: input[:background_access]&.to_s
            },
            errors: []
          }
        end
      end

      def emit_bulk_audit_event(namespace, project, inputs)
        tool_names = tool_ids(inputs).join(', ')

        ::Gitlab::Audit::Auditor.audit({
          name: 'ai_tool_rules_bulk_updated',
          author: current_user,
          scope: namespace,
          target: namespace,
          message: "Bulk updated #{inputs.size} AI tool rules: #{tool_names}",
          additional_details: {
            namespace_id: namespace.id,
            project_id: project&.id,
            tool_count: inputs.size,
            tool_names: tool_ids(inputs)
          }
        })
      end

      def find_object(full_path:, **_kwargs)
        namespace = ::Namespace.find_by_full_path(full_path)
        namespace&.root? ? namespace : nil
      end
    end
  end
end
