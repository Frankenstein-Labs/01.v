# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::AuditEventStreamingWorker, feature_category: :audit_events do
  let(:worker) { described_class.new }

  before do
    stub_licensed_features(external_audit_events: true)
  end

  describe 'STREAMING_COUNTER' do
    it 'defines a Prometheus counter with the correct name and description' do
      expect(described_class::STREAMING_COUNTER).to be_a(Prometheus::Client::Counter)
    end
  end

  shared_context 'a successful audit event stream' do
    let(:event_name) { 'event_type_filters_created' }

    context 'when audit event id is passed' do
      subject { worker.perform(event_name, audit_event.id) }

      include_context 'audit event stream'
    end

    context 'when audit event json is passed' do
      context 'when audit event is streamed as well as database saved' do
        subject { worker.perform(event_name, nil, audit_event.to_json) }

        include_context 'audit event stream'
      end

      context 'when audit event is stream only' do
        before do
          audit_event.id = nil # id is nil in case of stream only events because they are not stored in database.
        end

        subject { worker.perform(event_name, nil, audit_event.to_json) }

        include_context 'audit event stream'
      end
    end
  end

  shared_context 'a error is raised' do
    context 'when audit event id is passed' do
      subject { worker.perform('audit_operation', audit_event.id) }

      include_context 'http post error'
    end

    context 'when audit event json is passed' do
      subject { worker.perform('audit_operation', nil, audit_event.to_json) }

      include_context 'http post error'
    end

    context 'when both audit event id and audit event json is passed' do
      subject { worker.perform('audit_operation', audit_event.id, audit_event.to_json) }

      it 'a argument error is raised' do
        expect { subject }.to raise_error(ArgumentError, 'audit_event_id and audit_event_json cannot be passed together')
      end
    end
  end

  shared_context 'audit event stream' do
    context 'when the group has no destinations' do
      it 'makes no HTTP calls' do
        expect(Gitlab::HTTP).not_to receive(:post)

        subject
      end

      it 'increments the streaming counter with streamable: false' do
        expect(described_class::STREAMING_COUNTER).to receive(:increment).with(
          hash_including(
            streamable: false
          )
        )

        subject
      end
    end

    context 'when the group has a destination' do
      let!(:destination) do
        create(:audit_events_group_external_streaming_destination,
          group: group,
          config: { url: 'http://example.com' }
        )
      end

      it 'makes one HTTP call and logs the event type and namespace_id', :aggregate_failures do
        expect(Gitlab::HTTP).to receive(:post).once
        expect(worker).to receive(:log_extra_metadata_on_done).with(:audit_event_type, "event_type_filters_created")
        expect(worker).to receive(:log_extra_metadata_on_done).with(:namespace_id, audit_event.root_group_entity&.id)

        subject
      end

      it 'increments the streaming counter with correct labels' do
        allow(Gitlab::HTTP).to receive(:post)

        expect(described_class::STREAMING_COUNTER).to receive(:increment).with(
          hash_including(
            streamable: true
          )
        )

        subject
      end

      it 'sends the correct verification header' do
        expect(Gitlab::HTTP).to receive(:post).with(
          an_instance_of(String),
          a_hash_including(headers: a_hash_including("X-Gitlab-Audit-Event-Type" => "event_type_filters_created"))
        ).once

        subject
      end

      context 'sends correct event type in request body' do
        it 'adds event type only when audit operation is present' do
          expect(Gitlab::HTTP).to receive(:post).with(
            an_instance_of(String),
            hash_including(body: a_string_including("\"event_type\":\"event_type_filters_created\""))
          )

          subject
        end
      end

      context 'and id is always passed in request body' do
        before do
          allow(SecureRandom).to receive(:uuid).and_return('randomtoken')
        end

        it 'sends correct id in request body' do
          if audit_event.id.present?
            expect(Gitlab::HTTP).to receive(:post)
              .with(an_instance_of(String), hash_including(body: a_string_including("id\":#{audit_event.id}")))
          else
            expect(Gitlab::HTTP).to receive(:post)
              .with(an_instance_of(String), hash_including(body: a_string_including("id\":\"randomtoken\"")))
          end

          subject
        end
      end

      context 'when the destination has custom headers' do
        let!(:destination) do
          create(:audit_events_group_external_streaming_destination,
            group: group,
            config: {
              url: 'http://example.com',
              headers: {
                'key-1' => { 'value' => 'bar', 'active' => true },
                'key-2' => { 'value' => 'bar', 'active' => true }
              }
            }
          )
        end

        it 'sends the headers with the payload' do
          expected_hash = {
            'key-1' => 'bar',
            'key-2' => 'bar'
          }

          expect(Gitlab::HTTP).to receive(:post).with(
            an_instance_of(String),
            a_hash_including(headers: a_hash_including(expected_hash))
          ).once

          subject
        end
      end

      context 'when audit event type is tracked as an internal event' do
        let(:event_name) { AuditEvents::Streaming::BaseStreamer::INTERNAL_EVENTS.first }

        before do
          allow(Gitlab::HTTP).to receive(:post).once
        end

        it 'makes http call' do
          expect(Gitlab::HTTP).to receive(:post).once

          subject
        end

        it "triggers an internal event" do
          expect { subject }.to trigger_internal_events('trigger_audit_event').with(
            category: 'AuditEvents::Streaming::Group::Streamer',
            additional_properties: { label: event_name }
          )
        end
      end

      context 'when no event type filter is present' do
        it 'makes one HTTP call' do
          expect(Gitlab::HTTP).to receive(:post).once

          subject
        end
      end

      context 'when required streaming event type filter is not present' do
        before do
          create(
            :audit_events_group_event_type_filters,
            external_streaming_destination: destination,
            audit_event_type: 'event_type_filters_deleted'
          )
        end

        it 'does not make HTTP call' do
          expect(Gitlab::HTTP).not_to receive(:post)

          subject
        end
      end

      context 'when audit_operation streaming event type filter is present' do
        before do
          create(
            :audit_events_group_event_type_filters,
            external_streaming_destination: destination,
            audit_event_type: 'event_type_filters_created'
          )
          create(
            :audit_events_group_event_type_filters,
            external_streaming_destination: destination,
            audit_event_type: 'event_type_filters_deleted'
          )
        end

        it 'makes one HTTP call' do
          expect(Gitlab::HTTP).to receive(:post).once

          subject
        end
      end
    end

    context 'when the group has several destinations' do
      before do
        create(:audit_events_group_external_streaming_destination, group: group, config: { url: 'http://example.com' })
        create(:audit_events_group_external_streaming_destination, group: group, config: { url: 'http://example1.com' })
        create(:audit_events_group_external_streaming_destination, group: group, config: { url: 'http://example.org' })
      end

      it 'makes the correct number of HTTP calls' do
        expect(Gitlab::HTTP).to receive(:post).exactly(3).times

        subject
      end

      context 'when feature is unlicensed' do
        before do
          stub_licensed_features(external_audit_events: false)
        end

        it 'makes no HTTP calls' do
          expect(Gitlab::HTTP).not_to receive(:post)

          subject
        end
      end
    end

    context 'when silent mode is enabled' do
      before do
        stub_application_setting(silent_mode_enabled: true)
      end

      it 'returns nil without processing the audit event' do
        expect(worker.perform('audit_operation', nil, audit_event.to_json)).to be_nil
        expect(Gitlab::HTTP).not_to receive(:post)
      end

      it 'does not increment the streaming counter' do
        expect(described_class::STREAMING_COUNTER).not_to receive(:increment)

        worker.perform('audit_operation', nil, audit_event.to_json)
      end
    end
  end

  shared_context 'http post error' do
    let!(:destination) do
      create(:audit_events_group_external_streaming_destination,
        group: group,
        config: { url: 'http://example.com' }
      )
    end

    context 'when any of Gitlab::HTTP::HTTP_ERRORS is raised' do
      Gitlab::HTTP::HTTP_ERRORS.each do |error_klass|
        context "with #{error_klass}" do
          let(:error) { error_klass.new('error') }

          before do
            allow(Gitlab::HTTP).to receive(:post).and_raise(error)
          end

          it 'logs the error' do
            expect(Gitlab::ErrorTracking).to receive(:log_exception).with(
              an_instance_of(error_klass),
              hash_including(:destination_id, :destination_name, :destination_category)
            )
            subject
          end
        end
      end
    end

    context 'when URI::InvalidURIError exception is raised' do
      let(:error) { URI::InvalidURIError.new('invalid uri') }

      before do
        allow(Gitlab::HTTP).to receive(:post).and_raise(error)
      end

      it 'logs the error' do
        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(
          an_instance_of(URI::InvalidURIError),
          hash_including(:destination_id, :destination_name, :destination_category)
        ).once
        subject
      end
    end
  end

  shared_examples 'no HTTP calls are made' do
    context 'when audit event id is passed as param' do
      subject { worker.perform('audit_operation', audit_event.id) }

      it 'makes no HTTP calls' do
        expect(Gitlab::HTTP).not_to receive(:post)

        subject
      end
    end

    context 'when audit event json is passed as param' do
      subject { worker.perform('audit_operation', nil, audit_event.to_json) }

      it 'makes no HTTP calls' do
        expect(Gitlab::HTTP).not_to receive(:post)

        subject
      end
    end
  end

  describe "#perform" do
    context 'when the entity type is a group' do
      it_behaves_like 'a successful audit event stream' do
        let_it_be_with_refind(:audit_event) { create(:audit_event, :group_event) }

        let(:group) { audit_event.entity }
      end

      it_behaves_like 'a error is raised' do
        let_it_be_with_refind(:audit_event) { create(:audit_event, :group_event) }

        let(:group) { audit_event.entity }
      end
    end

    context 'when the entity type is a project that belongs to a group' do
      it_behaves_like 'a successful audit event stream' do
        let_it_be(:group) { create(:group) }
        let_it_be(:project) { create(:project, group: group) }
        let_it_be_with_refind(:audit_event) { create(:audit_event, :project_event, target_project: project) }
      end

      it_behaves_like 'a error is raised' do
        let_it_be(:group) { create(:group) }
        let_it_be(:project) { create(:project, group: group) }
        let_it_be_with_refind(:audit_event) { create(:audit_event, :project_event, target_project: project) }
      end
    end

    context 'when the entity type is a project at a root namespace level' do
      let_it_be_with_refind(:audit_event) { create(:audit_event, :project_event) }

      it_behaves_like 'no HTTP calls are made'
    end

    context 'when the entity is a NullEntity' do
      let_it_be_with_refind(:audit_event) { create(:audit_event, :project_event) }

      context 'when entity_id points to non-existing record' do
        before do
          audit_event.entity_id = non_existing_record_id
        end

        it_behaves_like 'no HTTP calls are made'
      end

      context 'when root_group_entity_id is passed in audit event json' do
        let(:group) { create(:group) }
        let(:project) { create(:project, group: group) }
        let(:audit_event) { create(:audit_event, :project_event, target_project: project) }
        let(:event_name) { 'event_type_filters_created' }

        before do
          audit_event.root_group_entity_id = group.id
        end

        subject { worker.perform(event_name, nil, audit_event.to_json(methods: [:root_group_entity_id])) }

        include_context 'audit event stream'
      end
    end

    context 'when the entity is InstanceScope' do
      let_it_be_with_refind(:audit_event) { create(:audit_event, :instance_event) }

      subject { worker.perform('audit_operation', nil, audit_event.to_json) }

      context 'when the gitlab instance has an external destination' do
        let_it_be(:destination) do
          create(:audit_events_instance_external_streaming_destination,
            config: { url: 'http://example.com/instance' }
          )
        end

        it 'receives HTTP call at destination' do
          expect(Gitlab::HTTP).to receive(:post).with(destination.config["url"], anything).once

          subject
        end

        it 'increments the streaming counter' do
          allow(Gitlab::HTTP).to receive(:post)

          expect(described_class::STREAMING_COUNTER).to receive(:increment).with(
            hash_including(
              streamable: true
            )
          )

          subject
        end
      end

      context 'when the gitlab instance does not have any external destination' do
        it 'makes no HTTP calls' do
          expect(Gitlab::HTTP).not_to receive(:post)

          subject
        end
      end
    end

    context 'when model_class is provided' do
      let(:group_audit_event) { create(:audit_events_group_audit_event) }
      let(:audit_operation) { 'audit_operation' }

      it 'delegates to AuditEvents::Processor' do
        expect(AuditEvents::Processor).to receive(:fetch).with(
          audit_event_id: group_audit_event.id,
          audit_event_json: nil,
          model_class: 'AuditEvents::GroupAuditEvent'
        ).and_call_original

        worker.perform(audit_operation, group_audit_event.id, nil, 'AuditEvents::GroupAuditEvent')
      end

      it 'delegates to AuditEvents::Processor with nil model_class' do
        expect(AuditEvents::Processor).to receive(:fetch).with(
          audit_event_id: group_audit_event.id,
          audit_event_json: nil,
          model_class: nil
        ).and_call_original

        worker.perform(audit_operation, group_audit_event.id)
      end

      context 'when constantize fails with NameError' do
        let(:invalid_model_class) { 'NonExistentClass' }

        it 'logs the error and returns nil' do
          expect(AuditEvents::Processor).to receive(:fetch).with(
            audit_event_id: group_audit_event.id,
            audit_event_json: nil,
            model_class: invalid_model_class
          ).and_return(nil)

          expect(worker).to receive(:log_extra_metadata_on_done).with(:error, "Failed to fetch audit event")

          result = worker.perform(audit_operation, group_audit_event.id, nil, invalid_model_class)
          expect(result).to be_nil
        end

        it 'does not increment the streaming counter' do
          allow(AuditEvents::Processor).to receive(:fetch).and_return(nil)
          allow(worker).to receive(:log_extra_metadata_on_done)

          expect(described_class::STREAMING_COUNTER).not_to receive(:increment)

          worker.perform(audit_operation, group_audit_event.id, nil, invalid_model_class)
        end
      end

      context 'when record is not found' do
        let(:non_existent_id) { non_existing_record_id }

        it 'logs the error and returns nil' do
          expect(AuditEvents::Processor).to receive(:fetch).with(
            audit_event_id: non_existent_id,
            audit_event_json: nil,
            model_class: 'AuditEvents::GroupAuditEvent'
          ).and_return(nil)

          expect(worker).to receive(:log_extra_metadata_on_done).with(:error, "Failed to fetch audit event")

          result = worker.perform(audit_operation, non_existent_id, nil, 'AuditEvents::GroupAuditEvent')
          expect(result).to be_nil
        end

        it 'does not increment the streaming counter' do
          allow(AuditEvents::Processor).to receive(:fetch).and_return(nil)
          allow(worker).to receive(:log_extra_metadata_on_done)

          expect(described_class::STREAMING_COUNTER).not_to receive(:increment)

          worker.perform(audit_operation, non_existent_id, nil, 'AuditEvents::GroupAuditEvent')
        end
      end
    end

    context 'when parsing audit event json fails' do
      let(:invalid_json) { '{invalid_json' }

      it 'logs the error and returns nil' do
        expect(AuditEvents::Processor).to receive(:fetch).with(
          audit_event_id: nil,
          audit_event_json: invalid_json,
          model_class: nil
        ).and_return(nil)

        expect(worker).to receive(:log_extra_metadata_on_done).with(:error, "Failed to fetch audit event")

        result = worker.perform('audit_operation', nil, invalid_json)
        expect(result).to be_nil
      end

      it 'does not increment the streaming counter' do
        allow(AuditEvents::Processor).to receive(:fetch).and_return(nil)
        allow(worker).to receive(:log_extra_metadata_on_done)

        expect(described_class::STREAMING_COUNTER).not_to receive(:increment)

        worker.perform('audit_operation', nil, invalid_json)
      end
    end

    context 'when entity lookup fails during JSON parsing' do
      let(:audit_event_json) do
        {
          group_id: non_existing_record_id,
          author_id: create(:user).id,
          entity_id: non_existing_record_id,
          entity_type: 'Group',
          created_at: Time.current
        }.to_json
      end

      it 'logs the error and returns nil' do
        expect(AuditEvents::Processor).to receive(:fetch).with(
          audit_event_id: nil,
          audit_event_json: audit_event_json,
          model_class: nil
        ).and_return(nil)

        expect(worker).to receive(:log_extra_metadata_on_done).with(:error, "Failed to fetch audit event")

        result = worker.perform('audit_operation', nil, audit_event_json)
        expect(result).to be_nil
      end

      it 'does not increment the streaming counter' do
        allow(AuditEvents::Processor).to receive(:fetch).and_return(nil)
        allow(worker).to receive(:log_extra_metadata_on_done)

        expect(described_class::STREAMING_COUNTER).not_to receive(:increment)

        worker.perform('audit_operation', nil, audit_event_json)
      end
    end

    describe 'streaming counter labels' do
      let_it_be(:group) { create(:group) }
      let_it_be_with_refind(:audit_event) { create(:audit_event, :group_event, entity_id: group.id) }
      let(:audit_operation) { 'test_audit_operation' }
      let(:definition) { instance_double(Gitlab::Audit::Type::Definition, streamed: true, saved_to_database: false) }

      before do
        allow(::Gitlab::Audit::Type::Definition).to receive(:get).with(audit_operation).and_return(definition)
        create(:audit_events_group_external_streaming_destination, group: group)
        allow(Gitlab::HTTP).to receive(:post)
      end

      it 'increments counter with should_stream from definition' do
        expect(described_class::STREAMING_COUNTER).to receive(:increment).with(
          hash_including(should_stream: true)
        )

        worker.perform(audit_operation, audit_event.id)
      end

      it 'increments counter with should_persist from definition' do
        expect(described_class::STREAMING_COUNTER).to receive(:increment).with(
          hash_including(should_persist: false)
        )

        worker.perform(audit_operation, audit_event.id)
      end

      context 'when definition is nil' do
        before do
          allow(::Gitlab::Audit::Type::Definition).to receive(:get).with(audit_operation).and_return(nil)
        end

        it 'defaults should_stream to false' do
          expect(described_class::STREAMING_COUNTER).to receive(:increment).with(
            hash_including(should_stream: false)
          )

          worker.perform(audit_operation, audit_event.id)
        end

        it 'defaults should_persist to false' do
          expect(described_class::STREAMING_COUNTER).to receive(:increment).with(
            hash_including(should_persist: false)
          )

          worker.perform(audit_operation, audit_event.id)
        end
      end
    end
  end

  describe 'AuditEvents::Processor' do
    describe '.fetch_from_json' do
      let(:group) { create(:group) }
      let(:project) { create(:project, group: group) }
      let(:user) { create(:user) }
      let(:author) { create(:user) }
      let(:base_json) do
        {
          author_id: author.id,
          entity_id: group.id,
          entity_type: 'Group',
          created_at: Time.current,
          details: { custom_message: 'test message' }
        }
      end

      context 'with group_id present' do
        let(:audit_event_json) do
          base_json.merge(
            group_id: group.id
          ).to_json
        end

        it 'creates a GroupAuditEvent' do
          event = AuditEvents::Processor.send(:fetch_from_json, audit_event_json)

          expect(event).to be_a(AuditEvents::GroupAuditEvent)
          expect(event.group_id).to eq(group.id)
        end
      end

      context 'with project_id present' do
        let(:audit_event_json) do
          base_json.merge(
            project_id: project.id
          ).to_json
        end

        it 'creates a ProjectAuditEvent' do
          event = AuditEvents::Processor.send(:fetch_from_json, audit_event_json)

          expect(event).to be_a(AuditEvents::ProjectAuditEvent)
          expect(event.project_id).to eq(project.id)
        end
      end

      context 'with user_id present' do
        let(:audit_event_json) do
          base_json.merge(
            user_id: user.id
          ).to_json
        end

        it 'creates a UserAuditEvent' do
          event = AuditEvents::Processor.send(:fetch_from_json, audit_event_json)

          expect(event).to be_a(AuditEvents::UserAuditEvent)
          expect(event.user_id).to eq(user.id)
        end
      end

      context 'with no specific id present and instance scope entity type' do
        let(:audit_event_json) do
          base_json.merge(
            entity_type: 'Gitlab::Audit::InstanceScope',
            entity_id: nil
          ).to_json
        end

        it 'creates an InstanceAuditEvent' do
          event = AuditEvents::Processor.send(:fetch_from_json, audit_event_json)

          expect(event).to be_a(AuditEvents::InstanceAuditEvent)
        end
      end

      context 'with entity_type/entity_id but no scoped id key' do
        let(:audit_event_json) do
          base_json.to_json
        end

        it 'creates a GroupAuditEvent from entity_type fallback' do
          event = AuditEvents::Processor.send(:fetch_from_json, audit_event_json)

          expect(event).to be_a(AuditEvents::GroupAuditEvent)
          expect(event.group_id).to eq(group.id)
        end
      end
    end
  end
end
