# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecrets::ListService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }

  let!(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:service) { described_class.new(project, user) }
  let(:include_rotation_info) { true }

  describe '#execute' do
    let(:user) { create(:user, owner_of: project) }

    subject(:result) { service.execute(include_rotation_info: include_rotation_info) }

    context 'when secrets manager is active and user is owner' do
      before do
        provision_project_secrets_manager(secrets_manager, user)
      end

      context 'when secrets only have initial metadata' do
        before do
          allow(SecretsManagement::ProjectSecrets::CreateService).to receive(:new).and_wrap_original do |orig, *args|
            svc = orig.call(*args)

            allow(svc).to receive(:update_metadata_for).and_wrap_original do
              |orig_m, project_secret, rotation_info, metadata_cas:|
              # Fail the first metadata write so no metadata doc is created at all
              if project_secret.name == 'SECRET1' && metadata_cas == 0
                raise SecretsManagement::SecretsManagerClient::ApiError, 'metadata write failed'
              end

              orig_m.call(project_secret, rotation_info, metadata_cas: metadata_cas)
            end

            svc
          end

          begin
            create_project_secret(
              user: user,
              project: project,
              name: 'SECRET1',
              description: 'First secret',
              branch: 'main',
              environment: 'production',
              value: 'secret-value-1'
            )
          rescue SecretsManagement::SecretsManagerClient::ApiError => e
            raise unless e.message == 'metadata write failed'
          end

          create_project_secret(
            user: user,
            project: project,
            name: 'SECRET2',
            description: 'Second secret',
            branch: 'staging',
            environment: 'staging',
            value: 'secret-value-2',
            rotation_interval_days: 30
          )
        end

        it 'returns a secret' do
          expect(result).to be_success

          secrets = result.payload[:secrets]
          expect(secrets.size).to eq(2)
          secret1 = secrets.find { |s| s.name == 'SECRET1' }
          expect(secret1.status).to eq('CREATE_IN_PROGRESS')
        end
      end

      context 'when there are no secrets' do
        it 'returns an empty array' do
          expect(result).to be_success
          expect(result.payload[:secrets]).to eq([])
        end
      end

      context 'when there are secrets' do
        before do
          create_project_secret(
            user: user,
            project: project,
            name: 'SECRET1',
            description: 'First secret',
            branch: 'main',
            environment: 'production',
            value: 'secret-value-1'
          )

          create_project_secret(
            user: user,
            project: project,
            name: 'SECRET2',
            description: 'Second secret',
            branch: 'staging',
            environment: 'staging',
            value: 'secret-value-2',
            rotation_interval_days: 30
          )
        end

        it 'returns all secrets' do
          expect(result).to be_success

          secrets = result.payload[:secrets]
          expect(secrets.size).to eq(2)

          expect(secrets.map(&:name)).to match_array(%w[SECRET1 SECRET2])

          # Verify a few properties of each secret
          secret1 = secrets.find { |s| s.name == 'SECRET1' }
          expect(secret1.description).to eq('First secret')
          expect(secret1.branch).to eq('main')
          expect(secret1.environment).to eq('production')
          expect(secret1.metadata_version).to eq(2)
          expect(secret1.rotation_info).to be_nil
          expect(secret1.status).to eq('COMPLETED')

          secret2 = secrets.find { |s| s.name == 'SECRET2' }
          expect(secret2.description).to eq('Second secret')
          expect(secret2.branch).to eq('staging')
          expect(secret2.environment).to eq('staging')
          expect(secret2.metadata_version).to eq(2)
          expect(secret1.status).to eq('COMPLETED')

          rotation_info = secret_rotation_info_for_project_secret(project, secret2.name, secret2.metadata_version - 1)
          expect(secret2.rotation_info).to eq(rotation_info)
        end

        context 'when status is derived from timestamps', :freeze_time do
          let(:namespace) { project.secrets_manager.full_project_namespace_path }
          let(:mount)     { project.secrets_manager.ci_secrets_mount_path }
          let(:client)    { secrets_manager_client.with_namespace(namespace) }

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
                project.secrets_manager.ci_data_path('SECRET2'),
                {
                  description: 'Second secret',
                  environment: 'staging',
                  branch: 'staging',
                  update_started_at: 2.minutes.ago.utc.iso8601
                },
                metadata_cas: cas
              )

              refreshed = service.execute(include_rotation_info: include_rotation_info)
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
                project.secrets_manager.ci_data_path('SECRET2'),
                {
                  description: 'Second secret',
                  environment: 'staging',
                  branch: 'staging',
                  update_started_at: 10.seconds.ago.utc.iso8601,
                  update_completed_at: Time.current.utc.iso8601
                },
                metadata_cas: cas
              )

              refreshed = service.execute(include_rotation_info: include_rotation_info)
              expect(refreshed).to be_success

              secret2 = refreshed.payload[:secrets].find { |s| s.name == 'SECRET2' }
              expect(secret2.status).to eq('COMPLETED')
            end
          end

          context 'when SECRET2 is in progress' do
            it 'keeps SECRET2 status' do
              cas = 2
              client.update_kv_secret_metadata(
                mount,
                project.secrets_manager.ci_data_path('SECRET2'),
                {
                  description: 'Second secret',
                  environment: 'staging',
                  branch: 'staging'
                },
                metadata_cas: cas
              )

              refreshed = service.execute(include_rotation_info: include_rotation_info)
              expect(refreshed).to be_success

              secret2 = refreshed.payload[:secrets].find { |s| s.name == 'SECRET2' }
              expect(secret2.status).to eq('CREATE_IN_PROGRESS')
            end
          end
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
      end
    end

    context 'when user is a developer and no permissions' do
      let(:user) { create(:user, developer_of: project) }

      subject(:result) { service.execute }

      it 'returns an error' do
        provision_project_secrets_manager(secrets_manager, user)

        expect { service.execute }.to raise_error(
          SecretsManagement::SecretsManagerClient::ApiError,
          "1 error occurred:\n\t* permission denied\n\n"
        )
      end
    end

    context 'when user is a developer and has proper permissions' do
      let(:user) { create(:user, developer_of: project) }

      subject(:result) { service.execute }

      before do
        provision_project_secrets_manager(secrets_manager, user)
        update_project_secrets_permission(
          user: user, project: project, actions: %w[read], principal: {
            id: Gitlab::Access.sym_options[:developer], type: 'Role'
          }
        )
      end

      it 'returns success' do
        expect(result).to be_success
        expect(result.payload[:secrets]).to eq([])
      end
    end

    context 'when user has a member role and has proper permissions' do
      let(:group) { create(:group) }
      let(:project) { create(:project, group: group) }

      let!(:member_role) { create(:member_role, namespace: project.group) }
      let!(:group_member) do
        create(:group_member, {
          user: user,
          group: member_role.namespace,
          access_level: Gitlab::Access::DEVELOPER,
          member_role: member_role
        })
      end

      let(:user) { create(:user) }

      subject(:result) { service.execute }

      before do
        provision_project_secrets_manager(secrets_manager, user)
        update_project_secrets_permission(
          user: user, project: project, actions: %w[
            read
          ], principal: { id: member_role.id, type: 'MemberRole' }
        )
      end

      it 'returns success' do
        expect(result).to be_success
        expect(result.payload[:secrets]).to eq([])
      end
    end

    context 'when user has a member role and has no permissions' do
      let(:group) { create(:group) }
      let(:project) { create(:project, group: group) }

      let!(:member_role) { create(:member_role, namespace: project.group) }
      let!(:group_member) do
        create(:group_member, {
          user: user,
          group: member_role.namespace,
          access_level: Gitlab::Access::DEVELOPER,
          member_role: member_role
        })
      end

      let(:user) { create(:user) }

      subject(:result) { service.execute }

      before do
        provision_project_secrets_manager(secrets_manager, user)
      end

      it 'returns an error' do
        expect { service.execute }.to raise_error(
          SecretsManagement::SecretsManagerClient::ApiError,
          "1 error occurred:\n\t* permission denied\n\n"
        )
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
