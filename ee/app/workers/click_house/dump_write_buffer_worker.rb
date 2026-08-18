# frozen_string_literal: true

module ClickHouse
  class DumpWriteBufferWorker
    include ApplicationWorker
    include ClickHouseWorker
    include LoopWithRuntimeLimit

    idempotent!
    queue_namespace :click_house_buffer_sync
    data_consistency :delayed
    feature_category :value_stream_management
    tags :clickhouse
    loggable_arguments 0

    MAX_RUNTIME = 200.seconds
    BATCH_SIZE = 1000

    INSERT_QUERY_TEMPLATE = <<~SQL.squish
      INSERT INTO %{table_name} (%{fields}) SETTINGS async_insert=1, wait_for_async_insert=1 FORMAT CSV
    SQL

    def perform(table_name)
      pending_gauge.set({ table: table_name }, ClickHouse::WriteBuffer.pending(table_name))

      return unless enabled?

      connection.ping # ensure CH is available

      total_inserted_rows = 0

      status = loop_with_runtime_limit(MAX_RUNTIME) do
        inserted_rows = process_next_batch(table_name)
        break :processed if inserted_rows == 0

        total_inserted_rows += inserted_rows
      end

      log_extra_metadata_on_done(:result, {
        status: status,
        inserted_rows: total_inserted_rows
      })
    end

    private

    def pending_gauge
      Gitlab::Metrics.gauge(
        :gitlab_clickhouse_write_buffer_pending,
        'Number of events pending in the ClickHouse write buffer',
        {},
        :max
      )
    end

    def enabled?
      Gitlab::ClickHouse.globally_enabled_for_analytics?
    end

    def process_next_batch(table_name)
      next_batch(table_name).group_by(&:keys).sum do |keys, rows|
        insert_rows(rows, mapping: build_csv_mapping(keys), table_name: table_name)
      end
    end

    def next_batch(table_name)
      ClickHouse::WriteBuffer.pop(table_name, BATCH_SIZE)
    end

    def build_csv_mapping(keys)
      keys.to_h { |key| [key.to_sym, key.to_sym] }
    end

    def insert_rows(rows, mapping:, table_name:)
      CsvBuilder::Gzip.new(rows, mapping).render do |tempfile|
        connection.insert_csv(prepare_insert_statement(mapping, table_name), File.open(tempfile.path))
        rows.size
      end
    end

    def prepare_insert_statement(mapping, table_name)
      format(INSERT_QUERY_TEMPLATE, fields: mapping.keys.join(', '), table_name: table_name)
    end

    def connection
      @connection ||= ClickHouse::Connection.new(:main)
    end
  end
end
