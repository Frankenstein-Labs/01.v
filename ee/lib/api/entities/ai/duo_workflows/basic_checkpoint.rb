# frozen_string_literal: true

module API
  module Entities
    module Ai
      module DuoWorkflows
        class BasicCheckpoint < Grape::Entity
          expose :id do |checkpoint|
            checkpoint.id.first
          end
          expose :thread_ts
          expose :parent_ts
          expose :checkpoint_ns
        end
      end
    end
  end
end
