# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::TimeWindowCappable, feature_category: :security_policy_management do
  let(:test_class) do
    Struct.new(:time_window_seconds, :next_run_at, keyword_init: true) do
      include Security::TimeWindowCappable

      def calculate_next_run_at(_from_time)
        next_run_at
      end
    end
  end

  let(:now) { Time.zone.parse('2024-01-01 12:00:00 UTC') }

  subject(:instance) { test_class.new(time_window_seconds: time_window_seconds, next_run_at: next_run_at) }

  describe '#effective_time_window' do
    context 'when time_window_seconds is nil' do
      let(:time_window_seconds) { nil }
      let(:next_run_at) { now + 1.hour }

      it 'returns nil' do
        travel_to(now) do
          expect(instance.effective_time_window(next_run_at)).to be_nil
        end
      end
    end

    context 'when time_window_seconds is less than seconds until next run' do
      let(:time_window_seconds) { 3600 }
      let(:next_run_at) { now + 24.hours }

      it 'returns the time_window_seconds unchanged' do
        travel_to(now) do
          expect(instance.effective_time_window(next_run_at)).to eq(3600)
        end
      end
    end

    context 'when time_window_seconds exceeds seconds until next run' do
      let(:time_window_seconds) { 86_400 }
      let(:next_run_at) { now + 1.hour }

      it 'caps to seconds until next run' do
        travel_to(now) do
          expect(instance.effective_time_window(next_run_at)).to eq(3600)
        end
      end
    end

    context 'when time_window_seconds exactly matches seconds until next run' do
      let(:time_window_seconds) { 3600 }
      let(:next_run_at) { now + 1.hour }

      it 'returns the time_window_seconds' do
        travel_to(now) do
          expect(instance.effective_time_window(next_run_at)).to eq(3600)
        end
      end
    end

    context 'when next_run_at is not provided' do
      let(:time_window_seconds) { 7200 }
      let(:next_run_at) { now + 24.hours }

      it 'falls back to calculate_next_run_at' do
        travel_to(now) do
          expect(instance.effective_time_window).to eq(7200)
        end
      end
    end

    context 'with a large time_window on a monthly schedule' do
      let(:time_window_seconds) { 30.days.to_i }
      let(:next_run_at) { now + 7.days }

      it 'caps to the interval until next run' do
        travel_to(now) do
          expect(instance.effective_time_window(next_run_at)).to eq(7.days.to_i)
        end
      end
    end
  end
end
