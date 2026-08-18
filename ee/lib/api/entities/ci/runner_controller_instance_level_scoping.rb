# frozen_string_literal: true

module API
  module Entities
    module Ci
      class RunnerControllerInstanceLevelScoping < Grape::Entity
        expose :created_at, documentation: { type: 'DateTime' }
        expose :updated_at, documentation: { type: 'DateTime' }
      end
    end
  end
end
