# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:secrets_management:backfill_api_auth', :gitlab_secrets_manager, :silence_output,
  feature_category: :secrets_management do
  before do
    Rake.application.rake_require('tasks/gitlab/secrets_management/backfill_api_auth')
  end

  let!(:user) { create(:user) }

  def task
    run_rake_task('gitlab:secrets_management:backfill_api_auth')
  end

  def task_scoped_to(root_namespace_id)
    run_rake_task('gitlab:secrets_management:backfill_api_auth', root_namespace_id)
  end

  context 'when there are no secrets managers' do
    it 'completes without error and reports zero counts', :aggregate_failures do
      expect { task }.to output(/0 succeeded, 0 failed/).to_stdout
    end
  end

  context 'when root_namespace_id is not a positive integer' do
    %w[12abc -1 0].each do |invalid_id|
      it "aborts without running the backfill for #{invalid_id.inspect}", :aggregate_failures do
        expect(SecretsManagement::ApiAuthConfigurator).not_to receive(:new)

        expect { task_scoped_to(invalid_id) }.to raise_error(SystemExit)
          .and output(/ERROR: root_namespace_id must be a positive integer/).to_stderr
      end
    end
  end

  shared_examples 'backfills secrets manager api_jwt auth' do
    let(:namespace_path) { secrets_manager.full_namespace_path }

    # Registering this fallback again from a later `fail_backfill_for` call
    # would take precedence over an earlier call's specific `with(...)` stub
    # (RSpec checks stubs most-recently-defined first), silently un-failing
    # it. Registering it once up front keeps multiple `fail_backfill_for`
    # calls in the same example independent of each other.
    before do
      allow(SecretsManagement::ApiAuthConfigurator).to receive(:new).and_call_original
    end

    def fail_backfill_for(secrets_manager)
      allow(SecretsManagement::ApiAuthConfigurator).to receive(:new)
        .with(hash_including(resource_id: resource_id_of(secrets_manager)))
        .and_raise(SecretsManagement::SecretsManagerClient::ApiError, 'boom')
    end

    before do
      provision_secrets_manager(secrets_manager)
    end

    context 'when the api_jwt mount is missing (an SM enrolled before api access)' do
      before do
        secrets_manager_client.with_namespace(namespace_path).disable_auth_engine(secrets_manager.api_auth_mount)
      end

      it 'recreates the api_jwt mount and all_api CEL role', :aggregate_failures do
        expect_jwt_auth_engine_not_to_be_mounted(namespace_path, secrets_manager.api_auth_mount)

        task

        expect_jwt_auth_engine_to_be_mounted(namespace_path, secrets_manager.api_auth_mount)
        expect_jwt_cel_role_to_exist(namespace_path, secrets_manager.api_auth_mount, secrets_manager.api_auth_role)
      end
    end

    it 'is idempotent: reprocessing an already-configured secrets manager re-runs safely', :aggregate_failures do
      task

      expect { task }.to output(/1 succeeded, 0 failed/).to_stdout
        .and output('').to_stderr

      expect_jwt_auth_engine_to_be_mounted(namespace_path, secrets_manager.api_auth_mount)
      expect_jwt_cel_role_to_exist(namespace_path, secrets_manager.api_auth_mount, secrets_manager.api_auth_role)
    end

    context 'when one secrets manager errors' do
      let(:healthy_namespace) { other_secrets_manager.full_namespace_path }

      before do
        provision_secrets_manager(other_secrets_manager)

        # Give the healthy SM visible work so we can prove it was still processed.
        secrets_manager_client
          .with_namespace(healthy_namespace)
          .disable_auth_engine(other_secrets_manager.api_auth_mount)

        fail_backfill_for(secrets_manager)
      end

      it 'warns about the failure, still backfills the others, reports it in the summary, and does not raise',
        :aggregate_failures do
        expect { task }.to output(/FAILED.*boom/).to_stderr
          .and output(/1 succeeded, 1 failed \(ids: #{secrets_manager.id}\)/).to_stdout

        expect_jwt_auth_engine_to_be_mounted(healthy_namespace, other_secrets_manager.api_auth_mount)
        expect_jwt_cel_role_to_exist(
          healthy_namespace, other_secrets_manager.api_auth_mount, other_secrets_manager.api_auth_role
        )
      end
    end

    context 'when multiple secrets managers error' do
      let(:another_secrets_manager) { create_secrets_manager }

      before do
        provision_secrets_manager(other_secrets_manager)
        provision_secrets_manager(another_secrets_manager)

        fail_backfill_for(secrets_manager)
        fail_backfill_for(another_secrets_manager)
      end

      it 'reports all failed ids and the correct succeeded count in the summary' do
        expect { task }.to output(
          /1 succeeded, 2 failed \(ids: #{secrets_manager.id}, #{another_secrets_manager.id}\)/
        ).to_stdout
      end
    end

    context 'when scoped to a root_namespace_id' do
      before do
        provision_secrets_manager(other_secrets_manager)

        secrets_manager_client.with_namespace(namespace_path).disable_auth_engine(secrets_manager.api_auth_mount)
        secrets_manager_client
          .with_namespace(other_secrets_manager.full_namespace_path)
          .disable_auth_engine(other_secrets_manager.api_auth_mount)
      end

      it 'only backfills secrets managers under that root namespace', :aggregate_failures do
        task_scoped_to(secrets_manager.root_namespace_id)

        expect_jwt_auth_engine_to_be_mounted(namespace_path, secrets_manager.api_auth_mount)
        expect_jwt_auth_engine_not_to_be_mounted(
          other_secrets_manager.full_namespace_path, other_secrets_manager.api_auth_mount
        )
      end
    end

    context 'when a secrets manager failed on an earlier run' do
      before do
        secrets_manager_client.with_namespace(namespace_path).disable_auth_engine(secrets_manager.api_auth_mount)
      end

      it 'backfills it on a later run once the cause is fixed', :aggregate_failures do
        fail_backfill_for(secrets_manager)

        task

        # First run failed and skipped it, so it is still not configured.
        expect_jwt_auth_engine_not_to_be_mounted(namespace_path, secrets_manager.api_auth_mount)

        # Cause fixed: the re-run backfills it, since the task is idempotent and safe to re-run.
        allow(SecretsManagement::ApiAuthConfigurator).to receive(:new).and_call_original

        task

        expect_jwt_auth_engine_to_be_mounted(namespace_path, secrets_manager.api_auth_mount)
        expect_jwt_cel_role_to_exist(namespace_path, secrets_manager.api_auth_mount, secrets_manager.api_auth_role)
      end
    end

    context 'when the secrets manager is not active' do
      %i[provisioning deprovisioning].each do |status|
        context "and it is #{status}" do
          before do
            secrets_manager.update!(status: SecretsManagement::BaseSecretsManager::STATUSES[status])
          end

          it 'skips it' do
            expect(SecretsManagement::ApiAuthConfigurator).not_to receive(:new)

            task
          end
        end
      end
    end
  end

  context 'for project secrets managers' do
    let(:secrets_manager) { create(:project_secrets_manager, project: create(:project)) }
    let(:other_secrets_manager) { create(:project_secrets_manager, project: create(:project)) }

    def provision_secrets_manager(secrets_manager)
      provision_project_secrets_manager(secrets_manager, user)
    end

    def resource_id_of(secrets_manager)
      secrets_manager.project_id
    end

    def create_secrets_manager
      create(:project_secrets_manager, project: create(:project))
    end

    it_behaves_like 'backfills secrets manager api_jwt auth'
  end

  context 'for group secrets managers' do
    let(:secrets_manager) { create(:group_secrets_manager, group: create(:group)) }
    let(:other_secrets_manager) { create(:group_secrets_manager, group: create(:group)) }

    def provision_secrets_manager(secrets_manager)
      provision_group_secrets_manager(secrets_manager, user)
    end

    def resource_id_of(secrets_manager)
      secrets_manager.group_id
    end

    def create_secrets_manager
      create(:group_secrets_manager, group: create(:group))
    end

    it_behaves_like 'backfills secrets manager api_jwt auth'
  end
end
