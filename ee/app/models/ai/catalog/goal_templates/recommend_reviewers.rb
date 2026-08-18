# frozen_string_literal: true

module Ai
  module Catalog
    module GoalTemplates
      class RecommendReviewers < Base
        def self.resolve(event_type:, resource:, user_input: nil, params: {}) # rubocop:disable Lint/UnusedMethodArgument -- interface contract from Base
          raise ArgumentError, 'resource must not be nil' unless resource

          # The flow binds context:goal as merge_request_iid, so the goal is the
          # bare iid for every event type - mention included, since this flow has
          # no conversational path. Declines rather than raises for other resource
          # types, because a raise would abort the unrescued mention loop in
          # Notes::PostProcessService; #612121 covers stopping the run outright.
          return unless resource.is_a?(::MergeRequest)

          resource.iid.to_s
        end
      end
    end
  end
end
