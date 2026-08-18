# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::AuditEvents::Streaming::EventTypeFilters::Destroy, feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:event_type_filter, freeze: false) do
    create(:audit_events_streaming_event_type_filter, audit_event_type: 'event_type_filters_created')
  end

  let(:destination) { event_type_filter.external_audit_event_destination }
  let(:group) { destination.group }
  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }
  let(:params) do
    {
      destination_id: destination.to_gid,
      event_type_filters: %w[event_type_filters_created]
    }
  end

  subject { mutation.resolve(**params) }

  describe '#resolve' do
    context 'when feature is unlicensed' do
      before do
        stub_licensed_features(external_audit_events: false)
      end

      it 'when user is not authorized' do
        expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when feature is licensed' do
      before do
        stub_licensed_features(external_audit_events: true)
      end

      context 'when current_user is not group owner' do
        it 'returns useful error messages' do
          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable, 'The resource that you '\
                 'are attempting to access does not exist or you don\'t have permission to perform this action')
        end
      end

      context 'when current_user is group owner' do
        before do
          group.add_owner(current_user)
        end

        context 'when event type filter is present' do
          it 'deletes the event type filter', :aggregate_failures do
            expect { subject }.to change { destination.event_type_filters.count }.by(-1)
            expect(subject).to eq({ errors: [] })
          end

          it 'creates an audit event' do
            expect { subject }.to change { AuditEventReader.count }.by(1)

            audit_event = AuditEventReader.last
            expect(audit_event.author).to eq(current_user)
            expect(audit_event.details[:custom_message]).to include('Deleted audit event type filter(s)')
          end
        end

        context 'when deleting multiple event type filters' do
          let(:second_filter) do
            create(:audit_events_streaming_event_type_filter,
              audit_event_type: 'member_created',
              external_audit_event_destination: destination)
          end

          let(:params) do
            {
              destination_id: destination.to_gid,
              event_type_filters: %w[event_type_filters_created member_created]
            }
          end

          before do
            second_filter
          end

          it 'deletes all specified filters', :aggregate_failures do
            expect { subject }.to change { destination.event_type_filters.count }.by(-2)
            expect(subject).to eq({ errors: [] })
            expect(destination.event_type_filters.pluck(:audit_event_type)).to be_empty
          end
        end

        context 'when event type filter is not already present' do
          let(:params) do
            {
              destination_id: destination.to_gid,
              event_type_filters: %w[event_type_filters_deleted]
            }
          end

          it 'does not delete event type filter', :aggregate_failures do
            expect { subject }.not_to change { destination.event_type_filters.count }
            expect(subject)
              .to eq(
                {
                  errors: [
                    "Couldn't find event type filters where audit event type(s): event_type_filters_deleted"
                  ]
                }
              )
          end
        end

        context 'with sync to streaming destination' do
          let(:stream_destination) do
            create(:audit_events_group_external_streaming_destination, group: group)
          end

          before do
            destination.update!(stream_destination: stream_destination)
            create(:audit_events_group_event_type_filters,
              audit_event_type: 'event_type_filters_created',
              external_streaming_destination: stream_destination,
              namespace: group)
          end

          context 'when sync is enabled' do
            it 'deletes filter from both destinations', :aggregate_failures do
              expect { subject }.to change { destination.event_type_filters.count }.by(-1)
                                .and change { stream_destination.event_type_filters.count }.by(-1)

              expect(subject).to eq({ errors: [] })
            end
          end
        end
      end
    end
  end
end
