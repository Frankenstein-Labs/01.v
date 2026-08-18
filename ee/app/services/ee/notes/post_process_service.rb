# frozen_string_literal: true

module EE
  module Notes
    module PostProcessService
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      override :execute
      def execute
        super

        ::Analytics::RefreshCommentsData.for_note(note)&.execute

        audit_comment_created unless note.system?
        audit_bot_author_comment if note.author.project_bot?

        process_duo_code_review_chat
        process_ai_flow_triggers
      end

      private

      def audit_comment_created
        return unless note.resource_parent

        ::Gitlab::Audit::Auditor.audit({
          name: 'comment_created',
          author: note.author,
          scope: note.resource_parent,
          target: note,
          message: "Added comment: #{::Gitlab::UrlBuilder.note_url(note)}",
          additional_details: {
            body: note.note
          },
          target_details: {
            id: note.id,
            noteable_type: note.noteable_type,
            noteable_id: note.noteable_id
          },
          stream_only: true
        })
      end

      def audit_bot_author_comment
        audit_context = {
          name: 'comment_by_project_bot',
          author: note.author,
          scope: note.project,
          target: note,
          message: "Added comment: #{::Gitlab::UrlBuilder.note_url(note)}",
          target_details: {
            id: note.id,
            noteable_type: note.noteable_type,
            noteable_id: note.noteable_id
          },
          stream_only: true
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def process_duo_code_review_chat
        author = note.author

        # Duo Code Review should respond to any MR note when mentioned
        return unless note.for_merge_request?

        # We don't want the bot to talk to itself
        return if note.authored_by_duo_bot?

        return unless note.noteable.ai_review_merge_request_allowed?(author)
        return unless note.duo_bot_mentioned?

        ::MergeRequests::DuoCodeReviewChatWorker.perform_async(note.id)
      end

      def process_ai_flow_triggers
        if note.project.nil?
          reply_non_project_noteable_error if mentioned_service_accounts_present?
          return
        end

        return unless note.author.can?(:trigger_ai_flow, note.project)

        lazy_sync_foundational_mention_triggers

        flow_triggers = note.project.ai_flow_triggers.triggered_on(:mention).by_service_accounts(note.mentioned_users)
        return if flow_triggers.empty?

        flow_triggers.each do |flow_trigger|
          # We don't want the service account to talk to itself
          next if note.author == flow_trigger.service_account

          if route_mention_through_adapter?(flow_trigger)
            run_mention_through_adapter(flow_trigger)
          else
            run_mention_through_run_service(flow_trigger)
          end
        end
      end

      def route_mention_through_adapter?(flow_trigger)
        consumer = flow_trigger.ai_catalog_item_consumer
        consumer.present? && consumer.item&.foundational?
      end

      def run_mention_through_adapter(flow_trigger)
        adapter = ::Ai::Messaging::Adapters::GitlabDuoNote.for_note(
          note,
          note_author_id: flow_trigger.service_account&.id
        )

        adapter.with_lifecycle_hooks do |callback_context|
          ::Ai::FlowTriggers::RunService.new(
            project: note.project,
            current_user: note.author,
            resource: note.noteable,
            flow_trigger: flow_trigger
          ).execute(mention_run_params.merge(
            messaging_callback_context: callback_context
          ))
        end
      end

      def run_mention_through_run_service(flow_trigger)
        ::Ai::FlowTriggers::RunService.new(
          project: note.project,
          current_user: note.author,
          resource: note.noteable,
          flow_trigger: flow_trigger
        ).execute(mention_run_params)
      end

      def mention_run_params
        {
          input: mention_conversation_context,
          event: :mention,
          discussion: note.discussion,
          discussion_id: note.discussion_id,
          note_id: note.id,
          triggered_by_username: note.author.username,
          source_context: mention_source_context
        }
      end

      def mention_conversation_context
        @mention_conversation_context ||= ::Ai::Notes::ConversationContextBuilder.new(note).build
      end

      def mention_source_context
        resource = note.noteable
        resource_url = ::Gitlab::UrlBuilder.build(resource)
        note_url = "#{resource_url}#note_#{note.id}"
        resource_label = ::Ai::Catalog::GoalTemplates::Developer.resource_display_name(resource).capitalize
        title = resource.respond_to?(:title) ? resource.title : nil

        parts = []
        parts << "#{resource_label}: #{resource_url}"
        parts << "Title: #{title}" if title.present?
        parts << "Note: #{note_url}"
        parts.join("\n")
      end

      def mentioned_service_accounts
        @mentioned_service_accounts ||= note.mentioned_users.select(&:service_account?)
      end

      def mentioned_service_accounts_present?
        mentioned_service_accounts.present?
      end

      def reply_non_project_noteable_error
        return unless note.noteable

        error_body = s_(
          'AiFlowTriggers|Mention-triggered flows are not supported on group-level resources. ' \
            'They require a project-level item such as an issue or merge request.'
        )

        service_account = mentioned_service_accounts.first
        error_note = ::Notes::CreateService.new(
          nil,
          service_account,
          note: error_body,
          noteable: note.noteable,
          in_reply_to_discussion_id: note.discussion_id
        ).execute(executing_user: note.author)

        return if error_note.persisted?

        ::Gitlab::AppLogger.warn(
          message: "Failed to post non-project noteable error reply",
          noteable_type: note.noteable_type,
          noteable_id: note.noteable_id,
          service_account_id: service_account.id,
          error: error_note.errors.full_messages.join(', ')
        )
      end

      def lazy_sync_foundational_mention_triggers
        return if mentioned_service_accounts.empty?

        mentioned_service_accounts.each do |service_account|
          parent_consumer = ::Ai::Catalog::ItemConsumer.for_service_account(service_account.id).first
          next unless foundational_flow_declares_mention_trigger?(parent_consumer)
          next if mention_trigger_exists_for?(service_account)

          create_foundational_mention_trigger(service_account, parent_consumer)
        end
      end

      def foundational_flow_declares_mention_trigger?(parent_consumer)
        flow_definition = foundational_flow_for(parent_consumer)
        return false unless flow_definition

        flow_definition.triggers.include?(::Ai::FlowTrigger::EVENT_TYPES[:mention])
      end

      def mention_trigger_exists_for?(service_account)
        note.project.ai_flow_triggers
          .triggered_on(:mention)
          .by_service_accounts([service_account])
          .exists?
      end

      def create_foundational_mention_trigger(service_account, parent_consumer)
        consumer = project_item_consumer_for(parent_consumer)
        return unless consumer

        trigger = ::Ai::FlowTrigger.create(
          project: note.project,
          ai_catalog_item_consumer: consumer,
          event_types: [::Ai::FlowTrigger::EVENT_TYPES[:mention]],
          description: "Foundational flow trigger for #{consumer.item.name}"
        )

        return if trigger.persisted?

        ::Gitlab::AppLogger.warn(
          message: "Failed to lazy-create foundational mention trigger",
          project_id: note.project.id,
          user_id: service_account.id,
          error: trigger.errors.full_messages.join(', ')
        )
      end

      def project_item_consumer_for(parent_consumer)
        parent_consumer.child_item_consumers.for_projects([note.project]).first
      end

      # The uniqueness constraint on service_account_id means at most one parent
      # consumer exists per service account, so foundational_flow_reference is
      # checked in Ruby rather than via a SQL join.
      def foundational_flow_for(parent_consumer)
        return unless parent_consumer&.item&.foundational_flow_reference

        ::Ai::Catalog::FoundationalFlow[parent_consumer.item.foundational_flow_reference]
      end
    end
  end
end
