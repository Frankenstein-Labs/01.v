# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::EnforcementType, feature_category: :security_policy_management do
  describe '#warn?' do
    context 'when enforcement_type is warn' do
      it 'returns true' do
        enforcement_type = described_class.new('warn')
        expect(enforcement_type.warn?).to be true
      end
    end

    context 'when enforcement_type is enforce' do
      it 'returns false' do
        enforcement_type = described_class.new('enforce')
        expect(enforcement_type.warn?).to be false
      end
    end

    context 'when enforcement_type is nil' do
      it 'returns false' do
        enforcement_type = described_class.new(nil)
        expect(enforcement_type.warn?).to be false
      end
    end
  end

  describe '#enforce?' do
    context 'when enforcement_type is enforce' do
      it 'returns true' do
        enforcement_type = described_class.new('enforce')
        expect(enforcement_type.enforce?).to be true
      end
    end

    context 'when enforcement_type is warn' do
      it 'returns false' do
        enforcement_type = described_class.new('warn')
        expect(enforcement_type.enforce?).to be false
      end
    end

    context 'when enforcement_type is nil' do
      it 'returns true (defaults to enforce)' do
        enforcement_type = described_class.new(nil)
        expect(enforcement_type.enforce?).to be true
      end
    end
  end
end
