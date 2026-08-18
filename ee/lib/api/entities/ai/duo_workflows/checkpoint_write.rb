# frozen_string_literal: true

module API
  module Entities
    module Ai
      module DuoWorkflows
        class CheckpointWrite < Grape::Entity
          expose :id
          expose :thread_ts
          expose :task
          expose :idx
          expose :channel
          expose :write_type
          expose :data
        end
      end
    end
  end
end
