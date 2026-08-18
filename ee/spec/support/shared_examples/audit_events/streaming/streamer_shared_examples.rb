# frozen_string_literal: true

RSpec.shared_examples 'streamer streaming audit events' do |scope|
  let_it_be(:group, freeze: false) { create(:group) if scope == :group }
  let_it_be(:audit_event, freeze: false) do
    scope == :group ? create(:audit_event, :group_event, target_group: group) : create(:audit_event, :instance_event)
  end

  let(:event_type) { 'event_type_filters_created' }
  let(:streamer) { described_class.new(event_type, audit_event) }

  describe '#streamable?' do
    subject(:check_streamable) { streamer.streamable? }

    context 'when audit events licensed feature is false' do
      before do
        if scope == :group
          allow(audit_event.root_group_entity).to receive(:licensed_feature_available?)
            .with(:external_audit_events).and_return(false)
        else
          stub_licensed_features(external_audit_events: false)
        end
      end

      it { is_expected.to be_falsey }
    end

    context 'when audit events licensed feature is true' do
      before do
        if scope == :group
          allow(audit_event.root_group_entity).to receive(:licensed_feature_available?)
            .with(:external_audit_events).and_return(true)
        else
          stub_licensed_features(external_audit_events: true)
        end
      end

      context 'when there is an active destination with no event type filters' do
        before do
          if scope == :group
            create(:audit_events_group_external_streaming_destination, :http, group: audit_event.root_group_entity)
          else
            create(:audit_events_instance_external_streaming_destination, :http)
          end
        end

        it { is_expected.to be_truthy }
      end

      context 'when there is an active destination with a matching event type filter' do
        before do
          destination = if scope == :group
                          create(:audit_events_group_external_streaming_destination, :http,
                            group: audit_event.root_group_entity)
                        else
                          create(:audit_events_instance_external_streaming_destination, :http)
                        end

          if scope == :group
            create(:audit_events_group_event_type_filters,
              external_streaming_destination: destination,
              audit_event_type: event_type)
          else
            create(:audit_events_instance_event_type_filters,
              external_streaming_destination: destination,
              audit_event_type: event_type)
          end
        end

        it { is_expected.to be_truthy }
      end

      context 'when all active destinations have event type filters that do not match' do
        before do
          destination = if scope == :group
                          create(:audit_events_group_external_streaming_destination, :http,
                            group: audit_event.root_group_entity)
                        else
                          create(:audit_events_instance_external_streaming_destination, :http)
                        end

          if scope == :group
            create(:audit_events_group_event_type_filters,
              external_streaming_destination: destination,
              audit_event_type: 'event_type_filters_deleted')
          else
            create(:audit_events_instance_event_type_filters,
              external_streaming_destination: destination,
              audit_event_type: 'event_type_filters_deleted')
          end
        end

        it { is_expected.to be_falsey }
      end

      context 'when one destination has no filters and another has a non-matching filter' do
        before do
          if scope == :group
            create(:audit_events_group_external_streaming_destination, :http,
              group: audit_event.root_group_entity)
            filtered_destination = create(:audit_events_group_external_streaming_destination, :gcp,
              group: audit_event.root_group_entity)
            create(:audit_events_group_event_type_filters,
              external_streaming_destination: filtered_destination,
              audit_event_type: 'event_type_filters_deleted')
          else
            create(:audit_events_instance_external_streaming_destination, :http)
            filtered_destination = create(:audit_events_instance_external_streaming_destination, :gcp)
            create(:audit_events_instance_event_type_filters,
              external_streaming_destination: filtered_destination,
              audit_event_type: 'event_type_filters_deleted')
          end
        end

        it { is_expected.to be_truthy }
      end

      context 'when event_type is blank and a destination has filters that would not match' do
        let(:event_type) { '' }

        before do
          destination = if scope == :group
                          create(:audit_events_group_external_streaming_destination, :http,
                            group: audit_event.root_group_entity)
                        else
                          create(:audit_events_instance_external_streaming_destination, :http)
                        end

          if scope == :group
            create(:audit_events_group_event_type_filters,
              external_streaming_destination: destination,
              audit_event_type: 'event_type_filters_deleted')
          else
            create(:audit_events_instance_event_type_filters,
              external_streaming_destination: destination,
              audit_event_type: 'event_type_filters_deleted')
          end
        end

        it 'matches the per-destination allowed_to_stream? behavior and returns true' do
          is_expected.to be_truthy
        end
      end
    end
  end

  describe '#destinations' do
    subject(:get_streamer_destinations) { streamer.destinations }

    context 'when no valid destinations exist' do
      before do
        if scope == :group
          audit_event.root_group_entity.external_audit_event_streaming_destinations.update_all(active: false)
        else
          AuditEvents::Instance::ExternalStreamingDestination.update_all(active: false)
        end
      end

      it { is_expected.to be_empty }
    end

    context 'when some active destinations exist' do
      before do
        if scope == :group
          audit_event.root_group_entity.external_audit_event_streaming_destinations.update_all(active: false)
        else
          AuditEvents::Instance::ExternalStreamingDestination.update_all(active: false)
        end
      end

      let!(:destination) do
        if scope == :group
          group = audit_event.root_group_entity.reload
          create(:audit_events_group_external_streaming_destination, :http, group: group)
        else
          create(:audit_events_instance_external_streaming_destination, :http)
        end
      end

      it 'returns only the active destinations' do
        expect(get_streamer_destinations).to contain_exactly(destination)
        expect(destination.active).to be_truthy
      end
    end

    context 'when valid destinations exist' do
      before do
        audit_event.root_group_entity_id = group.id if scope == :group
      end

      let!(:destination) do
        if scope == :group
          group = audit_event.root_group_entity.reload
          create(:audit_events_group_external_streaming_destination, :http, group: group)
        else
          create(:audit_events_instance_external_streaming_destination, :http)
        end
      end

      it 'returns the correct destination' do
        expect(get_streamer_destinations).to contain_exactly(destination)
      end
    end
  end

  describe '#execute' do
    subject(:execute_streaming) { streamer.execute }

    context 'when streamable' do
      before do
        allow(streamer).to receive(:streamable?).and_return(true)
      end

      context 'when there are active destinations' do
        let(:active_destination1) do
          if scope == :group
            instance_double(AuditEvents::Group::ExternalStreamingDestination, category: 'http')
          else
            instance_double(AuditEvents::Instance::ExternalStreamingDestination, category: 'http')
          end
        end

        let(:active_destination2) do
          if scope == :group
            instance_double(AuditEvents::Group::ExternalStreamingDestination, category: 'gcp')
          else
            instance_double(AuditEvents::Instance::ExternalStreamingDestination, category: 'gcp')
          end
        end

        before do
          allow(streamer).to receive(:destinations).and_return([active_destination1, active_destination2])

          allow(active_destination1).to receive(:allowed_to_stream?).with(event_type, audit_event).and_return(true)
          allow(active_destination2).to receive(:allowed_to_stream?).with(event_type, audit_event).and_return(true)
        end

        context 'when one destination fails' do
          let(:active_destination1) do
            if scope == :group
              instance_double(AuditEvents::Group::ExternalStreamingDestination,
                id: 1, name: 'failing_destination', category: 'http')
            else
              instance_double(AuditEvents::Instance::ExternalStreamingDestination,
                id: 1, name: 'failing_destination', category: 'http')
            end
          end

          let(:active_destination2) do
            if scope == :group
              instance_double(AuditEvents::Group::ExternalStreamingDestination,
                id: 2, name: 'successful_destination', category: 'gcp')
            else
              instance_double(AuditEvents::Instance::ExternalStreamingDestination,
                id: 2, name: 'successful_destination', category: 'gcp')
            end
          end

          before do
            allow(streamer).to receive(:destinations).and_return([active_destination1, active_destination2])
          end

          it 'continues with other destinations and tracks the error' do
            failing_streamer = instance_double(AuditEvents::Streaming::Destinations::HttpStreamDestination)
            successful_streamer = instance_double(
              AuditEvents::Streaming::Destinations::GoogleCloudLoggingStreamDestination
            )

            expect(AuditEvents::Streaming::Destinations::HttpStreamDestination)
              .to receive(:new)
              .with(event_type, audit_event, active_destination1)
              .and_return(failing_streamer)

            expect(AuditEvents::Streaming::Destinations::GoogleCloudLoggingStreamDestination)
              .to receive(:new)
              .with(event_type, audit_event, active_destination2)
              .and_return(successful_streamer)

            expect(failing_streamer).to receive(:stream)
              .and_raise(RuntimeError, 'Unexpected error')

            expect(successful_streamer).to receive(:stream)

            expect(Gitlab::ErrorTracking).to receive(:track_exception)
              .with(
                an_instance_of(RuntimeError),
                hash_including(
                  destination_id: 1,
                  destination_name: 'failing_destination',
                  destination_category: 'http'
                )
              )

            execute_streaming
          end

          it 'continues with other destinations and logs user-config errors without Sentry alerts' do
            failing_streamer = instance_double(AuditEvents::Streaming::Destinations::HttpStreamDestination)
            successful_streamer = instance_double(
              AuditEvents::Streaming::Destinations::GoogleCloudLoggingStreamDestination
            )

            expect(AuditEvents::Streaming::Destinations::HttpStreamDestination)
              .to receive(:new)
              .with(event_type, audit_event, active_destination1)
              .and_return(failing_streamer)

            expect(AuditEvents::Streaming::Destinations::GoogleCloudLoggingStreamDestination)
              .to receive(:new)
              .with(event_type, audit_event, active_destination2)
              .and_return(successful_streamer)

            expect(failing_streamer).to receive(:stream)
              .and_raise(URI::InvalidURIError, 'Invalid URL')

            expect(successful_streamer).to receive(:stream)

            expect(Gitlab::ErrorTracking).to receive(:log_exception)
              .with(
                an_instance_of(URI::InvalidURIError),
                hash_including(
                  destination_id: 1,
                  destination_name: 'failing_destination',
                  destination_category: 'http'
                )
              )
            expect(Gitlab::ErrorTracking).not_to receive(:track_exception)

            execute_streaming
          end

          context 'when a GCP destination raises a user-config error' do
            let(:active_destination1) do
              if scope == :group
                instance_double(AuditEvents::Group::ExternalStreamingDestination,
                  id: 1, name: 'failing_gcp_destination', category: 'gcp')
              else
                instance_double(AuditEvents::Instance::ExternalStreamingDestination,
                  id: 1, name: 'failing_gcp_destination', category: 'gcp')
              end
            end

            let(:active_destination2) do
              if scope == :group
                instance_double(AuditEvents::Group::ExternalStreamingDestination,
                  id: 2, name: 'successful_http_destination', category: 'http')
              else
                instance_double(AuditEvents::Instance::ExternalStreamingDestination,
                  id: 2, name: 'successful_http_destination', category: 'http')
              end
            end

            [
              [OpenSSL::PKey::RSAError, 'invalid private key'],
              [Signet::AuthorizationError, 'unauthorized']
            ].each do |error_class, error_message|
              context "with #{error_class}" do
                it 'continues with other destinations and logs without Sentry alerts' do
                  failing_streamer = instance_double(
                    AuditEvents::Streaming::Destinations::GoogleCloudLoggingStreamDestination
                  )
                  successful_streamer = instance_double(AuditEvents::Streaming::Destinations::HttpStreamDestination)

                  expect(AuditEvents::Streaming::Destinations::GoogleCloudLoggingStreamDestination)
                    .to receive(:new)
                    .with(event_type, audit_event, active_destination1)
                    .and_return(failing_streamer)

                  expect(AuditEvents::Streaming::Destinations::HttpStreamDestination)
                    .to receive(:new)
                    .with(event_type, audit_event, active_destination2)
                    .and_return(successful_streamer)

                  expect(failing_streamer).to receive(:stream).and_raise(error_class, error_message)
                  expect(successful_streamer).to receive(:stream)

                  expect(Gitlab::ErrorTracking).to receive(:log_exception)
                    .with(
                      an_instance_of(error_class),
                      hash_including(
                        destination_id: 1,
                        destination_name: 'failing_gcp_destination',
                        destination_category: 'gcp'
                      )
                    )
                  expect(Gitlab::ErrorTracking).not_to receive(:track_exception)
                  expect(AuditEvents::Streaming::CircuitBreaker).to receive(:record_failure).with(active_destination1)

                  execute_streaming
                end
              end
            end
          end
        end
      end

      context 'when destinations is empty' do
        before do
          allow(streamer).to receive(:destinations).and_return([])
        end

        it 'does not attempt any streaming' do
          expect(AuditEvents::Streaming::Destinations::HttpStreamDestination).not_to receive(:new)
          expect(AuditEvents::Streaming::Destinations::GoogleCloudLoggingStreamDestination).not_to receive(:new)
          expect(AuditEvents::Streaming::Destinations::AmazonS3StreamDestination).not_to receive(:new)

          execute_streaming
        end
      end
    end

    context 'when not streamable' do
      before do
        allow(streamer).to receive(:streamable?).and_return(false)
      end

      it 'does not execute streaming' do
        expect(streamer).not_to receive(:destinations)
        expect(AuditEvents::Streaming::Destinations::HttpStreamDestination).not_to receive(:new)

        execute_streaming
      end
    end
  end
end
