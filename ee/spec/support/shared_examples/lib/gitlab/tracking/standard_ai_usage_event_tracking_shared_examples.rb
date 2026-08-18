# frozen_string_literal: true

# Depends on following `lets`: event_name, event_context, expected_pg_attributes, expected_ch_attributes
RSpec.shared_examples 'standard ai usage event tracking' do
  subject(:track_event) { described_class.track_event(event_name, **event_context) }

  def work_off
    UsageEvents::DumpWriteBufferCronWorker.new.perform
    ClickHouse::DumpWriteBufferWorker.new.perform(Ai::UsageEvent.clickhouse_table_name)
  end

  def last_ch_record
    ClickHouse::Client.select("SELECT * FROM #{Ai::UsageEvent.clickhouse_table_name}", :main).last
  end

  def last_pg_record
    Ai::UsageEvent.last
  end

  context 'with clickhouse not available' do
    before do
      allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
    end

    it 'stores event to postgres only' do
      track_event
      work_off

      expect(Ai::UsageEvent.last).to have_attributes(expected_pg_attributes.deep_stringify_keys)
      expect(last_ch_record).to be_nil
    end
  end

  context 'when clickhouse is disabled for analytics' do
    before do
      allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
    end

    it 'does not store new event to clickhouse' do
      track_event

      expect(last_ch_record).to be_nil
    end
  end

  it 'stores new event to PG and CH' do
    track_event
    work_off

    expect(Ai::UsageEvent.last&.attributes).to match(hash_including(expected_pg_attributes.deep_stringify_keys))
    expect(last_ch_record).to match(hash_including(expected_ch_attributes.deep_stringify_keys))
  end

  it 'triggers last_duo_activity_on update' do
    expect(Ai::UserMetrics).to receive(:refresh_last_activity_on).with(current_user).and_call_original

    track_event
  end
end
