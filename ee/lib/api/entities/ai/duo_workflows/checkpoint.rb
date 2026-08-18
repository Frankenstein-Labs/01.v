# frozen_string_literal: true

module API
  module Entities
    module Ai
      module DuoWorkflows
        class Checkpoint < BasicCheckpoint
          expose :checkpoint, if: ->(object) { object.compressed_checkpoint.blank? }
          expose :compressed_checkpoint, if: ->(object) { object.compressed_checkpoint.present? }
          expose :checkpoint_writes, using: ::API::Entities::Ai::DuoWorkflows::CheckpointWrite
          expose :current_thread
          expose :metadata
        end
      end
    end
  end
end
