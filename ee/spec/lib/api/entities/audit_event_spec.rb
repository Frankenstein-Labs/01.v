# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::AuditEvent, feature_category: :audit_events do
  context 'when event_name exists' do
    let(:payload) do
      {
        author_id: 0,
        author_name: 'root',
        entity_id: 0,
        entity_type: 'Project',
        ip_address: '127.0.0.1',
        details: {
          event_name: 'delete_merge_request'
        }
      }
    end

    let(:audit_event) { AuditEvent.new(payload) }
    let(:entity) { described_class.new(audit_event).as_json }

    it 'returns the event_name in details' do
      expect(entity[:event_name]).to eq "delete_merge_request"
    end
  end

  context 'when event_name does not exist' do
    let(:audit_event) { create(:audit_event) }
    let(:entity) { described_class.new(audit_event).as_json }

    it 'returns nil in details' do
      expect(entity[:event_name]).to be_nil
    end
  end
end
