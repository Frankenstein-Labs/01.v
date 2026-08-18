# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AiUsageEventsBackfillWorker, feature_category: :value_stream_management do
  let_it_be_with_reload(:personal_namespace) { create(:namespace) }
  let(:event) { Analytics::ClickHouseForAnalyticsEnabledEvent.new(data: { enabled_at: 1.day.ago.iso8601 }) }
  let_it_be_with_reload(:user) do
    create(:user, namespace: personal_namespace, organizations: [personal_namespace.organization])
  end

  subject(:worker) { described_class.new }

  before do
    create(:application_setting)
  end

  def perform
    worker.perform(event.class.name, event.data)
  end

  it_behaves_like 'an idempotent worker'

  context 'when clickhouse is not configured' do
    it 'records disabled status' do
      perform

      expect(worker).to log_extra_metadata_on_done(result: { status: :disabled })
    end
  end

  describe '#perform', :click_house, :freeze_time do
    let!(:pg_events) do
      [
        create(:ai_usage_event, user: user, timestamp: 1.day.ago, extras: { foo: 'bar' }),
        create(:ai_usage_event, user: user, timestamp: 2.days.ago, extras: { foo: 'bar' }),
        create(:ai_usage_event, user: user, timestamp: 3.days.ago, extras: { foo: 'bar' })
      ]
    end

    let(:expected_ch_events) do
      pg_events.map do |e|
        {
          user_id: e.user_id,
          timestamp: e.timestamp,
          event: Ai::UsageEvent.events['request_duo_chat_response'],
          namespace_path: e.user.namespace.traversal_path(with_organization: false),
          extras: e.extras.to_json
        }.stringify_keys
      end
    end

    context 'when clickhouse for analytics is not enabled' do
      before do
        stub_application_setting(use_clickhouse_for_analytics: false)
      end

      it 'records disabled status' do
        perform

        expect(worker).to log_extra_metadata_on_done(result: { status: :disabled })
      end
    end

    context 'when clickhouse for analytics is enabled' do
      before do
        stub_application_setting(use_clickhouse_for_analytics: true)
      end

      let(:ch_records) do
        ClickHouse::Client.select("SELECT * FROM ai_usage_events FINAL ORDER BY timestamp", :main)
      end

      it 'inserts all records to ClickHouse' do
        perform

        expect(ch_records).to match_array(expected_ch_events)
      end

      it "doesn't reschedule itself" do
        expect(described_class).not_to receive(:perform_in)

        perform
      end

      it "doesn't create duplicates when data already exists in CH" do
        clickhouse_fixture(:ai_usage_events, [
          { user_id: pg_events.first.user.id,
            event: Ai::UsageEvent.events['request_duo_chat_response'],
            namespace_path: pg_events.first.user.namespace.traversal_path(with_organization: false),
            timestamp: pg_events.first.timestamp }, # duplicate
          { user_id: pg_events.first.user.id,
            event: Ai::UsageEvent.events['request_duo_chat_response'],
            namespace_path: pg_events.first.user.namespace.traversal_path(with_organization: false),
            timestamp: pg_events.first.timestamp - 10.days }
        ])

        perform

        expect(ch_records.size).to eq(pg_events.size + 1)
      end

      context 'when time limit is reached' do
        before do
          stub_const("ClickHouse::SyncStrategies::BaseSyncStrategy::BATCH_SIZE", 1)

          allow_next_instance_of(Gitlab::Metrics::RuntimeLimiter) do |runtime_limiter|
            allow(runtime_limiter).to receive(:over_time?).and_return(false, true)
          end
        end

        it 'stops the processing' do
          perform

          expect(worker).to log_extra_metadata_on_done(
            result: { status: :processed, records_inserted: 2, reached_end_of_table: false }
          )
          expect(ch_records.size).to eq(2)
        end

        it 'reschedules the worker in 1 minute' do
          expect(described_class).to receive(:perform_in).with(1.minute, event.class.name, event.data)

          perform
        end
      end
    end
  end
end
