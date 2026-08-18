# frozen_string_literal: true

module API
  module Entities
    module Ci
      class RunnerControllerToken < Grape::Entity
        expose :id, documentation: { type: 'Integer', format: 'int64', example: 1 }
        expose :runner_controller_id, documentation: { type: 'Integer', format: 'int64', example: 1 }
        expose :description, documentation: { type: 'String', example: 'Controller for managing runner' }
        expose :last_used_at, documentation: { type: 'DateTime' }
        expose :created_at, documentation: { type: 'DateTime' }
        expose :updated_at, documentation: { type: 'DateTime' }
      end
    end
  end
end
