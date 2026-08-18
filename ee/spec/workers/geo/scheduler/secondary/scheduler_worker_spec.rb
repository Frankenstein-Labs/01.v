# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::Scheduler::Secondary::SchedulerWorker, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let_it_be(:primary_node) { create(:geo_node, :primary) }

  subject(:worker) { described_class.new }

  describe '#perform' do
    context 'when Geo database is not configured' do
      before do
        allow(Gitlab::Geo).to receive(:geo_database_configured?).and_return(false)
      end

      it 'logs info and returns early' do
        expect(worker).to receive(:log_info).with('Geo database not configured')

        worker.perform
      end
    end

    context 'when Geo database is configured' do
      before do
        allow(Gitlab::Geo).to receive(:geo_database_configured?).and_return(true)
      end

      context 'when current node is a primary' do
        before do
          stub_current_geo_node(primary_node)
        end

        it 'logs info and returns early' do
          expect(worker).to receive(:log_info).with('Current node not a secondary')

          worker.perform
        end
      end

      context 'when current node is a secondary' do
        let_it_be(:secondary_node) { create(:geo_node) }

        before do
          stub_current_geo_node(secondary_node)
        end

        it 'calls parent perform' do
          expect(worker).to receive(:try_obtain_lease).and_return(nil)

          worker.perform
        end
      end

      context 'when current node is an org_migration_target' do
        before do
          stub_org_migration_target_cell
        end

        it 'calls parent perform' do
          expect(worker).to receive(:try_obtain_lease).and_return(nil)

          worker.perform
        end
      end
    end
  end
end
