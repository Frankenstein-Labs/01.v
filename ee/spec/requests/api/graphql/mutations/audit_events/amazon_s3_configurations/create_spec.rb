# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create Amazon S3 configuration', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:destination_name) { 'test_aws_s3_destination' }
  let_it_be(:access_key_id) { 'AKIARANDOMID1234' }
  let_it_be(:secret_access_key) { 'TEST/SECRET/XYZ' }
  let_it_be(:bucket_name) { 'test-bucket' }
  let_it_be(:aws_region) { 'us-east-1' }

  let(:mutation) { graphql_mutation(:audit_events_amazon_s3_configuration_create, input) }
  let(:mutation_response) { graphql_mutation_response(:audit_events_amazon_s3_configuration_create) }

  let(:input) do
    {
      name: destination_name,
      groupPath: group.full_path,
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

      expect(Gitlab::Audit::Auditor).to have_received(:audit) do |args|
        expect(args[:name]).to eq('amazon_s3_configuration_created')
        expect(args[:author]).to eq(current_user)
        expect(args[:scope]).to eq(group)
        expect(args[:target]).to eq(group)
        expect(args[:message]).to eq("Created Amazon S3 configuration with name: #{destination_name} " \
                                     "bucket: #{bucket_name} and AWS region: #{aws_region}")
      end
    end
  end

  shared_examples 'a mutation that does not create a configuration' do
    it 'does not create the configuration' do
      expect { mutate }
        .not_to change { AuditEvents::AmazonS3Configuration.count }
    end

    it 'does not create audit event' do
      expect { mutate }.not_to change { AuditEventReader.count }
    end
  end

  shared_examples 'an unauthorized mutation that does not create a configuration' do
    it_behaves_like 'a mutation on an unauthorized resource'
    it_behaves_like 'a mutation that does not create a configuration'
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is a group owner' do
      before_all do
        group.add_owner(current_user)
      end

      it 'resolves group by full path' do
        expect(::Group).to receive(:find_by_full_path).with(group.full_path).twice

        mutate
      end

      it 'creates the configuration' do
        expect { mutate }
          .to change { AuditEvents::AmazonS3Configuration.count }.by(1)

        config = AuditEvents::AmazonS3Configuration.last
        expect(config.group).to eq(group)
        expect(config.name).to eq(destination_name)
        expect(config.access_key_xid).to eq(access_key_id)
        expect(config.secret_access_key).to eq(secret_access_key)
        expect(config.bucket_name).to eq(bucket_name)
        expect(config.aws_region).to eq(aws_region)
      end

      it_behaves_like 'creates an audit event', 'audit_events'

      it_behaves_like 'creates a streaming destination',
        AuditEvents::AmazonS3Configuration do
        let(:attributes) do
          {
            legacy: {
              bucket_name: bucket_name,
              aws_region: aws_region,
              access_key_xid: access_key_id,
              secret_access_key: secret_access_key,
              namespace_id: group.id,
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
          allow_next_instance_of(AuditEvents::AmazonS3Configuration) do |s3_configuration|
            allow(s3_configuration).to receive(:save).and_return(false)

            errors = ActiveModel::Errors.new(s3_configuration).tap { |e| e.add(:aws_region, 'error message') }
            allow(s3_configuration).to receive(:errors).and_return(errors)
          end
        end

        it 'does not create the configuration and returns the error' do
          expect { mutate }
            .not_to change { AuditEvents::AmazonS3Configuration.count }

          expect(mutation_response).to include(
            'amazonS3Configuration' => nil,
            'errors' => ["Aws region error message"])
        end
      end
    end

    context 'when current user is a group maintainer' do
      before_all do
        group.add_maintainer(current_user)
      end

      it_behaves_like 'an unauthorized mutation that does not create a configuration'
    end

    context 'when current user is a group developer' do
      before_all do
        group.add_developer(current_user)
      end

      it_behaves_like 'an unauthorized mutation that does not create a configuration'
    end

    context 'when current user has guest access' do
      before_all do
        group.add_guest(current_user)
      end

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
    let_it_be(:granular_token_user) { create(:user) }

    before_all do
      group.add_owner(granular_token_user)
    end

    before do
      stub_licensed_features(external_audit_events: true)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_audit_event_streaming_destination do
      let(:user) { granular_token_user }
      let(:boundary_object) { group }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end
end
