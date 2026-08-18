# frozen_string_literal: true

RSpec.shared_examples 'a service for deleting a secret' do |resource_type|
  # Note: The including spec must define:
  # - service (the service instance)
  # - secrets_manager (the secrets manager instance)
  # - provision_secrets_manager (method to provision the secrets manager)
  # - create_initial_secret (method to create the initial secret for testing)
  # - name (secret name)
  # - result (the service execution result)
  # - user (the user performing the operation)

  describe '#execute' do
    context "when the #{resource_type} secrets manager is active" do
      before do
        provision_secrets_manager(secrets_manager, user)
      end

      context 'when the secret exists' do
        before do
          create_initial_secret
        end

        it_behaves_like "an operation requiring an exclusive #{resource_type} secret operation lease"

        it 'deletes the secret successfully' do
          expect(result).to be_success
          secret = result.payload[:secret]
          expect(secret).to be_present
          expect(secret.name).to eq(name)
        end

        it 'enqueues the namespace secret count refresh worker with the actor user id' do
          expect(SecretsManagement::ReconcileNamespaceSecretCountWorker)
            .to receive(:perform_async)
            .with(secrets_manager.namespace_id_for_secret_count, user.id)

          expect(result).to be_success
        end
      end

      context 'when the secret does not exist' do
        let(:name) { 'NONEXISTENT_SECRET' }

        it 'fails with not found error' do
          expect(result).to be_error
          expect(result.message).to include("#{resource_type.capitalize} secret does not exist")
          expect(result.reason).to eq(:not_found)
        end

        it 'does not enqueue the namespace secret count refresh worker' do
          expect(SecretsManagement::ReconcileNamespaceSecretCountWorker).not_to receive(:perform_async)

          expect(result).to be_error
        end
      end
    end

    context "when the #{resource_type} secrets manager is not active" do
      it 'fails with inactive error' do
        expect(result).to be_error
        expect(result.message).to eq('Secrets manager is not active')
      end

      it 'does not enqueue the namespace secret count refresh worker' do
        expect(SecretsManagement::ReconcileNamespaceSecretCountWorker).not_to receive(:perform_async)

        expect(result).to be_error
      end
    end
  end
end
