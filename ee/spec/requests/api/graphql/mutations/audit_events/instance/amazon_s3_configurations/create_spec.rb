# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create Instance level Amazon S3 configuration', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }
  let_it_be(:destination_name) { 'test_aws_s3_destination' }
  let_it_be(:access_key_id) { 'AKIARANDOMID1234' }
  let_it_be(:secret_access_key) { 'TEST/SECRET/XYZ' }
  let_it_be(:bucket_name) { 'test-bucket' }
  let_it_be(:aws_region) { 'us-east-1' }

  let(:mutation) { graphql_mutation(:audit_events_instance_amazon_s3_configuration_create, input) }
  let(:mutation_response) { graphql_mutation_response(:audit_events_instance_amazon_s3_configuration_create) }

  let(:input) do
    {
      name: destination_name,
      accessKeyXid: access_key_id,
      secretAccessKey: secret_access_key,
      bucketName: bucket_name,
      awsRegion: aws_region
    }
  end

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'creates an audit event' do
    before do
      allow(Gitlab::Audit::Auditor).to receive(:audit)
    end

    it 'audits the creation' do
      subject

      config = AuditEvents::Instance::AmazonS3Configuration.last

      expect(Gitlab::Audit::Auditor).to have_received(:audit) do |args|
        expect(args[:name]).to eq('instance_amazon_s3_configuration_created')
        expect(args[:author]).to eq(current_user)
        expect(args[:scope]).to be_an_instance_of(Gitlab::Audit::InstanceScope)
        expect(args[:target]).to eq(config)
        expect(args[:message])
          .to eq("Created Instance Amazon S3 configuration with name: #{destination_name} " \
                 "bucket: #{bucket_name} and AWS region: #{aws_region}")
      end
    end
  end

  shared_examples 'a mutation that does not create a configuration' do
    it 'does not create the configuration' do
      expect { mutate }.not_to change { AuditEvents::Instance::AmazonS3Configuration.count }
    end

    it 'does not create audit event' do
      expect { mutate }.not_to change { AuditEventReader.count }
    end
  end

  shared_examples 'an unauthorized mutation that does not create a configuration' do
    it_behaves_like 'a mutation that returns top-level errors',
      errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]

    it_behaves_like 'a mutation that does not create a configuration'
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is an admin' do
      it 'creates the configuration', :aggregate_failures do
        expect { mutate }.to change { AuditEvents::Instance::AmazonS3Configuration.count }.by(1)

        config = AuditEvents::Instance::AmazonS3Configuration.last

        expect(config.name).to eq(destination_name)
        expect(config.access_key_xid).to eq(access_key_id)
        expect(config.secret_access_key).to eq(secret_access_key)
        expect(config.bucket_name).to eq(bucket_name)
        expect(config.aws_region).to eq(aws_region)

        expect(mutation_response['errors']).to be_empty
        expect(mutation_response['instanceAmazonS3Configuration']['accessKeyXid']).to eq(access_key_id)
        expect(mutation_response['instanceAmazonS3Configuration']['id']).not_to be_empty
        expect(mutation_response['instanceAmazonS3Configuration']['secretAccessKey']).to be_nil
        expect(mutation_response['instanceAmazonS3Configuration']['bucketName']).to eq(bucket_name)
        expect(mutation_response['instanceAmazonS3Configuration']['awsRegion']).to eq(aws_region)
      end

      it_behaves_like 'creates an audit event', 'audit_events'

      it_behaves_like 'creates a streaming destination',
        AuditEvents::Instance::AmazonS3Configuration do
          let(:attributes) do
            {
              legacy: {
                bucket_name: bucket_name,
                aws_region: aws_region,
                access_key_xid: access_key_id,
                secret_access_key: secret_access_key,
                name: destination_name
              },
              streaming: {
                "bucketName" => bucket_name,
                "awsRegion" => aws_region,
                "accessKeyXid" => access_key_id
              }
            }
          end
        end

      context 'when there is error while saving' do
        before do
          allow_next_instance_of(AuditEvents::Instance::AmazonS3Configuration) do |s3_configuration|
            allow(s3_configuration).to receive(:save).and_return(false)
            errors = ActiveModel::Errors.new(s3_configuration).tap { |e| e.add(:bucket_name, 'invalid name') }
            allow(s3_configuration).to receive(:errors).and_return(errors)
          end
        end

        it 'does not create the configuration and returns the error' do
          expect { mutate }.not_to change { AuditEvents::Instance::AmazonS3Configuration.count }

          expect(mutation_response).to include(
            'instanceAmazonS3Configuration' => nil,
            'errors' => ["Bucket name invalid name"]
          )
        end
      end
    end

    context 'when current user is not an admin' do
      let_it_be(:current_user) { create(:user) }

      it_behaves_like 'an unauthorized mutation that does not create a configuration'
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'an unauthorized mutation that does not create a configuration'
  end

  context 'with granular token authorization' do
    let_it_be(:granular_token_user) { create(:admin) }

    before do
      stub_licensed_features(external_audit_events: true)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_audit_event_streaming_destination do
      let(:user) { granular_token_user }
      let(:boundary_object) { :instance }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end
end
