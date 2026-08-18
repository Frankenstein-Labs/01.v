# frozen_string_literal: true

module API
  module Entities
    module WorkItems
      module Features
        class Progress < Grape::Entity
          expose :progress,
            documentation: { type: 'Integer', example: 65 },
            expose_nil: true

          expose :updated_at,
            documentation: { type: 'DateTime', example: '2024-02-12T09:45:00Z' },
            expose_nil: true

          expose :current_value,
            documentation: { type: 'Integer', example: 13 },
            expose_nil: true

          expose :start_value,
            documentation: { type: 'Integer', example: 0 },
            expose_nil: true

          expose :end_value,
            documentation: { type: 'Integer', example: 20 },
            expose_nil: true
        end
      end
    end
  end
end
