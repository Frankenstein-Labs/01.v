# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SystemCheck::ContainerRegistryCheck, feature_category: :geo_replication do
  subject(:check) { described_class.new }

  describe '#skip?' do
    context 'when registry replication is not enabled' do
      before do
        allow(Gitlab.config.geo.registry_replication).to receive(:enabled).and_return(false)
      end

      it 'returns true' do
        expect(check.skip?).to be true
      end
    end

    context 'when registry replication is enabled' do
      before do
        allow(Gitlab.config.geo.registry_replication).to receive(:enabled).and_return(true)
      end

      it 'returns false' do
        expect(check.skip?).to be false
      end
    end
  end

  describe '#multi_check' do
    context 'when registry replication is not enabled' do
      before do
        allow(Gitlab.config.geo.registry_replication).to receive(:enabled).and_return(false)
      end

      it 'outputs skipped message' do
        expect { check.multi_check }.to output(
          /skipped \(Container Registry replication is not enabled\)\n\z/
        ).to_stdout
      end
    end

    context 'when registry replication is enabled' do
      before do
        allow(Gitlab.config.geo.registry_replication).to receive(:enabled).and_return(true)
      end

      context 'when there are no container registry events' do
        before do
          allow(Geo::Event).to receive_message_chain(:for_replicable, :last).and_return(nil)
        end

        it 'outputs replication enabled and no events found' do
          expect { check.multi_check }.to output(
            /yes\nContainer Registry Geo events ... none found/
          ).to_stdout
        end
      end

      context 'when there is a container registry event' do
        let(:event_time) { Time.utc(2026, 1, 15, 10, 30, 0) }
        let(:event) { instance_double(Geo::Event, created_at: event_time) }

        before do
          allow(Geo::Event).to receive_message_chain(:for_replicable, :last).and_return(event)
        end

        it 'outputs replication enabled and timestamp of last event' do
          expect { check.multi_check }.to output(
            /yes\nContainer Registry Geo events ... last event at 2026-01-15 10:30:00 UTC/
          ).to_stdout
        end
      end
    end
  end
end
