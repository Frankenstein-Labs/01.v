# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Group::EventTypeFilter, feature_category: :audit_events do
  subject(:event_type_filter) { build(:audit_events_group_event_type_filters) }

  describe 'Associations' do
    it 'belongs to an external audit event destination' do
      expect(event_type_filter.external_streaming_destination).not_to be_nil
    end
  end

  describe 'Validations' do
    it { is_expected.to belong_to(:external_streaming_destination) }
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to validate_uniqueness_of(:audit_event_type).scoped_to(:external_streaming_destination_id) }
  end

  describe '#namespace' do
    context 'when namespace is not passed' do
      subject(:event_type_filter) { create(:audit_events_group_event_type_filters, namespace: nil) }

      it 'sets destination group' do
        expect(event_type_filter.namespace).not_to be_nil
        expect(event_type_filter.namespace).to eql(event_type_filter.external_streaming_destination.group)
      end
    end

    context 'when namespace is passed' do
      let_it_be(:namespace) { create(:group) }

      context 'when destination group is different' do
        subject(:event_type_filter) { build(:audit_events_group_event_type_filters, namespace: namespace) }

        it 'returns error' do
          expect(event_type_filter.namespace).not_to be_nil

          expect(event_type_filter).to be_invalid
          expect(event_type_filter.errors.full_messages)
            .to contain_exactly(
              'External streaming destination must belong to the group.'
            )
        end
      end

      context 'when destination group is same' do
        let_it_be(:destination) { create(:audit_events_group_external_streaming_destination, group: namespace) }

        subject(:event_type_filter) do
          build(:audit_events_group_event_type_filters, namespace: namespace,
            external_streaming_destination: destination)
        end

        it 'successfully creates filter' do
          expect(event_type_filter.namespace).not_to be_nil

          expect(event_type_filter).to be_valid
        end
      end
    end
  end

  it_behaves_like 'audit event streaming filter' do
    let(:factory_name) { "audit_events_group_event_type_filters" }
  end

  describe '#kind' do
    it 'defaults to allow' do
      filter = build(:audit_events_group_event_type_filters)

      expect(filter.kind).to eq('allow')
      expect(filter).to be_allow
    end

    it 'can be set to deny' do
      filter = build(:audit_events_group_event_type_filters, kind: :deny)

      expect(filter).to be_deny
    end
  end

  describe 'scopes' do
    let_it_be(:destination) { create(:audit_events_group_external_streaming_destination) }
    let_it_be(:allow_filter) do
      create(:audit_events_group_event_type_filters,
        external_streaming_destination: destination,
        audit_event_type: 'event_type_filters_created')
    end

    let_it_be(:deny_filter) do
      create(:audit_events_group_event_type_filters,
        external_streaming_destination: destination,
        audit_event_type: 'event_type_filters_deleted',
        kind: :deny)
    end

    describe '.allowlist' do
      it 'returns only kind: allow filters' do
        expect(described_class.allowlist).to contain_exactly(allow_filter)
      end
    end

    describe '.denylist' do
      it 'returns only kind: deny filters' do
        expect(described_class.denylist).to contain_exactly(deny_filter)
      end
    end
  end
end
