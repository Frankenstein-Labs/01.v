# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsManagers::InitializeService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }

  let(:resource) { project }
  let(:service) { described_class.new(project, user) }

  let(:secrets_manager_class) { SecretsManagement::ProjectSecretsManager }
  let(:maintenance_task_class) { SecretsManagement::ProjectSecretsManagerMaintenanceTask }
  let(:provision_worker_class) { SecretsManagement::ProvisionProjectSecretsManagerTaskWorker }
  let(:payload_key) { :project_secrets_manager }
  let(:resource_type) { 'project' }
  let(:create_existing_secrets_manager) do
    -> { create(:project_secrets_manager, project: project) }
  end

  before do
    stub_feature_flags(secrets_manager_paid_experience: false)
  end

  describe '#execute' do
    it_behaves_like 'a secrets manager initialize service'

    it_behaves_like 'a secrets manager entitlement gate' do
      let(:gated_action) { 'initialized' }
    end

    context 'when the resource has no secrets manager' do
      subject(:result) { service.execute }

      it 'persists scope-specific snapshot ids on the maintenance task', :aggregate_failures do
        result

        task = maintenance_task_class.last
        expect(task.project_id).to eq(project.id)
        expect(task.organization_id).to eq(project.organization_id)
        expect(task.root_namespace_id).to eq(project.root_ancestor.id)
      end
    end

    context 'when a deprovision task is already pending for the project' do
      let(:provision_worker_spy) { class_spy(provision_worker_class) }

      subject(:result) { service.execute }

      before do
        create(:project_secrets_manager_maintenance_task, :deprovision, project: project)
        stub_const(provision_worker_class.name, provision_worker_spy)
      end

      it 'returns an error and does not create an SM or enqueue provisioning', :aggregate_failures do
        expect(result).to be_error
        expect(result.message).to eq('Secrets manager deprovision is in progress for the project.')
        expect(provision_worker_spy).not_to have_received(:perform_async)
        expect(project.reload.secrets_manager).to be_nil
      end
    end

    context 'when the project belongs to a user namespace' do
      let_it_be_with_reload(:user_project) { create(:project) }

      let(:provision_worker_spy) { class_spy(provision_worker_class) }
      let(:service) { described_class.new(user_project, user) }

      subject(:result) { service.execute }

      before do
        stub_const(provision_worker_class.name, provision_worker_spy)
      end

      it 'returns an error and does not enqueue provisioning', :aggregate_failures do
        expect(result).to be_error
        expect(result.message).to eq('Secrets manager is not available for projects in user namespaces.')
        expect(provision_worker_spy).not_to have_received(:perform_async)
        expect(user_project.reload.secrets_manager).to be_nil
        expect(maintenance_task_class.count).to eq(0)
      end
    end
  end
end
