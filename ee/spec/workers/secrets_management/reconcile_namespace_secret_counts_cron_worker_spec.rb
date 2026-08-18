# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ReconcileNamespaceSecretCountsCronWorker, feature_category: :secrets_management do
  let(:worker) { described_class.new }
  let(:reconcile_worker_spy) { class_spy(SecretsManagement::ReconcileNamespaceSecretCountWorker) }

  before do
    stub_const('SecretsManagement::ReconcileNamespaceSecretCountWorker', reconcile_worker_spy)
  end

  describe '#perform' do
    subject(:run_worker) { worker.perform }

    let_it_be_with_reload(:active_group) { create(:group) }
    let_it_be(:provisioning_group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project) }

    let_it_be(:active_group_manager) do
      create(:group_secrets_manager, :active, group: active_group)
    end

    let_it_be(:provisioning_group_manager) do
      create(:group_secrets_manager, :provisioning, group: provisioning_group)
    end

    let_it_be(:active_project_manager) do
      create(:project_secrets_manager, :active, project: project)
    end

    it 'enqueues a reconcile worker for each group secrets manager regardless of state' do
      run_worker

      expect(reconcile_worker_spy).to have_received(:perform_in)
        .with(kind_of(ActiveSupport::Duration), active_group.id)
      expect(reconcile_worker_spy).to have_received(:perform_in)
        .with(kind_of(ActiveSupport::Duration), provisioning_group.id)
    end

    it 'enqueues a reconcile worker for each project secrets manager' do
      run_worker

      expect(reconcile_worker_spy).to have_received(:perform_in)
        .with(kind_of(ActiveSupport::Duration), project.project_namespace_id)
    end

    context 'when database is read-only' do
      before do
        allow(Gitlab::Database).to receive(:read_only?).and_return(true)
      end

      it 'does not enqueue any workers' do
        run_worker

        expect(reconcile_worker_spy).not_to have_received(:perform_in)
      end
    end
  end

  it_behaves_like 'an idempotent worker'
end
