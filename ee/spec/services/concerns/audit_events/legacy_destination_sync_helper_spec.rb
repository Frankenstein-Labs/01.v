# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need to persist models
RSpec.describe AuditEvents::LegacyDestinationSyncHelper, feature_category: :audit_events do
  let(:helper) { Class.new { include AuditEvents::LegacyDestinationSyncHelper }.new }

  describe '#create_stream_destination' do
    context 'when feature flag is enabled' do
      describe 'http destinations' do
        context 'when instance level' do
          let!(:header) do
            create(:instance_audit_events_streaming_header,
              key: 'Custom-Header',
              value: 'test-value',
              active: true)
          end

          let!(:source) do
            create(:instance_external_audit_event_destination,
              name: 'test-destination',
              verification_token: 'a' * 16,
              destination_url: 'https://example.com/webhook',
              headers: [header])
          end

          let!(:event_type_filter) do
            create(:audit_events_streaming_instance_event_type_filter,
              instance_external_audit_event_destination: source,
              audit_event_type: 'user_created')
          end

          let!(:namespace_filter) do
            create(:audit_events_streaming_http_instance_namespace_filter,
              instance_external_audit_event_destination: source)
          end

          it 'creates streaming destination with basic attributes' do
            destination = helper.create_stream_destination(legacy_destination_model: source, category: :http,
              is_instance: true)

            aggregate_failures do
              expect(destination).to be_a(AuditEvents::Instance::ExternalStreamingDestination)
              expect(destination.name).to eq('test-destination')
              expect(destination.category).to eq('http')
              expect(destination.config['url']).to eq(source.destination_url)
              expect(destination.config['headers']).to include(
                'Custom-Header' => {
                  'value' => 'test-value',
                  'active' => true
                }
              )
              expect(destination.secret_token).to eq(source.verification_token)
              expect(destination.legacy_destination_ref).to eq(source.id)
              expect(source.stream_destination_id).to eq(destination.id)
              expect(destination.event_type_filters.count).to eq(0)
              expect(destination.namespace_filters.count).to eq(0)
            end
          end
        end

        context 'when group level' do
          let(:group) { create(:group) }

          let!(:header) do
            create(:audit_events_streaming_header,
              key: 'Custom-Header',
              value: 'test-value',
              active: true)
          end

          let!(:source) do
            create(:external_audit_event_destination,
              name: 'test-destination',
              group: group,
              verification_token: 'a' * 16,
              destination_url: 'https://example.com/webhook',
              headers: [header])
          end

          let!(:event_type_filter) do
            create(:audit_events_streaming_event_type_filter,
              external_audit_event_destination: source,
              audit_event_type: 'user_created')
          end

          context 'when source has a namespace filter' do
            let!(:namespace_filter) do
              create(:audit_events_streaming_http_namespace_filter,
                external_audit_event_destination: source,
                namespace: group)
            end

            it 'creates streaming destination with basic attributes' do
              destination = helper.create_stream_destination(legacy_destination_model: source, category: :http,
                is_instance: false)

              aggregate_failures do
                expect(destination).to be_a(AuditEvents::Group::ExternalStreamingDestination)
                expect(destination.name).to eq('test-destination')
                expect(destination.category).to eq('http')
                expect(destination.group).to eq(group)
                expect(destination.config['url']).to eq(source.destination_url)
                expect(destination.config['headers']).to include(
                  'Custom-Header' => {
                    'value' => 'test-value',
                    'active' => true
                  }
                )
                expect(destination.secret_token).to eq(source.verification_token)
                expect(destination.legacy_destination_ref).to eq(source.id)
                expect(source.stream_destination_id).to eq(destination.id)
                expect(destination.event_type_filters.count).to eq(0)
                expect(destination.namespace_filters.count).to eq(0)
              end
            end
          end

          context 'when source has no namespace filter' do
            it 'creates streaming destination without namespace filter' do
              destination = helper.create_stream_destination(legacy_destination_model: source, category: :http,
                is_instance: false)

              expect(destination.namespace_filters.count).to eq(0)
            end
          end
        end
      end

      describe 'aws destinations' do
        context 'when instance level' do
          let!(:source) do
            create(:instance_amazon_s3_configuration,
              name: 'test-destination',
              bucket_name: 'test-bucket',
              aws_region: 'us-east-1',
              access_key_xid: SecureRandom.hex(8),
              secret_access_key: 'test-secret-key')
          end

          it 'creates streaming destination correctly' do
            destination = helper.create_stream_destination(legacy_destination_model: source, category: :aws,
              is_instance: true)

            aggregate_failures do
              expect(destination).to be_a(AuditEvents::Instance::ExternalStreamingDestination)
              expect(destination.name).to eq('test-destination')
              expect(destination.category).to eq('aws')
              expect(destination.config['bucketName']).to eq(source.bucket_name)
              expect(destination.config['awsRegion']).to eq(source.aws_region)
              expect(destination.config['accessKeyXid']).to eq(source.access_key_xid)
              expect(destination.secret_token).to eq(source.secret_access_key)
              expect(destination.legacy_destination_ref).to eq(source.id)
              expect(source.stream_destination_id).to eq(destination.id)
            end
          end
        end

        context 'when group level' do
          let(:group) { create(:group) }

          let!(:source) do
            create(:amazon_s3_configuration,
              name: 'test-destination',
              group: group,
              bucket_name: 'test-bucket',
              aws_region: 'us-east-1',
              access_key_xid: SecureRandom.hex(8),
              secret_access_key: 'test-secret-key')
          end

          it 'creates streaming destination correctly' do
            destination = helper.create_stream_destination(legacy_destination_model: source, category: :aws,
              is_instance: false)

            aggregate_failures do
              expect(destination).to be_a(AuditEvents::Group::ExternalStreamingDestination)
              expect(destination.name).to eq('test-destination')
              expect(destination.category).to eq('aws')
              expect(destination.group).to eq(group)
              expect(destination.config['bucketName']).to eq(source.bucket_name)
              expect(destination.config['awsRegion']).to eq(source.aws_region)
              expect(destination.config['accessKeyXid']).to eq(source.access_key_xid)
              expect(destination.secret_token).to eq(source.secret_access_key)
              expect(destination.legacy_destination_ref).to eq(source.id)
              expect(source.stream_destination_id).to eq(destination.id)
            end
          end
        end
      end

      describe 'gcp destinations' do
        context 'when instance level' do
          let!(:source) do
            create(:instance_google_cloud_logging_configuration,
              name: 'test-destination',
              google_project_id_name: 'test-project',
              log_id_name: 'test-log',
              client_email: 'test@example.com',
              private_key: 'test-private-key')
          end

          it 'creates streaming destination correctly' do
            destination = helper.create_stream_destination(legacy_destination_model: source, category: :gcp,
              is_instance: true)

            aggregate_failures do
              expect(destination).to be_a(AuditEvents::Instance::ExternalStreamingDestination)
              expect(destination.name).to eq('test-destination')
              expect(destination.category).to eq('gcp')
              expect(destination.config['googleProjectIdName']).to eq(source.google_project_id_name)
              expect(destination.config['logIdName']).to eq(source.log_id_name)
              expect(destination.config['clientEmail']).to eq(source.client_email)
              expect(destination.secret_token).to eq(source.private_key)
              expect(destination.legacy_destination_ref).to eq(source.id)
              expect(source.stream_destination_id).to eq(destination.id)
            end
          end
        end

        context 'when group level' do
          let(:group) { create(:group) }

          let!(:source) do
            create(:google_cloud_logging_configuration,
              name: 'test-destination',
              group: group,
              google_project_id_name: 'test-project',
              log_id_name: 'test-log',
              client_email: 'test@example.com',
              private_key: 'test-private-key')
          end

          it 'creates streaming destination correctly' do
            destination = helper.create_stream_destination(legacy_destination_model: source, category: :gcp,
              is_instance: false)

            aggregate_failures do
              expect(destination).to be_a(AuditEvents::Group::ExternalStreamingDestination)
              expect(destination.name).to eq('test-destination')
              expect(destination.category).to eq('gcp')
              expect(destination.group).to eq(group)
              expect(destination.config['googleProjectIdName']).to eq(source.google_project_id_name)
              expect(destination.config['logIdName']).to eq(source.log_id_name)
              expect(destination.config['clientEmail']).to eq(source.client_email)
              expect(destination.secret_token).to eq(source.private_key)
              expect(destination.legacy_destination_ref).to eq(source.id)
              expect(source.stream_destination_id).to eq(destination.id)
            end
          end
        end
      end

      context 'when an error occurs during creation' do
        let(:group) { create(:group) }
        let(:source) { create(:external_audit_event_destination, group: group) }
        let(:mock_destination) { build(:audit_events_group_external_streaming_destination, group: group) }

        before do
          allow(AuditEvents::Group::ExternalStreamingDestination)
            .to receive(:new)
            .and_return(mock_destination)

          allow(mock_destination)
            .to receive(:save!)
            .and_raise(StandardError, 'Test error')
        end

        it 'returns nil and tracks the error' do
          expect(Gitlab::ErrorTracking)
            .to receive(:track_exception)
            .with(
              an_instance_of(StandardError),
              audit_event_destination_model: source.class.name
            )

          expect(helper.create_stream_destination(legacy_destination_model: source, category: :http,
            is_instance: false)).to be_nil
        end
      end
    end
  end

  describe '#update_stream_destination' do
    context 'when feature flag is enabled' do
      describe 'http destinations' do
        context 'when instance level' do
          let!(:header) do
            create(:instance_audit_events_streaming_header,
              key: 'Custom-Header',
              value: 'test-value',
              active: true)
          end

          let!(:legacy_destination) do
            create(:instance_external_audit_event_destination,
              name: 'test-stream_destination',
              verification_token: 'a' * 16,
              destination_url: 'https://example.com/webhook',
              headers: [header])
          end

          let(:stream_destination) do
            create(:audit_events_instance_external_streaming_destination, :http,
              legacy_destination_ref: legacy_destination.id)
          end

          it 'updates streaming destination with basic attributes' do
            legacy_destination.update!(
              name: 'updated-stream_destination',
              verification_token: 'b' * 16,
              destination_url: 'https://example.com/updated',
              stream_destination_id: stream_destination.id
            )
            legacy_destination.reload

            updated_destination = helper.update_stream_destination(legacy_destination_model: legacy_destination)

            expect(updated_destination.name).to eq('updated-stream_destination')
            expect(updated_destination.category).to eq('http')
            expect(updated_destination.config['url']).to eq(legacy_destination.destination_url)
            expect(updated_destination.config['headers']).not_to include(
              'X-Gitlab-Event-Streaming-Token' => {
                'value' => legacy_destination.verification_token,
                'active' => true
              }
            )
            expect(updated_destination.secret_token).to eq(legacy_destination.verification_token)
            expect(updated_destination.legacy_destination_ref).to eq(legacy_destination.id)
            expect(legacy_destination.stream_destination_id).to eq(updated_destination.id)
          end
        end

        context 'when group level' do
          let(:group) { create(:group) }

          let!(:legacy_destination) do
            create(:external_audit_event_destination,
              name: 'test-stream_destination',
              group: group,
              verification_token: 'a' * 16,
              destination_url: 'https://example.com/webhook')
          end

          let(:stream_destination) do
            create(:audit_events_group_external_streaming_destination, :http,
              group: group, legacy_destination_ref: legacy_destination.id)
          end

          it 'updates streaming destination correctly' do
            legacy_destination.update!(
              name: 'updated-stream_destination',
              verification_token: 'b' * 16,
              destination_url: 'https://updated.com/webhook',
              stream_destination_id: stream_destination.id
            )

            updated_destination = helper.update_stream_destination(legacy_destination_model: legacy_destination)

            expect(updated_destination.name).to eq('updated-stream_destination')
            expect(updated_destination.category).to eq('http')
            expect(updated_destination.group).to eq(group)
            expect(updated_destination.config['url']).to eq(legacy_destination.destination_url)
            expect(updated_destination.secret_token).to eq(legacy_destination.verification_token)
            expect(updated_destination.legacy_destination_ref).to eq(legacy_destination.id)
            expect(legacy_destination.stream_destination_id).to eq(updated_destination.id)
          end
        end
      end

      describe 'aws destinations' do
        context 'when instance level' do
          let!(:legacy_destination) do
            create(:instance_amazon_s3_configuration,
              name: 'test-stream_destination',
              bucket_name: 'test-bucket',
              aws_region: 'us-east-1',
              access_key_xid: SecureRandom.hex(8),
              secret_access_key: 'test-secret-key')
          end

          let(:stream_destination) do
            create(:audit_events_instance_external_streaming_destination, :aws,
              legacy_destination_ref: legacy_destination.id)
          end

          it 'updates streaming destination correctly' do
            legacy_destination.update!(
              name: 'updated-stream_destination',
              bucket_name: 'updated-bucket',
              aws_region: 'us-west-2',
              secret_access_key: 'updated-secret-key',
              stream_destination_id: stream_destination.id
            )

            updated_destination = helper.update_stream_destination(legacy_destination_model: legacy_destination)

            expect(updated_destination.name).to eq('updated-stream_destination')
            expect(updated_destination.category).to eq('aws')
            expect(updated_destination.config['bucketName']).to eq(legacy_destination.bucket_name)
            expect(updated_destination.config['awsRegion']).to eq(legacy_destination.aws_region)
            expect(updated_destination.secret_token).to eq(legacy_destination.secret_access_key)
            expect(updated_destination.legacy_destination_ref).to eq(legacy_destination.id)
            expect(legacy_destination.stream_destination_id).to eq(updated_destination.id)
          end
        end

        context 'when group level' do
          let(:group) { create(:group) }

          let!(:legacy_destination) do
            create(:amazon_s3_configuration,
              name: 'test-stream_destination',
              group: group,
              bucket_name: 'test-bucket',
              aws_region: 'us-east-1',
              secret_access_key: 'test-secret-key')
          end

          let(:stream_destination) do
            create(:audit_events_group_external_streaming_destination, :aws,
              group: group, legacy_destination_ref: legacy_destination.id)
          end

          it 'updates streaming destination correctly' do
            legacy_destination.update!(
              name: 'updated-stream_destination',
              bucket_name: 'updated-bucket',
              aws_region: 'us-west-2',
              secret_access_key: 'updated-secret-key',
              stream_destination_id: stream_destination.id
            )

            updated_destination = helper.update_stream_destination(legacy_destination_model: legacy_destination)

            expect(updated_destination.name).to eq('updated-stream_destination')
            expect(updated_destination.category).to eq('aws')
            expect(updated_destination.group).to eq(group)
            expect(updated_destination.config['bucketName']).to eq(legacy_destination.bucket_name)
            expect(updated_destination.config['awsRegion']).to eq(legacy_destination.aws_region)
            expect(updated_destination.secret_token).to eq(legacy_destination.secret_access_key)
            expect(updated_destination.legacy_destination_ref).to eq(legacy_destination.id)
            expect(legacy_destination.stream_destination_id).to eq(updated_destination.id)
          end
        end
      end

      describe 'gcp destinations' do
        context 'when instance level' do
          let!(:legacy_destination) do
            create(:instance_google_cloud_logging_configuration,
              name: 'test-stream_destination',
              google_project_id_name: 'test-project',
              log_id_name: 'test-log',
              client_email: 'test@example.com',
              private_key: 'test-private-key')
          end

          let(:stream_destination) do
            create(:audit_events_instance_external_streaming_destination, :gcp,
              legacy_destination_ref: legacy_destination.id)
          end

          it 'updates streaming destination correctly' do
            legacy_destination.update!(
              name: 'updated-stream_destination',
              google_project_id_name: 'updated-project',
              log_id_name: 'updated-log',
              client_email: 'updated@example.com',
              private_key: 'updated-private-key',
              stream_destination_id: stream_destination.id
            )

            updated_destination = helper.update_stream_destination(legacy_destination_model: legacy_destination)

            expect(updated_destination.name).to eq('updated-stream_destination')
            expect(updated_destination.category).to eq('gcp')
            expect(updated_destination.config['googleProjectIdName']).to eq(legacy_destination.google_project_id_name)
            expect(updated_destination.config['logIdName']).to eq(legacy_destination.log_id_name)
            expect(updated_destination.config['clientEmail']).to eq(legacy_destination.client_email)
            expect(updated_destination.secret_token).to eq(legacy_destination.private_key)
            expect(updated_destination.legacy_destination_ref).to eq(legacy_destination.id)
            expect(legacy_destination.stream_destination_id).to eq(updated_destination.id)
          end
        end

        context 'when group level' do
          let(:group) { create(:group) }

          let!(:legacy_destination) do
            create(:google_cloud_logging_configuration,
              name: 'test-stream_destination',
              group: group,
              google_project_id_name: 'test-project',
              log_id_name: 'test-log',
              client_email: 'test@example.com',
              private_key: 'test-private-key')
          end

          let(:stream_destination) do
            create(:audit_events_group_external_streaming_destination, :gcp,
              group: group, legacy_destination_ref: legacy_destination.id)
          end

          it 'updates streaming destination correctly' do
            legacy_destination.update!(
              name: 'updated-stream_destination',
              google_project_id_name: 'updated-project',
              log_id_name: 'updated-log',
              client_email: 'updated@example.com',
              private_key: 'updated-private-key',
              stream_destination_id: stream_destination.id
            )

            updated_destination = helper.update_stream_destination(legacy_destination_model: legacy_destination)

            expect(updated_destination.name).to eq('updated-stream_destination')
            expect(updated_destination.category).to eq('gcp')
            expect(updated_destination.group).to eq(group)
            expect(updated_destination.config['googleProjectIdName']).to eq(legacy_destination.google_project_id_name)
            expect(updated_destination.config['logIdName']).to eq(legacy_destination.log_id_name)
            expect(updated_destination.config['clientEmail']).to eq(legacy_destination.client_email)
            expect(updated_destination.secret_token).to eq(legacy_destination.private_key)
            expect(updated_destination.legacy_destination_ref).to eq(legacy_destination.id)
            expect(legacy_destination.stream_destination_id).to eq(updated_destination.id)
          end
        end
      end

      context 'when an error occurs during update' do
        let(:group) { create(:group) }
        let(:source) { create(:external_audit_event_destination, group: group) }
        let(:mock_destination) { create(:audit_events_group_external_streaming_destination, group: group) }

        before do
          source.update_column(:stream_destination_id, mock_destination.id)
          mock_destination.update_column(:legacy_destination_ref, source.id)

          allow(source)
            .to receive(:stream_destination)
            .and_return(mock_destination)

          allow(mock_destination)
            .to receive(:update!)
            .and_raise(StandardError, 'Test error')
        end

        it 'returns nil and tracks the error' do
          expect(Gitlab::ErrorTracking)
            .to receive(:track_exception)
            .with(
              an_instance_of(StandardError),
              audit_event_destination_model: source.class.name
            )

          expect(helper.update_stream_destination(legacy_destination_model: source)).to be_nil
        end
      end
    end
  end
end
# rubocop:enable RSpec/FactoryBot/AvoidCreate
