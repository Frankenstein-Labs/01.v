# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::Rollouts::CallbackToken, feature_category: :continuous_delivery do
  let_it_be(:rollout) { create(:cd_rollout) }
  let_it_be(:other_rollout) { create(:cd_rollout) }

  let(:jwt_secret) { SecureRandom.random_bytes(Gitlab::JwtAuthenticatable::SECRET_LENGTH) }

  before do
    allow(Gitlab::Kas).to receive(:secret).and_return(jwt_secret)
  end

  describe '.encode/.matches?' do
    it 'issues a token that matches the rollout it was issued for' do
      token = described_class.encode(rollout)

      expect(described_class.matches?(token, rollout)).to be(true)
    end

    it 'does not match a different rollout' do
      token = described_class.encode(rollout)

      expect(described_class.matches?(token, other_rollout)).to be(false)
    end

    it 'does not match a blank token' do
      expect(described_class.matches?(nil, rollout)).to be(false)
      expect(described_class.matches?('', rollout)).to be(false)
    end

    it 'does not match a garbage token' do
      expect(described_class.matches?('not-a-jwt', rollout)).to be(false)
    end

    it 'does not match a token signed with a different secret' do
      token = described_class.encode(rollout)

      allow(Gitlab::Kas).to receive(:secret).and_return(SecureRandom.random_bytes(Gitlab::JwtAuthenticatable::SECRET_LENGTH))

      expect(described_class.matches?(token, rollout)).to be(false)
    end

    it 'does not match an expired token' do
      token = described_class.encode(rollout)

      travel_to(described_class::EXPIRE_IN.from_now + 1.minute) do
        expect(described_class.matches?(token, rollout)).to be(false)
      end
    end
  end
end
