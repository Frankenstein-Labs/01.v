# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::CreateObjectPoolService, feature_category: :geo_replication do
  include ExclusiveLeaseHelpers

  let(:pool_repository) { build(:pool_repository, :without_project, id: 123) }
  let(:lease_key) { "object_pool:create:#{pool_repository.id}" }
  let(:lease_timeout) { described_class::LEASE_TIMEOUT }

  subject(:service) { described_class.new(pool_repository) }

  before do
    stub_exclusive_lease(lease_key, timeout: lease_timeout, renew: true)
  end

  describe '#execute' do
    it 'calls create_object_pool on the pool_repository' do
      expect(pool_repository).to receive(:create_object_pool)

      service.execute
    end

    it 'does not execute when lease cannot be obtained' do
      stub_exclusive_lease_taken(lease_key, timeout: lease_timeout)

      expect(pool_repository).not_to receive(:create_object_pool)

      service.execute
    end
  end
end
