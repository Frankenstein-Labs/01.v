# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Instance::EventTypeFilter, feature_category: :audit_events do
  subject(:event_type_filter) { build(:audit_events_instance_event_type_filters) }

  describe 'Associations' do
    it 'belongs to an external audit event destination' do
      expect(event_type_filter.external_streaming_destination).not_to be_nil
    end
  end

  describe 'Validations' do
    it { is_expected.to belong_to(:external_streaming_destination) }
    it { is_expected.to validate_uniqueness_of(:audit_event_type).scoped_to(:external_streaming_destination_id) }
  end

  it_behaves_like 'audit event streaming filter' do
    let(:factory_name) { "audit_events_instance_event_type_filters" }
  end
end
