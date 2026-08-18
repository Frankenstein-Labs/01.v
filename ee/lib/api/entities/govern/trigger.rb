# frozen_string_literal: true

module API
  module Entities
    module Govern
      class Trigger < Grape::Entity
        expose :id, documentation: { type: 'String', example: 'deployment_requested' }
        expose :name, documentation: { type: 'String', example: 'Deployment' }
      end
    end
  end
end
