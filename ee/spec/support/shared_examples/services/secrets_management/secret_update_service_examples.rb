# frozen_string_literal: true

RSpec.shared_examples 'a service for updating a secret' do |resource_type|
  # Note: The including spec must define:
  # - service (the service instance)
  # - secrets_manager (the secrets manager instance)
  # - provision_secrets_manager (method to provision the secrets manager)
  # - create_initial_secret (method to create the initial secret for testing)
  # - name (secret name)
  # - metadata_cas (current metadata version)
  # - initial_metadata_version (the metadata version after initial creation)
  # - new_rotation_interval_days (new rotation interval for update tests)
  # - original_rotation_interval_days (rotation interval on the initial secret)
  # - original_value (the original secret value)
  # - rotation_interval_days (rotation interval passed in execute_params)
  # - version_on_create (the metadata version of the rotation info record created on initial secret create)
  # - result (the service execution result)
  # - user (the user performing the operation)

  describe '#execute' do
    context "when the #{resource_type} secrets manager is active" do
      before do
        provision_secrets_manager(secrets_manager, user)
        create_initial_secret
      end

      it_behaves_like "an operation requiring an exclusive #{resource_type} secret operation lease"

      it 'updates the secret successfully', :freeze_time do
        frozen_time = Time.current.utc.iso8601

        expect(result).to be_success
        secret = result.payload[:secret]
        expect(secret).to be_present
        expect(secret.name).to eq(name)

        # Verify update timestamps are set
        expect_kv_secret_to_have_custom_metadata(
          full_namespace_path,
          secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          "update_started_at" => frozen_time,
          "update_completed_at" => frozen_time
        )
      end

      context 'when metadata_cas does not match' do
        let(:metadata_cas) { 999 }

        it 'fails with CAS error' do
          expect(result).to be_error
          expect(result.message).to include('This secret has been modified recently')
        end
      end

      context 'when metadata_cas is not given' do
        let(:metadata_cas) { nil }

        it 'updates the secret without checking CAS', :freeze_time do
          frozen_time = Time.current.utc.iso8601

          expect(result).to be_success
          secret = result.payload[:secret]
          expect(secret.metadata_version).to be_nil

          # Verify update timestamps are still set
          expect_kv_secret_to_have_custom_metadata(
            full_namespace_path,
            secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "update_started_at" => frozen_time,
            "update_completed_at" => frozen_time
          )
        end
      end

      context 'when adding rotation to a secret without existing rotation' do
        let(:rotation_interval_days) { new_rotation_interval_days }

        it 'creates a new rotation info record' do
          expect(result).to be_success

          secret = result.payload[:secret]
          new_version = initial_metadata_version + 1
          rotation_info = rotation_info_for_secret(public_send(resource_type), name, new_version)

          expect(rotation_info).not_to be_nil
          expect(rotation_info.rotation_interval_days).to eq(new_rotation_interval_days)
          expect(rotation_info.next_reminder_at).to be_present
          expect(rotation_info.last_reminder_at).to be_nil
          expect(secret.rotation_info).to eq(rotation_info)

          expect_kv_secret_to_have_metadata_version(
            full_namespace_path,
            secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            new_version + 1
          )

          expect_kv_secret_to_have_custom_metadata(
            full_namespace_path,
            secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "secret_rotation_info_id" => rotation_info.id.to_s
          )
        end
      end

      context 'when removing rotation from a secret with existing rotation' do
        let(:original_rotation_interval_days) { 60 }

        it 'unassigns the old rotation info record from the secret' do
          expect(result).to be_success

          secret = result.payload[:secret]
          expect(secret.rotation_info).to be_nil

          original_rotation_info = rotation_info_for_secret(public_send(resource_type), name, 1)
          expect(original_rotation_info).not_to be_nil

          rotation_info = rotation_info_for_secret(public_send(resource_type), name, 2)
          expect(rotation_info).to be_nil

          expect_kv_secret_not_to_have_custom_metadata(
            full_namespace_path,
            secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "secret_rotation_info_id"
          )
        end
      end

      context 'when updating rotation interval of existing rotation' do
        let(:original_rotation_interval_days) { 60 }
        let(:rotation_interval_days) { new_rotation_interval_days }

        it 'creates a new rotation info record with new interval' do
          expect(result).to be_success

          secret = result.payload[:secret]

          old_rotation_info = rotation_info_for_secret(public_send(resource_type), name, 1)
          expect(old_rotation_info).not_to be_nil
          expect(old_rotation_info.rotation_interval_days).to eq(60)

          new_version = metadata_cas + 1
          new_rotation_info = rotation_info_for_secret(public_send(resource_type), name, new_version)
          expect(new_rotation_info).not_to be_nil
          expect(new_rotation_info.id).not_to eq(old_rotation_info.id)
          expect(new_rotation_info.rotation_interval_days).to eq(new_rotation_interval_days)
          expect(new_rotation_info.next_reminder_at).to be_present
          expect(new_rotation_info.last_reminder_at).to be_nil
          expect(secret.rotation_info).to eq(new_rotation_info)

          expect_kv_secret_to_have_metadata_version(
            full_namespace_path,
            secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            new_version + 1
          )

          expect_kv_secret_to_have_custom_metadata(
            full_namespace_path,
            secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "secret_rotation_info_id" => new_rotation_info.id.to_s
          )
        end
      end

      context 'when explicitly preserving rotation with same interval' do
        let(:original_rotation_interval_days) { new_rotation_interval_days }
        let(:rotation_interval_days) { new_rotation_interval_days }

        it 'creates a new rotation info record with the same interval' do
          expect(result).to be_success

          secret = result.payload[:secret]

          old_rotation_info = rotation_info_for_secret(public_send(resource_type), name, version_on_create)
          expect(old_rotation_info).not_to be_nil
          expect(old_rotation_info.rotation_interval_days).to eq(original_rotation_interval_days)

          new_version = metadata_cas + 1
          new_rotation_info = rotation_info_for_secret(public_send(resource_type), name, new_version)
          expect(new_rotation_info).not_to be_nil
          expect(new_rotation_info.id).not_to eq(old_rotation_info.id)
          expect(new_rotation_info.rotation_interval_days).to eq(new_rotation_interval_days)
          expect(new_rotation_info.next_reminder_at).to be_present
          expect(new_rotation_info.last_reminder_at).to be_nil
          expect(secret.rotation_info).to eq(new_rotation_info)

          expect_kv_secret_to_have_metadata_version(
            full_namespace_path,
            secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            new_version + 1
          )

          expect_kv_secret_to_have_custom_metadata(
            full_namespace_path,
            secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "secret_rotation_info_id" => new_rotation_info.id.to_s
          )
        end
      end

      context 'when rotation interval is invalid' do
        let(:rotation_interval_days) { 1 }

        it 'returns an error and does not update' do
          expect(result).not_to be_success
          expect(result.message).to include('Rotation configuration error')

          expect_kv_secret_to_have_value(
            full_namespace_path,
            secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            original_value
          )

          rotation_info = rotation_info_for_secret(public_send(resource_type), name, metadata_cas + 1)
          expect(rotation_info).to be_nil
        end
      end

      context 'when the secret does not exist' do
        let(:name) { 'NONEXISTENT_SECRET' }

        it 'fails with not found error' do
          expect(result).to be_error
          expect(result.message).to include("#{resource_type.capitalize} secret does not exist")
          expect(result.reason).to eq(:not_found)
        end
      end
    end

    context "when the #{resource_type} secrets manager is not active" do
      it 'fails with inactive error' do
        expect(result).to be_error
        expect(result.message).to eq('Secrets manager is not active')
      end
    end
  end
end
