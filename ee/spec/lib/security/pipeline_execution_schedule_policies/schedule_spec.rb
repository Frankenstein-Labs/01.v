# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Security::PipelineExecutionSchedulePolicies::Schedule, feature_category: :security_policy_management do
  describe '#type' do
    context 'when type is present' do
      it 'returns the type value' do
        schedule = described_class.new({ type: 'daily', start_time: '09:00',
time_window: { value: 3600, distribution: 'random' } })
        expect(schedule.type).to eq('daily')
      end

      it 'handles weekly type' do
        schedule = described_class.new({ type: 'weekly', days: ['Monday'], start_time: '09:00',
time_window: { value: 3600, distribution: 'random' } })
        expect(schedule.type).to eq('weekly')
      end

      it 'handles monthly type' do
        schedule = described_class.new({ type: 'monthly', days_of_month: [1, 15], start_time: '09:00',
time_window: { value: 3600, distribution: 'random' } })
        expect(schedule.type).to eq('monthly')
      end
    end

    context 'when type is not present' do
      it 'returns nil' do
        schedule = described_class.new({ start_time: '09:00', time_window: { value: 3600, distribution: 'random' } })
        expect(schedule.type).to be_nil
      end
    end
  end

  describe '#branches' do
    context 'when branches is present' do
      it 'returns the branches array' do
        schedule = described_class.new({ type: 'daily', branches: %w[main develop], start_time: '09:00',
time_window: { value: 3600, distribution: 'random' } })
        expect(schedule.branches).to match_array(%w[main develop])
      end
    end

    context 'when branches is not present' do
      it 'returns an empty array' do
        schedule = described_class.new({ type: 'daily', start_time: '09:00',
time_window: { value: 3600, distribution: 'random' } })
        expect(schedule.branches).to eq([])
      end
    end
  end

  describe '#start_time' do
    context 'when start_time is present' do
      it 'returns the start_time value' do
        schedule = described_class.new({ type: 'daily', start_time: '09:00',
time_window: { value: 3600, distribution: 'random' } })
        expect(schedule.start_time).to eq('09:00')
      end
    end

    context 'when start_time is not present' do
      it 'returns nil' do
        schedule = described_class.new({ type: 'daily', time_window: { value: 3600, distribution: 'random' } })
        expect(schedule.start_time).to be_nil
      end
    end
  end

  describe '#time_window' do
    context 'when time_window is present' do
      it 'returns a TimeWindow instance' do
        schedule = described_class.new({ type: 'daily', start_time: '09:00',
time_window: { value: 3600, distribution: 'random' } })
        expect(schedule.time_window).to be_a(Security::PipelineExecutionSchedulePolicies::TimeWindow)
      end

      it 'returns time_window with correct values' do
        schedule = described_class.new({ type: 'daily', start_time: '09:00',
time_window: { value: 3600, distribution: 'random' } })
        time_window = schedule.time_window
        expect(time_window.value).to eq(3600)
        expect(time_window.distribution).to eq('random')
      end
    end

    context 'when time_window is not present' do
      it 'returns a TimeWindow instance with default values' do
        schedule = described_class.new({ type: 'daily', start_time: '09:00' })
        time_window = schedule.time_window
        expect(time_window.value).to be_nil
        expect(time_window.distribution).to be_nil
      end
    end
  end

  describe '#timezone' do
    context 'when timezone is present' do
      it 'returns the timezone value' do
        schedule = described_class.new({ type: 'daily', start_time: '09:00',
time_window: { value: 3600, distribution: 'random' }, timezone: 'America/New_York' })
        expect(schedule.timezone).to eq('America/New_York')
      end
    end

    context 'when timezone is not present' do
      it 'returns UTC as default' do
        schedule = described_class.new({ type: 'daily', start_time: '09:00',
time_window: { value: 3600, distribution: 'random' } })
        expect(schedule.timezone).to eq('UTC')
      end
    end
  end

  describe '#snooze' do
    context 'when snooze is present' do
      it 'returns a Snooze instance' do
        schedule = described_class.new({ type: 'daily', start_time: '09:00',
time_window: { value: 3600, distribution: 'random' }, snooze: { until: '2025-12-31T23:59:59+00:00' } })
        expect(schedule.snooze).to be_a(Security::PipelineExecutionSchedulePolicies::Snooze)
      end

      it 'returns snooze with correct values' do
        schedule = described_class.new({
          type: 'daily',
          start_time: '09:00',
          time_window: {
            value: 3600,
            distribution: 'random'
          },
          snooze: {
            until: '2025-12-31T23:59:59+00:00', reason: 'Holiday'
          }
        })
        snooze = schedule.snooze
        expect(snooze.until).to eq('2025-12-31T23:59:59+00:00')
        expect(snooze.reason).to eq('Holiday')
      end
    end

    context 'when snooze is not present' do
      it 'returns a Snooze instance with default values' do
        schedule = described_class.new({ type: 'daily', start_time: '09:00',
time_window: { value: 3600, distribution: 'random' } })
        snooze = schedule.snooze
        expect(snooze.until).to be_nil
        expect(snooze.reason).to be_nil
      end
    end
  end

  describe '#days' do
    context 'when days is present (weekly schedule)' do
      it 'returns the days array' do
        schedule = described_class.new({ type: 'weekly', days: %w[Monday Friday], start_time: '09:00',
time_window: { value: 3600, distribution: 'random' } })
        expect(schedule.days).to match_array(%w[Monday Friday])
      end
    end

    context 'when days is not present' do
      it 'returns an empty array' do
        schedule = described_class.new({ type: 'daily', start_time: '09:00',
time_window: { value: 3600, distribution: 'random' } })
        expect(schedule.days).to eq([])
      end
    end
  end

  describe '#days_of_month' do
    context 'when days_of_month is present (monthly schedule)' do
      it 'returns the days_of_month array' do
        schedule = described_class.new({ type: 'monthly', days_of_month: [1, 15, 30], start_time: '09:00',
time_window: { value: 3600, distribution: 'random' } })
        expect(schedule.days_of_month).to match_array([1, 15, 30])
      end
    end

    context 'when days_of_month is not present' do
      it 'returns an empty array' do
        schedule = described_class.new({ type: 'daily', start_time: '09:00',
time_window: { value: 3600, distribution: 'random' } })
        expect(schedule.days_of_month).to eq([])
      end
    end
  end
end
