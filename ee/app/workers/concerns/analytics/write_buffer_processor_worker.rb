# frozen_string_literal: true

module Analytics
  module WriteBufferProcessorWorker
    extend ActiveSupport::Concern
    include LoopWithRuntimeLimit

    included do
      attr_reader :model, :upsert_options
    end

    def perform
      total_inserted_rows = 0

      status = loop_with_runtime_limit(self.class::MAX_RUNTIME) do
        inserted_rows = process_next_batch
        break :processed if inserted_rows == 0

        total_inserted_rows += inserted_rows
      end

      log_extra_metadata_on_done(:result, {
        status: status,
        inserted_rows: total_inserted_rows
      })
    end

    private

    def process_next_batch
      batch = next_batch
      valid_objects = prepare_batch_objects(batch)

      return 0 if valid_objects.empty?

      grouped_attributes = prepare_attributes(valid_objects).group_by(&:keys).values

      grouped_attributes.sum do |attributes|
        res = model.upsert_all(attributes, **upsert_options)

        res ? res.rows.size : 0
      end
    rescue StandardError => e
      model.write_buffer.add(batch)
      raise e
    end

    def next_batch
      model.write_buffer.pop(self.class::BATCH_SIZE)
    end

    def prepare_attributes(valid_objects)
      valid_objects.map { |obj| obj.attributes.compact }.reject(&:empty?)
    end

    def prepare_batch_objects(batch)
      batch.map do |attrs|
        model.new(compatible_attributes(attrs.slice(*model.attribute_names)))
      end.select(&:valid?)
    end

    def compatible_attributes(buffered_attributes)
      buffered_attributes
    end
  end
end
