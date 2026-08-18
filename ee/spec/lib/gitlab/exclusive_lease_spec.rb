# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ExclusiveLease, :clean_gitlab_redis_shared_state,
  feature_category: :shared do
  let(:unique_key) { SecureRandom.hex(10) }

  describe '#try_obtain_with_ttl' do
    it 'cannot obtain twice before the lease has expired' do
      lease = described_class.new(unique_key, timeout: 3600)

      ttl_lease = lease.try_obtain_with_ttl

      expect(ttl_lease[:uuid]).to be_present
      expect(ttl_lease[:ttl]).to eq(0)

      second_ttl_lease = lease.try_obtain_with_ttl

      expect(second_ttl_lease[:uuid]).to be false
      expect(second_ttl_lease[:ttl]).to be > 0
    end

    it 'can obtain after the lease has expired' do
      timeout = 1
      lease = described_class.new(unique_key, timeout: 1)

      sleep(2 * timeout) # lease should have expired now

      ttl_lease = lease.try_obtain_with_ttl

      expect(ttl_lease[:uuid]).to be_present
      expect(ttl_lease[:ttl]).to eq(0)
    end
  end
end
