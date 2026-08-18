# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create an instance level external audit event destination', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:owner) { create(:admin) }
  let_it_be(:config) do
    {
      "url" => 'https://gitlab.com/example/testendpoint'
    }
  end

  let(:current_user) { owner }
  let(:mutation) { graphql_mutation(:instance_audit_event_streaming_destinations_create, input) }
  let(:mutation_response) { graphql_mutation_response(:instance_audit_event_streaming_destinations_create) }

  let(:input) do
    {
      config: config,
      category: 'http',
      secretToken: 'random_secret_token'
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
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .not_to change { AuditEvents::Instance::ExternalStreamingDestination.count }
    end

    it 'does not audit the creation' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .not_to change { AuditEventReader.count }
    end
  end

  context 'when feature is licensed' do
    subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

    let(:attributes) do
      {
        legacy: {
          destination_url: config["url"],
          verification_token: 'random_secret_token'
        },
        streaming: {
          "url" => config["url"]
        }
      }
    end

    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is instance admin' do
      context 'when destination fails to save' do
        before do
          allow_next_instance_of(AuditEvents::Instance::ExternalStreamingDestination) do |instance|
            allow(instance).to receive_message_chain(:errors, :any?).and_return(true)
            allow(instance).to receive_messages(save: false, persisted?: false, errors: ['Name is required'])
          end
        end

        it 'does not create audit event or legacy destination' do
          expect(AuditEvents::InstanceExternalAuditEventDestination).not_to receive(:new)

          expect { mutate }
            .to not_change { AuditEventReader.count }
            .and not_change { AuditEvents::InstanceExternalAuditEventDestination.count }

          expect(mutation_response['externalAuditEventDestination']).to be_nil
          expect(mutation_response['errors'].join).to include('Name is required')
        end
      end

      it 'creates the destination' do
        expect { mutate }
          .to change { AuditEvents::Instance::ExternalStreamingDestination.count }.by(1)

        destination = AuditEvents::Instance::ExternalStreamingDestination.last
        expect(destination.config).to eq(config)
        expect(destination.name).not_to be_empty
        expect(destination.category).to eq('http')
        expect(destination.secret_token).to eq('random_secret_token')
      end

      it_behaves_like 'creates an audit event'

      it_behaves_like 'creates a legacy destination',
        AuditEvents::Instance::ExternalStreamingDestination,
        -> { attributes }

      context 'for category' do
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
              .to change { AuditEvents::Instance::ExternalStreamingDestination.count }.by(1)

            destination = AuditEvents::Instance::ExternalStreamingDestination.last
            expect(destination.config).to eq(config)
            expect(destination.name).not_to be_empty
            expect(destination.category).to eq('aws')
            expect(destination.secret_token).to eq('some_secret_token')
          end

          it_behaves_like 'creates a legacy destination',
            AuditEvents::Instance::ExternalStreamingDestination,
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
              .to change { AuditEvents::Instance::ExternalStreamingDestination.count }.by(1)

            destination = AuditEvents::Instance::ExternalStreamingDestination.last
            expect(destination.config).to eq(config)
            expect(destination.name).not_to be_empty
            expect(destination.category).to eq('gcp')
            expect(destination.secret_token).to eq('some_secret_token')
          end

          it_behaves_like 'creates a legacy destination',
            AuditEvents::Instance::ExternalStreamingDestination,
            -> { attributes }
        end

        context 'when category is invalid' do
          let(:input) do
            {
              config: config,
              category: 'invalid',
              secretToken: 'random_secret_token'
            }
          end

          it_behaves_like 'a mutation that does not create a destination'
        end

        context 'when category is not provided' do
          let(:input) do
            {
              config: config,
              secretToken: 'random_secret_token'
            }
          end

          it_behaves_like 'a mutation that does not create a destination'
        end
      end

      context 'when secret_token is not provided for non http category' do
        let(:input) do
          {
            config: config,
            category: 'aws'
          }
        end

        it_behaves_like 'a mutation that does not create a destination'
      end

      context 'when secret_token is not provided for http category' do
        let(:input) do
          {
            config: config,
            category: 'http'
          }
        end

        it 'creates a destination with an auto-generated secret token' do
          expect { mutate }
          .to change { AuditEvents::Instance::ExternalStreamingDestination.count }.by(1)

          destination = AuditEvents::Instance::ExternalStreamingDestination.last

          expect(destination.secret_token).not_to be_empty
          expect(destination.secret_token).not_to eq('random_secret_token')
          expect(mutation_response['externalAuditEventDestination']['secretToken']).to eq(destination.secret_token)
        end

        it_behaves_like 'creates an audit event'
      end

      context 'for config' do
        context 'when config is invalid' do
          let(:input) do
            {
              config: "string_value",
              category: 'http',
              secretToken: 'random_secret_token'
            }
          end

          it_behaves_like 'a mutation that does not create a destination'
        end

        context 'when config is not provided' do
          let(:input) do
            {
              category: 'http',
              secretToken: 'random_secret_token'
            }
          end

          it_behaves_like 'a mutation that does not create a destination'
        end
      end
    end

    context 'when current user is not instance admin' do
      let(:current_user) { create(:user) }

      it_behaves_like 'a mutation that does not create a destination'
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'a mutation on an unauthorized resource'

    it 'does not create the destination' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .not_to change { AuditEvents::Instance::ExternalStreamingDestination.count }
    end
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
