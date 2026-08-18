# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo::LogCursor::Daemon, :clean_gitlab_redis_shared_state, feature_category: :geo_replication do
  include ::EE::GeoHelpers
  include ExclusiveLeaseHelpers

  # freeze: true catches accidental mutation causing state leakage across tests.
  # primary and secondary use reload: true because tests intentionally mutate them.
  # See https://gitlab.com/gitlab-org/gitlab/-/issues/590041
  let_it_be_with_reload(:primary) { create(:geo_node, :primary) }
  let_it_be_with_reload(:secondary) { create(:geo_node) }

  let(:options) { {} }

  subject(:daemon) { described_class.new(options) }

  around do |example|
    Sidekiq::Testing.fake! { example.run }
  end

  before do
    stub_current_geo_node(secondary)

    allow(daemon).to receive(:trap_signals)
    allow(daemon).to receive(:sleep_break).and_return(0.1)
  end

  # Warning: Ensure an exit condition for the main run! loop, or RSpec will not
  # stop without an interrupt. You can use `ensure_exit_on` to specify the exact
  # number of calls to `exit?`, with the last call returning `true`.
  describe '#run!' do
    it 'traps signals' do
      ensure_exit_on(1)
      is_expected.to receive(:trap_signals)

      daemon.run!
    end

    it 'delegates to #run_once! in a loop' do
      ensure_exit_on(3)
      is_expected.to receive(:run_once!).twice

      daemon.run!
    end
  end

  describe '#run_once!' do
    it 'skips execution if cannot achieve a lease' do
      lease = stub_exclusive_lease_taken('geo_log_cursor_processed')

      allow(lease).to receive(:try_obtain_with_ttl).and_return({ ttl: 1, uuid: false })
      allow(lease).to receive(:same_uuid?).and_return(false)
      allow(Gitlab::Geo::LogCursor::Lease).to receive(:exclusive_lease).and_return(lease)

      is_expected.not_to receive(:find_and_handle_events!)

      daemon.run_once!
    end

    it 'skips execution if not a Geo node' do
      stub_current_geo_node(nil)

      is_expected.to receive(:sleep_break).with(1.minute)
      is_expected.not_to receive(:find_and_handle_events!)

      daemon.run_once!
    end

    it 'skips execution if the current node is a primary' do
      stub_current_geo_node(primary)

      is_expected.to receive(:sleep_break).with(1.minute)
      is_expected.not_to receive(:find_and_handle_events!)

      daemon.run_once!
    end

    context 'when the current node is an org migration target' do
      before do
        stub_feature_flags(org_migration_target_cell: true)
      end

      it 'does not skip execution' do
        is_expected.not_to receive(:sleep_break).with(1.minute)
        is_expected.to receive(:find_and_handle_events!)

        daemon.run_once!
      end
    end

    context 'when the lease block rescues an error' do
      context 'when this error is the final straw' do
        it 'calls `#exit!`' do
          is_expected.to receive(:exit!)

          is_expected.to receive(:find_and_handle_events!).and_raise('any error').twice

          daemon.run_once!

          travel_to((described_class::MAX_ERROR_DURATION + 1.second).from_now) do
            daemon.run_once!
          end
        end
      end

      context 'when this error is not the final straw' do
        it 'does not call `#exit!`' do
          is_expected.not_to receive(:exit!)

          is_expected.to receive(:find_and_handle_events!).and_raise('any error')
          daemon.run_once!

          travel_to((described_class::MAX_ERROR_DURATION + 1.second).from_now) do
            is_expected.to receive(:find_and_handle_events!) # successful
            daemon.run_once!

            is_expected.to receive(:find_and_handle_events!).and_raise('any error')
            daemon.run_once!
          end
        end
      end
    end
  end

  describe '#find_and_handle_events!' do
    context 'with some event logs' do
      let(:cache_invalidation_event) { create(:geo_cache_invalidation_event) }
      let(:event_log) { create(:geo_event_log, cache_invalidation_event: cache_invalidation_event) }
      let(:batch) { [event_log] }
      let!(:event_log_state) { create(:geo_event_log_state, event_id: event_log.id - 1) }

      it 'handles events' do
        expect(daemon).to receive(:handle_events).with(batch, anything)

        daemon.find_and_handle_events!
      end

      it 'calls #handle_gap_event for each gap the gap tracking finds' do
        second_event_log = create(:geo_event_log, cache_invalidation_event: cache_invalidation_event)

        allow_any_instance_of(::Gitlab::Geo::LogCursor::EventLogs).to receive(:fetch_in_batches)
        allow(daemon.send(:gap_tracking)).to receive(:fill_gaps).and_yield(event_log).and_yield(second_event_log)

        expect(daemon).to receive(:handle_single_event).with(event_log)
        expect(daemon).to receive(:handle_single_event).with(second_event_log)

        daemon.find_and_handle_events!
      end

      it 'exits when told to stop' do
        allow_any_instance_of(::Gitlab::Geo::LogCursor::EventLogs).to receive(:fetch_in_batches)
        allow(daemon).to receive(:exit?).and_return(true)

        expect(daemon).not_to receive(:handle_events)

        daemon.find_and_handle_events!
      end
    end
  end

  describe '#handle_events' do
    let(:batch) { create_list(:geo_event_log, 2) }

    it 'passes the previous batch id on to gap tracking' do
      expect(daemon.send(:gap_tracking)).to receive(:previous_id=).with(55).ordered
      batch.each do |event_log|
        expect(daemon.send(:gap_tracking)).to receive(:previous_id=).with(event_log.id).ordered
      end

      daemon.send(:handle_events, batch, 55)
    end

    it 'checks for gaps for each id in batch' do
      batch.each do |event_log|
        expect(daemon.send(:gap_tracking)).to receive(:check!).with(event_log.id)
      end

      daemon.send(:handle_events, batch, 55)
    end

    it 'handles every single event' do
      batch.each do |event_log|
        expect(daemon).to receive(:handle_single_event).with(event_log)
      end

      daemon.send(:handle_events, batch, 55)
    end

    it 'logs the correlation id passed in the payload' do
      expect(daemon.send(:logger)).to receive(:info).with(
        "#handle_events:",
        first_id: batch.first.id,
        last_id: batch.last.id,
        correlation_id: Labkit::Correlation::CorrelationId.current_id
      )

      daemon.send(:handle_events, batch, 55)
    end
  end

  # freeze: true catches accidental mutation causing state leakage across tests.
  # See https://gitlab.com/gitlab-org/gitlab/-/issues/590041
  describe '#handle_single_event' do
    let_it_be(:event_log, freeze: true) { create(:geo_event_log, :geo_event) }

    it 'skips execution when no event data is found' do
      event_log = build(:geo_event_log)
      expect(daemon).not_to receive(:can_replay?)

      daemon.send(:handle_single_event, event_log)
    end

    it 'checks if it can replay the event' do
      expect(daemon).to receive(:can_replay?)

      daemon.send(:handle_single_event, event_log)
    end

    it 'processes event when it is replayable' do
      allow(daemon).to receive(:can_replay?).and_return(true)
      expect(daemon).to receive(:process_event).with(event_log.event, event_log).and_call_original

      daemon.send(:handle_single_event, event_log)
    end
  end

  describe '#process_event' do
    context 'when NoMethodError occurs' do
      let(:error_message) { 'undefined method' }
      let(:event_log) { create(:geo_event_log) }
      let(:logger) { Gitlab::Geo::LogCursor::Logger.new(described_class, :debug) }

      before do
        allow(daemon).to receive(:event_klass_for).with(event_log.event)
          .and_raise(NoMethodError.new(error_message))
        allow(Gitlab::Geo::LogCursor::Logger).to receive(:new).and_return(logger)
        allow(daemon).to receive(:correlation_id).and_return('test-correlation-id')
      end

      it 'logs the error and re-raises it' do
        expect(logger).to receive(:error).with(
          error_message,
          correlation_id: 'test-correlation-id'
        )

        # daemon.send(:process_event, event_log.event, event_log)
        expect { daemon.send(:process_event, event_log.event, event_log) }
          .to raise_error(NoMethodError, error_message)
      end
    end
  end

  def read_gaps
    gaps = []

    travel_to(12.minutes.from_now) do
      daemon.send(:gap_tracking).send(:fill_gaps) { |event| gaps << event.id }
    end

    gaps
  end

  # It is extremely easy to get run! into an infinite loop.
  #
  # Regardless of `allow` or `expect`, this method ensures that the loop will
  # exit at the specified number of exit? calls.
  def ensure_exit_on(num_calls = 3, expect = true)
    # E.g. If num_calls is `3`, returns is set to `[false, false, true]`.
    returns = Array.new(num_calls) { false }
    returns[-1] = true

    if expect
      expect(daemon).to receive(:exit?).and_return(*returns)
    else
      allow(daemon).to receive(:exit?).and_return(*returns)
    end
  end
end
