# frozen_string_literal: true

module API
  module Entities
    module WorkItems
      module Features
        class HealthStatus < Grape::Entity
          expose :health_status,
            documentation: {
              type: 'String',
              example: 'needs_attention',
              values: ::WorkItem.health_statuses.keys
            },
            expose_nil: true
        end
      end
    end
  end
end
