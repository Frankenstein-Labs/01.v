# frozen_string_literal: true

module Ai
  module Messaging
    module Adapters
      # Delivers the UX for AI flows triggered by @mentioning a service account
      # in a note. Two surfaces share one note lifecycle (started note -> reply);
      # they differ only in who authors the notes:
      #
      #   * @GitLabDuo MR mention (AssistantFlowHandler, via Base#trigger):
      #     authored by the Duo code-review bot.
      #
      #   * Duo Developer @mention (Notes::PostProcessService, via
      #     Base#with_lifecycle_hooks): authored by the flow-trigger SA.
      #
      # Both surfaces log session start and session end on the item's activity
      # log via the framework's default system notes (CreateWorkflowService and
      # UpdateWorkflowStatusService).
      #
      class GitlabDuoNote < Base
        include SafeFormatHelper

        FLOW_CONFIG_ID = 'gitlab_duo_mention_assistant'
        FLOW_CONFIG_SCHEMA_VERSION = 'v1'
        FLOW_VERSION = 'v1'

        def self.adapter_key
          'gitlab_duo_note'
        end

        def self.for_note(note, note_author_id:)
          new(note_id: note.id, note_author_id: note_author_id)
        end

        def self.from_callback_context(ctx)
          new(
            note_id: ctx['note_id'],
            note_author_id: ctx['note_author_id']
          )
        end

        def initialize(note_id:, note_author_id:)
          @note_id = note_id
          @note_author_id = note_author_id
        end

        def on_request_received
          note = find_note(@note_id)
          return ServiceResponse.error(message: 'Note not found') unless note
          return ServiceResponse.error(message: 'Noteable not found') unless note.noteable

          ServiceResponse.success
        end

        def on_flow_enqueued(callback_context:, workflow:)
          note = find_note(callback_context['note_id'])
          author = note_author(callback_context)
          return unless note&.noteable && author

          started_note = ::SystemNotes::IssuablesService.new(
            noteable: note.noteable,
            container: note.project,
            author: author
          ).duo_mention_started(workflow, note.discussion)

          return unless started_note&.persisted?

          workflow.merge_messaging_callback_context!('started_note_id' => started_note.id)
        end

        # Persisted on the workflow; CallbackWorker rebuilds the adapter from it.
        def build_callback_context
          {
            'adapter' => self.class.adapter_key,
            'note_id' => @note_id,
            'note_author_id' => @note_author_id
          }.compact
        end

        # Notes::CreateService returns an unsaved note instead of raising when the note is
        # rejected, so persisted? is what tells CallbackWorker the reply actually landed.
        def deliver_result(callback_context:, message:, workflow:)
          started_note = load_started_note(callback_context)
          destroy_started_note(started_note, callback_context['started_note_id'])
          reply = create_note_on(callback_context, append_session_link(message, workflow))
          link_created_note(workflow, reply)

          reply&.persisted?
        end

        def deliver_error(callback_context:, error:)
          started_note = load_started_note(callback_context)
          workflow = started_note&.duo_metadata&.workflow
          destroy_started_note(started_note, callback_context['started_note_id'])
          error_note = create_note_on(callback_context, error_text(error))
          link_created_note(workflow, error_note)
        end

        private

        def find_note(note_id)
          ::Note.find_by_id(note_id)
        end

        def note_author(ctx)
          ::User.find_by_id(ctx['note_author_id'])
        end

        # Loads the started note once so callers can reuse it for both workflow
        # lookup and destruction without issuing a second DB query.
        def load_started_note(callback_context)
          note_id = callback_context['started_note_id']
          return unless note_id

          ::Note.find_by_id(note_id)
        end

        def destroy_started_note(started_note, note_id)
          return unless started_note

          # Rescue so a destroy failure is tracked but never blocks the reply
          # that deliver_result/deliver_error posts next.
          started_note.destroy!
        rescue ActiveRecord::RecordNotDestroyed => e
          ::Gitlab::ErrorTracking.track_exception(e, note_id: note_id)
        end

        def append_session_link(message, workflow)
          return message if workflow.nil?

          session_link = safe_format(
            s_("Ai|[View session](%{url})"),
            url: workflow.web_url
          )

          [message.presence, session_link].compact.join("\n\n")
        end

        def create_note_on(callback_context, content)
          return if content.blank?

          note = find_note(callback_context['note_id'])
          author = note_author(callback_context)
          return unless note&.noteable && author

          # A composite-identity service account's permissions are evaluated
          # against a linked human; terminal delivery runs in CallbackWorker with
          # no request identity, so without this link the SA cannot post the
          # reply. Link it to the original mentioner, mirroring the composite
          # token the legacy self-post path relied on. (No-op for @GitLabDuo,
          # whose bot author is not composite-enforced.)
          link_composite_identity!(author, note.author, note.project.organization)

          ::Notes::CreateService.new(
            note.project,
            author,
            noteable: note.noteable,
            note: content,
            in_reply_to_discussion_id: note.discussion_id
          ).execute
        end

        def link_created_note(workflow, note)
          return unless workflow
          return unless note&.persisted?

          ::Ai::DuoWorkflows::LinkArtifactService.new(
            workflow: workflow,
            artifact: note,
            link_type: :created
          ).execute
        rescue StandardError => e
          ::Gitlab::ErrorTracking.track_exception(e, workflow_id: workflow.id)
        end

        def error_text(error)
          case error
          when :service_account_error
            ::Gitlab::Duo::CodeReview::Messages.missing_service_account_error
          when :execute_workflow_failed
            s_("DuoCodeReview|Failed to start the Duo workflow. Please try again.")
          when :flow_failed
            s_("DuoCodeReview|Something went wrong while running the task. Please try again.")
          when :no_response
            s_("DuoCodeReview|The workflow completed but no response was produced. Please try again.")
          else
            s_("DuoCodeReview|Something went wrong. Please try again.")
          end
        end
      end
    end
  end
end
