# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecrets::ListService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:group) { create(:group) }

  let!(:secrets_manager) { create(:group_secrets_manager, group: group) }

  let(:service) { described_class.new(group, user) }

  describe '#execute' do
    let(:user) { create(:user, owner_of: group) }
    let(:include_rotation_info) { true }

    subject(:result) { service.execute(include_rotation_info: include_rotation_info) }

    context 'when secrets manager is active and user is owner' do
      before do
        provision_group_secrets_manager(secrets_manager, user)
      end

      context 'when there are no secrets' do
        it 'returns an empty array' do
          expect(result).to be_success
          expect(result.payload[:secrets]).to eq([])
        end
      end

      context 'when there are secrets' do
        before do
          SecretsManagement::GroupSecrets::CreateService.new(group, user).execute(
            name: 'SECRET1',
            description: 'First secret',
            value: 'secret-value-1',
            environment: 'production',
            protected: true
          )

          SecretsManagement::GroupSecrets::CreateService.new(group, user).execute(
            name: 'SECRET2',
            description: 'Second secret',
            value: 'secret-value-2',
            environment: 'staging',
            protected: false,
            rotation_interval_days: 30
          )
        end

        it 'returns all secrets with rotation info' do
          expect(result).to be_success

          secrets = result.payload[:secrets]
          expect(secrets.size).to eq(2)

          expect(secrets.map(&:name)).to match_array(%w[SECRET1 SECRET2])

          secret1 = secrets.find { |s| s.name == 'SECRET1' }
          expect(secret1.description).to eq('First secret')
          expect(secret1.environment).to eq('production')
          expect(secret1.protected).to be true
          expect(secret1.metadata_version).to eq(2)
          expect(secret1.status).to eq('COMPLETED')
          expect(secret1.rotation_info).to be_nil

          secret2 = secrets.find { |s| s.name == 'SECRET2' }
          expect(secret2.description).to eq('Second secret')
          expect(secret2.environment).to eq('staging')
          expect(secret2.protected).to be false
          expect(secret2.metadata_version).to eq(2)
          expect(secret2.status).to eq('COMPLETED')

          rotation_info = secret_rotation_info_for_group_secret(group, secret2.name, secret2.metadata_version - 1)
          expect(secret2.rotation_info).to eq(rotation_info)
        end

        context 'and include_rotation_info is false' do
          let(:include_rotation_info) { false }

          it 'does not include the rotation info in the result' do
            expect(result).to be_success

            secrets = result.payload[:secrets]
            expect(secrets.size).to eq(2)

            expect(secrets.filter_map(&:rotation_info)).to be_empty
          end
        end

        context 'when status is derived from timestamps', :freeze_time do
          let(:namespace) { group.secrets_manager.full_group_namespace_path }
          let(:mount) { group.secrets_manager.ci_secrets_mount_path }
          let(:client) { secrets_manager_client.with_namespace(namespace) }

          it 'returns completed for both secrets right after creation' do
            expect(result).to be_success
            secrets = result.payload[:secrets]

            secret1 = secrets.find { |s| s.name == 'SECRET1' }
            secret2 = secrets.find { |s| s.name == 'SECRET2' }

            expect(secret1.status).to eq('COMPLETED')
            expect(secret2.status).to eq('COMPLETED')
          end

          context 'when SECRET2 has a long-running update without completion' do
            it 'marks SECRET2 as stale and keeps SECRET1 completed' do
              cas = 2
              client.update_kv_secret_metadata(
                mount,
                group.secrets_manager.ci_data_path('SECRET2'),
                {
                  description: 'Second secret',
                  environment: 'staging',
                  protected: 'false',
                  update_started_at: 2.minutes.ago.utc.iso8601
                },
                metadata_cas: cas
              )

              refreshed = service.execute
              expect(refreshed).to be_success
              secrets = refreshed.payload[:secrets]

              secret1 = secrets.find { |s| s.name == 'SECRET1' }
              secret2 = secrets.find { |s| s.name == 'SECRET2' }

              expect(secret1.status).to eq('COMPLETED')
              expect(secret2.status).to eq('UPDATE_STALE')
            end
          end

          context 'when SECRET2 has a recent update with completion' do
            it 'keeps SECRET2 completed' do
              cas = 2
              client.update_kv_secret_metadata(
                mount,
                group.secrets_manager.ci_data_path('SECRET2'),
                {
                  description: 'Second secret',
                  environment: 'staging',
                  protected: 'false',
                  update_started_at: 10.seconds.ago.utc.iso8601,
                  update_completed_at: Time.current.utc.iso8601
                },
                metadata_cas: cas
              )

              refreshed = service.execute
              expect(refreshed).to be_success

              secret2 = refreshed.payload[:secrets].find { |s| s.name == 'SECRET2' }
              expect(secret2.status).to eq('COMPLETED')
            end
          end
        end
      end
    end

    context 'when user is a maintainer and no permissions' do
      let(:user) { create(:user, maintainer_of: group) }

      it 'returns an error' do
        provision_group_secrets_manager(secrets_manager, user)

        expect { service.execute }.to raise_error(
          SecretsManagement::SecretsManagerClient::ApiError,
          "1 error occurred:\n\t* permission denied\n\n"
        )
      end
    end

    context 'when user is a maintainer and has proper permissions' do
      let(:user) { create(:user, maintainer_of: group) }

      before do
        provision_group_secrets_manager(secrets_manager, user)
        update_group_secrets_permission(
          user: user, group: group, actions: %w[read], principal: {
            id: Gitlab::Access.sym_options[:maintainer], type: 'Role'
          }
        )
      end

      it 'returns success' do
        expect(result).to be_success
        expect(result.payload[:secrets]).to eq([])
      end
    end

    context 'when secrets manager is not active' do
      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq('Secrets manager is not active')
      end
    end
  end
end
