# frozen_string_literal: true

module API
  module Entities
    module WorkItems
      module Features
        class VerificationStatus < Grape::Entity
          expose :verification_status,
            documentation: { type: 'String', example: 'satisfied' },
            expose_nil: true
        end
      end
    end
  end
end
