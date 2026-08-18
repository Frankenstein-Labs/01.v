# frozen_string_literal: true

module Search
  module Zoekt
    module Taskable
      extend ActiveSupport::Concern

      PARTITION_DURATION = 1.day
      PARTITION_CLEANUP_THRESHOLD = 7.days
      PROCESSING_BATCH_SIZE = 100
      RETRY_DELAY = 5.minutes

      included do
        include EachBatch
        include BulkInsertSafe
        include PartitionedTable

        self.primary_key = :id

        ignore_column :partition_id, remove_never: true
        attribute :retries_left, default: 3

        scope :for_partition, ->(partition) { where(partition_id: partition) }
        scope :join_nodes, -> { joins(:node) }
        scope :perform_now, -> { where(perform_at: (..Time.zone.now)) }
        scope :pending_or_processing, -> { where(state: %i[pending processing]) }
        scope :processing_queue, -> { perform_now.pending_or_processing }

        enum :state, {
          pending: 0,
          processing: 1,
          done: 10,
          skipped: 250,
          failed: 255,
          orphaned: 256
        }

        partitioned_by :partition_id,
          strategy: :sliding_list,
          next_partition_if: ->(active_partition) { next_partition?(active_partition) },
          detach_partition_if: ->(partition) { detach_partition?(partition) }
      end

      class_methods do
        def next_partition?(active_partition)
          oldest_record_in_partition = self
            .select(:id, :created_at)
            .for_partition(active_partition.value)
            .order(:id)
            .first

          oldest_record_in_partition.present? && oldest_record_in_partition.created_at < PARTITION_DURATION.ago
        end

        def detach_partition?(partition)
          newest_task_older(partition, PARTITION_CLEANUP_THRESHOLD) && no_pending_or_processing(partition)
        end

        def newest_task_older(partition, duration)
          newest_record = self.select(:id, :created_at).for_partition(partition.value).order(:id).last
          return true if newest_record.nil?

          newest_record.created_at < duration.ago
        end

        def no_pending_or_processing(partition)
          !for_partition(partition.value).join_nodes.pending_or_processing.exists?
        end

        def each_task_for_processing(limit:)
          return unless block_given?

          process_tasks(limit) do |task|
            yield task
          end
        end

        def process_tasks(limit)
          count = 0
          processed_identifiers = Set.new

          task_iterator.each_batch(of: PROCESSING_BATCH_SIZE) do |tasks|
            task_states = tasks.each_with_object(valid: [], orphaned: [], skipped: [], done: []) do |task, states|
              case determine_task_state(task)
              when :done
                states[:done] << task.id
              when :orphaned
                states[:orphaned] << task.id
              when :skipped
                states[:skipped] << task.id
              when :valid
                next unless processed_identifiers.add?(task.per_batch_unique_id)

                states[:valid] << task.id

                yield task
                count += 1
              end

              break states if count >= limit
            end

            update_task_states(states: task_states)
            break if count >= limit
          end
        end

        def update_task_states(states:)
          id_in(states[:orphaned]).update_all(state: :orphaned, updated_at: Time.current) if states[:orphaned].any?
          id_in(states[:skipped]).update_all(state: :skipped, updated_at: Time.current) if states[:skipped].any?

          if states[:valid].any?
            id_in(states[:valid]).where.not(state: [:orphaned, :skipped, :done, :failed]).update_all(
              state: :processing, updated_at: Time.current
            )
          end

          return unless states[:done].any?

          done_tasks = id_in(states[:done])
          done_tasks.update_all(state: :done, updated_at: Time.current)
          on_tasks_done(done_tasks)
        end

        def task_iterator
          raise NotImplementedError
        end

        def determine_task_state(task)
          raise NotImplementedError
        end

        def on_tasks_done(done_tasks)
          raise NotImplementedError
        end

        def per_batch_unique_id
          raise NotImplementedError
        end
      end
    end
  end
end
