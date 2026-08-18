# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI events backfill', :freeze_time, :click_house, :sidekiq_inline,
  feature_category: :value_stream_management do
  include ApiHelpers
  include AdminModeHelper

  let_it_be(:organization) { create(:organization) }
  let_it_be(:current_user) { create(:admin, organizations: [organization]) }

  def events_in_ch(model)
    ClickHouse::Client.select("SELECT * FROM #{model.clickhouse_table_name} FINAL ORDER BY timestamp ASC", :main)
  end

  def change_analytics_in_ch_setting(enabled)
    put api("/application/settings", current_user), params: { use_clickhouse_for_analytics: enabled }
  end

  shared_examples 'data backfill worker' do |model|
    it 'adds records from PG to clickhouse' do
      change_analytics_in_ch_setting(true)

      expect(events_in_ch(model).pluck('timestamp')).to eq(usage_events.map(&:timestamp))
    end

    context 'when application setting is enabled twice' do
      it 'does not add duplicate records from PG to clickhouse twice' do
        change_analytics_in_ch_setting(true)

        expect do
          change_analytics_in_ch_setting(false)
          change_analytics_in_ch_setting(true)
        end.not_to change { events_in_ch(model).size }
      end
    end

    context 'when different application setting was changed' do
      it 'does not add records from postgres to clickhouse' do
        put api("/application/settings", current_user), params: { max_pages_size: 100 }

        expect(events_in_ch(model)).to be_empty
      end
    end

    context 'when application setting was already enabled' do
      before do
        change_analytics_in_ch_setting(true)

        ClickHouse::Client.execute("TRUNCATE #{model.clickhouse_table_name}", :main)
      end

      it 'does not add records from postgres to clickhouse' do
        expect do
          change_analytics_in_ch_setting(true)
        end.not_to change { events_in_ch(model).size }
      end
    end
  end

  before do
    enable_admin_mode!(current_user)

    change_analytics_in_ch_setting(false)
  end

  it_behaves_like 'data backfill worker', Ai::UsageEvent do
    let_it_be(:usage_events) do
      [
        create(:ai_usage_event, timestamp: 3.days.ago),
        create(:ai_usage_event, timestamp: 2.days.ago)
      ]
    end
  end
end
