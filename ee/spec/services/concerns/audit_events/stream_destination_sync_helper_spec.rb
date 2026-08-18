# frozen_string_literal: true

# rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need to persist destination models to use helpers
require 'spec_helper'

RSpec.describe AuditEvents::StreamDestinationSyncHelper, feature_category: :audit_events do
  let(:helper) { Class.new { include AuditEvents::StreamDestinationSyncHelper }.new }

  describe '#create_legacy_destination' do
    context 'when feature flag is enabled' do
      describe 'http destinations' do
        context 'when instance level' do
          let_it_be_with_reload(:source) do
            create(:audit_events_instance_external_streaming_destination, :http)
          end

          let_it_be(:event_type_filter) do
            create(:audit_events_instance_event_type_filters,
              external_streaming_destination: source,
              audit_event_type: 'user_created')
          end

          let_it_be(:namespace_filter) do
            create(:audit_events_streaming_instance_namespace_filters,
              external_streaming_destination: source)
          end

          it 'creates legacy destination with basic attributes' do
            destination = helper.create_legacy_destination(source)

            aggregate_failures do
              expect(destination).to be_a(AuditEvents::InstanceExternalAuditEventDestination)
              expect(destination.name).to eq(source.name)
              expect(destination.destination_url).to eq(source.config['url'])
              expect(destination.verification_token).to eq(source.secret_token)
              expect(destination.stream_destination_id).to eq(source.id)
              expect(source.legacy_destination_ref).to eq(destination.id)
              expect(destination.event_type_filters.count).to eq(0)
              expect(destination.namespace_filter).to be_nil
            end
          end
        end

        context 'when group level' do
          let_it_be(:group) { create(:group) }

          let_it_be_with_reload(:source) do
            create(:audit_events_group_external_streaming_destination, :http, group: group)
          end

          let_it_be(:event_type_filter) do
            create(:audit_events_group_event_type_filters,
              external_streaming_destination: source,
              namespace: group,
              audit_event_type: 'user_created')
          end

          let_it_be(:namespace_filter) do
            create(:audit_events_streaming_group_namespace_filters,
              external_streaming_destination: source,
              namespace: group)
          end

          it 'creates legacy destination with basic attributes' do
            destination = helper.create_legacy_destination(source)

            aggregate_failures do
              expect(destination).to be_a(AuditEvents::ExternalAuditEventDestination)
              expect(destination.name).to eq(source.name)
              expect(destination.namespace_id).to eq(group.id)
              expect(destination.destination_url).to eq(source.config['url'])
              expect(destination.verification_token).to eq(source.secret_token)
              expect(destination.stream_destination_id).to eq(source.id)
              expect(source.legacy_destination_ref).to eq(destination.id)
              expect(destination.event_type_filters.count).to eq(0)
              expect(destination.namespace_filter).to be_nil
            end
          end
        end
      end

      describe 'aws destinations' do
        context 'when instance level' do
          let_it_be_with_reload(:source) do
            create(:audit_events_instance_external_streaming_destination, :aws)
          end

          it 'creates legacy destination correctly' do
            destination = helper.create_legacy_destination(source)

            aggregate_failures do
              expect(destination).to be_a(AuditEvents::Instance::AmazonS3Configuration)
              expect(destination.name).to eq(source.name)
              expect(destination.bucket_name).to eq(source.config['bucketName'])
              expect(destination.aws_region).to eq(source.config['awsRegion'])
              expect(destination.access_key_xid).to eq(source.config['accessKeyXid'])
              expect(destination.secret_access_key).to eq(source.secret_token)
              expect(destination.stream_destination_id).to eq(source.id)
              expect(source.legacy_destination_ref).to eq(destination.id)
            end
          end
        end

        context 'when group level' do
          let_it_be(:group) { create(:group) }

          let_it_be_with_reload(:source) do
            create(:audit_events_group_external_streaming_destination, :aws, group: group)
          end

          it 'creates legacy destination correctly' do
            destination = helper.create_legacy_destination(source)

            aggregate_failures do
              expect(destination).to be_a(AuditEvents::AmazonS3Configuration)
              expect(destination.name).to eq(source.name)
              expect(destination.namespace_id).to eq(group.id)
              expect(destination.bucket_name).to eq(source.config['bucketName'])
              expect(destination.aws_region).to eq(source.config['awsRegion'])
              expect(destination.access_key_xid).to eq(source.config['accessKeyXid'])
              expect(destination.secret_access_key).to eq(source.secret_token)
              expect(destination.stream_destination_id).to eq(source.id)
              expect(source.legacy_destination_ref).to eq(destination.id)
            end
          end
        end
      end

      describe 'gcp destinations' do
        context 'when instance level' do
          let_it_be_with_reload(:source) do
            create(:audit_events_instance_external_streaming_destination, :gcp)
          end

          it 'creates legacy destination correctly' do
            destination = helper.create_legacy_destination(source)

            aggregate_failures do
              expect(destination).to be_a(AuditEvents::Instance::GoogleCloudLoggingConfiguration)
              expect(destination.name).to eq(source.name)
              expect(destination.google_project_id_name).to eq(source.config['googleProjectIdName'])
              expect(destination.log_id_name).to eq(source.config['logIdName'])
              expect(destination.client_email).to eq(source.config['clientEmail'])
              expect(destination.private_key).to eq(source.secret_token)
              expect(destination.stream_destination_id).to eq(source.id)
              expect(source.legacy_destination_ref).to eq(destination.id)
            end
          end
        end

        context 'when group level' do
          let_it_be(:group) { create(:group) }

          let_it_be_with_reload(:source) do
            create(:audit_events_group_external_streaming_destination, :gcp, group: group)
          end

          it 'creates legacy destination correctly' do
            destination = helper.create_legacy_destination(source)

            aggregate_failures do
              expect(destination).to be_a(AuditEvents::GoogleCloudLoggingConfiguration)
              expect(destination.name).to eq(source.name)
              expect(destination.google_project_id_name).to eq(source.config['googleProjectIdName'])
              expect(destination.log_id_name).to eq(source.config['logIdName'])
              expect(destination.client_email).to eq(source.config['clientEmail'])
              expect(destination.private_key).to eq(source.secret_token)
              expect(destination.stream_destination_id).to eq(source.id)
              expect(source.legacy_destination_ref).to eq(destination.id)
            end
          end
        end
      end

      context 'when an error occurs during creation' do
        let(:group) { create(:group) }
        let(:source) do
          create(:audit_events_group_external_streaming_destination, :http, group: group)
        end

        let(:mock_destination) { build(:external_audit_event_destination, group: group) }

        before do
          allow(AuditEvents::ExternalAuditEventDestination)
            .to receive(:new)
            .and_return(mock_destination)

          allow(mock_destination)
            .to receive(:save!)
            .and_raise(described_class::CreateError, 'Test error')
        end

        it 'returns nil and tracks the error' do
          expect(Gitlab::ErrorTracking)
            .to receive(:track_exception)
            .with(
              an_instance_of(described_class::CreateError),
              audit_event_destination_model: source.class.name
            )

          expect(helper.create_legacy_destination(source)).to be_nil
        end
      end
    end
  end

  describe '#update_legacy_destination' do
    context 'when feature flag is enabled' do
      describe 'http destinations' do
        context 'when instance level' do
          let_it_be_with_reload(:source) do
            create(:audit_events_instance_external_streaming_destination, :http)
          end

          let_it_be_with_reload(:legacy_destination) do
            create(:instance_external_audit_event_destination)
          end

          before do
            source.update_column(:legacy_destination_ref, legacy_destination.id)
            legacy_destination.update_column(:stream_destination_id, source.id)
          end

          it 'updates legacy destination with new attributes' do
            source.update!(
              name: 'Updated Name',
              active: false,
              config: { 'url' => 'https://new-url.com' },
              secret_token: 'a' * 20
            )

            helper.update_legacy_destination(source)
            legacy_destination.reload

            aggregate_failures do
              expect(legacy_destination.name).to eq('Updated Name')
              expect(legacy_destination.active).to be false
              expect(legacy_destination.destination_url).to eq('https://new-url.com')
              expect(legacy_destination.verification_token).to eq('a' * 20)
              expect(legacy_destination.stream_destination_id).to eq(source.id)
              expect(source.legacy_destination_ref).to eq(legacy_destination.id)
            end
          end
        end

        context 'when group level' do
          let_it_be(:group) { create(:group) }

          let_it_be_with_reload(:source) do
            create(:audit_events_group_external_streaming_destination, :http, group: group)
          end

          let_it_be_with_reload(:legacy_destination) do
            create(:external_audit_event_destination, group: group)
          end

          before do
            source.update_column(:legacy_destination_ref, legacy_destination.id)
            legacy_destination.update_column(:stream_destination_id, source.id)
          end

          it 'updates legacy destination with new attributes' do
            source.update!(
              name: 'Updated Name',
              active: false,
              config: { 'url' => 'https://new-url.com' },
              secret_token: 'a' * 20
            )

            helper.update_legacy_destination(source)
            legacy_destination.reload

            aggregate_failures do
              expect(legacy_destination.name).to eq('Updated Name')
              expect(legacy_destination.active).to be false
              expect(legacy_destination.destination_url).to eq('https://new-url.com')
              expect(legacy_destination.verification_token).to eq('a' * 20)
              expect(legacy_destination.namespace_id).to eq(group.id)
              expect(legacy_destination.stream_destination_id).to eq(source.id)
              expect(source.legacy_destination_ref).to eq(legacy_destination.id)
            end
          end
        end
      end

      describe 'aws destinations' do
        context 'when instance level' do
          let_it_be_with_reload(:source) do
            create(:audit_events_instance_external_streaming_destination, :aws)
          end

          let_it_be_with_reload(:legacy_destination) do
            create(:instance_amazon_s3_configuration)
          end

          before do
            source.update_column(:legacy_destination_ref, legacy_destination.id)
            legacy_destination.update_column(:stream_destination_id, source.id)
          end

          it 'updates legacy destination with new attributes' do
            source.update!(
              name: 'Updated Name',
              active: false,
              config: {
                'bucketName' => 'new-bucket',
                'awsRegion' => 'us-west-2',
                'accessKeyXid' => 'a' * 20
              },
              secret_token: 'new_secret_key'
            )

            helper.update_legacy_destination(source)
            legacy_destination.reload

            aggregate_failures do
              expect(legacy_destination.name).to eq('Updated Name')
              expect(legacy_destination.active).to be false
              expect(legacy_destination.bucket_name).to eq('new-bucket')
              expect(legacy_destination.aws_region).to eq('us-west-2')
              expect(legacy_destination.access_key_xid).to eq('a' * 20)
              expect(legacy_destination.secret_access_key).to eq('new_secret_key')
              expect(legacy_destination.stream_destination_id).to eq(source.id)
              expect(source.legacy_destination_ref).to eq(legacy_destination.id)
            end
          end
        end

        context 'when group level' do
          let_it_be(:group) { create(:group) }

          let_it_be_with_reload(:source) do
            create(:audit_events_group_external_streaming_destination, :aws, group: group)
          end

          let_it_be_with_reload(:legacy_destination) do
            create(:amazon_s3_configuration, group: group)
          end

          before do
            source.update_column(:legacy_destination_ref, legacy_destination.id)
            legacy_destination.update_column(:stream_destination_id, source.id)
          end

          it 'updates legacy destination with new attributes' do
            source.update!(
              name: 'Updated Name',
              active: false,
              config: {
                'bucketName' => 'new-bucket',
                'awsRegion' => 'us-west-2',
                'accessKeyXid' => 'a' * 20
              },
              secret_token: 'new_secret_key'
            )

            helper.update_legacy_destination(source)
            legacy_destination.reload

            aggregate_failures do
              expect(legacy_destination.name).to eq('Updated Name')
              expect(legacy_destination.active).to be false
              expect(legacy_destination.bucket_name).to eq('new-bucket')
              expect(legacy_destination.aws_region).to eq('us-west-2')
              expect(legacy_destination.access_key_xid).to eq('a' * 20)
              expect(legacy_destination.secret_access_key).to eq('new_secret_key')
              expect(legacy_destination.stream_destination_id).to eq(source.id)
              expect(source.legacy_destination_ref).to eq(legacy_destination.id)
            end
          end
        end
      end

      describe 'gcp destinations' do
        context 'when instance level' do
          let_it_be_with_reload(:source) do
            create(:audit_events_instance_external_streaming_destination, :gcp)
          end

          let_it_be_with_reload(:legacy_destination) do
            create(:instance_google_cloud_logging_configuration)
          end

          before do
            source.update_column(:legacy_destination_ref, legacy_destination.id)
            legacy_destination.update_column(:stream_destination_id, source.id)
          end

          it 'updates legacy destination with new attributes' do
            source.update!(
              name: 'Updated Name',
              active: false,
              config: {
                'googleProjectIdName' => 'updated-project-id',
                'clientEmail' => 'test@example.com',
                'logIdName' => 'a' * 20
              },
              secret_token: 'new_secret_key'
            )

            helper.update_legacy_destination(source)
            legacy_destination.reload

            aggregate_failures do
              expect(legacy_destination.name).to eq('Updated Name')
              expect(legacy_destination.active).to be false
              expect(legacy_destination.google_project_id_name).to eq('updated-project-id')
              expect(legacy_destination.client_email).to eq('test@example.com')
              expect(legacy_destination.log_id_name).to eq('a' * 20)
              expect(legacy_destination.private_key).to eq('new_secret_key')
              expect(legacy_destination.stream_destination_id).to eq(source.id)
              expect(source.legacy_destination_ref).to eq(legacy_destination.id)
            end
          end
        end

        context 'when group level' do
          let_it_be(:group) { create(:group) }

          let_it_be_with_reload(:source) do
            create(:audit_events_group_external_streaming_destination, :gcp, group: group)
          end

          let_it_be_with_reload(:legacy_destination) do
            create(:google_cloud_logging_configuration, group: group)
          end

          before do
            source.update_column(:legacy_destination_ref, legacy_destination.id)
            legacy_destination.update_column(:stream_destination_id, source.id)
          end

          it 'updates legacy destination with new attributes' do
            source.update!(
              name: 'Updated Name',
              active: false,
              config: {
                'googleProjectIdName' => 'updated-project-id',
                'clientEmail' => 'test@example.com',
                'logIdName' => 'a' * 20
              },
              secret_token: 'new_secret_key'
            )

            helper.update_legacy_destination(source)
            legacy_destination.reload

            aggregate_failures do
              expect(legacy_destination.name).to eq('Updated Name')
              expect(legacy_destination.active).to be false
              expect(legacy_destination.google_project_id_name).to eq('updated-project-id')
              expect(legacy_destination.client_email).to eq('test@example.com')
              expect(legacy_destination.log_id_name).to eq('a' * 20)
              expect(legacy_destination.private_key).to eq('new_secret_key')
              expect(legacy_destination.stream_destination_id).to eq(source.id)
              expect(source.legacy_destination_ref).to eq(legacy_destination.id)
            end
          end
        end
      end

      context 'when an error occurs during update' do
        let_it_be_with_reload(:source) do
          create(:audit_events_instance_external_streaming_destination, :http)
        end

        let_it_be_with_reload(:legacy_destination) do
          create(:instance_external_audit_event_destination)
        end

        before do
          source.update_column(:legacy_destination_ref, legacy_destination.id)
          legacy_destination.update_column(:stream_destination_id, source.id)

          allow(source).to receive(:legacy_destination).and_return(legacy_destination)

          allow(legacy_destination)
            .to receive(:update!)
            .and_raise(described_class::UpdateError, 'Test error')
        end

        it 'returns nil and tracks the error' do
          expect(Gitlab::ErrorTracking)
            .to receive(:track_exception)
            .with(
              an_instance_of(described_class::UpdateError),
              audit_event_destination_model: source.class.name
            )

          expect(helper.update_legacy_destination(source)).to be_nil
        end
      end
    end
  end
end

# rubocop:enable RSpec/FactoryBot/AvoidCreate
