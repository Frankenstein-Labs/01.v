# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::FallbackBehavior, feature_category: :security_policy_management do
  describe '#fail_open?' do
    context 'when fail is set to open' do
      it 'returns true' do
        fallback_behavior = described_class.new({ fail: 'open' })
        expect(fallback_behavior.fail_open?).to be true
      end
    end

    context 'when fail is set to closed' do
      it 'returns false' do
        fallback_behavior = described_class.new({ fail: 'closed' })
        expect(fallback_behavior.fail_open?).to be false
      end
    end

    context 'when fail is not set' do
      it 'returns false' do
        fallback_behavior = described_class.new({})
        expect(fallback_behavior.fail_open?).to be false
      end
    end

    context 'when fail is set to an invalid value' do
      it 'returns false' do
        fallback_behavior = described_class.new({ fail: 'invalid' })
        expect(fallback_behavior.fail_open?).to be false
      end
    end
  end

  describe '#fail_closed?' do
    context 'when fail is set to closed' do
      it 'returns true' do
        fallback_behavior = described_class.new({ fail: 'closed' })
        expect(fallback_behavior.fail_closed?).to be true
      end
    end

    context 'when fail is set to open' do
      it 'returns false' do
        fallback_behavior = described_class.new({ fail: 'open' })
        expect(fallback_behavior.fail_closed?).to be false
      end
    end

    context 'when fail is not set' do
      it 'returns false' do
        fallback_behavior = described_class.new({})
        expect(fallback_behavior.fail_closed?).to be false
      end
    end

    context 'when fail is set to an invalid value' do
      it 'returns false' do
        fallback_behavior = described_class.new({ fail: 'invalid' })
        expect(fallback_behavior.fail_closed?).to be false
      end
    end
  end
end
