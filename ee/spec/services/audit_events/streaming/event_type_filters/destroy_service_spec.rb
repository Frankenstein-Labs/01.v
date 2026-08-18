# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Streaming::EventTypeFilters::DestroyService, feature_category: :audit_events do
  let_it_be(:destination) { create(:external_audit_event_destination) }
  let_it_be(:user) { create(:user) }

  before do
    allow(Gitlab::Audit::Type::Definition).to receive(:defined?).and_return(true)
  end

  subject(:response) do
    described_class.new(destination: destination, event_type_filters: event_type_filters, current_user: user).execute
  end

  describe '#execute' do
    context 'when event type filter is not already present' do
      let(:expected_error) { ["Couldn't find event type filters where audit event type(s): filter_2"] }
      let(:event_type_filters) { ['filter_2'] }

      it 'does not delete event type filter', :aggregate_failures do
        expect { subject }.not_to change { destination.event_type_filters.count }
        expect(response.errors).to match_array(expected_error)
      end

      it 'does not create audit event' do
        expect { subject }.not_to change { AuditEventReader.count }
      end
    end

    context 'when event type filter is already present' do
      shared_examples 'destroys event type filter' do
        let(:expected_error) { [] }
        let(:event_type_filters) { [event_type_filter.audit_event_type] }

        it 'deletes event type filter', :aggregate_failures do
          expect { subject }.to change { destination.event_type_filters.count }.by(-1)
          expect(response).to be_success
          expect(response.errors).to match_array(expected_error)
        end

        it 'creates audit event', :aggregate_failures do
          audit_context = {
            name: 'event_type_filters_deleted',
            author: user,
            scope: scope,
            target: destination,
            message: "Deleted audit event type filter(s): #{event_type_filter.audit_event_type}"
          }

          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)
                                                             .and_call_original

          expect { subject }.to change { AuditEventReader.count }.by(1)
        end
      end

      context 'when destination is group level destination' do
        let_it_be(:event_type_filter) do
          create(
            :audit_events_streaming_event_type_filter,
            external_audit_event_destination: destination
          )
        end

        it_behaves_like 'destroys event type filter' do
          let(:scope) { destination.group }
        end
      end

      context 'when destination is instance level destination' do
        let_it_be(:destination) { create(:instance_external_audit_event_destination) }
        let_it_be(:event_type_filter) do
          create(
            :audit_events_streaming_instance_event_type_filter,
            instance_external_audit_event_destination: destination
          )
        end

        it_behaves_like 'destroys event type filter' do
          let(:scope) { be_an_instance_of(Gitlab::Audit::InstanceScope) }
        end
      end
    end

    describe 'syncing event type filter deletions' do
      let(:service_instance) do
        described_class.new(
          destination: destination,
          event_type_filters: event_type_filters,
          current_user: user
        )
      end

      let(:event_type_filters) { %w[repository_push_event merge_request_created] }

      before do
        case destination
        when AuditEvents::InstanceExternalAuditEventDestination
          event_type_filters.each do |filter_type|
            create(:audit_events_streaming_instance_event_type_filter,
              instance_external_audit_event_destination: destination,
              audit_event_type: filter_type)
          end
        when AuditEvents::Group::ExternalStreamingDestination
          event_type_filters.each do |filter_type|
            create(:audit_events_group_event_type_filters,
              external_streaming_destination: destination,
              audit_event_type: filter_type)
          end
        when AuditEvents::Instance::ExternalStreamingDestination
          event_type_filters.each do |filter_type|
            create(:audit_events_instance_event_type_filters,
              external_streaming_destination: destination,
              audit_event_type: filter_type)
          end
        else
          event_type_filters.each do |filter_type|
            create(:audit_events_streaming_event_type_filter,
              external_audit_event_destination: destination,
              audit_event_type: filter_type)
          end
        end

        allow(service_instance).to receive(:log_audit_event)
      end

      shared_examples 'syncs deletions to streaming destination' do
        context 'when stream destination id is present and sync is enabled' do
          let(:stream_destination) { create(:audit_events_group_external_streaming_destination) }

          before do
            allow(destination).to receive(:stream_destination_id).and_return(stream_destination.id)
          end

          it 'syncs deleted filters to streaming destination' do
            expect(service_instance).to receive(:sync_delete_stream_event_type_filter) do |dest, filters|
              expect(dest).to eq(destination)
              expect(filters).to match_array(event_type_filters)
            end

            service_instance.execute
          end
        end

        context 'when stream destination id is not present' do
          before do
            allow(destination).to receive(:stream_destination_id).and_return(nil)
          end

          it 'does not sync to streaming destination' do
            expect(service_instance).not_to receive(:sync_delete_stream_event_type_filter)

            service_instance.execute
          end
        end

        context 'when no filters are deleted' do
          let(:event_type_filters) { ['non_existent_filter'] }

          it 'does not attempt to sync' do
            expect(service_instance).not_to receive(:sync_delete_stream_event_type_filter)
            expect(service_instance).not_to receive(:sync_delete_legacy_event_type_filter)

            service_instance.execute
          end
        end
      end

      shared_examples 'syncs deletions to legacy destination' do
        context 'when legacy destination ref is present and sync is enabled' do
          let(:legacy_destination) { create(:external_audit_event_destination) }

          before do
            allow(destination).to receive(:legacy_destination_ref).and_return(legacy_destination)
          end

          it 'syncs deleted filters to legacy destination' do
            expect(service_instance).to receive(:sync_delete_legacy_event_type_filter) do |dest, filters|
              expect(dest).to eq(destination)
              expect(filters).to match_array(event_type_filters)
            end

            service_instance.execute
          end
        end

        context 'when legacy destination ref is not present' do
          before do
            allow(destination).to receive(:legacy_destination_ref).and_return(nil)
          end

          it 'does not sync to legacy destination' do
            expect(service_instance).not_to receive(:sync_delete_legacy_event_type_filter)

            service_instance.execute
          end
        end
      end

      context 'when destination is ExternalAuditEventDestination' do
        let_it_be(:destination) { create(:external_audit_event_destination) }

        it_behaves_like 'syncs deletions to streaming destination'

        it 'does not attempt to sync to legacy destination' do
          expect(service_instance).not_to receive(:sync_delete_legacy_event_type_filter)

          service_instance.execute
        end
      end

      context 'when destination is InstanceExternalAuditEventDestination' do
        let_it_be(:destination) { create(:instance_external_audit_event_destination) }

        it_behaves_like 'syncs deletions to streaming destination'

        it 'does not attempt to sync to legacy destination' do
          expect(service_instance).not_to receive(:sync_delete_legacy_event_type_filter)

          service_instance.execute
        end
      end

      context 'when destination is Group::ExternalStreamingDestination' do
        let(:group) { create(:group) }
        let(:destination) { create(:audit_events_group_external_streaming_destination, group: group) }

        it_behaves_like 'syncs deletions to legacy destination'

        it 'does not attempt to sync to streaming destination' do
          expect(service_instance).not_to receive(:sync_delete_stream_event_type_filter)

          service_instance.execute
        end
      end

      context 'when destination is Instance::ExternalStreamingDestination' do
        let(:destination) { create(:audit_events_instance_external_streaming_destination) }

        it_behaves_like 'syncs deletions to legacy destination'

        it 'does not attempt to sync to streaming destination' do
          expect(service_instance).not_to receive(:sync_delete_stream_event_type_filter)

          service_instance.execute
        end
      end

      context 'with multiple event type filters' do
        let(:event_type_filters) { %w[repository_push_event merge_request_created user_created project_deleted] }
        let(:stream_destination) { create(:audit_events_group_external_streaming_destination) }

        before do
          allow(destination).to receive(:stream_destination_id).and_return(stream_destination.id)
        end

        it 'syncs all deleted filters at once' do
          expect(service_instance).to receive(:sync_delete_stream_event_type_filter) do |dest, filters|
            expect(dest).to eq(destination)
            expect(filters).to match_array(event_type_filters)
          end.once

          service_instance.execute
        end
      end

      context 'when sync raises an error' do
        let(:stream_destination) { create(:audit_events_group_external_streaming_destination) }

        before do
          allow(destination).to receive(:stream_destination_id).and_return(stream_destination.id)
          allow(service_instance).to receive(:sync_delete_stream_event_type_filter)
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
        event_type_filters: ['test_filter'],
        current_user: user
      )
    end

    context 'when destination has stream_destination_id' do
      let(:stream_destination) { create(:audit_events_group_external_streaming_destination) }

      before do
        allow(destination).to receive(:stream_destination_id).and_return(stream_destination.id)
      end

      context 'when legacy destination sync is enabled' do
        it 'returns true' do
          expect(service_instance.send(:should_sync_to_streaming?)).to be true
        end
      end

      context 'when destination is not instance level' do
        before do
          allow(destination).to receive(:instance_level?).and_return(false)
        end

        it 'passes false as instance flag' do
          expect(service_instance.send(:should_sync_to_streaming?)).to be true
        end
      end

      context 'when destination is instance level' do
        before do
          allow(destination).to receive(:instance_level?).and_return(true)
        end

        it 'passes true as instance flag' do
          expect(service_instance.send(:should_sync_to_streaming?)).to be true
        end
      end
    end

    context 'when destination does not have stream_destination_id' do
      before do
        allow(destination).to receive(:stream_destination_id).and_return(nil)
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
        event_type_filters: ['test_filter'],
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
