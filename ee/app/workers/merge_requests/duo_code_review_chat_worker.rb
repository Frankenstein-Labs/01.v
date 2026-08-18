# frozen_string_literal: true

module MergeRequests
  class DuoCodeReviewChatWorker # rubocop:disable Scalability/IdempotentWorker -- Running worker twice will create duplicate notes
    include ApplicationWorker
    include ::Gitlab::Utils::StrongMemoize
    include Gitlab::InternalEventsTracking

    # Intent values returned by the AI Gateway classifier prompt defined in:
    # https://gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist/-/blob/main/ai_gateway/prompts/definitions/classify_code_review_mention_intent/system/1.0.0.jinja
    INTENT_CODE_REVIEW = 'code_review_request'
    INTENT_ASSISTANT_FLOW = 'assistant_flow'

    feature_category :duo_code_review

    urgency :low
    data_consistency :sticky
    worker_has_external_dependencies!
    deduplicate :until_executed
    sidekiq_options retry: 3

    def perform(note_id)
      note = Note.find_by_id(note_id)

      return unless note
      return unless note.duo_bot_mentioned?

      project = note.project
      duo_code_review_bot = ::Users::Internal.in_organization(project.organization_id).duo_code_review_bot

      track_internal_event('mention_gitlabduo_in_mr_comment', user: note.author, project: note.project)

      intent = classify_intent(note)

      if intent == INTENT_CODE_REVIEW
        ::Ai::DuoWorkflows::CodeReview::Mention::CodeReviewHandler.new(note).execute
        return
      end

      if use_assistant_flow?(intent, note)
        ::Ai::DuoWorkflows::CodeReview::Mention::AssistantFlowHandler.new(note).execute
        return
      end

      progress_note = create_progress_note(note, duo_code_review_bot)

      prompt_message = prepare_prompt_message(note)
      response = execute_chat_request(prompt_message, note)
      create_note_on(note, duo_code_review_bot, parse_response(note, response.response_body))
    rescue StandardError => error
      Gitlab::ErrorTracking.track_exception(error)

      create_note_on(note, duo_code_review_bot, error_note)
    ensure
      progress_note.destroy if progress_note
    end

    private

    def classify_intent(note)
      message_text = note.note.gsub(/@GitLabDuo\b/i, '').strip
      return if message_text.blank?

      prompt_message = ::Gitlab::Llm::AiMessage.for(action: :classify_code_review_mention_intent).new(
        request_id: SecureRandom.uuid,
        ai_action: 'classify_code_review_mention_intent',
        user: note.author,
        content: message_text,
        role: ::Gitlab::Llm::AiMessage::ROLE_USER,
        context: ::Gitlab::Llm::AiMessageContext.new(resource: note.noteable)
      )

      ::Gitlab::Llm::AiGateway::Completions::ClassifyCodeReviewMentionIntent.new(
        prompt_message,
        nil,
        { message: message_text }
      ).execute[:ai_message]&.content&.strip
    rescue StandardError => error
      Gitlab::ErrorTracking.track_exception(error)
      nil
    end

    def use_assistant_flow?(intent, note)
      intent == INTENT_ASSISTANT_FLOW &&
        ::Gitlab::Duo::CodeReview::ModeResolver.new(user: note.author, container: note.project).mode == :dap
    end

    def prepare_prompt_message(note)
      author = note.author
      thread = author.ai_conversation_threads.create!(conversation_type: :duo_code_review)
      prompt_message = nil
      notes = note.discussion.notes

      notes.each_with_index do |note, index|
        # We skip notes that are not mentioning the bot as we don't need it included
        # in the context we send with our chat request.
        next unless note.duo_bot_mentioned? || note.authored_by_duo_bot?

        role =
          if note.authored_by_duo_bot?
            ::Gitlab::Llm::AiMessage::ROLE_ASSISTANT
          else
            ::Gitlab::Llm::AiMessage::ROLE_USER
          end

        content = build_note_content(note, index == notes.size - 1)

        # We set the MR object as the resource so that it's accessible if Duo Chat decides
        # to utilize the merge_request_reader tool with identifier type "current".
        prompt_message = save_prompt_message(author, role, note.noteable, content, thread)
      end

      prompt_message
    end

    def build_note_content(note, last_note)
      content = note.note

      return content unless note.diff_note?

      # NOTE: We currently can't handle consequent messages from the same role so we need to
      #   append the extra instruction to the user message.
      #   We could change this once https://gitlab.com/gitlab-org/gitlab/-/issues/517435 gets fixed.
      last_note ? ::Gitlab::Llm::Utils::CodeSuggestionFormatter.append_prompt(content) : content
    end

    def parse_response(note, response_body)
      return response_body unless note.diff_note?

      ::Gitlab::Llm::Utils::CodeSuggestionFormatter.parse(response_body)[:body]
    end

    def save_prompt_message(user, role, resource, content, thread)
      prompt_message = ::Gitlab::Llm::ChatMessage
        .new(
          ai_action: 'chat',
          user: user,
          content: content,
          role: role,
          context: ::Gitlab::Llm::AiMessageContext.new(resource: resource),
          thread: thread
        )

      prompt_message.save!
      prompt_message
    end

    def execute_chat_request(prompt_message, note)
      ::Gitlab::Llm::Completions::Chat
        .new(
          prompt_message,
          nil,
          additional_context: additional_context(note),
          is_duo_code_review: true
        )
        .execute
    end

    # For non-diff notes, we want to leverage Duo Chat's merge_request_reader tool
    # to provide the MR context. In case the LLM decides not to use the "current" resource identifier,
    # we provide the MR's iid in a string format recognized by MergeRequestReader::Executor::SYSTEM_PROMPT.
    # This way it has the option to use the `iid` or `reference` identifier type instead.
    def additional_context(note)
      if note.diff_note?
        {
          id: note.latest_diff_file_path,
          category: 'file',
          content: note.raw_truncated_diff_lines
        }
      else
        {
          id: 'reference',
          category: 'merge_request',
          content: "!#{note.noteable.iid}"
        }
      end
    end

    def create_note_on(note, duo_code_review_bot, content)
      return if content.blank?

      merge_request = note.noteable

      ::Notes::CreateService.new(
        merge_request.project,
        duo_code_review_bot,
        noteable: merge_request,
        note: content,
        in_reply_to_discussion_id: note.discussion_id,
        type: note.type
      ).execute
    end

    def error_note
      s_("DuoCodeReview|I encountered some problems while responding to your query. Please try again later.")
    end

    def create_progress_note(note, duo_code_review_bot)
      ::SystemNotes::MergeRequestsService.new(
        noteable: note.noteable,
        container: note.project,
        author: duo_code_review_bot
      ).duo_code_review_chat_started(note.discussion)
    end
  end
end
