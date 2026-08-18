# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Security::PipelineExecutionSchedulePolicies::TimeWindow, feature_category: :security_policy_management do
  describe '#value' do
    context 'when value is present' do
      it 'returns the value' do
        time_window = described_class.new({ value: 3600, distribution: 'random' })
        expect(time_window.value).to eq(3600)
      end

      it 'handles different values' do
        time_window = described_class.new({ value: 7200, distribution: 'random' })
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

  describe '#distribution' do
    context 'when distribution is present' do
      it 'returns the distribution value' do
        time_window = described_class.new({ value: 3600, distribution: 'random' })
        expect(time_window.distribution).to eq('random')
      end
    end

    context 'when distribution is not present' do
      it 'returns nil' do
        time_window = described_class.new({ value: 3600 })
        expect(time_window.distribution).to be_nil
      end
    end
  end

  describe 'complete time_window' do
    it 'handles time_window with all fields' do
      time_window_data = {
        value: 3600,
        distribution: 'random'
      }
      time_window = described_class.new(time_window_data)

      expect(time_window.value).to eq(3600)
      expect(time_window.distribution).to eq('random')
    end

    context 'when time_window is nil' do
      it 'handles nil gracefully' do
        time_window = described_class.new(nil)
        expect(time_window.value).to be_nil
        expect(time_window.distribution).to be_nil
      end
    end

    context 'when time_window is empty' do
      it 'handles empty hash gracefully' do
        time_window = described_class.new({})
        expect(time_window.value).to be_nil
        expect(time_window.distribution).to be_nil
      end
    end
  end
end
