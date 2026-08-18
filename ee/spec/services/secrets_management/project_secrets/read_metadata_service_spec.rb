# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecrets::ReadMetadataService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user, owner_of: project) }

  let!(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:service) { described_class.new(project, user) }
  let(:name) { 'TEST_SECRET' }
  let(:description) { 'test description' }
  let(:branch) { 'main' }
  let(:environment) { 'prod' }
  let(:value) { 'secret-value' }

  describe '#execute' do
    let(:include_rotation_info) { true }

    context 'when secrets manager is active' do
      subject(:result) { service.execute(name, include_rotation_info: include_rotation_info) }

      before do
        provision_project_secrets_manager(secrets_manager, user)
      end

      context 'when the secret exists' do
        before do
          create_project_secret(
            user: user,
            project: project,
            name: name,
            description: description,
            branch: branch,
            environment: environment,
            value: value,
            rotation_interval_days: 30
          )
        end

        context 'with right permissions' do
          it 'returns success with the secret metadata' do
            expect(result).to be_success
            project_secret = result.payload[:secret]
            expect(project_secret).to be_a(SecretsManagement::ProjectSecret)
            expect(project_secret.name).to eq(name)
            expect(project_secret.description).to eq(description)
            expect(project_secret.branch).to eq(branch)
            expect(project_secret.environment).to eq(environment)
            expect(project_secret.metadata_version).to eq(2)
            expect(project_secret.project).to eq(project)

            rotation_info = secret_rotation_info_for_project_secret(
              project,
              project_secret.name
            )

            expect(project_secret.rotation_info).to eq(rotation_info)
          end

          context 'when reading after an update' do
            it 'successfully reads timestamps as stored strings without parsing into timestamp objects' do
              update_result = SecretsManagement::ProjectSecrets::UpdateService
                .new(project, user)
                .execute(name: name, value: 'new-secret-value')

              expect(update_result).to be_success

              read_result = described_class.new(project, user).execute(name, include_rotation_info: true)
              expect(read_result).to be_success

              project_secret = read_result.payload[:secret]
              expect(project_secret).to be_a(SecretsManagement::ProjectSecret)

              # Timestamps should remain as raw strings from OpenBao (or nil), not parsed Time objects.
              %i[create_started_at create_completed_at update_started_at update_completed_at].each do |attr|
                value = project_secret.public_send(attr)
                expect(value).to be_a(String)
              end
            end
          end

          context 'and include_rotation_info is false' do
            let(:include_rotation_info) { false }

            it 'does not include the rotation info in the result' do
              expect(result).to be_success
              project_secret = result.payload[:secret]
              expect(project_secret.rotation_info).to be_nil
            end
          end

          context 'when evaluating status', :freeze_time do
            let(:namespace) { project.secrets_manager.full_project_namespace_path }
            let(:mount)     { project.secrets_manager.ci_secrets_mount_path }
            let(:path)      { project.secrets_manager.ci_data_path(name) }
            let(:client)    { secrets_manager_client.with_namespace(namespace) }
            let(:cas)       { 2 }
            let(:threshold) { 30.seconds }

            def iso(time)
              time&.utc&.iso8601
            end

            shared_examples 'writes metadata and expects status' do |expected|
              it "computes status as #{expected}" do
                stringified_timestamps = timestamps.transform_values(&:to_s)

                metadata = {
                  description: description,
                  environment: environment,
                  branch: branch
                }.merge(stringified_timestamps)

                client.update_kv_secret_metadata(mount, path, metadata, metadata_cas: cas)
                project_secret = service.execute(name, include_rotation_info: true).payload[:secret]
                expect(project_secret.status).to eq(expected)
              end
            end

            context 'when update timestamps are evaluated' do
              context 'when no timestamps are present' do
                let(:timestamps) { {} }

                it_behaves_like 'writes metadata and expects status', 'CREATE_IN_PROGRESS'
              end

              context 'when update started recently and completed' do
                let(:timestamps) do
                  {
                    create_completed_at: iso(1.hour.ago),
                    update_started_at: iso((threshold / 3).ago),
                    update_completed_at: iso(Time.current)
                  }
                end

                it_behaves_like 'writes metadata and expects status', 'COMPLETED'
              end

              context 'when update started long ago and completed' do
                let(:timestamps) do
                  {
                    update_started_at: iso((threshold * 3).ago),
                    update_completed_at: iso(Time.current)
                  }
                end

                it_behaves_like 'writes metadata and expects status', 'COMPLETED'
              end

              context 'when update started long ago and not completed' do
                let(:timestamps) do
                  { update_started_at: iso((threshold * 2).ago) }
                end

                it_behaves_like 'writes metadata and expects status', 'UPDATE_STALE'
              end

              context 'when update timestamps are reversed and recent' do
                let(:timestamps) do
                  {
                    update_started_at: iso(Time.current),
                    update_completed_at: iso(1.minute.ago)
                  }
                end

                it_behaves_like 'writes metadata and expects status', 'COMPLETED'
              end

              context 'when update is recent but timestamps are reversed beyond threshold' do
                let(:timestamps) do
                  {
                    update_started_at: iso(Time.current),
                    update_completed_at: iso(2.minutes.ago)
                  }
                end

                it_behaves_like 'writes metadata and expects status', 'COMPLETED'
              end
            end

            context 'when creation timestamps are evaluated and no updates are present' do
              context 'when creation started recently and not completed' do
                let(:timestamps) { {} }

                it_behaves_like 'writes metadata and expects status', 'CREATE_IN_PROGRESS'
              end

              context 'when creation started and completed normally' do
                let(:timestamps) do
                  {
                    create_completed_at: iso(5.minutes.ago)
                  }
                end

                it_behaves_like 'writes metadata and expects status', 'COMPLETED'
              end
            end
          end
        end
      end

      context 'when the secret does not exist' do
        it 'returns an error with not_found reason' do
          expect(result).to be_error
          expect(result.message).to eq('Project secret does not exist.')
          expect(result.reason).to eq(:not_found)
        end
      end

      context 'when the secret name does not conform' do
        let(:name) { '../../OTHER_SECRET' }

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq("Name can contain only letters, digits and '_'.")
        end
      end
    end

    context 'when user is a developer and no permissions' do
      let(:user) { create(:user, developer_of: project) }

      subject(:result) { service.execute(name) }

      it 'returns an error' do
        provision_project_secrets_manager(secrets_manager, user)
        expect { result }
        .to raise_error(SecretsManagement::SecretsManagerClient::ApiError,
          "1 error occurred:\n\t* permission denied\n\n")
      end
    end

    context 'when secrets manager is not active' do
      subject(:result) { service.execute(name) }

      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq('Secrets manager is not active')
      end
    end
  end
end
