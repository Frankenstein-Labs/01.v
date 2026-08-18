# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update instance level external audit event destination', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be_with_reload(:destination) { create(:audit_events_instance_external_streaming_destination, :aws) }
  let_it_be(:current_user) { create(:admin) }
  let_it_be(:updated_config) do
    {
      "accessKeyXid" => 'AKIA1234RANDOM5678',
      "bucketName" => 'test-rspec-bucket',
      "awsRegion" => 'us-east-2'
    }
  end

  let_it_be(:updated_secret_token) { 'TEST/SECRET/XYZ/PQR' }
  let_it_be(:updated_category) { 'aws' }
  let_it_be(:updated_destination_name) { 'updated_destination_name' }
  let_it_be(:destination_gid) { global_id_of(destination) }

  let(:mutation) { graphql_mutation(:instance_audit_event_streaming_destinations_update, input) }
  let(:mutation_response) { graphql_mutation_response(:instance_audit_event_streaming_destinations_update) }
  let(:mutation_name) { :instance_audit_event_streaming_destinations_update }
  let(:mutation_field) { 'externalAuditEventDestination' }
  let(:model) { destination }
  let(:event_name) { 'updated_instance_audit_event_streaming_destination' }

  let(:input) do
    {
      id: destination_gid,
      config: updated_config,
      name: updated_destination_name,
      category: updated_category,
      secret_token: updated_secret_token,
      active: true
    }
  end

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'a mutation that does not update the instance destination' do
    it 'does not update the destination' do
      expect { mutate }.not_to change { destination.reload.attributes }
    end

    it 'does not create audit event' do
      expect { mutate }.not_to change { AuditEventReader.count }
    end
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is instance admin' do
      before_all do
        destination.deactivate!
      end

      before do
        allow(Gitlab::Audit::Auditor).to receive(:audit)
      end

      context 'when updating active status with limits' do
        let(:plan_limit) { 3 }

        before do
          AuditEvents::Instance::ExternalStreamingDestination
            .where.not(id: destination.id)
            .delete_all

          plan = Plan.default
          plan.actual_limits.update!(external_audit_event_destinations: plan_limit)
        end

        context 'when activating would exceed the limit' do
          before do
            destinations_data = Array.new(plan_limit) do |i|
              {
                name: "Test Destination #{i}",
                category: 0,
                config: { url: "https://example#{i}.com" }.to_json,
                encrypted_secret_token: SecureRandom.hex(32),
                encrypted_secret_token_iv: SecureRandom.hex(8),
                active: true,
                created_at: Time.current,
                updated_at: Time.current
              }
            end

            AuditEvents::Instance::ExternalStreamingDestination.insert_all!(destinations_data)
          end

          it 'returns an error' do
            input[:active] = true

            mutate

            expect(mutation_response['errors']).to include(
              "Cannot activate: Maximum number of external audit event destinations (#{plan_limit}) exceeded"
            )
            expect(mutation_response['externalAuditEventDestination']).to be_nil
            expect(destination.reload.active).to be false
          end

          it 'allows updating other fields without changing active status' do
            input.delete(:active)

            mutate

            expect(mutation_response['errors']).to be_empty
            expect(mutation_response['externalAuditEventDestination']).to be_present
            destination.reload
            expect(destination.config).to eq(updated_config)
            expect(destination.name).to eq(updated_destination_name)
            expect(destination.active).to be false
          end
        end

        context 'when activating within the limit' do
          before do
            destinations_data = Array.new((plan_limit - 1)) do |i|
              {
                name: "Test Destination #{i}",
                category: 0,
                config: { url: "https://example#{i}.com" }.to_json,
                encrypted_secret_token: SecureRandom.hex(32),
                encrypted_secret_token_iv: SecureRandom.hex(8),
                active: true,
                created_at: Time.current,
                updated_at: Time.current
              }
            end

            AuditEvents::Instance::ExternalStreamingDestination.insert_all!(destinations_data)
          end

          it 'allows activation' do
            mutate

            expect(mutation_response['errors']).to be_empty
            expect(mutation_response['externalAuditEventDestination']).to be_present
            expect(destination.reload.active).to be true
          end
        end

        context 'when deactivating' do
          before do
            destinations_data = Array.new((plan_limit - 1)) do |i|
              {
                name: "Test Destination #{i}",
                category: 0,
                config: { url: "https://example#{i}.com" }.to_json,
                encrypted_secret_token: SecureRandom.hex(32),
                encrypted_secret_token_iv: SecureRandom.hex(8),
                active: true,
                created_at: Time.current,
                updated_at: Time.current
              }
            end

            AuditEvents::Instance::ExternalStreamingDestination.insert_all!(destinations_data)

            destination.update_column(:active, true)
          end

          it 'always allows deactivation' do
            input[:active] = false

            mutate

            expect(mutation_response['errors']).to be_empty
            expect(mutation_response['externalAuditEventDestination']).to be_present
            expect(destination.reload.active).to be false
          end
        end

        context 'when destination is already active' do
          before do
            destinations_data = Array.new((plan_limit - 1)) do |i|
              {
                name: "Test Destination #{i}",
                category: 0,
                config: { url: "https://example#{i}.com" }.to_json,
                encrypted_secret_token: SecureRandom.hex(32),
                encrypted_secret_token_iv: SecureRandom.hex(8),
                active: true,
                created_at: Time.current,
                updated_at: Time.current
              }
            end

            AuditEvents::Instance::ExternalStreamingDestination.insert_all!(destinations_data)

            destination.update_column(:active, true)
          end

          it 'allows updating an already active destination' do
            mutate

            expect(mutation_response['errors']).to be_empty
            expect(mutation_response['externalAuditEventDestination']).to be_present
            expect(destination.reload.active).to be true
            expect(destination.config).to eq(updated_config)
          end
        end
      end

      it 'updates the destination' do
        mutate

        destination.reload

        expect(destination.config).to eq(updated_config)
        expect(destination.name).to eq(updated_destination_name)
        expect(destination.category).to eq(updated_category)
        expect(destination.secret_token).to eq(updated_secret_token)
        expect(destination.active).to be(true)
      end

      it 'audits the update' do
        Mutations::AuditEvents::Instance::AuditEventStreamingDestinations::Update::AUDIT_EVENT_COLUMNS.each do |column|
          current_value = destination[column]
          new_value = input[column.to_s.camelize(:lower).to_sym]

          next if column == :active && current_value == new_value
          next if new_value.nil? || current_value == new_value

          message = if column == :secret_token
                      "Changed #{column}"
                    else
                      "Changed #{column} from #{current_value} to #{new_value}"
                    end

          expected_hash = {
            name: Mutations::AuditEvents::Instance::AuditEventStreamingDestinations::Update::UPDATE_EVENT_NAME,
            author: current_user,
            scope: an_instance_of(Gitlab::Audit::InstanceScope),
            target: destination,
            message: message
          }

          expect(Gitlab::Audit::Auditor).to receive(:audit).once.ordered.with(hash_including(expected_hash))
        end

        mutate
      end

      context 'when the fields are updated with existing values' do
        let(:input) do
          {
            id: destination_gid,
            config: destination.config,
            name: destination.name
          }
        end

        it 'does not audit the event' do
          expect(Gitlab::Audit::Auditor).not_to receive(:audit)
          mutate
        end
      end

      context 'when no fields are provided for update' do
        let(:input) do
          {
            id: destination_gid
          }
        end

        it_behaves_like 'a mutation that does not update the instance destination'
      end

      context 'when there is error while updating' do
        before do
          allow_next_instance_of(
            Mutations::AuditEvents::Instance::AuditEventStreamingDestinations::Update) do |mutation|
            allow(mutation).to receive(:authorized_find!).with(id: destination_gid).and_return(destination)
          end

          allow(destination).to receive(:update).and_return(false)

          errors = ActiveModel::Errors.new(destination).tap { |e| e.add(:base, 'error message') }
          allow(destination).to receive(:errors).and_return(errors)
        end

        it 'does not update the destination and returns the error' do
          mutate

          expect(mutation_response).to include(
            'externalAuditEventDestination' => nil,
            'errors' => ['error message']
          )
        end
      end

      context 'when destination is updated' do
        let(:legacy_destination) { create(:instance_amazon_s3_configuration, stream_destination_id: destination.id) }

        before do
          destination.activate!
        end

        it_behaves_like 'audits streaming active status changes'

        it_behaves_like 'updates a legacy destination', :destination,
          proc {
            {
              legacy: {
                bucket_name: updated_config["bucketName"],
                aws_region: updated_config["awsRegion"],
                access_key_xid: updated_config["accessKeyXid"],
                name: updated_destination_name
              },
              streaming: {
                "accessKeyXid" => updated_config["accessKeyXid"],
                "bucketName" => updated_config["bucketName"],
                "awsRegion" => updated_config["awsRegion"],
                "name" => updated_destination_name
              }
            }
          }
      end

      context 'when only specific fields are updated' do
        before do
          allow(Gitlab::Audit::Auditor).to receive(:audit)
        end

        let(:input) do
          {
            id: destination_gid,
            config: updated_config,
            name: updated_destination_name
          }
        end

        it 'only audits the changed attributes' do
          expect(Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: Mutations::AuditEvents::Instance::AuditEventStreamingDestinations::Update::UPDATE_EVENT_NAME,
              author: current_user,
              scope: an_instance_of(Gitlab::Audit::InstanceScope),
              target: destination,
              message: "Changed config from #{destination.config} to #{updated_config}"
            )
          ).once

          expect(Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: Mutations::AuditEvents::Instance::AuditEventStreamingDestinations::Update::UPDATE_EVENT_NAME,
              author: current_user,
              scope: an_instance_of(Gitlab::Audit::InstanceScope),
              target: destination,
              message: "Changed name from #{destination.name} to #{updated_destination_name}"
            )
          ).once

          expect(Gitlab::Audit::Auditor).not_to receive(:audit).with(
            hash_including(message: /Changed category/)
          )

          expect(Gitlab::Audit::Auditor).not_to receive(:audit).with(
            hash_including(message: /Changed secret_token/)
          )

          expect(Gitlab::Audit::Auditor).not_to receive(:audit).with(
            hash_including(message: /Changed active/)
          )

          mutate

          destination.reload
          expect(destination.config).to eq(updated_config)
          expect(destination.name).to eq(updated_destination_name)
          expect(destination.category).to eq('aws')
          expect(destination.secret_token).not_to eq(updated_secret_token)
        end
      end
    end

    context 'when current user is not instance admin' do
      let_it_be(:current_user) { create(:user) }

      it_behaves_like 'a mutation on an unauthorized resource'
      it_behaves_like 'a mutation that does not update the instance destination'
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
    it_behaves_like 'a mutation that does not update the instance destination'
  end

  context 'with granular token authorization' do
    let_it_be(:granular_token_user) { create(:admin) }

    before do
      stub_licensed_features(external_audit_events: true)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_audit_event_streaming_destination do
      let(:user) { granular_token_user }
      let(:boundary_object) { :instance }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end
end
