# frozen_string_literal: true

module Ai
  module DuoWorkflows
    module CodeReview
      module Mention
        class AssistantFlowHandler < BaseHandler
          def execute
            code_review_flow = ::Ai::Catalog::FoundationalFlow.code_review
            catalog_item = code_review_flow.catalog_item
            return unless catalog_item

            unless flow_enabled_for_project?(catalog_item)
              create_note_on(::Gitlab::Duo::CodeReview::Messages.foundational_flow_not_enabled_error)
              return
            end

            sa_result = ::Ai::Catalog::ItemConsumers::ResolveServiceAccountService.new(
              container: note.project.root_namespace,
              item: catalog_item
            ).execute

            unless sa_result.success?
              create_note_on(::Gitlab::Duo::CodeReview::Messages.missing_service_account_error)
              return
            end

            adapter = ::Ai::Messaging::Adapters::GitlabDuoNote.for_note(
              note, note_author_id: duo_code_review_bot.id
            )
            adapter.trigger(build_trigger_bundle(code_review_flow, sa_result.payload[:service_account]))
          end

          private

          def build_trigger_bundle(code_review_flow, service_account)
            ::Ai::Messaging::Adapters::Base::TriggerBundle.new(
              current_user: note.author,
              service_account: service_account,
              flow_reference: code_review_flow.foundational_flow_reference,
              flow_config_id: ::Ai::Messaging::Adapters::GitlabDuoNote::FLOW_CONFIG_ID,
              flow_config_schema_version: ::Ai::Messaging::Adapters::GitlabDuoNote::FLOW_CONFIG_SCHEMA_VERSION,
              flow_version: ::Ai::Messaging::Adapters::GitlabDuoNote::FLOW_VERSION,
              project: note.project,
              goal: build_goal,
              resource: note.noteable,
              source_branch: source_branch
            )
          end

          def source_branch
            note.noteable.source_branch if note.noteable.is_a?(MergeRequest)
          end

          def flow_enabled_for_project?(catalog_item)
            note.project.duo_foundational_flows_enabled &&
              note.project.enabled_flow_catalog_item_ids.include?(catalog_item.id)
          end

          def build_goal
            resource_url = ::Gitlab::UrlBuilder.build(note.noteable)
            conversation = build_conversation_context
            source_context = build_source_context(resource_url)

            <<~GOAL.strip
              <gitlab_context>
              #{source_context}
              </gitlab_context>

              <conversation>
              #{conversation}
              </conversation>
            GOAL
          end

          def build_conversation_context
            notes = note.discussion.notes
            ActiveRecord::Associations::Preloader.new(records: notes, associations: :author).call
            notes.map do |discussion_note|
              author = if discussion_note.authored_by_duo_bot?
                         'GitLabDuo'
                       else
                         "@#{discussion_note.author.username}"
                       end

              "<message author=\"#{author}\">\n#{discussion_note.note}\n</message>"
            end.join("\n")
          end

          def build_source_context(resource_url)
            resource_label = note.noteable.is_a?(MergeRequest) ? 'Merge request' : 'Issue'
            parts = []
            parts << "#{resource_label}: #{resource_url}"
            parts << "Project: #{note.project.full_path} (ID: #{note.project_id})"

            if note.noteable.is_a?(MergeRequest)
              mr = note.noteable
              parts << "Source branch: #{mr.source_branch}"
              parts << "Target branch: #{mr.target_branch}"
            end

            if note.diff_note?
              parts << "File: #{note.latest_diff_file_path}"
              parts << "Diff:\n#{note.raw_truncated_diff_lines}"
            end

            parts.join("\n")
          end
        end
      end
    end
  end
end
