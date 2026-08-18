# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanExecutionPolicies::TimeWindow, feature_category: :security_policy_management do
  describe '#distribution' do
    context 'when distribution is present' do
      it 'returns random' do
        time_window = described_class.new({ distribution: 'random', value: 7200 })
        expect(time_window.distribution).to eq('random')
      end
    end

    context 'when distribution is not present' do
      it 'returns nil' do
        time_window = described_class.new({ value: 7200 })
        expect(time_window.distribution).to be_nil
      end
    end
  end

  describe '#value' do
    context 'when value is present' do
      it 'returns the value in seconds' do
        time_window = described_class.new({ distribution: 'random', value: 7200 })
        expect(time_window.value).to eq(7200)
      end
    end

    context 'when value is not present' do
      it 'returns nil' do
        time_window = described_class.new({ distribution: 'random' })
        expect(time_window.value).to be_nil
      end
    end
  end

  describe 'complete time_window configuration' do
    it 'handles time_window with both required fields' do
      time_window_data = {
        distribution: 'random',
        value: 7200
      }
      time_window = described_class.new(time_window_data)

      expect(time_window.distribution).to eq('random')
      expect(time_window.value).to eq(7200)
    end
  end

  describe 'when time_window is nil' do
    it 'handles nil gracefully' do
      time_window = described_class.new(nil)
      expect(time_window.distribution).to be_nil
      expect(time_window.value).to be_nil
    end
  end
end
