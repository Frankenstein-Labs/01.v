# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SyncTimeoutCronWorker, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  describe '#perform' do
    context 'when on a secondary or org migration target' do
      before do
        stub_secondary_node
      end

      it 'calls fail_sync_timeouts' do
        replicator = double('replicator')

        expect(replicator).to receive(:fail_sync_timeouts)
        expect(Gitlab::Geo).to receive(:replication_enabled_replicator_classes).and_return([replicator])

        described_class.new.perform
      end
    end

    context 'when not a secondary or org migration target' do
      before do
        stub_primary_node
      end

      it 'does not call fail_sync_timeouts' do
        expect(Gitlab::Geo).not_to receive(:replication_enabled_replicator_classes)

        described_class.new.perform
      end
    end

    context 'when there is no Geo site record at all' do
      it 'does not raise' do
        expect { described_class.new.perform }.not_to raise_error
      end
    end
  end

  it 'uses a cronjob queue' do
    expect(subject.sidekiq_options_hash).to include(
      'queue_namespace' => :cronjob
    )
  end
end
