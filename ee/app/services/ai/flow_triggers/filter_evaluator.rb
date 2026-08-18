# frozen_string_literal: true

module Ai
  module FlowTriggers
    class FilterEvaluator
      def initialize(flow_trigger:, hook_scope:, data:)
        @flow_trigger = flow_trigger
        @hook_scope = hook_scope
        @data = data
      end

      def allowed?
        resolved_filter = resolve_filter
        return true if resolved_filter.blank?

        ::Gitlab::FilterEvaluator.evaluate(resolved_filter, @data)
      end

      private

      def resolve_filter
        base_filter = @flow_trigger.filter&.dig(@hook_scope.to_s)
        precondition = foundational_flow_precondition

        merge_filters(base_filter, precondition)
      end

      def foundational_flow_precondition
        @flow_trigger.foundational_flow_precondition
      end

      def merge_filters(base_filter, precondition)
        return base_filter if precondition.blank?
        return precondition if base_filter.blank?

        {
          'match' => 'all',
          'rules' => [
            { 'type' => 'group' }.merge(precondition),
            { 'type' => 'group' }.merge(base_filter)
          ]
        }
      end
    end
  end
end
