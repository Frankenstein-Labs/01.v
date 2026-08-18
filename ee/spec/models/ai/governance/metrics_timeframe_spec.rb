# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Governance::MetricsTimeframe, feature_category: :compliance_management do
  around do |example|
    travel_to(Time.utc(2026, 7, 3, 15, 30)) { example.run }
  end

  describe 'last_7_days' do
    subject(:timeframe) { described_class.new(:last_7_days) }

    it 'spans 7 days ending now, aligned to day start', :aggregate_failures do
      expect(timeframe.to).to eq(Time.utc(2026, 7, 3, 15, 30))
      expect(timeframe.from).to eq(Time.utc(2026, 6, 26))
      expect(timeframe.previous_from).to eq(Time.utc(2026, 6, 19))
      expect(timeframe.step).to eq(1.day)
      expect(timeframe).not_to be_hourly
    end

    it 'produces one bucket start per day from aligned from to now', :aggregate_failures do
      expect(timeframe.bucket_starts.size).to eq(8)
      expect(timeframe.bucket_starts.first).to eq(Time.utc(2026, 6, 26))
      expect(timeframe.bucket_starts.last).to eq(Time.utc(2026, 7, 3))
    end
  end

  describe 'last_24_hours' do
    subject(:timeframe) { described_class.new(:last_24_hours) }

    it 'spans 24 hours with hourly buckets', :aggregate_failures do
      expect(timeframe.from).to eq(Time.utc(2026, 7, 2, 15))
      expect(timeframe.step).to eq(1.hour)
      expect(timeframe).to be_hourly
      expect(timeframe.bucket_starts.size).to eq(25)
    end
  end

  describe 'last_30_days' do
    subject(:timeframe) { described_class.new(:last_30_days) }

    it 'spans 30 days with daily buckets', :aggregate_failures do
      expect(timeframe.from).to eq(Time.utc(2026, 6, 3))
      expect(timeframe.previous_from).to eq(Time.utc(2026, 5, 4))
      expect(timeframe.step).to eq(1.day)
      expect(timeframe).not_to be_hourly
      expect(timeframe.bucket_starts.size).to eq(31)
    end
  end

  it 'raises KeyError for unknown timeframes' do
    expect { described_class.new(:last_year) }.to raise_error(KeyError)
  end
end
