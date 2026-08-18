# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AntiAbuse::IdentityVerification::ArkoseAnomalyDetection,
  feature_category: :instance_resiliency do
  subject(:anomaly_detection) { described_class }

  before do
    stub_const("#{described_class}::MIN_BASELINE_COUNT", 5)
  end

  describe '.decide' do
    let(:baseline) { [95.0, 96.0, 94.0, 97.0, 95.0] }

    def stats(values)
      mean = values.sum(0.0) / values.size
      sum_sq = values.sum(0.0) { |v| (v - mean)**2 }
      stddev = Math.sqrt(sum_sq / (values.size - 1))
      [mean, stddev]
    end

    it 'returns non-anomalous when z-score is above the negative threshold' do
      mean, stddev = stats(baseline)
      current = mean - (2.0 * stddev)

      decision = anomaly_detection.decide(current_value: current, baseline_values: baseline)

      expect(decision.anomalous).to be(false)
      expect(decision.reason).to eq(format('zscore_ok=%.2f', (current - mean) / stddev))
    end

    it 'returns anomalous when z-score is below the negative threshold' do
      mean, stddev = stats(baseline)
      current = mean - (3.5 * stddev)
      z = (current - mean) / stddev

      decision = anomaly_detection.decide(current_value: current, baseline_values: baseline)

      expect(decision.anomalous).to be(true)
      expect(decision.reason).to eq(
        format('zscore=%.2f mean=%.2f std=%.2f current=%.2f', z, mean, stddev, current)
      )
    end

    it 'treats z = -3.00 as anomalous' do
      mean, stddev = stats(baseline)
      current = mean - (3.0 * stddev)
      z = (current - mean) / stddev

      decision = anomaly_detection.decide(current_value: current, baseline_values: baseline)

      expect(decision.anomalous).to be(true)
      expect(decision.reason).to eq(
        format('zscore=%.2f mean=%.2f std=%.2f current=%.2f', z, mean, stddev, current)
      )
    end

    it 'returns non-anomalous when baseline stddev is zero' do
      baseline_values = Array.new(5, 95.0)
      decision = anomaly_detection.decide(current_value: 80.0, baseline_values: baseline_values)

      expect(decision.anomalous).to be(false)
      expect(decision.reason).to eq('zscore_ok=0.00')
    end

    it 'returns non-anomalous for positive z' do
      mean, stddev = stats(baseline)
      current = mean + (1.5 * stddev)
      z = (current - mean) / stddev

      decision = anomaly_detection.decide(current_value: current, baseline_values: baseline)

      expect(decision.anomalous).to be(false)
      expect(decision.reason).to eq(format('zscore_ok=%.2f', z))
    end
  end

  describe '#mean' do
    it 'returns 0.0 for empty input' do
      expect(described_class.send(:mean, [])).to eq(0.0)
    end

    it 'computes the arithmetic mean for non-empty input' do
      expect(described_class.send(:mean, [1.0, 3.0, 5.0])).to eq(3.0)
    end
  end

  describe '#variance' do
    it 'returns 0.0 when there are fewer than 2 values' do
      expect(described_class.send(:variance, [1.0])).to eq(0.0)
    end

    it 'computes sample variance when precomputed_mean is not provided' do
      values = [1.0, 3.0, 5.0]

      # sample variance = 4.0 for [1,3,5]
      expect(described_class.send(:variance, values)).to be_within(1e-6).of(4.0)
    end

    it 'uses precomputed_mean when provided' do
      values = [1.0, 3.0, 5.0]

      expect(described_class.send(:variance, values, 3.0)).to be_within(1e-6).of(4.0)
    end
  end
end
