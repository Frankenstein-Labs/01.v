# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Streaming::Destinations::AmazonS3StreamDestination, feature_category: :audit_events do
  let_it_be(:audit_event) { create(:audit_event, :group_event) }
  let(:event_type) { 'event_type' }
  let(:destination) { create(:audit_events_instance_external_streaming_destination, :aws) }
  let(:s3_destination) { described_class.new(event_type, audit_event, destination) }

  describe '#stream' do
    let(:aws_s3_client) { instance_double(Aws::S3Client) }
    let(:bucket_name) { 'test-bucket' }
    let(:filename) { 'group/2023/09/event_type_1_1694441509820.json' }

    before do
      allow(s3_destination).to receive_messages(
        aws_s3_client: aws_s3_client,
        bucket_name: bucket_name,
        filename: filename
      )
    end

    it 'uploads the audit event to S3' do
      expect(aws_s3_client).to receive(:upload_object).with(
        filename,
        bucket_name,
        kind_of(String),
        'application/json'
      )

      s3_destination.stream
    end

    context 'when an error occurs' do
      before do
        allow(aws_s3_client).to receive(:upload_object).and_raise(StandardError.new('Unexpected error'))
      end

      it 'raises the exception to be handled by the caller' do
        expect { s3_destination.stream }.to raise_error(StandardError, 'Unexpected error')
      end
    end

    context 'when S3 specific error occurs' do
      before do
        allow(aws_s3_client).to receive(:upload_object).and_raise(Aws::S3::Errors::ServiceError.new(nil,
          "S3 Service Error"))
      end

      it 'raises the exception to be handled by the caller' do
        expect { s3_destination.stream }.to raise_error(Aws::S3::Errors::ServiceError)
      end
    end
  end

  describe '#filename' do
    subject(:filename) { s3_destination.send(:filename, payload) }

    let(:payload) { s3_destination.send(:request_body) }

    it 'returns the correct filename format' do
      expect(filename).to match(%r{group/\d{4}/\d{2}/event_type_\d+_\d+\.json})
    end

    context 'when entity_type is Gitlab::Audit::InstanceScope' do
      let(:audit_event) { create(:audit_event, :instance_event) }

      it 'uses "instance" in the filename' do
        expect(filename).to start_with('instance/')
      end
    end

    context 'when entity_type is Namespaces::UserNamespace' do
      let(:audit_event) { create(:audit_event, entity_type: "Namespaces::UserNamespace") }

      it 'uses "user" in the filename' do
        expect(filename).to start_with('user/')
      end
    end

    context 'when entity_type is neither Namespaces::UserNamespace or Gitlab::Audit::InstanceScope' do
      let(:audit_event) { create(:audit_event, entity_type: "Other::Entity::Type") }

      it 'uses "other_entity_type" in the filename' do
        expect(filename).to start_with('other_entity_type/')
      end
    end

    context 'when audit_event["entity_type"] is nil' do
      let(:audit_event) do
        create(:audit_event, :group_event).tap do |event|
          allow(event).to receive(:[]).with('entity_type').and_return(nil)
          allow(event).to receive(:as_json).and_return(
            event.attributes.merge('entity_type' => 'Group')
          )
        end
      end

      it 'falls back to parsing entity_type from payload' do
        expect(::Gitlab::Json).to receive(:parse).with(payload, any_args).at_least(:once).and_call_original
        expect(filename).to start_with('group/')
      end
    end

    context 'when audit_event["entity_type"] is present' do
      let(:audit_event) { create(:audit_event, entity_type: 'Project') }

      it 'uses audit_event["entity_type"] without parsing payload' do
        expect(::Gitlab::Json).to receive(:parse).with(payload, any_args).once.and_call_original
        expect(filename).to start_with('project/')
      end
    end

    context 'when audit_event["entity_type"] is nil and payload contains Gitlab::Audit::InstanceScope' do
      let(:audit_event) do
        create(:audit_event, :instance_event).tap do |event|
          allow(event).to receive(:[]).with('entity_type').and_return(nil)
          allow(event).to receive(:as_json).and_return(
            event.attributes.merge('entity_type' => 'Gitlab::Audit::InstanceScope')
          )
        end
      end

      it 'correctly maps to "instance" from payload' do
        expect(filename).to start_with('instance/')
      end
    end

    context 'when audit_event["entity_type"] is nil and payload contains Namespaces::UserNamespace' do
      let(:audit_event) do
        create(:audit_event).tap do |event|
          allow(event).to receive(:[]).with('entity_type').and_return(nil)
          allow(event).to receive(:as_json).and_return(
            event.attributes.merge('entity_type' => 'Namespaces::UserNamespace')
          )
        end
      end

      it 'correctly maps to "user" from payload' do
        expect(filename).to start_with('user/')
      end
    end

    context 'when audit_event entity_type is nil and payload is malformed' do
      let(:audit_event) { build_stubbed(:audit_event, entity_type: nil) }
      let(:payload) { 'malformed json' }

      it 'does not raise an error and generates a filename with unspecified entity type' do
        expect { filename }.not_to raise_error
        expect(filename).to match(%r{^unspecified/\d{4}/\d{2}/event_type__\d+\.json$})
      end
    end

    context 'when Gitlab::Json.safe_parse returns nil' do
      before do
        allow(::Gitlab::Json).to receive(:safe_parse).with(payload).and_return(nil)
      end

      it 'does not raise an error and generates filename without id' do
        expect { filename }.not_to raise_error
        expect(filename).to match(%r{group/\d{4}/\d{2}/event_type__\d+\.json})
      end
    end
  end

  describe '#aws_s3_client' do
    it 'initializes an AWS S3 client with correct credentials' do
      expect(Aws::S3Client).to receive(:new).with(
        destination.config["accessKeyXid"],
        destination.secret_token,
        destination.config["awsRegion"]
      )

      s3_destination.send(:aws_s3_client)
    end

    it 'memoizes the client' do
      client = instance_double(Aws::S3Client)
      allow(Aws::S3Client).to receive(:new).and_return(client)

      expect(s3_destination.send(:aws_s3_client)).to eq(client)
      expect(Aws::S3Client).to have_received(:new).once

      expect(s3_destination.send(:aws_s3_client)).to eq(client)
      expect(Aws::S3Client).to have_received(:new).once
    end
  end

  describe '#bucket_name' do
    it 'returns the bucket name from the destination configuration' do
      expect(s3_destination.send(:bucket_name)).to eq(destination.config["bucketName"])
    end
  end

  describe '#stream_batch' do
    let(:batch_destination) { described_class.for_batch(destination) }
    let(:aws_s3_client) { instance_double(Aws::S3Client) }
    let(:event_bodies) do
      [
        { 'id' => '10', 'event_type' => 'type_a', 'entity_type' => 'Project' },
        { 'id' => '11', 'event_type' => 'type_b', 'entity_type' => 'Group' }
      ]
    end

    before do
      allow(batch_destination).to receive_messages(aws_s3_client: aws_s3_client, bucket_name: 'test-bucket')
    end

    it 'writes a single object with a date-partitioned, collision-safe key', :aggregate_failures do
      expect(aws_s3_client).to receive(:upload_object) do |key, bucket, body, content_type|
        expect(bucket).to eq('test-bucket')
        expect(content_type).to eq('application/json')
        # YYYY/MM/DD/<time_in_ms>_<first_id>.json - no entity-type segment
        # (batch may mix entity types), time leads for chronological sort,
        # first_id is the uniqueness tiebreaker.
        expect(key).to match(%r{\A\d{4}/\d{2}/\d{2}/\d+_10\.json\z})
        expect(::Gitlab::Json.safe_parse(body).size).to eq(2)
      end

      batch_destination.stream_batch(event_bodies)
    end
  end
end
