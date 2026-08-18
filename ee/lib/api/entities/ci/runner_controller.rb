# frozen_string_literal: true

module API
  module Entities
    module Ci
      class RunnerController < Grape::Entity
        expose :id, documentation: { type: 'Integer', format: 'int64', example: 1 }
        expose :description, documentation: { type: 'String', example: 'Controller for managing runner' }
        expose :state, documentation: { type: 'String', example: 'enabled' }
        expose :created_at, documentation: { type: 'DateTime' }
        expose :updated_at, documentation: { type: 'DateTime' }
      end
    end
  end
end
