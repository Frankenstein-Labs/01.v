# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::MetricsUpdateService, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let_it_be(:primary, freeze: true) { create(:geo_node, :primary) }
  let_it_be(:secondary, freeze: true) { create(:geo_node) }
  let_it_be(:another_secondary, freeze: true) { create(:geo_node) }
  let(:event_date) { Time.current.utc }
  let(:data) do
    {
      status_message: nil,
      db_replication_lag_seconds: 0,
      project_repositories_count: 10,
      last_event_id: 2,
      last_event_date: event_date,
      cursor_last_event_id: 1,
      cursor_last_event_date: event_date,
      event_log_max_id: 555,
      project_repositories_registry_count: 10,
      project_repositories_checksummed_count: 3,
      project_repositories_checksum_failed_count: 4,
      project_repositories_synced_count: 5,
      project_repositories_failed_count: 6,
      project_repositories_verified_count: 7,
      project_repositories_verification_failed_count: 8
    }
  end

  let(:primary_data) do
    {
      status_message: nil,
      project_repositories_count: 10,
      last_event_id: 2,
      last_event_date: event_date,
      event_log_max_id: 555
    }
  end

  subject(:service) { described_class.new }

  before do
    # We disable the transaction_open? check because Gitlab::Database::BatchCounter.batch_count
    # is not allowed within a transaction but all RSpec tests run inside of a transaction.
    stub_batch_counter_transaction_open_check

    # Enable Prometheus metrics for the service
    allow(Gitlab::Metrics).to receive(:prometheus_metrics_enabled?).and_return(true)

    # Clear any cached status from previous examples to prevent test pollution
    # when using let_it_be. See https://gitlab.com/gitlab-org/gitlab/-/issues/590041
    primary.reload_status
    secondary.reload_status
    another_secondary.reload_status
  end

  describe '#execute' do
    before do
      allow_next_instance_of(Geo::NodeStatusRequestService) do |instance|
        allow(instance).to receive(:execute).and_return(true)
      end
    end

    context 'when called from metrics worker' do
      let(:timeout) { 1.hour }

      before do
        stub_current_geo_node(primary)
        allow(GeoNodeStatus).to receive(:current_node_status)
      end

      it 'passes timing parameters to GeoNodeStatus' do
        service.execute(
          timeout:
        )

        expect(GeoNodeStatus).to have_received(:current_node_status).with(timeout:).once
      end
    end

    context 'when Geo is not enabled' do
      before do
        allow(Gitlab::Geo).to receive(:enabled?).and_return(false)
      end

      it 'returns early without doing any work' do
        expect(GeoNodeStatus).not_to receive(:current_node_status)

        service.execute
      end
    end

    context 'when current node is nil' do
      before do
        stub_current_geo_node(nil)
      end

      it 'skips posting the status' do
        expect(Geo::NodeStatusRequestService).not_to receive(:new)

        service.execute
      end
    end

    context 'when current node status is nil' do
      before do
        stub_current_geo_node(primary)
        allow(GeoNodeStatus).to receive(:current_node_status).and_return(nil)
        allow(GeoNode).to receive(:current_node_name).and_return('primary-node')
      end

      it 'logs a warning and returns early' do
        expect(service).to receive(:log_warning)
          .with('Failed to load current node status', current_node_name: 'primary-node')
        expect(Gitlab::Metrics).not_to receive(:gauge)

        service.execute
      end
    end

    context 'when Prometheus metrics are disabled' do
      it 'skips updating Prometheus metrics' do
        stub_current_geo_node(primary)
        allow(Gitlab::Metrics).to receive(:prometheus_metrics_enabled?).and_return(false)
        expect(Gitlab::Metrics).not_to receive(:gauge)

        service.execute
      end

      it 'still updates the cache' do
        stub_current_geo_node(primary)
        allow(Gitlab::Metrics).to receive(:prometheus_metrics_enabled?).and_return(false)
        status = GeoNodeStatus.new(primary_data)
        allow(GeoNodeStatus).to receive(:current_node_status).and_return(status)

        expect(status).to receive(:update_cache!)

        service.execute
      end
    end

    context 'when node is the primary' do
      before do
        stub_current_geo_node(primary)
      end

      it 'calls GeoNodeStatus without timing parameters by default' do
        allow(GeoNodeStatus).to receive(:current_node_status)

        service.execute

        expect(GeoNodeStatus).to have_received(:current_node_status).with(timeout: nil).once
      end

      it 'updates the cache' do
        status = GeoNodeStatus.new(primary_data)
        allow(GeoNodeStatus).to receive(:current_node_status).and_return(status)

        expect(status).to receive(:update_cache!)

        service.execute
      end

      it 'updates metrics for all sites' do
        # Mock Prometheus gauge for this test only
        mock_gauge = instance_double(::Prometheus::Client::Gauge, set: nil)
        allow(Gitlab::Metrics).to receive(:gauge).and_return(mock_gauge)

        allow(GeoNodeStatus).to receive(:current_node_status).and_return(GeoNodeStatus.new(primary_data))

        # Create fresh secondary nodes for this test since we need to mutate them
        # (the let_it_be nodes are frozen to prevent state leakage)
        test_secondary = create(:geo_node)
        test_another_secondary = create(:geo_node)
        test_secondary.update!(status: GeoNodeStatus.new(data))
        test_another_secondary.update!(status: GeoNodeStatus.new(data))

        service.execute

        # Verify that gauge method is called to create metrics
        expect(Gitlab::Metrics).to have_received(:gauge).at_least(:once)
      end

      it 'updates the GeoNodeStatus entry' do
        expect { service.execute }.to change { GeoNodeStatus.count }.by(1)
      end
    end

    context 'when node is a secondary' do
      before do
        stub_current_geo_node(secondary)
        @status = GeoNodeStatus.new(data)
        allow(GeoNodeStatus).to receive(:current_node_status).and_return(@status)
      end

      it 'updates the cache' do
        expect(@status).to receive(:update_cache!)

        service.execute
      end

      it 'adds gauges for various metrics' do
        # Mock Prometheus gauge for this test only
        mock_gauge = instance_double(::Prometheus::Client::Gauge, set: nil)
        allow(Gitlab::Metrics).to receive(:gauge).and_return(mock_gauge)

        service.execute

        # Verify that gauge method is called to create metrics
        expect(Gitlab::Metrics).to have_received(:gauge).at_least(:once)
      end

      it 'increments a counter when metrics fail to retrieve' do
        # Mock Prometheus counter for this test only
        mock_counter = instance_double(::Prometheus::Client::Counter, increment: nil)
        allow(Gitlab::Metrics).to receive(:counter).and_return(mock_counter)

        allow_next_instance_of(Geo::NodeStatusRequestService) do |instance|
          allow(instance).to receive(:execute).and_return(false)
        end

        service.execute

        expect(Gitlab::Metrics).to have_received(:counter).at_least(:once)
      end

      it 'does not create GeoNodeStatus entries' do
        expect { service.execute }.to not_change { GeoNodeStatus.count }
      end
    end

    context 'when node is an org migration target' do
      before do
        stub_feature_flags(org_migration_target_cell: true)
        stub_current_geo_node(secondary)
        @status = GeoNodeStatus.new(data)
        allow(GeoNodeStatus).to receive(:current_node_status).and_return(@status)
      end

      it 'sends status to primary' do
        expect_next_instance_of(Geo::NodeStatusRequestService) do |instance|
          expect(instance).to receive(:execute)
        end

        service.execute
      end

      it 'updates the cache' do
        expect(@status).to receive(:update_cache!)

        service.execute
      end

      it 'adds gauges for various metrics' do
        # Mock Prometheus gauge for this test only
        mock_gauge = instance_double(::Prometheus::Client::Gauge, set: nil)
        allow(Gitlab::Metrics).to receive(:gauge).and_return(mock_gauge)

        service.execute

        # Verify that gauge method is called to create metrics
        expect(Gitlab::Metrics).to have_received(:gauge).at_least(:once)
      end

      it 'increments a counter when metrics fail to retrieve' do
        # Mock Prometheus counter for this test only
        mock_counter = instance_double(::Prometheus::Client::Counter, increment: nil)
        allow(Gitlab::Metrics).to receive(:counter).and_return(mock_counter)

        allow_next_instance_of(Geo::NodeStatusRequestService) do |instance|
          allow(instance).to receive(:execute).and_return(false)
        end

        service.execute

        expect(Gitlab::Metrics).to have_received(:counter).at_least(:once)
      end

      it 'does not create GeoNodeStatus entries' do
        expect { service.execute }.to not_change { GeoNodeStatus.count }
      end
    end
  end

  describe '#current_node_status' do
    context 'when called with a timeout' do
      let(:timeout) { 1.hour }

      it 'calls GeoNodeStatus.current_node_status with the provided timeout' do
        allow(GeoNodeStatus).to receive(:current_node_status).and_return(nil)

        service.send(:current_node_status, timeout: timeout)

        expect(GeoNodeStatus).to have_received(:current_node_status).with(timeout: timeout).once
      end
    end

    context 'when called without a timeout' do
      it 'calls GeoNodeStatus.current_node_status with nil timeout' do
        allow(GeoNodeStatus).to receive(:current_node_status).and_return(nil)

        service.send(:current_node_status)

        expect(GeoNodeStatus).to have_received(:current_node_status).with(timeout: nil).once
      end
    end
  end
end
