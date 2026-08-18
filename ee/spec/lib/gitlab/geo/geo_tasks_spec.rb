# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo::GeoTasks, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  describe '.set_primary_geo_node' do
    before do
      allow(GeoNode).to receive(:current_node_name).and_return('https://primary.geo.example.com')
      allow(GeoNode).to receive(:current_node_url).and_return('https://primary.geo.example.com')
    end

    it 'sets the primary node' do
      expect { subject.set_primary_geo_node }.to output(%r{https://primary.geo.example.com/ is now the primary Geo node}).to_stdout
    end

    it 'returns error when there is already a Primary node' do
      create(:geo_node, :primary)

      expect { subject.set_primary_geo_node }.to output(/Error saving Geo node:/).to_stdout
    end
  end

  describe '.set_secondary_as_primary' do
    let!(:primary) { create(:geo_node, :primary) }
    let!(:secondary) { create(:geo_node) }

    before do
      allow(GeoNode).to receive(:current_node).and_return(secondary)
      allow_next_instance_of(Gitlab::Geo::CronManager) do |cron_manager|
        allow(cron_manager).to receive(:enable_all_jobs!).and_return(true)
      end
      allow(Gitlab::SidekiqConfig::CronJobInitializer).to receive(:execute).and_return(true)
    end

    it 'aborts if the primary node is not set' do
      primary.update_column(:primary, false)

      expect(subject).to receive(:abort).with('The primary Geo site is not set').and_raise('aborted')

      expect { subject.set_secondary_as_primary }.to raise_error('aborted')
    end

    context 'without secondary geo node' do
      let(:secondary) { nil }

      it 'aborts if current node is not identified' do
        expect(subject).to receive(:abort).with('Current node is not identified').and_raise('aborted')

        expect { subject.set_secondary_as_primary }.to raise_error('aborted')
      end
    end

    it 'does nothing if run on a node that is not a secondary' do
      primary.update_column(:primary, false)
      secondary.update!(primary: true)

      expect(subject).not_to receive(:abort)

      expect { subject.set_secondary_as_primary }.to output(/#{secondary.url} is already the primary Geo site/).to_stdout
      expect(secondary.reload).to be_primary
      expect(primary.reload).to be_secondary
    end

    it 'sets the secondary as the primary node' do
      expect(subject).not_to receive(:abort)

      expect { subject.set_secondary_as_primary }.to output(/#{secondary.url} is now the primary Geo site/).to_stdout
      expect(secondary.reload).to be_primary
    end

    it 'sets the secondary as the primary node, even if the secondary is disabled' do
      secondary.update_column(:enabled, false)

      expect(subject).not_to receive(:abort)

      expect { subject.set_secondary_as_primary }.to output(/#{secondary.url} is now the primary Geo site/).to_stdout
      expect(secondary.reload).to be_primary
      expect(secondary.reload).to be_enabled
    end

    it 'enables all cron jobs' do
      expect_next_instance_of(Gitlab::Geo::CronManager) do |cron_manager|
        expect(cron_manager).to receive(:enable_all_jobs!).and_return(true)
      end

      subject.set_secondary_as_primary
    end

    it 'executes Gitlab::SidekiqConfig::CronJobInitializer' do
      expect(Gitlab::SidekiqConfig::CronJobInitializer).to receive(:execute).and_return(true)

      subject.set_secondary_as_primary
    end
  end

  describe '.enable_maintenance_mode' do
    context 'when MAINTENANCE_MESSAGE is present' do
      before do
        stub_env('MAINTENANCE_MESSAGE', 'foo')
      end

      it 'enables maintenance mode' do
        described_class.enable_maintenance_mode

        expect(::Gitlab::CurrentSettings.maintenance_mode?).to be_truthy
      end

      it 'sets the maintenance mode message application setting to MAINTENANCE_MESSAGE' do
        described_class.enable_maintenance_mode

        expect(::Gitlab::CurrentSettings.maintenance_mode_message).to eq('foo')
      end

      it 'outputs what it is doing' do
        expect do
          described_class.enable_maintenance_mode
        end.to output("Enabling GitLab Maintenance Mode\n").to_stdout
      end
    end

    context 'when MAINTENANCE_MESSAGE is not present' do
      it 'enables maintenance mode' do
        described_class.enable_maintenance_mode

        expect(::Gitlab::CurrentSettings.maintenance_mode?).to be_truthy
      end

      it 'does not set the maintenance mode message application setting' do
        described_class.enable_maintenance_mode

        expect(::Gitlab::CurrentSettings.maintenance_mode_message).to be_nil
      end

      it 'outputs what it is doing' do
        expect do
          described_class.enable_maintenance_mode
        end.to output("Enabling GitLab Maintenance Mode\n").to_stdout
      end
    end
  end

  describe '.drain_non_geo_queues' do
    before do
      allow(described_class).to receive(:validate_geo_queues_exist!)
    end

    it 'disables all non-Geo Sidekiq cron jobs' do
      cronjob1 = instance_double(Sidekiq::Cron::Job)
      cronjob2 = instance_double(Sidekiq::Cron::Job)
      allow(Sidekiq::Cron::Job).to receive(:all).and_return([cronjob1, cronjob2])
      expect(cronjob1).to receive(:disable!)
      expect(cronjob2).to receive(:disable!)

      described_class.drain_non_geo_queues
    end

    it 'enables Geo primary Sidekiq cron jobs' do
      cronjob1 = instance_double(Sidekiq::Cron::Job)
      cronjob2 = instance_double(Sidekiq::Cron::Job)
      allow(described_class).to receive(:geo_primary_jobs).and_return(%w[foo bar])
      allow(Sidekiq::Cron::Job).to receive(:find).with('foo').and_return(cronjob1)
      allow(Sidekiq::Cron::Job).to receive(:find).with('bar').and_return(cronjob2)
      expect(cronjob1).to receive(:enable!)
      expect(cronjob2).to receive(:enable!)

      described_class.drain_non_geo_queues
    end

    it 'waits until all non-Geo queues are empty' do
      queue1 = instance_double(Sidekiq::Queue, name: 'foo')
      queue2 = instance_double(Sidekiq::Queue, name: 'geo_bar')
      queue3 = instance_double(Sidekiq::Queue, name: 'baz')
      allow(Sidekiq::Queue).to receive(:all).and_return([queue1, queue2, queue3])

      # Simulate the draining of relevant queues. Failure modes include:
      #
      # * Queue#size gets called more than the specified number of times
      # * Queue#size gets called fewer than the specified number of times
      expect(queue1).to receive(:size).and_return(5).once
      expect(queue1).to receive(:size).and_return(0).once
      expect(queue3).to receive(:size).and_return(99).twice
      expect(queue3).to receive(:size).and_return(0).once

      expect(queue2).not_to receive(:size)
      expect(described_class).to receive(:sleep).with(1).twice

      expected_output = <<~MSG
        Sidekiq Queues: Disabling all non-Geo cron jobs
        Sidekiq Queues: Waiting for all non-Geo queues to be empty
        Sidekiq Queues: Non-Geo queues empty
      MSG

      expect do
        described_class.drain_non_geo_queues
      end.to output(expected_output).to_stdout
    end
  end

  describe '.wait_until_replicated_and_verified' do
    it 'delegates the steps' do
      expect(described_class).to receive(:drain_geo_secondary_queues)
      expect(described_class).to receive(:wait_for_database_replication)
      expect(described_class).to receive(:wait_for_geo_log_cursor)
      expect(described_class).to receive(:wait_for_data_replication_and_verification)

      described_class.wait_until_replicated_and_verified
    end
  end

  describe '.drain_geo_secondary_queues' do
    it 'waits until all Geo queues are empty' do
      allow(described_class).to receive(:validate_geo_queues_exist!)
      queue1 = instance_double(Sidekiq::Queue, name: 'geo_foo')
      queue2 = instance_double(Sidekiq::Queue, name: 'bar')
      queue3 = instance_double(Sidekiq::Queue, name: 'geo_baz')
      allow(Sidekiq::Queue).to receive(:all).and_return([queue1, queue2, queue3])

      expect(queue1).to receive(:size).and_return(5).once
      expect(queue1).to receive(:size).and_return(0).once
      expect(queue3).to receive(:size).and_return(99).twice
      expect(queue3).to receive(:size).and_return(0).once

      expect(queue2).not_to receive(:size)
      expect(described_class).to receive(:sleep).with(1).twice

      described_class.drain_geo_secondary_queues
    end

    it 'outputs what it is doing' do
      allow(described_class).to receive(:validate_geo_queues_exist!)
      expected_output = <<~MSG
        Sidekiq Queues: Waiting for all Geo queues to be empty
        Sidekiq Queues: Geo queues empty
      MSG

      expect do
        described_class.drain_geo_secondary_queues
      end.to output(expected_output).to_stdout
    end
  end

  describe '.wait_for_database_replication' do
    let(:health_check) { instance_double(Gitlab::Geo::HealthCheck) }

    before do
      allow(Gitlab::Geo::HealthCheck).to receive(:new).and_return(health_check)
    end

    context 'when db_replication_lag_seconds is nil' do
      before do
        allow(health_check).to receive(:db_replication_lag_seconds).and_return(nil)
      end

      it 'returns immediately without sleeping' do
        expect(described_class).not_to receive(:sleep)
        expected_output = "Database replication: Replication method unknown. Skipping wait for DB replication.\n"
        expect { described_class.wait_for_database_replication }.to output(expected_output).to_stdout
      end
    end

    context 'when db_replication_lag_seconds is not nil' do
      let(:lag) { 1.34 }

      before do
        allow(health_check).to receive(:db_replication_lag_seconds).and_return(lag)
      end

      it 'waits until database replication has caught up' do
        expect(described_class).to receive(:sleep).with(lag).once

        expected_output = <<~MSG
          Database replication: Waiting for database replication to catch up
          Database replication: Caught up
        MSG

        expect do
          described_class.wait_for_database_replication
        end.to output(expected_output).to_stdout
      end
    end
  end

  describe '.wait_for_geo_log_cursor' do
    it 'waits until Geo log cursor has caught up' do
      status = instance_double(GeoNodeStatus)
      allow(GeoNodeStatus).to receive(:new).and_return(status)
      latest_event = instance_double(::Geo::EventLog)
      allow(::Geo::EventLog).to receive(:latest_event).and_return(latest_event)

      expect(latest_event).to receive(:id).and_return(123).exactly(3).times
      expect(status).to receive(:current_cursor_last_event_id).and_return(98)
      expect(status).to receive(:current_cursor_last_event_id).and_return(115)
      expect(status).to receive(:current_cursor_last_event_id).and_return(123)
      expect(described_class).to receive(:sleep).with(1).twice

      expected_output = <<~MSG
        Geo log cursor: Wait Geo log cursor to have processed all events on this secondary
        Geo log cursor: Latest known ID: 123, current cursor ID: 98
        Geo log cursor: Latest known ID: 123, current cursor ID: 115
        Geo log cursor: Latest known ID: 123, current cursor ID: 123
        Geo log cursor: Caught up
      MSG

      expect do
        described_class.wait_for_geo_log_cursor
      end.to output(expected_output).to_stdout
    end
  end

  describe '.wait_for_data_replication_and_verification' do
    it 'waits until all data is replicated and verified' do
      status_check = instance_double(Gitlab::Geo::GeoNodeStatusCheck)
      expect(described_class).to receive(:do_status_check).and_return(status_check).exactly(3).times

      expect(status_check).to receive(:replication_verification_complete?).and_return(false).twice
      expect(status_check).to receive(:replication_verification_complete?).and_return(true)
      expect(status_check).to receive(:print_replication_verification_status).twice

      # The print status method is stubbed, so its output is not shown here
      expected_output = <<~MSG
        Data replication/verification: Wait for all data to be replicated and verified
        Data replication/verification: All data successfully replicated and verified
      MSG

      expect do
        described_class.wait_for_data_replication_and_verification
      end.to output(expected_output).to_stdout
    end
  end

  # freeze: true catches accidental mutation causing state leakage across tests.
  # See https://gitlab.com/gitlab-org/gitlab/-/issues/590041
  describe '.do_status_check' do
    let_it_be(:secondary, freeze: true) { create(:geo_node) }

    before do
      stub_current_geo_node(secondary)
    end

    it 'does not aggregate data itself, instead it relies on Geo::MetricsUpdateWorker' do
      expect(GeoNodeStatus).to receive(:fast_current_node_status)
      expect(GeoNodeStatus).not_to receive(:current_node_status)

      described_class.do_status_check
    end

    context 'when a status is cached' do
      it 'returns a Gitlab::Geo::GeoNodeStatusCheck' do
        status = build(:geo_node_status, geo_node: secondary)
        allow(Rails.cache).to receive(:read).with(status.class.cache_key).and_return(status.attributes)

        expect(described_class.do_status_check).to be_a(Gitlab::Geo::GeoNodeStatusCheck)
      end
    end

    context 'when a status is not cached' do
      it 'returns nil' do
        expect(described_class.do_status_check).to be_nil
      end
    end
  end

  describe '.validate_geo_queues_exist!' do
    let(:geo_queue) { instance_double(Sidekiq::Queue, name: 'geo:sync') }
    let(:non_geo_queue) { instance_double(Sidekiq::Queue, name: 'default') }

    before do
      allow(Gitlab::Redis::Queues).to receive(:instances)
                                        .and_return({ main: Gitlab::Redis::Queues })
      allow(Gitlab::Redis::Queues).to receive(:sidekiq_redis)
      allow(Sidekiq::Client).to receive(:via).and_yield
    end

    context 'when Geo queues exist' do
      before do
        allow(Sidekiq::Queue).to receive(:all).and_return([geo_queue, non_geo_queue])
      end

      it 'does not raise an error' do
        expect { described_class.validate_geo_queues_exist! }.not_to raise_error
      end
    end

    context 'when no Geo queues exist' do
      before do
        allow(Sidekiq::Queue).to receive(:all).and_return([non_geo_queue])
      end

      it 'raises an error' do
        expect { described_class.validate_geo_queues_exist! }.to raise_error(
          RuntimeError, "No Geo queues detected. Unable to check if Geo or non-Geo jobs are drained")
      end
    end

    context 'when multiple Redis instances are present' do
      before do
        allow(Gitlab::Redis::Queues).to receive(:instances)
          .and_return({ foo: Gitlab::Redis::Queues, bar: Gitlab::Redis::Queues })
        allow(Gitlab::Redis::Queues).to receive(:sidekiq_redis)
      end

      it 'checks all instances and stops when a Geo queue is found' do
        expect(Sidekiq::Client).to receive(:via).ordered.and_yield
        expect(Sidekiq::Queue).to receive(:all).and_return([non_geo_queue])

        expect(Sidekiq::Client).to receive(:via).ordered.and_yield
        expect(Sidekiq::Queue).to receive(:all).and_return([geo_queue])

        expect { described_class.validate_geo_queues_exist! }.not_to raise_error
      end
    end

    context 'when no Redis instances are present' do
      before do
        allow(Gitlab::Redis::Queues).to receive(:instances).and_return({})
      end

      it 'raises an error' do
        expect { described_class.validate_geo_queues_exist! }.to raise_error(
          RuntimeError, "No Geo queues detected. Unable to check if Geo or non-Geo jobs are drained")
      end
    end
  end
end
