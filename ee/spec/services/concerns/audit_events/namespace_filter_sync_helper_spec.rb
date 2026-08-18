# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need to create models for syncing
RSpec.describe AuditEvents::NamespaceFilterSyncHelper, feature_category: :audit_events do
  let(:test_class) { Class.new { include AuditEvents::NamespaceFilterSyncHelper } }
  let(:helper) { test_class.new }

  describe '#sync_stream_namespace_filter' do
    let_it_be(:group) { create(:group) }

    context 'with HTTP destination' do
      let_it_be_with_reload(:legacy_destination) { create(:external_audit_event_destination, group: group) }
      let_it_be_with_reload(:stream_destination) do
        create(:audit_events_group_external_streaming_destination, group: group)
      end

      before do
        legacy_destination.update_column(:stream_destination_id, stream_destination.id)
        allow(legacy_destination).to receive_messages(http?: true, stream_destination: stream_destination)
        allow(helper).to receive(:should_sync_http?).with(legacy_destination).and_return(true)
      end

      it 'creates namespace filter for stream destination' do
        expect do
          helper.sync_stream_namespace_filter(legacy_destination, group)
        end.to change { AuditEvents::Group::NamespaceFilter.count }.by(1)

        filter = AuditEvents::Group::NamespaceFilter.last
        expect(filter.namespace_id).to eq(group.id)
        expect(filter.external_streaming_destination_id).to eq(stream_destination.id)
      end

      it 'updates existing namespace filter if it already exists' do
        other_group = create(:group, parent: group)

        existing_filter = AuditEvents::Group::NamespaceFilter.create!(
          external_streaming_destination_id: stream_destination.id,
          namespace_id: other_group.id
        )

        expect do
          helper.sync_stream_namespace_filter(legacy_destination, group)
        end.not_to change { AuditEvents::Group::NamespaceFilter.count }

        existing_filter.reload
        expect(existing_filter.namespace_id).to eq(group.id)
      end

      context 'when instance level destination' do
        it 'does not create namespace filter' do
          allow(legacy_destination).to receive(:instance_level?).and_return(true)

          expect do
            helper.sync_stream_namespace_filter(legacy_destination, group)
          end.not_to change { AuditEvents::Group::NamespaceFilter.count }
        end
      end

      context 'when error occurs' do
        before do
          allow_next_instance_of(AuditEvents::Group::NamespaceFilter) do |instance|
            allow(instance).to receive(:save!).and_raise(StandardError, "Test error")
          end
          allow(Gitlab::ErrorTracking).to receive(:track_exception)
        end

        it 'tracks the error and returns nil' do
          result = helper.sync_stream_namespace_filter(legacy_destination, group)

          expect(result).to be_nil
          expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
            an_instance_of(StandardError),
            audit_event_destination_model: legacy_destination.class.name
          )
        end
      end

      context 'when should_sync_http? returns false' do
        before do
          allow(helper).to receive(:should_sync_http?).with(legacy_destination).and_return(false)
        end

        it 'does not create namespace filter' do
          expect do
            helper.sync_stream_namespace_filter(legacy_destination, group)
          end.not_to change { AuditEvents::Group::NamespaceFilter.count }
        end
      end
    end
  end

  describe '#sync_legacy_namespace_filter' do
    let_it_be(:group) { create(:group) }

    context 'with HTTP streaming destination' do
      let_it_be_with_reload(:legacy_destination) { create(:external_audit_event_destination, group: group) }
      let_it_be_with_reload(:stream_destination) do
        create(:audit_events_group_external_streaming_destination, group: group)
      end

      before do
        stream_destination.update_column(:legacy_destination_ref, legacy_destination.id)
        allow(stream_destination).to receive_messages(
          legacy_destination: legacy_destination,
          http?: true
        )
        allow(legacy_destination).to receive(:instance_level?).and_return(false)
      end

      it 'creates namespace filter for legacy destination' do
        expect do
          helper.sync_legacy_namespace_filter(stream_destination, group)
        end.to change { AuditEvents::Streaming::HTTP::NamespaceFilter.count }.by(1)

        filter = AuditEvents::Streaming::HTTP::NamespaceFilter.last
        expect(filter.namespace_id).to eq(group.id)
        expect(filter.external_audit_event_destination_id).to eq(legacy_destination.id)
      end

      context 'when filter already exists' do
        let!(:existing_filter) do
          create(:audit_events_streaming_http_namespace_filter,
            external_audit_event_destination: legacy_destination,
            namespace: group)
        end

        it 'updates the existing filter' do
          subgroup = create(:group, parent: group)

          expect do
            helper.sync_legacy_namespace_filter(stream_destination, subgroup)
          end.not_to change { AuditEvents::Streaming::HTTP::NamespaceFilter.count }

          existing_filter.reload
          expect(existing_filter.namespace_id).to eq(subgroup.id)
        end
      end

      context 'when legacy_destination_ref is not present' do
        before do
          allow(stream_destination).to receive(:legacy_destination_ref).and_return(nil)
        end

        it 'does not create namespace filter' do
          expect do
            helper.sync_legacy_namespace_filter(stream_destination, group)
          end.not_to change { AuditEvents::Streaming::HTTP::NamespaceFilter.count }
        end
      end

      context 'when http? returns false' do
        before do
          allow(stream_destination).to receive(:http?).and_return(false)
        end

        it 'does not create namespace filter' do
          expect do
            helper.sync_legacy_namespace_filter(stream_destination, group)
          end.not_to change { AuditEvents::Streaming::HTTP::NamespaceFilter.count }
        end
      end

      context 'when legacy_destination returns nil' do
        before do
          allow(stream_destination).to receive(:legacy_destination).and_return(nil)
        end

        it 'does not create namespace filter' do
          expect do
            helper.sync_legacy_namespace_filter(stream_destination, group)
          end.not_to change { AuditEvents::Streaming::HTTP::NamespaceFilter.count }
        end
      end

      context 'when error occurs' do
        before do
          allow_next_instance_of(AuditEvents::Streaming::HTTP::NamespaceFilter) do |instance|
            allow(instance).to receive(:save!).and_raise(StandardError, "Test error")
          end
          allow(Gitlab::ErrorTracking).to receive(:track_exception)
        end

        it 'tracks the error and returns nil' do
          result = helper.sync_legacy_namespace_filter(stream_destination, group)

          expect(result).to be_nil
          expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
            an_instance_of(StandardError),
            audit_event_destination_model: stream_destination.class.name
          )
        end
      end
    end

    context 'with instance-level HTTP streaming destination' do
      let(:stream_destination) { instance_double(AuditEvents::Instance::ExternalStreamingDestination) }
      let(:namespace) { create(:group) }
      let(:legacy_destination) { instance_double(AuditEvents::InstanceExternalAuditEventDestination) }

      before do
        allow(stream_destination).to receive_messages(
          legacy_destination_ref: 123,
          http?: true,
          legacy_destination: legacy_destination
        )
        allow(legacy_destination).to receive_messages(
          id: 123,
          instance_level?: true
        )
      end

      it 'uses correct filter class and foreign key for instance-level destination' do
        existing_filter = instance_double(AuditEvents::Streaming::HTTP::Instance::NamespaceFilter)

        expect(AuditEvents::Streaming::HTTP::Instance::NamespaceFilter).to receive(:where)
          .with('audit_events_instance_external_audit_event_destination_id' => 123)
          .and_return(instance_double(ActiveRecord::Relation, first: nil))

        expect(AuditEvents::Streaming::HTTP::Instance::NamespaceFilter).to receive(:new)
          .with(hash_including(
            'audit_events_instance_external_audit_event_destination_id' => 123,
            namespace_id: namespace.id
          ))
          .and_return(existing_filter)

        expect(existing_filter).to receive(:save!).and_return(true)

        result = helper.sync_legacy_namespace_filter(stream_destination, namespace)
        expect(result).to eq(existing_filter)
      end

      it 'updates existing filter if it exists' do
        existing_filter = instance_double(AuditEvents::Streaming::HTTP::Instance::NamespaceFilter)

        expect(AuditEvents::Streaming::HTTP::Instance::NamespaceFilter).to receive(:where)
          .with('audit_events_instance_external_audit_event_destination_id' => 123)
          .and_return(instance_double(ActiveRecord::Relation, first: existing_filter))

        expect(existing_filter).to receive(:namespace=).with(namespace)
        expect(existing_filter).to receive(:save!).and_return(true)

        result = helper.sync_legacy_namespace_filter(stream_destination, namespace)
        expect(result).to eq(existing_filter)
      end
    end
  end

  describe '#sync_delete_stream_namespace_filter' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:legacy_destination) { create(:external_audit_event_destination, group: group) }
    let_it_be_with_reload(:stream_destination) do
      create(:audit_events_group_external_streaming_destination, group: group)
    end

    before do
      legacy_destination.update_column(:stream_destination_id, stream_destination.id)
      allow(legacy_destination).to receive_messages(
        http?: true,
        stream_destination: stream_destination
      )
      allow(helper).to receive(:should_sync_http?).and_return(true)
    end

    context 'when filters exist' do
      let!(:namespace_filter) do
        create(:audit_events_streaming_group_namespace_filters,
          external_streaming_destination: stream_destination,
          namespace: group)
      end

      it 'deletes all namespace filters for the stream destination' do
        expect do
          helper.sync_delete_stream_namespace_filter(legacy_destination)
        end.to change { AuditEvents::Group::NamespaceFilter.count }.by(-1)

        expect(AuditEvents::Group::NamespaceFilter.exists?(external_streaming_destination_id: stream_destination.id))
          .to be_falsey
      end

      context 'when should_sync_http? returns false' do
        before do
          allow(helper).to receive(:should_sync_http?).with(legacy_destination).and_return(false)
        end

        it 'does not delete namespace filters' do
          expect do
            helper.sync_delete_stream_namespace_filter(legacy_destination)
          end.not_to change { AuditEvents::Group::NamespaceFilter.count }
        end
      end
    end

    context 'when instance level destination' do
      let(:instance_legacy_destination) { instance_double(AuditEvents::InstanceExternalAuditEventDestination) }
      let(:instance_stream_destination) do
        instance_double(AuditEvents::Instance::ExternalStreamingDestination, id: 456)
      end

      before do
        allow(instance_legacy_destination).to receive_messages(
          instance_level?: true,
          stream_destination: instance_stream_destination
        )
        allow(helper).to receive(:should_sync_http?).with(instance_legacy_destination).and_return(true)
      end

      it 'deletes all namespace filters for the instance stream destination' do
        filter_relation = instance_double(ActiveRecord::Relation)
        expect(AuditEvents::Instance::NamespaceFilter).to receive(:where)
          .with(external_streaming_destination_id: 456)
          .and_return(filter_relation)
        expect(filter_relation).to receive(:delete_all).and_return(1)

        helper.sync_delete_stream_namespace_filter(instance_legacy_destination)
      end
    end

    context 'when error occurs' do
      before do
        allow(AuditEvents::Group::NamespaceFilter).to receive(:where).and_raise(StandardError, "Test error")
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'tracks the error and returns nil' do
        result = helper.sync_delete_stream_namespace_filter(legacy_destination)

        expect(result).to be_nil
        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
          an_instance_of(StandardError),
          audit_event_destination_model: legacy_destination.class.name
        )
      end
    end
  end

  describe '#sync_delete_legacy_namespace_filter' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:legacy_destination) { create(:external_audit_event_destination, group: group) }
    let_it_be_with_reload(:stream_destination) do
      create(:audit_events_group_external_streaming_destination, group: group)
    end

    before do
      stream_destination.update_column(:legacy_destination_ref, legacy_destination.id)
      allow(stream_destination).to receive_messages(
        legacy_destination: legacy_destination,
        http?: true
      )
      allow(legacy_destination).to receive(:instance_level?).and_return(false)
    end

    context 'when group-level filters exist' do
      it 'deletes all namespace filters for the legacy destination' do
        filter_relation = instance_double(ActiveRecord::Relation)
        expect(AuditEvents::Streaming::HTTP::NamespaceFilter).to receive(:where)
          .with('external_audit_event_destination_id' => legacy_destination.id)
          .and_return(filter_relation)
        expect(filter_relation).to receive(:delete_all).and_return(1)

        helper.sync_delete_legacy_namespace_filter(stream_destination)
      end
    end

    context 'when legacy_destination_ref is not present' do
      before do
        allow(stream_destination).to receive(:legacy_destination_ref).and_return(nil)
      end

      it 'does not delete namespace filters' do
        expect(AuditEvents::Streaming::HTTP::NamespaceFilter).not_to receive(:where)

        helper.sync_delete_legacy_namespace_filter(stream_destination)
      end
    end

    context 'when http? returns false' do
      before do
        allow(stream_destination).to receive(:http?).and_return(false)
      end

      it 'does not delete namespace filters' do
        expect(AuditEvents::Streaming::HTTP::NamespaceFilter).not_to receive(:where)

        helper.sync_delete_legacy_namespace_filter(stream_destination)
      end
    end

    context 'when legacy_destination returns nil' do
      before do
        allow(stream_destination).to receive(:legacy_destination).and_return(nil)
      end

      it 'does not delete namespace filters' do
        expect(AuditEvents::Streaming::HTTP::NamespaceFilter).not_to receive(:where)

        helper.sync_delete_legacy_namespace_filter(stream_destination)
      end
    end

    context 'when instance-level filters exist' do
      let(:instance_stream_destination) { instance_double(AuditEvents::Instance::ExternalStreamingDestination) }
      let(:instance_legacy_destination) { instance_double(AuditEvents::InstanceExternalAuditEventDestination) }

      before do
        allow(instance_stream_destination).to receive_messages(
          legacy_destination_ref: 123,
          legacy_destination: instance_legacy_destination,
          http?: true
        )
        allow(instance_legacy_destination).to receive_messages(
          id: 123,
          instance_level?: true
        )
      end

      it 'deletes all instance-level namespace filters for the legacy destination' do
        filter_relation = instance_double(ActiveRecord::Relation)
        expect(AuditEvents::Streaming::HTTP::Instance::NamespaceFilter).to receive(:where)
          .with('audit_events_instance_external_audit_event_destination_id' => 123)
          .and_return(filter_relation)
        expect(filter_relation).to receive(:delete_all).and_return(1)

        helper.sync_delete_legacy_namespace_filter(instance_stream_destination)
      end
    end

    context 'when error occurs' do
      before do
        allow(AuditEvents::Streaming::HTTP::NamespaceFilter).to receive(:where).and_raise(StandardError, "Test error")
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'tracks the error and returns nil' do
        result = helper.sync_delete_legacy_namespace_filter(stream_destination)

        expect(result).to be_nil
        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
          an_instance_of(StandardError),
          audit_event_destination_model: stream_destination.class.name
        )
      end
    end
  end
end

# rubocop:enable RSpec/FactoryBot/AvoidCreate
