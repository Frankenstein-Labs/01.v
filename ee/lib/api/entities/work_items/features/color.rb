# frozen_string_literal: true

module API
  module Entities
    module WorkItems
      module Features
        class Color < Grape::Entity
          expose :color,
            documentation: { type: 'String', example: '#A8DADC' },
            expose_nil: true

          expose :text_color,
            documentation: { type: 'String', example: '#1D3557' },
            expose_nil: true
        end
      end
    end
  end
end
