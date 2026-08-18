# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecretsManagers::InitializeService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:resource) { group }
  let(:service) { described_class.new(group, user) }

  let(:secrets_manager_class) { SecretsManagement::GroupSecretsManager }
  let(:maintenance_task_class) { SecretsManagement::GroupSecretsManagerMaintenanceTask }
  let(:provision_worker_class) { SecretsManagement::ProvisionGroupSecretsManagerTaskWorker }
  let(:payload_key) { :group_secrets_manager }
  let(:resource_type) { 'group' }
  let(:create_existing_secrets_manager) do
    -> { create(:group_secrets_manager, group: group) }
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
        expect(task.group_id).to eq(group.id)
        expect(task.organization_id).to eq(group.organization_id)
        expect(task.root_namespace_id).to eq(group.root_ancestor.id)
      end
    end

    context 'when a deprovision task is already pending for the group' do
      let(:provision_worker_spy) { class_spy(provision_worker_class) }

      subject(:result) { service.execute }

      before do
        create(:group_secrets_manager_maintenance_task, :deprovision, group: group)
        stub_const(provision_worker_class.name, provision_worker_spy)
      end

      it 'returns an error and does not create an SM or enqueue provisioning', :aggregate_failures do
        expect(result).to be_error
        expect(result.message).to eq('Secrets manager deprovision is in progress for the group.')
        expect(provision_worker_spy).not_to have_received(:perform_async)
        expect(group.reload.secrets_manager).to be_nil
      end
    end
  end
end
