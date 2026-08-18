# frozen_string_literal: true

module API
  module Entities
    module Ci
      class RunnerControllerDetail < RunnerController
        expose :connected, documentation: { type: 'Boolean', example: true } do |controller, _options|
          controller.connected?
        end
      end
    end
  end
end
