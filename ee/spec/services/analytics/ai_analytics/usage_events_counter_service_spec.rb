# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AiAnalytics::UsageEventsCounterService, feature_category: :value_stream_management do
  let(:runtime_limiter) { instance_double(Gitlab::Metrics::RuntimeLimiter, over_time?: false) }
  let(:service) { described_class.new(cursor: 1, runtime_limiter: runtime_limiter) }

  before do
    # Ensure all new records starts with id 1 for all specs
    # to test the cursor behavior properly.
    ApplicationRecord.connection.execute(
      "ALTER SEQUENCE ai_usage_events_id_seq RESTART WITH 1"
    )
  end

  describe '#execute' do
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:user) { create(:user) }

    let_it_be(:timestamp) { Time.current.beginning_of_day }

    context 'when there are no events to process' do
      it 'returns finished with the original cursor' do
        create(:ai_usage_event)
        cursor = service.execute[:last_processed_id] # Process records

        result = service.execute # no records to process

        expect(result).to be_success
        expect(result[:result]).to eq(:finished)
        expect(result[:last_processed_id]).to eq(cursor) # same cursor from first run
        expect(result[:exception]).to be_nil
      end
    end

    context 'when processing events successfully' do
      let!(:events) do
        create_list(:ai_usage_event, 3,
          namespace_id: namespace.id,
          user_id: user.id,
          event: 'code_suggestion_shown_in_ide'
        )
      end

      it 'processes all events and returns success' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:result]).to eq(:finished)
        expect(result.payload[:last_processed_id]).to eq(Ai::UsageEvent.last.id)
      end

      it 'creates aggregated event counts' do
        expect { service.execute }.to change { Ai::EventsCount.count }.by(1)

        event_count = Ai::EventsCount.last
        expect(event_count.namespace_id).to eq(namespace.id)
        expect(event_count.user_id).to eq(user.id)
        expect(event_count.event).to eq('code_suggestion_shown_in_ide')
        expect(event_count.events_date).to eq(timestamp.to_date)
        expect(event_count.total_occurrences).to eq(3)
      end

      it 'only processes events after the cursor' do
        last_event = create(:ai_usage_event)

        service =
          described_class.new(cursor: last_event.id, runtime_limiter: runtime_limiter)

        expect { service.execute }.to change { Ai::EventsCount.count }.by(1)

        last_count = Ai::EventsCount.last
        expect(last_count.events_date).to eq(last_event.timestamp.to_date)
        expect(last_count.namespace).to eq(last_event.namespace)
        expect(last_count.user).to eq(last_event.user)
        expect(last_count.event).to eq(last_event.event)
        expect(last_count.total_occurrences).to eq(1)
      end
    end

    context 'when cursor is 1' do
      let(:cursor) { 1 }
      let!(:event) { create(:ai_usage_event) }

      it 'treats cursor as 0 to include the first record' do
        result = service.execute

        expect(result).to be_success
        expect(Ai::EventsCount.count).to eq(1)
      end
    end

    context 'when events span multiple groups' do
      let(:namespace2) { create(:namespace) }
      let(:user2) { create(:user) }
      let(:today) { timestamp.to_date }
      let(:tomorrow) { (timestamp + 1.day).to_date }

      let!(:events) do
        [
          # Group 1: namespace1, user1, code_suggestions, today (2 events to test aggregation)
          create(:ai_usage_event, namespace_id: namespace.id,
            user_id: user.id, event: 'code_suggestion_shown_in_ide', timestamp: timestamp),
          create(:ai_usage_event, namespace_id: namespace.id,
            user_id: user.id, event: 'code_suggestion_shown_in_ide', timestamp: timestamp + 1.hour),

          # Group 2: namespace1, user1, chat, today (2 events to test different event type)
          create(:ai_usage_event, namespace_id: namespace.id,
            user_id: user.id, event: 'request_duo_chat_response', timestamp: timestamp),
          create(:ai_usage_event, namespace_id: namespace.id,
            user_id: user.id, event: 'request_duo_chat_response', timestamp: timestamp + 2.hours),

          # Group 3: namespace1, user1, code_suggestions, tomorrow (different date)
          create(:ai_usage_event, namespace_id: namespace.id,
            user_id: user.id, event: 'code_suggestion_shown_in_ide', timestamp: timestamp + 1.day),

          # Group 4: namespace1, user2, code_suggestions, today (different user)
          create(:ai_usage_event, namespace_id: namespace.id,
            user_id: user2.id, event: 'code_suggestion_shown_in_ide', timestamp: timestamp),

          # Group 5: namespace2, user1, code_suggestions, today (different namespace)
          create(:ai_usage_event, namespace_id: namespace2.id,
            user_id: user.id, event: 'code_suggestion_shown_in_ide', timestamp: timestamp)
        ]
      end

      it 'creates separate aggregations for each unique combination of namespace, user, event, and date' do
        expect { service.execute }.to change { Ai::EventsCount.count }.by(5)

        counts = Ai::EventsCount.pluck(:namespace_id, :user_id, :event, :events_date, :total_occurrences)

        expect(counts).to contain_exactly(
          [namespace.id, user.id, 'code_suggestion_shown_in_ide', today, 2],
          [namespace.id, user.id, 'request_duo_chat_response', today, 2],
          [namespace.id, user.id, 'code_suggestion_shown_in_ide', tomorrow, 1],
          [namespace.id, user2.id, 'code_suggestion_shown_in_ide', today, 1],
          [namespace2.id, user.id, 'code_suggestion_shown_in_ide', today, 1]
        )
      end
    end

    context 'when MAX_ROWS_PROCESSED limit is reached' do
      before do
        stub_const("#{described_class}::MAX_ROWS_PROCESSED", 2)
        stub_const("#{described_class}::GROUPING_BATCH_SIZE", 1)
      end

      let!(:events) do
        create_list(:ai_usage_event, 3)
      end

      it 'stops processing after MAX_ROWS_PROCESSED' do
        result = service.execute

        expect(result).to be_success
        expect(result[:status]).to eq(:success)
        expect(result[:result]).to eq(:finished)
        expect(result[:last_processed_id]).to eq(2)
        expect(result[:last_processed_id]).not_to eq(events.map(&:id).max)
      end
    end

    context 'when runtime limit is exceeded' do
      before do
        allow(runtime_limiter).to receive(:over_time?).and_return(false, true)
        stub_const("#{described_class}::GROUPING_BATCH_SIZE", 1)
      end

      let!(:events) do
        create_list(:ai_usage_event, 3)
      end

      it 'interrupts processing and returns the last processed cursor' do
        result = service.execute

        expect(result).to be_success
        expect(result[:result]).to eq(:interrupted)
        expect(result[:last_processed_id]).to eq(events[0].id)
      end
    end

    context 'when exception occurs mid-processing' do
      let!(:events) { create_list(:ai_usage_event, 3) }

      before do
        stub_const("#{described_class}::GROUPING_BATCH_SIZE", 1)

        # Fail on second batch
        call_count = 0
        allow(Ai::EventsCount).to receive(:upsert_all) do
          call_count += 1
          raise StandardError, 'Upsert failed' if call_count == 2
        end
        allow(Gitlab::ErrorTracking).to receive(:log_exception)
      end

      it 'returns the last successfully processed cursor' do
        result = service.execute

        expect(result).to be_error
        expect(result.payload[:last_processed_id]).to eq(1)
        expect(Gitlab::ErrorTracking).to have_received(:log_exception)
          .with(instance_of(StandardError), last_processed_id: events[0].id, processed_rows: 1)
      end
    end

    context 'when processing multiple batches' do
      before do
        stub_const("#{described_class}::GROUPING_BATCH_SIZE", 2)
      end

      let!(:events) do
        create_list(:ai_usage_event, 4)
      end

      it 'processes all batches and updates cursor correctly' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:last_processed_id]).to eq(events.last.id)
      end
    end
  end
end
