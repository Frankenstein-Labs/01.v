# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse, feature_category: :secrets_management do
  describe '#initialize' do
    it 'accepts a non-blocked response without a reason' do
      response = described_class.new(blocked: false)

      expect(response.blocked).to be false
      expect(response.blocked_reason).to be_nil
    end

    it 'accepts every allowlisted blocked_reason' do
      described_class::BLOCKED_REASONS.each do |reason|
        expect(described_class.new(blocked: true, blocked_reason: reason).blocked_reason).to eq(reason)
      end
    end

    it 'accepts no_billable_source_error as a blocked_reason' do
      response = described_class.new(blocked: true, blocked_reason: :no_billable_source_error)

      expect(response.blocked_reason).to eq(:no_billable_source_error)
    end

    it 'rejects an unknown blocked_reason' do
      expect { described_class.new(blocked: true, blocked_reason: :below_min_gitlab_version) }
        .to raise_error(ArgumentError, /Unknown CDot consumer-resolve blocked_reason/)
    end

    it 'rejects a blocked_reason on a non-blocked response' do
      expect { described_class.new(blocked: false, blocked_reason: :no_billable_source_error) }
        .to raise_error(ArgumentError, /Unknown CDot consumer-resolve blocked_reason/)
    end
  end
end
