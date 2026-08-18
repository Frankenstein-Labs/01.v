# frozen_string_literal: true

module Gitlab
  module Tracking
    # Class for tracking AI usage events.
    # @see doc/development/ai_features/usage_tracking.md for documentation
    module AiTracking
      extend AiUsageEventsRegistryDsl

      register_feature(:code_suggestions) do
        deprecated_events(code_suggestions_requested: 1) # old data

        events(
          code_suggestion_shown_in_ide: 2,
          code_suggestion_accepted_in_ide: 3,
          code_suggestion_rejected_in_ide: 4
        ) do |context|
          context.slice(*%w[unique_tracking_id suggestion_size language branch_name
            ide_name ide_vendor ide_version
            extension_name extension_version language_server_version
            model_name model_engine])
        end

        deprecated_events(code_suggestion_direct_access_token_refresh: 5) # old data
      end

      register_feature(:chat) do
        events(request_duo_chat_response: 6)
      end

      register_feature(:troubleshoot_job) do
        events(troubleshoot_job: 7) do |context|
          {
            job_id: context['job'].id,
            project_id: context['job'].project_id,
            pipeline_id: context['job'].pipeline&.id,
            merge_request_id: context['job'].pipeline&.merge_request_id
          }
        end
      end

      register_feature(:agent_platform) do
        events(
          agent_platform_session_created: 8,
          agent_platform_session_started: 9,
          agent_platform_session_finished: 19,
          agent_platform_session_dropped: 20,
          agent_platform_session_stopped: 21,
          agent_platform_session_resumed: 22) do |context|
          {
            project_id: context['project']&.id,
            session_id: context['value'],
            flow_type: context['label'],
            environment: context['property']
          }
        end

        events(
          view_duo_agentic_subscription_expired_empty_state: 28,
          click_duo_agentic_subscription_expired_upgrade: 29,
          click_duo_agentic_subscription_expired_learn_more: 30
        )
      end

      register_feature(:code_review) do
        events(
          encounter_duo_code_review_error_during_review: 10,
          find_no_issues_duo_code_review_after_review: 11,
          find_nothing_to_review_duo_code_review_on_mr: 12,
          post_comment_duo_code_review_on_diff: 13,
          react_thumbs_up_on_duo_code_review_comment: 14,
          react_thumbs_down_on_duo_code_review_comment: 15,
          request_review_duo_code_review_on_mr_by_author: 16,
          request_review_duo_code_review_on_mr_by_non_author: 17,
          excluded_files_from_duo_code_review: 18,
          publish_duo_code_review_comments: 32
        )
      end

      register_feature(:mcp) do
        events(
          start_mcp_tool_call: 23,
          finish_mcp_tool_call: 24
        ) do |context|
          {
            session_id: context['session_id'],
            tool_name: context['tool_name'],
            has_tool_call_success: context['has_tool_call_success'],
            failure_reason: context['failure_reason'],
            error_status: context['error_status']
          }
        end
      end
      register_feature(:fix_pipeline) do
        events(
          fix_pipeline_suggestion_posted: 25,
          fix_pipeline_suggestion_applied: 26
        )
      end

      register_feature(:duo_workflow) do
        events(duo_workflow_workload_completed: 27) do |context|
          context.slice(*%w[workflow_id workflow_definition])
        end
      end
      register_feature(:ai_catalog) do
        events(restore_ai_catalog_item: 31)
      end

      register_feature(:summarize_review) do
        events(summarize_review: 36)
      end

      register_feature(:summarize_new_merge_request) do
        events(summarize_new_merge_request: 33)
      end

      register_feature(:generate_merge_commit_message) do
        events(generate_merge_commit_message: 37)
      end

      register_feature(:duo_messaging) do
        events(ai_duo_messaging_feedback_submitted: 38) do |context|
          {
            feedback: context['label'],
            workflow_id: context['value'],
            surface: context['property']
          }
        end
      end

      register_feature(:request_duo_vulnerability_resolution) do
        events(request_duo_vulnerability_resolution: 34)
      end

      register_feature(:explain_vulnerability) do
        events(explain_vulnerability: 35)
      end

      # IDs 39-44 are reserved by in-flight merge requests.

      register_feature(:feature_discovery) do
        events(resolve_feature_discovery_search: 46) do |context|
          {
            resolution_tier: context['label'],
            latency_ms: context['value']
          }
        end
      end
      # Current highest event ID: 46, next available: 47

      class << self
        def track_event(event_name, **context_hash)
          return unless AiTracking.registered_events.key?(event_name.to_s)

          event = build_event_model(event_name, context_hash)

          store_to_postgres(event)
          store_to_clickhouse(event)

          track_user_activity(context_hash[:user])
        end

        def track_user_activity(user)
          ::Ai::UserMetrics.refresh_last_activity_on(user)
        end

        private

        def base_attributes
          %w[user timestamp event namespace_id].freeze
        end

        def build_event_model(event_name, context_hash = {})
          context_hash = context_hash.with_indifferent_access

          attributes = apply_transformations(event_name, context_hash)

          basic_attributes = context_hash.slice(*base_attributes).merge(attributes.slice(*base_attributes))
          extra_attributes = attributes.except(*base_attributes)

          ::Ai::UsageEvent.new(basic_attributes.merge(event: event_name, extras: extra_attributes))
        end

        def store_to_clickhouse(event)
          return unless ::Gitlab::ClickHouse.globally_enabled_for_analytics?

          event.store_to_clickhouse
        end

        def store_to_postgres(event)
          event.store_to_pg
        end

        def apply_transformations(event_name, context_hash)
          result = {}.with_indifferent_access

          AiTracking.registered_transformations(event_name).each do |transformation|
            transformation_result = transformation.call(context_hash.merge(result))

            result.merge!(transformation_result)
          end.compact

          unless result[:namespace_id]
            guessed_namespace_id = guess_namespace_id(context_hash.merge(result))

            result[:namespace_id] = guessed_namespace_id if guessed_namespace_id
          end

          result
        end

        def guess_namespace_id(context_hash)
          related_namespace(context_hash)&.id
        end

        def related_namespace(context_hash)
          # Order matters. project should take precedence over namespace
          project = if context_hash[:project]
                      context_hash[:project]
                    elsif context_hash[:project_id]
                      ::Project.find_by_id(context_hash[:project_id])
                    end

          return project.project_namespace if project

          if context_hash[:namespace]
            context_hash[:namespace]
          elsif context_hash[:namespace_id]
            ::Namespace.find_by_id(context_hash[:namespace_id])
          end
        end
      end
    end
  end
end
