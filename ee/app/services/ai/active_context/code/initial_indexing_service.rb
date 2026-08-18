# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class InitialIndexingService < IndexingServiceBase
        def execute
          if repository.empty?
            update_repository_state!(:ready)
            return
          end

          update_repository_state!(:code_indexing_in_progress)

          run_indexer_and_enqueue_ref

          update_repository_state!(:embedding_indexing_in_progress)
        rescue StandardError => e
          update_repository_state!(:failed, last_error: e.message)

          raise e
        end

        private

        def set_highest_enqueued_item!(item_id)
          repository.update!(
            initial_indexing_last_queued_item: item_id,
            indexed_at: Time.current
          )

          log_info(
            'initial_indexing_last_queued_item',
            initial_indexing_last_queued_item: item_id
          )
        end

        def update_repository_state!(state, extra_params = {})
          repository.update!(state: state, **extra_params)

          if state == :failed
            log_error(state.to_s, last_error: extra_params[:last_error])
          else
            log_info(state.to_s)
          end
        end
      end
    end
  end
end
