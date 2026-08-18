# frozen_string_literal: true

module Ai
  module ActiveContext
    module Queues
      class CodeBackfill < Code
        def self.extra_preprocess_options
          { next_model_only: true }
        end
      end
    end
  end
end
