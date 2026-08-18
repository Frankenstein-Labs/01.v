# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create an external audit event destination', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:config) do
    {
      "url" => 'https://gitlab.com/example/testendpoint'
    }
  end

  let(:current_user) { owner }
  let(:mutation) { graphql_mutation(:group_audit_event_streaming_destinations_create, input) }
  let(:mutation_response) { graphql_mutation_response(:group_audit_event_streaming_destinations_create) }

  let(:input) do
    {
      groupPath: group.full_path,
      config: config,
      category: 'http',
      secretToken: 'some_secret_token'
    }
  end

  shared_examples 'creates an audit event' do
    it 'audits the creation' do
      expect { subject }
        .to change { AuditEventReader.count }.by(1)
    end
  end

  shared_examples 'a mutation that does not create a destination' do
    it 'does not destroy the destination' do
      expect { post_graphql_mutation(mutation, current_user: owner) }
        .not_to change { AuditEvents::Group::ExternalStreamingDestination.count }
    end

    it 'does not audit the creation' do
      expect { post_graphql_mutation(mutation, current_user: owner) }
        .not_to change { AuditEventReader.count }
    end
  end

  context 'when feature is licensed' do
    subject(:mutate) { post_graphql_mutation(mutation, current_user: owner) }

    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is a group owner' do
      before_all do
        group.add_owner(owner)
      end

      let(:attributes) do
        {
          legacy: {
            destination_url: config["url"],
            namespace_id: group.id,
            verification_token: 'some_secret_token'
          },
          streaming: {
            "url" => config["url"]
          }
        }
      end

      it 'resolves group by full path' do
        expect(::Group).to receive(:find_by_full_path).with(group.full_path).twice

        mutate
      end

      it 'creates the destination' do
        expect { mutate }
          .to change { AuditEvents::Group::ExternalStreamingDestination.count }.by(1)

        destination = AuditEvents::Group::ExternalStreamingDestination.last
        expect(destination.group).to eq(group)
        expect(destination.config).to eq(config)
        expect(destination.name).not_to be_empty
        expect(destination.category).to eq('http')
        expect(destination.secret_token).to eq('some_secret_token')
      end

      it_behaves_like 'creates an audit event'

      it_behaves_like 'creates a legacy destination',
        AuditEvents::Group::ExternalStreamingDestination,
        -> { attributes }

      context 'when category is aws' do
        let(:config) do
          {
            "accessKeyXid" => SecureRandom.hex(8),
            "bucketName" => SecureRandom.hex(8),
            "awsRegion" => "ap-south-2"
          }
        end

        let(:input) do
          {
            groupPath: group.full_path,
            config: config,
            category: 'aws',
            secret_token: 'some_secret_token'
          }
        end

        let(:attributes) do
          {
            legacy: {
              access_key_xid: config["accessKeyXid"],
              bucket_name: config["bucketName"],
              aws_region: config["awsRegion"],
              namespace_id: group.id,
              secret_access_key: 'some_secret_token'
            },
            streaming: {
              "accessKeyXid" => config["accessKeyXid"],
              "bucketName" => config["bucketName"],
              "awsRegion" => config["awsRegion"]
            }
          }
        end

        it 'creates the destination' do
          expect { mutate }
            .to change { AuditEvents::Group::ExternalStreamingDestination.count }.by(1)

          destination = AuditEvents::Group::ExternalStreamingDestination.last
          expect(destination.group).to eq(group)
          expect(destination.config).to eq(config)
          expect(destination.name).not_to be_empty
          expect(destination.category).to eq('aws')
          expect(destination.secret_token).to eq('some_secret_token')
        end

        it_behaves_like 'creates a legacy destination',
          AuditEvents::Group::ExternalStreamingDestination,
          -> { attributes }
      end

      context 'when category is gcp' do
        let(:config) do
          {
            "googleProjectIdName" => "#{FFaker::Lorem.word.downcase}-#{SecureRandom.hex(4)}",
            "clientEmail" => FFaker::Internet.safe_email,
            "logIdName" => "audit_events"
          }
        end

        let(:input) do
          {
            groupPath: group.full_path,
            config: config,
            category: 'gcp',
            secret_token: 'some_secret_token'
          }
        end

        let(:attributes) do
          {
            legacy: {
              google_project_id_name: config["googleProjectIdName"],
              client_email: config["clientEmail"],
              log_id_name: config["logIdName"],
              namespace_id: group.id,
              private_key: 'some_secret_token'
            },
            streaming: {
              "googleProjectIdName" => config["googleProjectIdName"],
              "clientEmail" => config["clientEmail"],
              "logIdName" => config["logIdName"]
            }
          }
        end

        it 'creates the destination' do
          expect { mutate }
            .to change { AuditEvents::Group::ExternalStreamingDestination.count }.by(1)

          destination = AuditEvents::Group::ExternalStreamingDestination.last
          expect(destination.group).to eq(group)
          expect(destination.config).to eq(config)
          expect(destination.name).not_to be_empty
          expect(destination.category).to eq('gcp')
          expect(destination.secret_token).to eq('some_secret_token')
        end

        it_behaves_like 'creates a legacy destination',
          AuditEvents::Group::ExternalStreamingDestination,
          -> { attributes }
      end

      context 'for category' do
        context 'when category is invalid' do
          let(:input) do
            {
              groupPath: group.full_path,
              config: config,
              category: 'invalid',
              secret_token: 'some_secret_token'
            }
          end

          it_behaves_like 'a mutation that does not create a destination'
        end

        context 'when category is not provided' do
          let(:input) do
            {
              groupPath: group.full_path,
              config: config,
              secret_token: 'some_secret_token'
            }
          end

          it_behaves_like 'a mutation that does not create a destination'
        end
      end

      context 'when secret_token is not provided' do
        let(:input) do
          {
            groupPath: group.full_path,
            config: config,
            category: 'http'
          }
        end

        it 'creates the destination' do
          expect { mutate }
            .to change { AuditEvents::Group::ExternalStreamingDestination.count }.by(1)

          destination = AuditEvents::Group::ExternalStreamingDestination.last
          expect(destination.group).to eq(group)
          expect(destination.config).to eq(config)
          expect(destination.name).not_to be_empty
          expect(destination.category).to eq('http')
          expect(destination.secret_token).to be_present
        end
      end

      context 'when secret_token is not provided for required destination' do
        let(:input) do
          {
            groupPath: group.full_path,
            config: config,
            category: 'aws'
          }
        end

        it 'returns an error' do
          mutate

          expect(mutation_response["errors"]).to eq(["Secret token is required for category"])
          expect(mutation_response["externalAuditEventDestination"]).to be_nil
        end
      end

      context 'for config' do
        context 'when config is invalid' do
          let(:input) do
            {
              groupPath: group.full_path,
              config: "string_value",
              category: 'http',
              secret_token: 'some_secret_token'
            }
          end

          it_behaves_like 'a mutation that does not create a destination'
        end

        context 'when config is not provided' do
          let(:input) do
            {
              groupPath: group.full_path,
              category: 'http',
              secret_token: 'some_secret_token'
            }
          end

          it_behaves_like 'a mutation that does not create a destination'
        end
      end

      context 'when group is a subgroup' do
        let_it_be(:group) { create(:group, :nested) }

        it_behaves_like 'a mutation that does not create a destination'
      end
    end

    context 'when current user is a group maintainer' do
      before_all do
        group.add_maintainer(owner)
      end

      it_behaves_like 'a mutation that does not create a destination'
    end

    context 'when current user is a group developer' do
      before_all do
        group.add_developer(owner)
      end

      it_behaves_like 'a mutation that does not create a destination'
    end

    context 'when current user is a group guest' do
      before_all do
        group.add_guest(owner)
      end

      it_behaves_like 'a mutation that does not create a destination'
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'a mutation on an unauthorized resource'

    it 'does not create the destination' do
      expect { post_graphql_mutation(mutation, current_user: owner) }
        .not_to change { AuditEvents::Group::ExternalStreamingDestination.count }
    end
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
