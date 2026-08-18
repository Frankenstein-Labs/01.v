# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Group::EventTypeFilters::Denylist::CreateService, feature_category: :audit_events do
  let_it_be(:user) { create(:user) }
  let_it_be(:destination) { create(:audit_events_group_external_streaming_destination) }
  let_it_be(:event_type_filters) { ['event_type_filters_created'] }

  subject(:response) do
    described_class.new(
      destination: destination,
      event_type_filters: event_type_filters,
      current_user: user
    ).execute
  end

  describe '#execute' do
    it 'creates a denylist filter and emits an audit event', :aggregate_failures do
      expect { response }
        .to change { destination.event_type_denylist_filters.count }.by(1)
        .and change { AuditEventReader.count }.by(1)

      filter = destination.event_type_denylist_filters.order(:id).last
      expect(filter.audit_event_type).to eq('event_type_filters_created')
      expect(filter).to be_deny
      expect(response).to be_success
    end

    it 'does not create allowlist entries' do
      expect { response }.not_to change { destination.event_type_filters.count }
    end

    context 'when the filter already exists' do
      before do
        create(:audit_events_group_event_type_filters,
          external_streaming_destination: destination,
          audit_event_type: 'event_type_filters_created',
          kind: :deny)
      end

      it 'returns a clear error and does not create a duplicate' do
        expect { response }.not_to change { destination.event_type_denylist_filters.count }
        expect(response).to be_error
        expect(response.message).to include('already on the denylist')
        expect(response.message).to include('event_type_filters_created')
      end
    end

    context 'when the same event type is already on the allowlist' do
      before do
        create(:audit_events_group_event_type_filters,
          external_streaming_destination: destination,
          audit_event_type: 'event_type_filters_created')
      end

      it 'returns a clear error explaining the allowlist conflict' do
        expect { response }.not_to change { destination.event_type_denylist_filters.count }
        expect(response).to be_error
        expect(response.message).to include('already on the allowlist')
        expect(response.message).to include('event_type_filters_created')
      end
    end
  end
end
