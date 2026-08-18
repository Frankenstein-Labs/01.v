# frozen_string_literal: true

module EE
  module Integrations
    module SlackEvents
      module AppMentionedService
        extend ::Gitlab::Utils::Override

        FOUNDATIONAL_FLOW_REFERENCE = 'developer/v1'

        SLACK_CONTEXT_PREAMBLE = <<~PREAMBLE.strip
          You were mentioned in a Slack conversation.

          <formatting>
          Respond in standard Markdown. Slack renders it natively, so do not use
          Slack-specific mrkdwn syntax. Always write links as [text](url); never
          put a bare URL inside bold, italic, or code formatting.
          </formatting>
          Your final response will automatically be posted back to the Slack thread.
        PREAMBLE

        SLACK_GOAL_MAX = ::Ai::Messaging::Adapters::Slack::GOAL_CHARACTER_LIMIT

        private

        override :duo_workspace_namespace
        def duo_workspace_namespace(gitlab_user)
          gitlab_user.default_duo_namespace&.root_ancestor
        end

        override :trigger_duo_flow
        def trigger_duo_flow(gitlab_user)
          resolved = ::Ai::Messaging::DefaultProjectFlowResolver.new(
            flow_reference: FOUNDATIONAL_FLOW_REFERENCE, current_user: gitlab_user
          ).execute

          adapter = build_adapter

          unless resolved.success?
            adapter.deliver_error(
              callback_context: adapter.build_callback_context,
              error: resolved.reason
            )
            return
          end

          goal = build_goal

          # build_goal returns nil when the triggering message alone exceeds the
          # budget, so truncation cannot produce a usable goal. Tell the user.
          unless goal
            slack_api.add_reaction(channel: channel_id, name: 'x', timestamp: message_ts)
            adapter.deliver_error(
              callback_context: adapter.build_callback_context,
              error: :message_too_long
            )
            return
          end

          bundle = ::Ai::Messaging::Adapters::Base::TriggerBundle.new(
            current_user: gitlab_user,
            service_account: resolved.payload[:service_account],
            flow_reference: FOUNDATIONAL_FLOW_REFERENCE,
            flow_config_id: resolved.payload[:flow_config_id],
            flow_config_schema_version: resolved.payload[:flow_config_schema_version],
            flow_version: resolved.payload[:flow_version],
            project: resolved.payload[:project],
            goal: goal
          )

          result = adapter.trigger(bundle)
          return if result.success?

          ::Gitlab::IntegrationsLogger.info(
            message: 'Duo Messaging: flow trigger failed',
            failure_reason: result.reason,
            error_message: result.message,
            slack_workspace_id: slack_workspace_id
          )
        end

        def build_goal
          messages = fetch_thread_messages
          if messages.nil? || messages.empty?
            messages = [{ 'user' => slack_user_id, 'text' => slack_event[:text].to_s }]
          end

          user_map = build_user_map(messages)
          conversation = build_conversation(messages, user_map)
          return if conversation.nil? # the triggering message alone exceeds the budget

          assemble_goal(conversation, user_map)
        end

        # Returns the conversation block, or nil when even the newest (triggering)
        # message cannot fit on its own.
        def build_conversation(messages, user_map)
          rendered = messages.map { |m| render_message(m, user_map) }
          full_conversation = rendered.join("\n")

          # Fast path: everything fits within the budget.
          return full_conversation if goal_fits?(full_conversation, user_map)

          truncate_conversation(rendered, user_map)
        end

        # Returns true when the full goal assembled with the given conversation block
        # would not exceed SLACK_GOAL_MAX.
        def goal_fits?(conversation_block, user_map)
          assemble_goal(conversation_block, user_map).length <= SLACK_GOAL_MAX
        end

        # Assembles the full goal string from its parts so we can measure its length.
        def assemble_goal(conversation_block, user_map)
          participants = format_participants(user_map)
          <<~GOAL.strip
            #{SLACK_CONTEXT_PREAMBLE}

            <participants>
            #{participants}
            </participants>

            <conversation>
            #{conversation_block}
            </conversation>
          GOAL
        end

        # Keeps the largest chronological suffix (the newest messages, including the
        # triggering one) that fits, dropping the oldest and marking the gap.
        # Returns nil when not even the newest message fits on its own. Re-measuring
        # the real goal each pass avoids hand-tracking per-message character costs;
        # threads are small, so the extra assembles are negligible.
        def truncate_conversation(rendered, user_map)
          kept = nil

          (rendered.length - 1).downto(0) do |i|
            block = conversation_block(rendered[i..], i)
            break unless goal_fits?(block, user_map)

            kept = block
          end

          kept
        end

        # Joins the included (already rendered) messages, prefixed with a marker
        # when older messages were dropped.
        def conversation_block(included_rendered, omitted_count)
          parts = []
          parts << omitted_marker(omitted_count) if omitted_count > 0
          parts.concat(included_rendered)
          parts.join("\n")
        end

        def omitted_marker(count)
          "<!-- #{count} earlier #{'message'.pluralize(count)} omitted due to length -->"
        end

        def render_message(message, user_map)
          author_id = message['user'] || message['bot_id']
          gitlab_attr = user_map[author_id] ? " gitlab=\"@#{user_map[author_id]}\"" : ''
          text = CGI.escapeHTML(message['text'].to_s)
          "<message author=\"#{author_id}\"#{gitlab_attr}>\n#{text}\n</message>"
        end

        def fetch_thread_messages
          parsed = slack_api.get('conversations.replies', channel: channel_id, ts: thread_ts).parsed_response

          if parsed.is_a?(Hash) && parsed['ok']
            parsed['messages'] || []
          else
            log_slack_error('Slack API error when fetching thread', parsed)
            nil
          end
        rescue *::Gitlab::HTTP::HTTP_ERRORS => e
          ::Gitlab::ErrorTracking.track_exception(e, slack_workspace_id: slack_workspace_id)
          nil
        end

        # Returns a mapping of Slack user IDs to GitLab usernames:
        #   { 'U0001' => 'alice', 'U0002' => nil }
        # Unlinked Slack users map to nil.
        def build_user_map(messages)
          # Cap resolved authors to bound the DB query. Recent participants are
          # most relevant, so we take the last N unique IDs from the conversation.
          author_ids = messages.filter_map { |m| m['user'] }.uniq.last(50)
          gitlab_map = ChatName.for_team_and_chat_ids(slack_workspace_id, author_ids).with_user
            .each_with_object({}) { |cn, h| h[cn.chat_id] = cn.user.username }

          author_ids.index_with { |id| gitlab_map[id] }
        rescue ::ActiveRecord::ActiveRecordError => e
          ::Gitlab::ErrorTracking.track_exception(e, slack_workspace_id: slack_workspace_id)
          {}
        end

        def format_participants(user_map)
          user_map.map do |slack_id, gitlab_username|
            parts = ["Slack: #{slack_id}"]
            parts << "GitLab: @#{gitlab_username}" if gitlab_username
            "- #{parts.join(' | ')}"
          end.join("\n")
        end

        def log_slack_error(message, response)
          ::Gitlab::IntegrationsLogger.error(
            message: message,
            slack_workspace_id: slack_workspace_id,
            slack_user_id: slack_user_id,
            channel_id: channel_id,
            response: response.respond_to?(:to_h) ? response.to_h : response.to_s
          )
        end

        def build_adapter
          ::Ai::Messaging::Adapters::Slack.new(
            team_id: slack_workspace_id,
            channel_id: channel_id,
            thread_ts: thread_ts,
            message_ts: message_ts,
            user_id: slack_user_id
          )
        end
      end
    end
  end
end
