# frozen_string_literal: true

RSpec.shared_examples 'a service for creating a secret' do |resource_type|
  describe '#execute' do
    context "when the #{resource_type} secrets manager is active" do
      before do
        provision_secrets_manager(secrets_manager, user)
      end

      it_behaves_like "an operation requiring an exclusive #{resource_type} secret operation lease"

      it 'enqueues the namespace secret count refresh worker with the actor user id' do
        expect(SecretsManagement::ReconcileNamespaceSecretCountWorker)
          .to receive(:perform_async)
          .with(secrets_manager.namespace_id_for_secret_count, user.id)

        expect(result).to be_success
      end

      it 'creates a secret successfully', :freeze_time do
        frozen_time = Time.current.utc.iso8601

        expect(result).to be_success
        secret = result.payload[:secret]
        expect(secret).to be_present
        expect(secret.name).to eq(name)
        expect(secret.description).to eq(description)
        expect(secret.metadata_version).to eq(2)

        # Verify secret value in OpenBao
        expect_kv_secret_to_have_value(
          full_namespace_path,
          secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          value
        )

        # Verify metadata version (2 for group secrets, rotation_info.secret_metadata_version + 1 for project secrets)
        expected_metadata_version = secret.rotation_info ? secret.rotation_info.secret_metadata_version + 1 : 2
        expect_kv_secret_to_have_metadata_version(
          full_namespace_path,
          secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          expected_metadata_version
        )

        # Verify custom metadata
        expected_metadata = {
          "description" => description,
          "create_completed_at" => frozen_time
        }

        # Add rotation info ID if present
        expected_metadata["secret_rotation_info_id"] = secret.rotation_info.id.to_s if secret.rotation_info

        expect_kv_secret_to_have_custom_metadata(
          full_namespace_path,
          secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          expected_metadata
        )
      end

      shared_examples_for 'rejecting secrets that exist' do
        it 'fails' do
          expect(result).to be_error
          expect(result.message).to eq('Secret already exists.')
        end
      end

      context 'when the secret is created but initial metadata update fail' do
        before do
          allow_next_instance_of(described_class) do |svc|
            allow(svc).to receive(:user_client).and_wrap_original do |orig|
              client = orig.call

              failed_once = false

              allow(client).to receive(:update_kv_secret_metadata).and_wrap_original do |orig_ud, *args, **kwargs|
                if !failed_once && kwargs[:metadata_cas] == 0
                  failed_once = true
                  raise SecretsManagement::SecretsManagerClient::ApiError, 'metadata write failed'
                end

                orig_ud.call(*args, **kwargs)
              end

              client
            end
          end

          begin
            service.execute(**execute_params)
          rescue SecretsManagement::SecretsManagerClient::ApiError => e
            raise unless e.message == 'metadata write failed'
          end
        end

        it_behaves_like 'rejecting secrets that exist'
      end

      context 'when the secret already exists' do
        before do
          # Create the secret first
          service.execute(**execute_params)
        end

        it_behaves_like 'rejecting secrets that exist'
      end

      it 'creates a secret with rotation info' do
        expect(result).to be_success
        secret = result.payload[:secret]

        rotation_info = rotation_info_for_secret(public_send(resource_type), secret.name)
        expect(rotation_info).not_to be_nil
        expect(rotation_info.rotation_interval_days).to eq(rotation_interval_days)
        expect(rotation_info.secret_metadata_version).to eq(1)
        expect(rotation_info.next_reminder_at).to be_present
        expect(rotation_info.last_reminder_at).to be_nil

        expect(secret.rotation_info).to eq(rotation_info)

        expect_kv_secret_to_have_custom_metadata(
          full_namespace_path,
          secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          "secret_rotation_info_id" => rotation_info.id.to_s
        )
      end

      context 'when rotation_interval_days is not given' do
        let(:rotation_interval_days) { nil }

        it 'does not create a rotation info record' do
          expect(result).to be_success

          secret = result.payload[:secret]
          rotation_info = rotation_info_for_secret(public_send(resource_type), secret.name)
          expect(rotation_info).to be_nil
          expect(secret.rotation_info).to be_nil
        end
      end

      context 'when the secret value exceeds size limit' do
        let(:value) { 'x' * 10001 }

        it 'fails with size limit error' do
          expect(result).to be_error
          expect(result.message).to eq('Length of secret value exceeds allowed limits (10k bytes).')
        end
      end

      context 'when the secret name is invalid' do
        let(:name) { 'invalid-name!' }

        it 'fails with validation error' do
          expect(result).to be_error
          expect(result.message).to include("can contain only letters, digits and '_'")
        end
      end

      context 'when secrets limit is exceeded' do
        let(:limit) { 10 }
        let(:secret_count_service) { instance_double(count_service_class) }

        let(:count_service_class) do
          case resource_type
          when 'project'
            SecretsManagement::ProjectSecretsCountService
          when 'group'
            SecretsManagement::GroupSecretsCountService
          else
            raise ArgumentError, "Unknown secrets manager scope: #{resource_type}"
          end
        end

        let(:limit_setting) do
          case resource_type
          when 'project'
            :project_secrets_limit
          when 'group'
            :group_secrets_limit
          else
            raise ArgumentError, "Unknown secrets manager scope: #{resource_type}"
          end
        end

        before do
          stub_application_setting(limit_setting => limit)
          allow(count_service_class)
            .to receive(:new)
            .with(public_send(resource_type), user)
            .and_return(secret_count_service)
          allow(secret_count_service).to receive(:secrets_limit_exceeded?).and_return(true)
        end

        it 'returns secrets_limit_exceeded_response' do
          expect(result).to be_error
          expect(result.reason).to eq(:secrets_limit_exceeded)
          expect(result.message).to eq(
            "Maximum number of secrets (#{limit}) for this #{resource_type} has been reached. " \
              'Please delete unused secrets or contact your administrator to increase the limit.'
          )
        end

        it 'does not create anything' do
          expect(result).to be_error

          expect(rotation_info_count).to be_zero

          expect_kv_secret_not_to_exist(
            full_namespace_path,
            secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name)
          )
        end
      end
    end

    context "when the #{resource_type} secrets manager is not active" do
      it 'fails with inactive error' do
        secrets_manager.initiate_deprovision
        expect(result).to be_error
        expect(result.message).to eq('Secrets manager is not active')
      end

      it 'does not enqueue the namespace secret count refresh worker' do
        secrets_manager.initiate_deprovision

        expect(SecretsManagement::ReconcileNamespaceSecretCountWorker).not_to receive(:perform_async)

        expect(result).to be_error
      end
    end

    context "when the #{resource_type} has not enabled secrets manager at all" do
      it 'fails with inactive error' do
        expect(result).to be_error
        expect(result.message).to eq('Secrets manager is not active')
      end
    end
  end
end
