# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Security::PipelineExecutionSchedulePolicies::Snooze, feature_category: :security_policy_management do
  describe '#until' do
    context 'when until is present' do
      it 'returns the until value' do
        snooze = described_class.new({ until: '2025-12-31T23:59:59+00:00', reason: 'Holiday' })
        expect(snooze.until).to eq('2025-12-31T23:59:59+00:00')
      end

      it 'handles different date-time formats' do
        snooze = described_class.new({ until: '2025-06-15T10:30:00+00:00' })
        expect(snooze.until).to eq('2025-06-15T10:30:00+00:00')
      end
    end

    context 'when until is not present' do
      it 'returns nil' do
        snooze = described_class.new({ reason: 'Holiday' })
        expect(snooze.until).to be_nil
      end
    end
  end

  describe '#reason' do
    context 'when reason is present' do
      it 'returns the reason value' do
        snooze = described_class.new({ until: '2025-12-31T23:59:59+00:00', reason: 'Holiday break' })
        expect(snooze.reason).to eq('Holiday break')
      end
    end

    context 'when reason is not present' do
      it 'returns nil' do
        snooze = described_class.new({ until: '2025-12-31T23:59:59+00:00' })
        expect(snooze.reason).to be_nil
      end
    end
  end

  describe 'complete snooze' do
    it 'handles snooze with all fields' do
      snooze_data = {
        until: '2025-12-31T23:59:59+00:00',
        reason: 'Holiday break'
      }
      snooze = described_class.new(snooze_data)

      expect(snooze.until).to eq('2025-12-31T23:59:59+00:00')
      expect(snooze.reason).to eq('Holiday break')
    end

    it 'handles snooze with only until field' do
      snooze_data = {
        until: '2025-12-31T23:59:59+00:00'
      }
      snooze = described_class.new(snooze_data)

      expect(snooze.until).to eq('2025-12-31T23:59:59+00:00')
      expect(snooze.reason).to be_nil
    end

    context 'when snooze is nil' do
      it 'handles nil gracefully' do
        snooze = described_class.new(nil)
        expect(snooze.until).to be_nil
        expect(snooze.reason).to be_nil
      end
    end

    context 'when snooze is empty' do
      it 'handles empty hash gracefully' do
        snooze = described_class.new({})
        expect(snooze.until).to be_nil
        expect(snooze.reason).to be_nil
      end
    end
  end
end
