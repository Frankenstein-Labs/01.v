# frozen_string_literal: true

module WorkItems
  module Callbacks
    class AgentPlan < Base
      ALLOWED_PARAMS = %i[content readiness_score].freeze

      def before_create
        handle_agent_plan_change unless excluded_in_new_type?
      end

      def before_update
        if excluded_in_new_type?
          if work_item.agent_plan.present?
            work_item.agent_plan.destroy!
            @agent_plan_event = ::Gitlab::WorkItems::Instrumentation::EventActions::AGENT_PLAN_DESTROY
          end

          return
        end

        handle_agent_plan_change
      end

      def after_save_commit
        return unless @agent_plan_event

        ::Gitlab::WorkItems::Instrumentation::TrackingService.new(
          work_item: work_item,
          current_user: current_user,
          event: @agent_plan_event,
          extra_properties: {
            source: ::Gitlab::WorkItems::Instrumentation::TrackingService.current_source
          }
        ).execute
      end

      private

      def handle_agent_plan_change
        return unless params.key?(:content) || readiness_score_param?
        return unless has_permission?(:update_work_item)

        agent_plan = work_item.agent_plan || work_item.build_agent_plan
        # Use content presence rather than row persistence: a score-only call can
        # persist a row with blank content, so persisted? is no longer a reliable
        # proxy for "the plan did not exist yet".
        had_content = agent_plan.content.present?

        if params.key?(:content)
          content_changed = agent_plan.content != params[:content]
          agent_plan.content = params[:content]

          @agent_plan_event = if content_changed && !had_content
                                ::Gitlab::WorkItems::Instrumentation::EventActions::AGENT_PLAN_CREATE
                              elsif content_changed
                                ::Gitlab::WorkItems::Instrumentation::EventActions::AGENT_PLAN_UPDATE
                              end
        end

        agent_plan.readiness_score = params[:readiness_score] if readiness_score_param?

        raise_error(agent_plan.errors.full_messages.join(', ')) unless agent_plan.valid?
      end

      # Gated by the same flag as the read path; a score set while disabled could not be read back.
      def readiness_score_param?
        params.key?(:readiness_score) &&
          Feature.enabled?(:workplan_score, work_item.namespace&.root_ancestor)
      end
    end
  end
end
