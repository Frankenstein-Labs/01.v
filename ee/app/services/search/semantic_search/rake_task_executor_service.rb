# frozen_string_literal: true

module Search
  module SemanticSearch
    class RakeTaskExecutorService
      TASKS = %i[
        info
      ].freeze

      def initialize(logger:)
        @logger = logger
      end

      def execute(task)
        raise ArgumentError, "Unknown task: #{task}" unless TASKS.include?(task)

        case task
        when :info
          info
        end
      end

      private

      attr_reader :logger

      def info
        logger.info(Rainbow("\nSemantic Code Search").yellow)

        safely("Indexing Status") { display_indexing_status }
        safely("Connection Info") { display_connection_info }
        safely("Repository Stats") { display_repository_stats }
        safely("Embedding Queue Stats") { display_embedding_queue_stats }
      end

      def safely(section)
        yield
      rescue StandardError => e
        logger.error(Rainbow("\n#{section}: error - #{e.message}").red)
      end

      def display_indexing_status
        logger.info("Indexing enabled:\t\t#{ActiveContext::Config.indexing_enabled? ? Rainbow('yes').green : 'no'}")

        indexing_active = Ai::ActiveContext::Collections::Code.indexing?
        logger.info("Indexing active:\t\t#{indexing_active ? Rainbow('yes').green : 'no'}")
      end

      def display_connection_info
        connection = Ai::ActiveContext::Connection.active

        if connection
          logger.info("\nConnection:")
          logger.info("  Name:\t\t\t\t#{connection.name}")
          logger.info("  Adapter:\t\t\t#{connection.adapter_class}")
          logger.info("  Active:\t\t\t#{connection.active ? Rainbow('yes').green : 'no'}")
        else
          logger.warn(Rainbow("\nConnection:\t\t\tNone configured").yellow)
        end
      end

      def display_repository_stats
        repos = Ai::ActiveContext::Code::Repository

        total = repos.count
        ready_count = repos.ready.count
        pending_count = repos.pending.count
        code_indexing_count = repos.code_indexing_in_progress.count
        embedding_indexing_count = repos.embedding_indexing_in_progress.count
        failed_count = repos.failed.count

        logger.info(Rainbow("\nRepositories").yellow)
        logger.info("Total:\t\t\t\t#{total}")
        logger.info("Ready:\t\t\t\t#{ready_count} #{percentage(ready_count, total)}")
        logger.info("Pending:\t\t\t#{pending_count} #{percentage(pending_count, total)}")
        logger.info("Code indexing in progress:\t#{code_indexing_count} #{percentage(code_indexing_count, total)}")
        logger.info("Embedding indexing in progress:\t#{embedding_indexing_count} #{percentage(
          embedding_indexing_count, total)}")
        logger.info("Failed:\t\t\t\t#{failed_count} #{percentage(failed_count, total)}")
      end

      def percentage(count, total)
        return "(0%)" if total == 0

        percent = (count.to_f / total * 100).round
        "(#{percent}%)"
      end

      def display_embedding_queue_stats
        code_queue = Ai::ActiveContext::Queues::Code
        backfill_queue = Ai::ActiveContext::Queues::CodeBackfill
        retry_queue = ActiveContext::RetryQueue
        dead_queue = ActiveContext::DeadQueue

        code_queue_size = code_queue.queue_size
        shard_limit = code_queue.shard_limit

        logger.info(Rainbow("\nEmbedding Queues").yellow)
        logger.info("Code queue:\t\t\t#{code_queue_size}")
        logger.info("  Shard count:\t\t\t#{code_queue.number_of_shards}")
        logger.info("  Shard limit:\t\t\t#{shard_limit}")
        logger.info("Backfill queue:\t\t\t#{backfill_queue.queue_size}")
        logger.info("  Shard count:\t\t\t#{backfill_queue.number_of_shards}")
        logger.info("  Shard limit:\t\t\t#{backfill_queue.shard_limit}")
        logger.info("Retry queue:\t\t\t#{retry_queue.queue_size}")
        logger.info("Dead queue:\t\t\t#{dead_queue.queue_size}")
        logger.info("\nNote: Queue is processed every 1 minute (up to #{shard_limit} items at once)")
      end
    end
  end
end
