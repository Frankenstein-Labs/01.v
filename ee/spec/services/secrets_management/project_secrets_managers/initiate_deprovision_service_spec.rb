# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsManagers::InitiateDeprovisionService, feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:service) { described_class.new(project&.secrets_manager, user, project_id: project.id) }

  describe '#execute' do
    let(:deprovision_worker_spy) { class_spy(SecretsManagement::DeprovisionProjectSecretsManagerWorker) }

    before do
      stub_const('SecretsManagement::DeprovisionProjectSecretsManagerWorker', deprovision_worker_spy)
    end

    context 'when secrets manager exists and is active' do
      let!(:secrets_manager) { create(:project_secrets_manager, :active, project: project) }

      subject(:result) { service.execute }

      it 'destroys the SM, leaving the trigger to insert the deprovision task', :aggregate_failures do
        expect { result }
          .to change { SecretsManagement::ProjectSecretsManager.where(project_id: project.id).count }.from(1).to(0)
          .and change {
                 SecretsManagement::ProjectSecretsManagerMaintenanceTask.where(project_id: project.id).count
               }.from(0).to(1)

        expect(result).to be_success
        expect(result.payload[:project_secrets_manager]).to be_destroyed
      end

      it 'carries snapshot ids on the trigger-created task and leaves user_id / last_processed_at NULL' do
        result

        task = SecretsManagement::ProjectSecretsManagerMaintenanceTask.find_by(project_id: project.id)
        expect(task.action).to eq('deprovision')
        expect(task.retry_count).to eq(0)
        expect(task.user_id).to be_nil
        expect(task.last_processed_at).to be_nil
        expect(task.organization_id).to eq(project.organization_id)
        expect(task.root_namespace_id).to eq(project.root_ancestor.id)
      end

      it 'enqueues the deprovision worker by default' do
        result

        task = SecretsManagement::ProjectSecretsManagerMaintenanceTask.find_by(project_id: project.id)
        expect(deprovision_worker_spy).to have_received(:perform_async).with(task.id)
      end

      context 'when enqueue_worker is false' do
        subject(:result) { service.execute(enqueue_worker: false) }

        it 'still destroys the SM and creates the task via the trigger, but skips perform_async' do
          expect { result }
            .to change {
                  SecretsManagement::ProjectSecretsManagerMaintenanceTask.where(project_id: project.id).count
                }.from(0).to(1)

          expect(deprovision_worker_spy).not_to have_received(:perform_async)
        end
      end
    end

    context 'when secrets manager does not exist' do
      subject(:result) { service.execute }

      it 'fails without touching the database or Sidekiq', :aggregate_failures do
        expect { result }.not_to change { SecretsManagement::ProjectSecretsManagerMaintenanceTask.count }

        expect(result).to be_error
        expect(result.message).to eq('Secrets manager not found for the project.')
        expect(deprovision_worker_spy).not_to have_received(:perform_async)
      end

      context 'when a deprovision task is still pending for the project' do
        before do
          SecretsManagement::ProjectSecretsManagerMaintenanceTask.create!(
            project_id: project.id,
            organization_id: project.organization_id,
            root_namespace_id: project.root_ancestor.id,
            action: :deprovision,
            last_processed_at: Time.zone.now
          )
        end

        it 'returns the in-progress error rather than not found', :aggregate_failures do
          expect(result).to be_error
          expect(result.message).to eq('Secrets manager deprovision is in progress')
          expect(deprovision_worker_spy).not_to have_received(:perform_async)
        end
      end
    end

    context 'when secrets manager is not active' do
      let!(:secrets_manager) { create(:project_secrets_manager, :deprovisioning, project: project) }

      subject(:result) { service.execute }

      it 'fails without destroying or enqueueing', :aggregate_failures do
        expect { result }.not_to change { SecretsManagement::ProjectSecretsManager.count }
        expect(result).to be_error
        expect(result.message).to eq('Secrets manager is not active')
        expect(deprovision_worker_spy).not_to have_received(:perform_async)
      end
    end

    context 'when a deprovision task is already pending for the project' do
      let!(:secrets_manager) { create(:project_secrets_manager, :active, project: project) }

      before do
        create(:project_secrets_manager_maintenance_task, :deprovision, project: project)
      end

      subject(:result) { service.execute }

      it 'returns the in-progress error and does not destroy the SM or enqueue', :aggregate_failures do
        expect { result }.not_to change { SecretsManagement::ProjectSecretsManager.count }
        expect(result).to be_error
        expect(result.message).to eq('Secrets manager deprovision is in progress')
        expect(deprovision_worker_spy).not_to have_received(:perform_async)
      end
    end
  end

  describe '.bulk_initiate_for_projects' do
    let_it_be(:projects) { create_list(:project, 3) }
    let(:deprovision_worker_spy) { class_spy(SecretsManagement::DeprovisionProjectSecretsManagerWorker) }

    before do
      stub_const('SecretsManagement::DeprovisionProjectSecretsManagerWorker', deprovision_worker_spy)
    end

    subject(:bulk_call) do
      described_class.bulk_initiate_for_projects(
        SecretsManagement::ProjectSecretsManager.unscoped.where(project_id: projects).select(:project_id)
      )
    end

    context 'when no active SMs match' do
      it 'no-ops' do
        expect { bulk_call }
          .to not_change { SecretsManagement::ProjectSecretsManagerMaintenanceTask.count }
          .and not_change { SecretsManagement::ProjectSecretsManager.count }
        expect(deprovision_worker_spy).not_to have_received(:bulk_perform_async)
      end
    end

    context 'when active SMs exist' do
      let_it_be_with_reload(:sm1) { create(:project_secrets_manager, :active, project: projects[0]) }
      let_it_be_with_reload(:sm2) { create(:project_secrets_manager, :active, project: projects[1]) }
      # Inactive SM stays untouched because the bulk scope filters on :active.
      let_it_be_with_reload(:sm_provisioning) { create(:project_secrets_manager, project: projects[2]) }

      it 'destroys only the active SMs and lets the trigger insert one task per row', :aggregate_failures do
        active_count = -> { SecretsManagement::ProjectSecretsManager.where(status: ::SecretsManagement::BaseSecretsManager::STATUSES[:active]).count }
        provisioning_count = -> { SecretsManagement::ProjectSecretsManager.where(status: ::SecretsManagement::BaseSecretsManager::STATUSES[:provisioning]).count }

        expect { bulk_call }
          .to change { active_count.call }.from(2).to(0)
          .and not_change { provisioning_count.call }.from(1)
          .and change { SecretsManagement::ProjectSecretsManagerMaintenanceTask.count }.by(2)
      end

      it 'leaves tasks with NULL last_processed_at so cron picks them up via :unprocessed' do
        bulk_call

        tasks = SecretsManagement::ProjectSecretsManagerMaintenanceTask.where(project_id: projects[0..1].map(&:id))
        expect(tasks.pluck(:last_processed_at)).to all(be_nil)
        expect(tasks.pluck(:user_id)).to all(be_nil)
        expect(tasks.pluck(:action)).to all(eq('deprovision'))
      end

      it 'does not enqueue any worker; cron is the driver here' do
        bulk_call

        expect(deprovision_worker_spy).not_to have_received(:perform_async)
        expect(deprovision_worker_spy).not_to have_received(:bulk_perform_async)
      end
    end
  end
end
