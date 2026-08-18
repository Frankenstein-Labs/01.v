# frozen_string_literal: true

module SystemNotes # rubocop:disable Gitlab/BoundedContexts -- SystemNotes module already exists and holds the other services
  class AgentsService < ::SystemNotes::BaseService
    # Called when a new agent session is started
    #
    # session_id - The ID of the agent session
    # trigger_source - Who/what triggered the session. Can be a User object or a String (default: 'User')
    # service_account_user - The service account user executing the workflow (optional).
    #   When nil, no system note is created since Note requires a valid author.
    #
    # Example Note text:
    #
    # "started session [123](session_url) triggered by @jane_doe"
    #
    # Returns the created Note object, or nil if no valid author is available
    def agent_session_started(session_id, trigger_source, service_account_user)
      author = agent_author(service_account_user)
      return unless author

      session_link = create_session_link(session_id)
      trigger_source_reference = format_trigger_source(trigger_source)

      body = "started session #{session_link}"

      body += " triggered by #{trigger_source_reference}" if trigger_source.present?

      create_note(NoteSummary.new(
        noteable,
        project,
        author,
        body,
        action: 'duo_agent_started'
      ))
    end

    # Called when a Duo agent session is completed
    #
    # session_id - The ID of the agent session
    # service_account_user - The service account user executing the workflow (optional).
    #   When nil, no system note is created since Note requires a valid author.
    #
    # Example Note text:
    #
    # "completed session [123](session_url)"
    #
    # Returns the created Note object, or nil if no valid author is available
    def agent_session_completed(session_id, service_account_user)
      author = agent_author(service_account_user)
      return unless author

      session_link = create_session_link(session_id)

      body = "completed session #{session_link}"

      create_note(NoteSummary.new(
        noteable,
        project,
        author,
        body,
        action: 'duo_agent_completed'
      ))
    end

    # Called when a Duo agent session fails
    #
    # session_id - The ID of the agent session
    # reason - Optional reason for failure
    # service_account_user - The service account user executing the workflow (optional).
    #   When nil, no system note is created since Note requires a valid author.
    #
    # Example Note text:
    #
    # "session [123](session_url) failed"
    # "session [123](session_url) failed (dropped)"
    #
    # Returns the created Note object, or nil if no valid author is available
    def agent_session_failed(session_id, service_account_user, reason = nil)
      author = agent_author(service_account_user)
      return unless author

      session_link = create_session_link(session_id)

      body = "session #{session_link} failed"

      body += " (#{reason})" if reason.present?

      create_note(NoteSummary.new(
        noteable,
        project,
        author,
        body,
        action: 'duo_agent_failed'
      ))
    end

    private

    def agent_author(service_account_user)
      return service_account_user if service_account_user&.service_account?

      nil
    end

    def create_session_link(session_id)
      session_id = ERB::Util.html_escape(session_id)

      return session_id.to_s unless project

      session_url = "#{project.web_url}/-/automate/agent-sessions/#{session_id}"

      "[#{session_id}](#{session_url})"
    end

    # Formats a trigger source into a user reference or escaped string.
    #
    # For User objects this emits a `@username` reference (the same form
    # "requested review from @user" notes use) so Banzai renders it as a
    # linked user mention with the member popover, rather than a plain
    # full-name profile link.
    #
    # @param trigger_source [User, String] The trigger source to format
    # @return [String] User reference (@username) for User objects, escaped string otherwise
    #
    # Examples:
    #   format_trigger_source(user)     # => "@jane_doe"
    #   format_trigger_source("agent") # => "agent"
    def format_trigger_source(trigger_source)
      if trigger_source.is_a?(User)
        trigger_source.to_reference
      else
        ERB::Util.html_escape(trigger_source.to_s)
      end
    end
  end
end
