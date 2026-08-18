# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Streaming::EventTypeFilters::CreateService, feature_category: :audit_events do
  let_it_be(:destination) { create(:external_audit_event_destination) }
  let_it_be(:event_type_filters) { ['event_type_filters_deleted'] }
  let_it_be(:user) { create(:user) }

  let(:expected_error) { [] }

  subject(:response) do
    described_class.new(
      destination: destination,
      event_type_filters: event_type_filters,
      current_user: user
    ).execute
  end

  describe '#execute' do
    context 'when event type filter is not already present' do
      shared_examples 'creates event filter' do
        it 'creates event type filter', :aggregate_failures do
          expect { subject }.to change { destination.event_type_filters.count }.by 1

          expect(destination.event_type_filters.last.audit_event_type).to eq(event_type_filters.first)
          expect(response).to be_success
          expect(response.errors).to match_array(expected_error)
        end

        it 'creates audit event', :aggregate_failures do
          audit_context = {
            name: 'event_type_filters_created',
            author: user,
            scope: scope,
            target: destination,
            message: "Created audit event type filter(s): event_type_filters_deleted"
          }

          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)
                                                             .and_call_original

          expect { subject }.to change { AuditEventReader.count }.by(1)
        end
      end

      context 'when destination is group level destination' do
        it_behaves_like 'creates event filter' do
          let(:scope) { destination.group }
        end
      end

      context 'when destination is instance level destination' do
        let_it_be(:destination) { create(:instance_external_audit_event_destination) }

        it_behaves_like 'creates event filter' do
          let(:scope) { be_an_instance_of(Gitlab::Audit::InstanceScope) }
        end
      end
    end

    context 'when record is invalid' do
      let(:expected_error) { 'Validation Failed' }

      before do
        expect_next_instance_of(::AuditEvents::Streaming::EventTypeFilter) do |filter|
          allow(filter).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(filter), expected_error)
        end
      end

      it 'returns error message', :aggregate_failures do
        expect { subject }.not_to change { destination.event_type_filters.count }
        expect(response.errors).to match_array([expected_error])
      end

      it 'does not create audit event' do
        expect { subject }.not_to change { AuditEventReader.count }
      end
    end

    describe 'syncing event type filters' do
      let(:service_instance) do
        described_class.new(
          destination: destination,
          event_type_filters: event_type_filters,
          current_user: user
        )
      end

      before do
        allow(service_instance).to receive(:create_event_type_filters!)
        allow(service_instance).to receive(:log_audit_event)
      end

      shared_examples 'syncs to streaming destination' do
        context 'when stream destination is present and sync is enabled' do
          let(:stream_destination) { create(:audit_events_group_external_streaming_destination) }

          before do
            allow(destination).to receive(:stream_destination).and_return(stream_destination)
          end

          it 'syncs each event type filter to streaming destination' do
            event_type_filters.each do |filter|
              expect(service_instance).to receive(:sync_stream_event_type_filter)
                .with(destination, filter)
            end

            service_instance.execute
          end
        end

        context 'when stream destination is not present' do
          before do
            allow(destination).to receive(:stream_destination).and_return(nil)
          end

          it 'does not sync to streaming destination' do
            expect(service_instance).not_to receive(:sync_stream_event_type_filter)

            service_instance.execute
          end
        end
      end

      shared_examples 'syncs to legacy destination' do
        context 'when legacy destination ref is present and sync is enabled' do
          let(:legacy_destination) { create(:external_audit_event_destination) }

          before do
            allow(destination).to receive(:legacy_destination_ref).and_return(legacy_destination)
          end

          it 'syncs each event type filter to legacy destination' do
            event_type_filters.each do |filter|
              expect(service_instance).to receive(:sync_legacy_event_type_filter)
                .with(destination, filter)
            end

            service_instance.execute
          end
        end

        context 'when legacy destination ref is not present' do
          before do
            allow(destination).to receive(:legacy_destination_ref).and_return(nil)
          end

          it 'does not sync to legacy destination' do
            expect(service_instance).not_to receive(:sync_legacy_event_type_filter)

            service_instance.execute
          end
        end
      end

      context 'when destination is ExternalAuditEventDestination' do
        let_it_be(:destination) { create(:external_audit_event_destination) }

        it_behaves_like 'syncs to streaming destination'

        it 'does not attempt to sync to legacy destination' do
          expect(service_instance).not_to receive(:sync_legacy_event_type_filter)

          service_instance.execute
        end
      end

      context 'when destination is InstanceExternalAuditEventDestination' do
        let_it_be(:destination) { create(:instance_external_audit_event_destination) }

        it_behaves_like 'syncs to streaming destination'

        it 'does not attempt to sync to legacy destination' do
          expect(service_instance).not_to receive(:sync_legacy_event_type_filter)

          service_instance.execute
        end
      end

      context 'when destination is Group::ExternalStreamingDestination' do
        let(:group) { create(:group) }
        let(:destination) { create(:audit_events_group_external_streaming_destination, group: group) }

        it_behaves_like 'syncs to legacy destination'

        it 'does not attempt to sync to streaming destination' do
          expect(service_instance).not_to receive(:sync_stream_event_type_filter)

          service_instance.execute
        end
      end

      context 'when destination is Instance::ExternalStreamingDestination' do
        let(:destination) { create(:audit_events_instance_external_streaming_destination) }

        it_behaves_like 'syncs to legacy destination'

        it 'does not attempt to sync to streaming destination' do
          expect(service_instance).not_to receive(:sync_stream_event_type_filter)

          service_instance.execute
        end
      end

      context 'with multiple event type filters' do
        let(:event_type_filters) { %w[repository_push_event merge_request_created user_created] }
        let(:stream_destination) { create(:audit_events_group_external_streaming_destination) }

        before do
          allow(destination).to receive(:stream_destination).and_return(stream_destination)
        end

        it 'syncs all filters in order' do
          event_type_filters.each_with_index do |filter, _index|
            expect(service_instance).to receive(:sync_stream_event_type_filter)
              .with(destination, filter)
              .ordered
          end

          service_instance.execute
        end
      end

      context 'when sync raises an error' do
        let(:stream_destination) { create(:audit_events_group_external_streaming_destination) }

        before do
          allow(destination).to receive(:stream_destination).and_return(stream_destination)

          allow(service_instance).to receive(:sync_stream_event_type_filter)
            .and_raise(StandardError, 'Sync failed')
        end

        it 'does not rescue the error' do
          expect { service_instance.execute }.to raise_error(StandardError, 'Sync failed')
        end
      end
    end
  end

  describe '#should_sync_to_streaming?' do
    let(:service_instance) do
      described_class.new(
        destination: destination,
        event_type_filters: event_type_filters,
        current_user: user
      )
    end

    context 'when destination has stream_destination' do
      let(:stream_destination) { create(:audit_events_group_external_streaming_destination) }

      before do
        allow(destination).to receive(:stream_destination).and_return(stream_destination)
      end

      context 'when legacy destination sync is enabled' do
        it 'returns true' do
          expect(service_instance.send(:should_sync_to_streaming?)).to be true
        end
      end
    end

    context 'when destination does not have stream_destination' do
      before do
        allow(destination).to receive(:stream_destination).and_return(nil)
      end

      it 'returns false' do
        expect(service_instance.send(:should_sync_to_streaming?)).to be false
      end
    end
  end

  describe '#should_sync_to_legacy?' do
    let(:group) { create(:group) }
    let(:destination) { create(:audit_events_group_external_streaming_destination, group: group) }
    let(:service_instance) do
      described_class.new(
        destination: destination,
        event_type_filters: event_type_filters,
        current_user: user
      )
    end

    context 'when destination has legacy_destination_ref' do
      let(:legacy_destination) { create(:external_audit_event_destination) }

      before do
        allow(destination).to receive(:legacy_destination_ref).and_return(legacy_destination)
      end

      context 'when stream destination sync is enabled' do
        it 'returns true' do
          expect(service_instance.send(:should_sync_to_legacy?)).to be true
        end
      end
    end

    context 'when destination does not have legacy_destination_ref' do
      before do
        allow(destination).to receive(:legacy_destination_ref).and_return(nil)
      end

      it 'returns false' do
        expect(service_instance.send(:should_sync_to_legacy?)).to be false
      end
    end
  end
end
