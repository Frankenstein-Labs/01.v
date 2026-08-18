# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Group::ExternalStreamingDestination, feature_category: :audit_events do
  subject(:destination) { build(:audit_events_group_external_streaming_destination) }

  describe 'Associations' do
    it 'belongs to a group' do
      expect(destination.group).not_to be_nil
    end

    it { is_expected.to have_many(:event_type_filters) }
    it { is_expected.to have_many(:namespace_filters).class_name('AuditEvents::Group::NamespaceFilter') }
  end

  describe 'Validations' do
    let_it_be(:group) { create(:group) }

    it 'validates uniqueness of name scoped to category, and group_id' do
      create(:audit_events_group_external_streaming_destination, name: 'Test Destination', group: group)
      destination = build(:audit_events_group_external_streaming_destination, name: 'Test Destination', group: group)

      expect(destination).not_to be_valid
      expect(destination.errors.full_messages).to include('Name has already been taken')

      group2 = create(:group)
      destination2 = build(:audit_events_group_external_streaming_destination, name: 'Test Destination', group: group2)

      expect(destination2).to be_valid
    end

    it 'allows duplicate name in different categories' do
      create(:audit_events_group_external_streaming_destination, name: 'Test Destination', group: group)
      aws_destination = create(:audit_events_group_external_streaming_destination, :aws,
        name: 'Test Destination', group: group)
      gcp_destination = create(:audit_events_group_external_streaming_destination, :gcp,
        name: 'Test Destination', group: group)

      expect(aws_destination).to be_valid
      expect(gcp_destination).to be_valid
    end

    describe '#no_more_than_5_namespace_filters?' do
      it 'can have 5 namespace filters' do
        5.times do
          create(:audit_events_streaming_group_namespace_filters, external_streaming_destination: destination,
            namespace: create(:group, parent: destination.group))
        end

        expect(destination).to be_valid
      end

      it 'cannot have more than 5 namespace filters' do
        6.times do
          create(:audit_events_streaming_group_namespace_filters, external_streaming_destination: destination,
            namespace: create(:group, parent: destination.group))
        end

        expect(destination).not_to be_valid
        expect(destination.errors.full_messages)
          .to contain_exactly(_('Namespace filters are limited to 5 per destination'))
      end
    end

    context 'when group' do
      it 'is a subgroup' do
        destination.group = build(:group, :nested)

        expect(destination).to be_invalid
        expect(destination.errors.full_messages).to include('Group must not be a subgroup. Use a top-level group.')
      end
    end

    context 'for uniqueness of config url for http destinations' do
      let_it_be(:destination1) { create(:audit_events_group_external_streaming_destination) }

      it 'returns error if destination with same url exists' do
        destination2 = build(:audit_events_group_external_streaming_destination, group: destination1.group,
          config: destination1.config)

        expect(destination2).to be_invalid
        expect(destination2.errors.full_messages)
          .to include('Config url already taken.')
      end
    end
  end

  it_behaves_like 'includes Limitable concern' do
    subject { build(:audit_events_group_external_streaming_destination) }
  end

  it_behaves_like 'includes ExternallyStreamable concern', :audit_events_group_external_streaming_destination do
    subject { build(:audit_events_group_external_streaming_destination) }

    let(:model_factory_name) { :audit_events_group_external_streaming_destination }
  end

  it_behaves_like 'includes LegacyDestinationMappable concern',
    :audit_events_group_external_streaming_destination,
    described_class

  it_behaves_like 'includes Activatable concern' do
    let(:model_factory_name) { :audit_events_group_external_streaming_destination }
  end

  describe 'denylist event type filtering' do
    let_it_be(:group) { create(:group) }
    let_it_be(:destination) { create(:audit_events_group_external_streaming_destination, group: group) }
    let_it_be(:audit_event) { create(:audit_events_group_audit_event, group_id: group.id) }

    before_all do
      create(:audit_events_group_event_type_filters,
        external_streaming_destination: destination,
        audit_event_type: 'event_type_filters_deleted',
        kind: :deny)
    end

    it 'blocks the denylisted event' do
      expect(destination.allowed_to_stream?('event_type_filters_deleted', audit_event)).to be false
    end

    it 'still streams events that are not denylisted' do
      create(:audit_events_group_event_type_filters,
        external_streaming_destination: destination,
        audit_event_type: 'event_type_filters_created')

      expect(destination.allowed_to_stream?('event_type_filters_created', audit_event)).to be true
    end

    it 'short-circuits before checking whether the event is in the allowlist' do
      create(:audit_events_group_event_type_filters,
        external_streaming_destination: destination,
        audit_event_type: 'event_type_filters_created')

      # Even with an allowlist present, a denylist hit takes priority.
      expect(destination.allowed_to_stream?('event_type_filters_deleted', audit_event)).to be false
    end
  end

  describe ".configs_of_parent" do
    let!(:http_destinations) do
      create_list(:audit_events_group_external_streaming_destination, 3, group: destination.group)
    end

    let!(:other_group_destination) { create(:audit_events_group_external_streaming_destination) }
    let!(:non_http_destination) do
      create(:audit_events_group_external_streaming_destination, :aws, group: destination.group)
    end

    it 'returns configs of other destinations of same category for same group' do
      configs = destination.group.external_audit_event_streaming_destinations.configs_of_parent(destination.id, 'http')

      expect(configs.length).to eq(http_destinations.length)
      expect(configs).to match_array(http_destinations.pluck(:config))
      expect(configs).to exclude(other_group_destination.config)
      expect(configs).to exclude(non_http_destination.config)
    end
  end
end
