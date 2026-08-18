# frozen_string_literal: true

module API
  module Entities
    module WorkItems
      module Features
        class Iteration < Grape::Entity
          expose :iteration,
            using: ::API::Entities::Iteration,
            documentation: { type: 'Entities::Iteration' },
            expose_nil: true
        end
      end
    end
  end
end
