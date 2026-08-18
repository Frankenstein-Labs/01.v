# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/FactoryBot/AvoidCreate -- Necessary for testing database operations
RSpec.describe AuditEvents::EventFilterSyncHelper, feature_category: :audit_events do
  let(:test_class) { Class.new { include AuditEvents::EventFilterSyncHelper } }
  let(:helper) { test_class.new }

  let(:valid_audit_event_type) { 'event_type_filters_created' }
  let(:another_valid_audit_event_type) { 'member_created' }

  describe '#sync_stream_event_type_filter' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:legacy_destination) { create(:external_audit_event_destination, group: group) }
    let_it_be_with_reload(:stream_destination) do
      create(:audit_events_group_external_streaming_destination, group: group)
    end

    before do
      legacy_destination.update_column(:stream_destination_id, stream_destination.id)
      allow(helper).to receive(:should_sync_http?).and_return(true)
      allow(legacy_destination).to receive(:stream_destination).and_return(stream_destination)
    end

    it 'creates event type filter for stream destination' do
      expect do
        helper.sync_stream_event_type_filter(legacy_destination, valid_audit_event_type)
      end.to change { AuditEvents::Group::EventTypeFilter.count }.by(1)

      filter = AuditEvents::Group::EventTypeFilter.last
      expect(filter.audit_event_type).to eq(valid_audit_event_type)
      expect(filter.external_streaming_destination_id).to eq(stream_destination.id)
    end

    context 'with instance level destination' do
      let_it_be_with_reload(:instance_legacy_destination) { create(:instance_external_audit_event_destination) }
      let_it_be_with_reload(:instance_stream_destination) do
        create(:audit_events_instance_external_streaming_destination, :http)
      end

      before do
        instance_legacy_destination.update_column(:stream_destination_id, instance_stream_destination.id)
        allow(helper).to receive(:should_sync_http?).and_return(true)
        allow(instance_legacy_destination).to receive(:stream_destination).and_return(instance_stream_destination)
        allow(instance_stream_destination).to receive(:instance_level?).and_return(true)
      end

      it 'creates event type filter for instance level destination' do
        expect do
          helper.sync_stream_event_type_filter(instance_legacy_destination, valid_audit_event_type)
        end.to change { AuditEvents::Instance::EventTypeFilter.count }.by(1)

        filter = AuditEvents::Instance::EventTypeFilter.last
        expect(filter.audit_event_type).to eq(valid_audit_event_type)
        expect(filter.external_streaming_destination_id).to eq(instance_stream_destination.id)
      end
    end

    context 'when filter already exists' do
      before do
        AuditEvents::Group::EventTypeFilter.create!(
          audit_event_type: valid_audit_event_type,
          external_streaming_destination_id: stream_destination.id,
          namespace_id: group.id
        )
      end

      it 'does not create duplicate filter' do
        expect do
          helper.sync_stream_event_type_filter(legacy_destination, valid_audit_event_type)
        end.not_to change { AuditEvents::Group::EventTypeFilter.count }
      end
    end

    context 'when error occurs' do
      before do
        allow_next_instance_of(AuditEvents::Group::EventTypeFilter) do |instance|
          allow(instance).to receive(:save!).and_raise(StandardError)
        end
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'tracks the error' do
        helper.sync_stream_event_type_filter(legacy_destination, valid_audit_event_type)

        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
          an_instance_of(StandardError),
          audit_event_destination_model: legacy_destination.class.name
        )
      end
    end
  end

  describe '#sync_legacy_event_type_filter' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:legacy_destination) { create(:external_audit_event_destination, group: group) }
    let_it_be_with_reload(:stream_destination) do
      create(:audit_events_group_external_streaming_destination, group: group)
    end

    before do
      stream_destination.update_column(:legacy_destination_ref, legacy_destination.id)
      allow(stream_destination).to receive(:legacy_destination).and_return(legacy_destination)
    end

    it 'creates event type filter for legacy destination' do
      expect do
        helper.sync_legacy_event_type_filter(stream_destination, valid_audit_event_type)
      end.to change { AuditEvents::Streaming::EventTypeFilter.count }.by(1)

      filter = AuditEvents::Streaming::EventTypeFilter.last
      expect(filter.audit_event_type).to eq(valid_audit_event_type)
      expect(filter.external_audit_event_destination_id).to eq(legacy_destination.id)
    end

    context 'with instance level destination' do
      let_it_be_with_reload(:instance_legacy_destination) { create(:instance_external_audit_event_destination) }
      let_it_be_with_reload(:instance_stream_destination) do
        create(:audit_events_instance_external_streaming_destination, :http)
      end

      before do
        instance_stream_destination.update_column(:legacy_destination_ref, instance_legacy_destination.id)
        allow(stream_destination).to receive(:legacy_destination).and_return(instance_legacy_destination)
        allow(instance_legacy_destination).to receive(:instance_level?).and_return(true)
      end

      it 'creates instance level event type filter with correct foreign key' do
        expect do
          helper.sync_legacy_event_type_filter(stream_destination, valid_audit_event_type)
        end.to change { AuditEvents::Streaming::InstanceEventTypeFilter.count }.by(1)

        filter = AuditEvents::Streaming::InstanceEventTypeFilter.last
        expect(filter.audit_event_type).to eq(valid_audit_event_type)
        expect(filter.instance_external_audit_event_destination_id).to eq(instance_legacy_destination.id)
      end
    end

    context 'when error occurs' do
      before do
        allow_next_instance_of(AuditEvents::Streaming::EventTypeFilter) do |instance|
          allow(instance).to receive(:save!).and_raise(StandardError)
        end
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'tracks the error' do
        helper.sync_legacy_event_type_filter(stream_destination, valid_audit_event_type)

        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
          an_instance_of(StandardError),
          audit_event_destination_model: stream_destination.class.name
        )
      end
    end
  end

  describe '#sync_delete_stream_event_type_filter' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:legacy_destination) { create(:external_audit_event_destination, group: group) }
    let_it_be_with_reload(:stream_destination) do
      create(:audit_events_group_external_streaming_destination, group: group)
    end

    before do
      legacy_destination.update_column(:stream_destination_id, stream_destination.id)
      allow(helper).to receive(:should_sync_http?).and_return(true)
      allow(legacy_destination).to receive(:stream_destination).and_return(stream_destination)
    end

    context 'with filters to delete' do
      before do
        AuditEvents::Group::EventTypeFilter.create!(
          audit_event_type: valid_audit_event_type,
          external_streaming_destination_id: stream_destination.id,
          namespace_id: group.id
        )

        AuditEvents::Group::EventTypeFilter.create!(
          audit_event_type: another_valid_audit_event_type,
          external_streaming_destination_id: stream_destination.id,
          namespace_id: group.id
        )
      end

      it 'deletes specific filter types' do
        expect do
          helper.sync_delete_stream_event_type_filter(legacy_destination, [valid_audit_event_type])
        end.to change { AuditEvents::Group::EventTypeFilter.count }.by(-1)

        expect(AuditEvents::Group::EventTypeFilter.exists?(audit_event_type: valid_audit_event_type)).to be_falsey
        expect(AuditEvents::Group::EventTypeFilter.exists?(audit_event_type: another_valid_audit_event_type))
          .to be_truthy
      end

      it 'deletes multiple filter types' do
        expect do
          helper.sync_delete_stream_event_type_filter(
            legacy_destination,
            [valid_audit_event_type, another_valid_audit_event_type]
          )
        end.to change { AuditEvents::Group::EventTypeFilter.count }.by(-2)

        expect(AuditEvents::Group::EventTypeFilter.exists?(audit_event_type: valid_audit_event_type)).to be_falsey
        expect(AuditEvents::Group::EventTypeFilter.exists?(audit_event_type: another_valid_audit_event_type))
          .to be_falsey
      end
    end

    context 'when no specific audit_event_types are provided' do
      before do
        AuditEvents::Group::EventTypeFilter.create!(
          audit_event_type: valid_audit_event_type,
          external_streaming_destination_id: stream_destination.id,
          namespace_id: group.id
        )

        AuditEvents::Group::EventTypeFilter.create!(
          audit_event_type: another_valid_audit_event_type,
          external_streaming_destination_id: stream_destination.id,
          namespace_id: group.id
        )
      end

      it 'deletes all event type filters for the stream destination' do
        expect do
          helper.sync_delete_stream_event_type_filter(legacy_destination, nil)
        end.to change { AuditEvents::Group::EventTypeFilter.count }.by(-2)

        expect(AuditEvents::Group::EventTypeFilter.exists?(external_streaming_destination_id: stream_destination.id))
          .to be_falsey
      end
    end

    context 'when error occurs' do
      before do
        allow(AuditEvents::Group::EventTypeFilter).to receive(:where).and_raise(StandardError.new("Test error"))
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'tracks the error' do
        helper.sync_delete_stream_event_type_filter(legacy_destination, [valid_audit_event_type])

        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
          an_instance_of(StandardError),
          audit_event_destination_model: legacy_destination.class.name
        )
      end
    end
  end

  describe '#sync_delete_legacy_event_type_filter' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:legacy_destination) { create(:external_audit_event_destination, group: group) }
    let_it_be_with_reload(:stream_destination) do
      create(:audit_events_group_external_streaming_destination, group: group)
    end

    before do
      stream_destination.update_column(:legacy_destination_ref, legacy_destination.id)
      allow(stream_destination).to receive(:legacy_destination).and_return(legacy_destination)
    end

    context 'with filters to delete' do
      before do
        AuditEvents::Streaming::EventTypeFilter.create!(
          audit_event_type: valid_audit_event_type,
          external_audit_event_destination_id: legacy_destination.id
        )

        AuditEvents::Streaming::EventTypeFilter.create!(
          audit_event_type: another_valid_audit_event_type,
          external_audit_event_destination_id: legacy_destination.id
        )
      end

      it 'deletes specific filter types' do
        expect do
          helper.sync_delete_legacy_event_type_filter(stream_destination, [valid_audit_event_type])
        end.to change { AuditEvents::Streaming::EventTypeFilter.count }.by(-1)

        expect(AuditEvents::Streaming::EventTypeFilter.exists?(audit_event_type: valid_audit_event_type)).to be_falsey
        expect(AuditEvents::Streaming::EventTypeFilter.exists?(audit_event_type: another_valid_audit_event_type))
          .to be_truthy
      end

      it 'deletes multiple filter types' do
        expect do
          helper.sync_delete_legacy_event_type_filter(
            stream_destination,
            [valid_audit_event_type, another_valid_audit_event_type]
          )
        end.to change { AuditEvents::Streaming::EventTypeFilter.count }.by(-2)

        expect(AuditEvents::Streaming::EventTypeFilter.exists?(audit_event_type: valid_audit_event_type)).to be_falsey
        expect(AuditEvents::Streaming::EventTypeFilter.exists?(audit_event_type: another_valid_audit_event_type))
          .to be_falsey
      end
    end

    context 'when no specific audit_event_types are provided' do
      before do
        AuditEvents::Streaming::EventTypeFilter.create!(
          audit_event_type: valid_audit_event_type,
          external_audit_event_destination_id: legacy_destination.id
        )

        AuditEvents::Streaming::EventTypeFilter.create!(
          audit_event_type: another_valid_audit_event_type,
          external_audit_event_destination_id: legacy_destination.id
        )
      end

      it 'deletes all event type filters for the legacy destination' do
        expect do
          helper.sync_delete_legacy_event_type_filter(stream_destination, nil)
        end.to change { AuditEvents::Streaming::EventTypeFilter.count }.by(-2)

        expect(
          AuditEvents::Streaming::EventTypeFilter.exists?(external_audit_event_destination_id: legacy_destination.id)
        ).to be_falsey
      end
    end

    context 'with instance level destination' do
      let_it_be_with_reload(:instance_legacy_destination) { create(:instance_external_audit_event_destination) }
      let_it_be_with_reload(:instance_stream_destination) do
        create(:audit_events_instance_external_streaming_destination, :http)
      end

      before do
        instance_stream_destination.update_column(:legacy_destination_ref, instance_legacy_destination.id)
        allow(stream_destination).to receive(:legacy_destination).and_return(instance_legacy_destination)
        allow(instance_legacy_destination).to receive(:instance_level?).and_return(true)

        AuditEvents::Streaming::InstanceEventTypeFilter.create!(
          audit_event_type: valid_audit_event_type,
          instance_external_audit_event_destination_id: instance_legacy_destination.id
        )

        AuditEvents::Streaming::InstanceEventTypeFilter.create!(
          audit_event_type: another_valid_audit_event_type,
          instance_external_audit_event_destination_id: instance_legacy_destination.id
        )
      end

      it 'deletes specific instance-level filter types' do
        expect do
          helper.sync_delete_legacy_event_type_filter(stream_destination, [valid_audit_event_type])
        end.to change { AuditEvents::Streaming::InstanceEventTypeFilter.count }.by(-1)

        expect(AuditEvents::Streaming::InstanceEventTypeFilter.exists?(audit_event_type: valid_audit_event_type))
          .to be_falsey
        expect(
          AuditEvents::Streaming::InstanceEventTypeFilter.exists?(audit_event_type: another_valid_audit_event_type)
        ).to be_truthy
      end

      it 'deletes all instance-level filters when no types specified' do
        expect do
          helper.sync_delete_legacy_event_type_filter(stream_destination, nil)
        end.to change { AuditEvents::Streaming::InstanceEventTypeFilter.count }.by(-2)

        expect(AuditEvents::Streaming::InstanceEventTypeFilter.exists?(
          instance_external_audit_event_destination_id: instance_legacy_destination.id
        )).to be_falsey
      end
    end

    context 'when error occurs' do
      before do
        allow(AuditEvents::Streaming::EventTypeFilter).to receive(:where).and_raise(StandardError.new("Test error"))
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'tracks the error' do
        helper.sync_delete_legacy_event_type_filter(stream_destination, [valid_audit_event_type])

        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
          an_instance_of(StandardError),
          audit_event_destination_model: stream_destination.class.name
        )
      end
    end
  end

  describe '#audit_event_namespace' do
    it 'returns correct namespace for instance level destination' do
      destination = instance_double(AuditEvents::Instance::ExternalStreamingDestination, instance_level?: true)
      expect(helper.send(:audit_event_namespace, destination)).to eq('AuditEvents::Instance')
    end

    it 'returns correct namespace for group level destination' do
      destination = instance_double(AuditEvents::Group::ExternalStreamingDestination, instance_level?: false)
      expect(helper.send(:audit_event_namespace, destination)).to eq('AuditEvents::Group')
    end
  end
end
# rubocop:enable RSpec/FactoryBot/AvoidCreate
