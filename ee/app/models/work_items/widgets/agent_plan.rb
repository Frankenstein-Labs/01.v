# frozen_string_literal: true

module WorkItems
  module Widgets
    class AgentPlan < Base
      def self.required_user_ability
        :update_work_item
      end

      delegate :content, :content_html, :readiness_score, to: :agent_plan_record, allow_nil: true

      def ai_planning_enabled_for_widget
        agent_plan_record&.ai_planning_enabled || false
      end

      private

      def agent_plan_record
        work_item.agent_plan
      end
    end
  end
end
