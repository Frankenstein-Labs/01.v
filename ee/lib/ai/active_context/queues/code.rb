# frozen_string_literal: true

module Ai
  module ActiveContext
    module Queues
      class Code
        include ::ActiveContext::Concerns::Queue

        COLLECTION_CLASS = ::Ai::ActiveContext::Collections::Code

        DEFAULT_SHARD_LIMIT = 1000
        DEFAULT_SHARD_COUNT = 1

        TARGET_RPM_FOR_LIMITED_THROUGHPUT = 20

        class << self
          def number_of_shards
            return DEFAULT_SHARD_COUNT if limit_throughput?

            COLLECTION_CLASS.collection_record&.queue_shard_count || DEFAULT_SHARD_COUNT
          end

          def shard_limit
            limit = COLLECTION_CLASS.collection_record&.queue_shard_limit || DEFAULT_SHARD_LIMIT

            return [max_shard_limit, limit].min if limit_throughput?

            limit
          end

          def limit_throughput?
            # Throughput limiting logic was introduced in https://gitlab.com/gitlab-org/gitlab/-/merge_requests/230480
            # We set this to always `false` for now until we can support Self-hosted models
            false
          end

          private

          def max_shard_limit
            TARGET_RPM_FOR_LIMITED_THROUGHPUT * embedding_model_batch_size
          end

          def embedding_model_batch_size
            collection_record = COLLECTION_CLASS.collection_record
            Ai::ActiveContext::Embedding.embeddings_request_batch_size(
              collection_record&.current_indexing_embedding_model
            )
          end
        end
      end
    end
  end
end
