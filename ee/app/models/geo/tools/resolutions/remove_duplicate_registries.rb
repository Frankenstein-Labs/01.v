# frozen_string_literal: true

module Geo
  module Tools
    module Resolutions
      # SPIKE (gitlab-org/gitlab#602803): removes duplicate registry rows (the same model
      # record tracked by more than one row), keeping the most useful row and deleting the
      # rest. Secondary-side. The kept row is a synced one if present, otherwise the most
      # recently created (highest id). Registry rows are reconstructable, so this is the
      # lower-risk destructive resolution. Why duplicates exist (a missing unique index) is
      # tracked separately.
      class RemoveDuplicateRegistries < Base
        def affected_count
          registry_classes.sum { |klass| extra_rows_count(klass) }
        end

        def sample(limit: 5)
          registry_classes.flat_map do |klass|
            duplicate_counts(klass).first(limit).map do |model_id, count|
              "#{klass.name} model #{model_id} (#{count} rows)"
            end
          end.first(limit)
        end

        def apply(limit: nil)
          deleted = 0
          remaining = limit

          registry_classes.each do |klass|
            duplicate_model_ids(klass).each do |model_id|
              ids = removable_ids(klass, model_id)
              # LIMIT caps the number of rows deleted, not the number of records
              # de-duplicated: a model whose duplicate set exceeds the remaining budget is
              # left partially de-duplicated. The one-row-per-model invariant only holds for
              # an unlimited run.
              ids = ids.first(remaining) if remaining
              next if ids.empty?

              klass.where(id: ids).delete_all
              log("Removed duplicate registries",
                registry_class: klass.name, model_record_id: model_id, count: ids.size)

              deleted += ids.size
              remaining -= ids.size if remaining
              break if remaining && remaining <= 0
            end

            break if remaining && remaining <= 0
          end

          deleted
        end

        def summary(count)
          "Removed #{count} duplicate registry rows."
        end

        private

        def foreign_key(klass)
          klass.model_foreign_key
        end

        # { model_record_id => row_count } for model records tracked more than once.
        # Memoized per class: affected_count and apply both read it within one invocation.
        #
        # A single GROUP BY ... HAVING COUNT(*) > 1 over the whole table is a full-table
        # aggregate that times out on large registries. Instead we walk the distinct model
        # foreign keys in batches (a loose index scan over the indexed foreign key) and, for
        # each batch of keys, run a bounded GROUP BY ... HAVING over just those keys. Using
        # distinct_each_batch rather than each_batch on the foreign key keeps each step
        # bounded by the number of distinct keys and avoids looping when one model record has
        # many duplicate rows. Every key appears in exactly one batch, so the counts merge
        # cleanly.
        def duplicate_counts(klass)
          @duplicate_counts ||= {}
          @duplicate_counts[klass] ||= begin
            fk = foreign_key(klass)
            counts = {}

            klass.distinct_each_batch(column: fk, of: BATCH_SIZE) do |batch|
              model_ids = batch.pluck(fk) # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- bounded by distinct_each_batch
              counts.merge!(klass.where(fk => model_ids).group(fk).having("COUNT(*) > 1").count)
            end

            counts
          end
        end

        def duplicate_model_ids(klass)
          duplicate_counts(klass).keys
        end

        def extra_rows_count(klass)
          duplicate_counts(klass).values.sum { |count| count - 1 }
        end

        # Ids to delete for a duplicated model record: everything except the keeper. This
        # issues one SELECT per duplicate group, which is fine for an on-demand run; a real
        # iteration over many duplicates should batch-fetch these in a single query.
        def removable_ids(klass, model_id)
          records = klass.model_id_in(model_id).to_a
          keeper = choose_keeper(records)

          records.excluding(keeper).map(&:id)
        end

        # Keep one synced row (the highest id) if any exist, otherwise the highest-id row.
        # When several synced rows exist for one model the extra synced rows are deleted too;
        # registry rows are reconstructable, so that is acceptable. Registries have no
        # updated_at column, so id is the stable recency tiebreak.
        def choose_keeper(records)
          synced = records.select { |record| record.state == Geo::ReplicableRegistry::STATE_VALUES[:synced] }

          (synced.presence || records).max_by(&:id)
        end
      end
    end
  end
end
