# frozen_string_literal: true

module API
  module Entities
    module WorkItems
      module Features
        class Weight < Grape::Entity
          expose :weight,
            documentation: { type: 'Integer', example: 3 },
            expose_nil: true

          expose :rolled_up_weight,
            documentation: { type: 'Integer', example: 8 },
            expose_nil: true

          expose :rolled_up_completed_weight,
            documentation: { type: 'Integer', example: 5 },
            expose_nil: true
        end
      end
    end
  end
end
