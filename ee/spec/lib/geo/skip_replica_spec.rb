# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SkipReplica, feature_category: :geo_replication do
  let(:project) { build_stubbed(:project) }

  let(:host_class) do
    Class.new do
      def skip_writes_if_replica(_sharding_object)
        yield
      end

      prepend Geo::SkipReplica
    end
  end

  let(:instance) { host_class.new }

  describe '#skip_writes_if_replica' do
    context 'when the sharding object is a replica' do
      before do
        allow(::Gitlab::Geo).to receive(:replica_sharding_object?).with(project).and_return(true)
      end

      it 'does not yield the block' do
        block_called = false

        instance.skip_writes_if_replica(project) { block_called = true }

        expect(block_called).to be false
      end

      it 'logs a skip message' do
        expect(Gitlab::Geo::Logger).to receive(:info).with(
          message: 'skip_writes_if_replica skipped a block because the sharding object is a replica',
          sharding_object_class: 'Project',
          sharding_object_id: project.id
        )

        instance.skip_writes_if_replica(project) { nil }
      end

      it 'logs only once per sharding object due to strong memoization' do
        expect(Gitlab::Geo::Logger).to receive(:info).once

        instance.skip_writes_if_replica(project) { nil }
        instance.skip_writes_if_replica(project) { nil }
      end
    end

    context 'when the sharding object is not a replica' do
      before do
        allow(::Gitlab::Geo).to receive(:replica_sharding_object?).with(project).and_return(false)
      end

      it 'yields the block' do
        block_called = false

        instance.skip_writes_if_replica(project) { block_called = true }

        expect(block_called).to be true
      end

      it 'does not log' do
        expect(Gitlab::Geo::Logger).not_to receive(:info)

        instance.skip_writes_if_replica(project) { nil }
      end
    end
  end

  describe '#skip_writes_if_replica?' do
    it 'delegates to Gitlab::Geo.replica_sharding_object?' do
      expect(::Gitlab::Geo).to receive(:replica_sharding_object?).with(project).and_return(true)

      expect(instance.skip_writes_if_replica?(project)).to be true
    end
  end
end
