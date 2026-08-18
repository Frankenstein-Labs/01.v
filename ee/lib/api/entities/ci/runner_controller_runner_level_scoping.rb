# frozen_string_literal: true

module API
  module Entities
    module Ci
      class RunnerControllerRunnerLevelScoping < Grape::Entity
        expose :runner_id, documentation: { type: 'Integer', format: 'int64' }
        expose :created_at, documentation: { type: 'DateTime' }
        expose :updated_at, documentation: { type: 'DateTime' }
      end
    end
  end
end
