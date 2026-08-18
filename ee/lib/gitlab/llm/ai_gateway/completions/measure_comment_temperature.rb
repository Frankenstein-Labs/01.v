# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      module Completions
        class MeasureCommentTemperature < Base
          def inputs
            { content: prompt_message.content }
          end
        end
      end
    end
  end
end
