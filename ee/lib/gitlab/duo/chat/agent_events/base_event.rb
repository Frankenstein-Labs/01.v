# frozen_string_literal: true

module Gitlab
  module Duo
    module Chat
      module AgentEvents
        class BaseEvent
          def initialize(data)
            @data = data
          end

          private

          attr_reader :data
        end
      end
    end
  end
end
