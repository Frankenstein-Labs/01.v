# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecrets::ReadMetadataService, :gitlab_secrets_manager, feature_category: :secrets_management do
  describe '#execute', :aggregate_failures do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:user) { create(:user) }

    let(:service) { described_class.new(group, user) }
    let(:name) { 'TEST_SECRET' }
    let(:secrets_manager) { create(:group_secrets_manager, group: group) }

    let(:include_rotation_info) { true }

    subject(:result) { service.execute(name, include_rotation_info: include_rotation_info) }

    before_all do
      group.add_owner(user)
    end

    context 'when the group secrets manager is active' do
      before do
        provision_group_secrets_manager(secrets_manager, user)
      end

      context 'when the secret exists' do
        before do
          SecretsManagement::GroupSecrets::CreateService.new(group, user).execute(
            name: name,
            description: 'test description',
            value: 'secret-value',
            environment: 'production',
            protected: true,
            rotation_interval_days: 30
          )
        end

        it 'returns the group secret with rotation info' do
          expect(result).to be_success
          secret = result.payload[:secret]
          expect(secret).to be_present
          expect(secret.name).to eq(name)
          expect(secret.description).to eq('test description')
          expect(secret.environment).to eq('production')
          expect(secret.protected).to be true
          expect(secret.metadata_version).to eq(2)

          rotation_info = secret_rotation_info_for_group_secret(group, secret.name)
          expect(secret.rotation_info).to eq(rotation_info)
        end

        it 'converts protected string to boolean' do
          secret = result.payload[:secret]
          expect(secret.protected).to be_a(TrueClass)
        end

        context 'and include_rotation_info is false' do
          let(:include_rotation_info) { false }

          it 'does not include the rotation info in the result' do
            expect(result).to be_success
            secret = result.payload[:secret]
            expect(secret.rotation_info).to be_nil
          end
        end

        context 'when protected is false' do
          before do
            SecretsManagement::GroupSecrets::UpdateService.new(group, user).execute(
              name: name,
              metadata_cas: 2,
              protected: false
            )
          end

          it 'returns false for protected' do
            secret = result.payload[:secret]
            expect(secret.protected).to be false
          end
        end
      end

      context 'when the secret does not exist' do
        it 'returns not found error' do
          expect(result).to be_error
          expect(result.message).to eq('Group secret does not exist.')
          expect(result.reason).to eq(:not_found)
        end
      end

      context 'when the secret name is invalid' do
        let(:name) { 'invalid-name!' }

        it 'returns validation error' do
          expect(result).to be_error
          expect(result.message).to eq("Name can contain only letters, digits and '_'.")
        end
      end
    end

    context 'when the group secrets manager is not active' do
      before do
        provision_group_secrets_manager(secrets_manager, user)
        secrets_manager.initiate_deprovision
      end

      it 'fails' do
        expect(result).to be_error
        expect(result.message).to eq('Secrets manager is not active')
      end
    end

    context 'when the group has not enabled secrets manager' do
      it 'fails' do
        expect(result).to be_error
        expect(result.message).to eq('Secrets manager is not active')
      end
    end
  end
end
