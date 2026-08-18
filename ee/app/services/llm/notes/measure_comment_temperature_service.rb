# frozen_string_literal: true

module Llm
  module Notes
    class MeasureCommentTemperatureService < BaseService
      def valid?
        super && Ability.allowed?(user, :measure_comment_temperature, resource)
      end

      private

      def ai_action
        :measure_comment_temperature
      end

      def perform
        schedule_completion_worker
      end
    end
  end
end
