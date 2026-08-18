# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::EmitSecretsStoredBillableEventCronWorker, feature_category: :secrets_management do
  let(:worker) { described_class.new }
  let(:emit_worker_spy) { class_spy(SecretsManagement::EmitSecretsStoredBillableEventWorker) }

  before do
    stub_const('SecretsManagement::EmitSecretsStoredBillableEventWorker', emit_worker_spy)
    stub_feature_flags(secrets_manager_emit_secret_stored_events: true)
  end

  describe '#perform' do
    subject(:run_worker) { worker.perform }

    let_it_be(:root_group_a) { create(:group) }
    let_it_be(:root_group_b) { create(:group) }
    let_it_be(:subgroup_a) { create(:group, parent: root_group_a) }
    let_it_be(:project_in_a) { create(:project, group: root_group_a) }

    before do
      SecretsManagement::NamespaceSecretCount.upsert_all(
        [
          { namespace_id: root_group_a.id, root_namespace_id: root_group_a.id, count: 3 },
          { namespace_id: subgroup_a.id, root_namespace_id: root_group_a.id, count: 2 },
          { namespace_id: project_in_a.project_namespace_id, root_namespace_id: root_group_a.id, count: 1 },
          { namespace_id: root_group_b.id, root_namespace_id: root_group_b.id, count: 7 }
        ],
        unique_by: :namespace_id
      )
    end

    it 'bulk-enqueues one emission worker per distinct root namespace with namespace context' do
      captured_batches = []
      captured_kwargs = nil
      allow(emit_worker_spy).to receive(:bulk_perform_async_with_contexts) do |batch, **kwargs|
        captured_batches << batch
        captured_kwargs = kwargs
      end

      run_worker

      ids = captured_batches.flat_map { |batch| batch.map(&:id) }
      expect(ids).to contain_exactly(root_group_a.id, root_group_b.id)
      expect(captured_kwargs[:arguments_proc].call(root_group_a)).to eq(root_group_a.id)
      expect(captured_kwargs[:context_proc].call(root_group_a)).to eq(namespace: root_group_a)
    end

    it 'does not enqueue for non-root namespaces under the same root' do
      enqueued_ids = []
      allow(emit_worker_spy).to receive(:bulk_perform_async_with_contexts) do |batch, **|
        enqueued_ids.concat(batch.map(&:id))
      end

      run_worker

      expect(enqueued_ids).not_to include(subgroup_a.id, project_in_a.project_namespace_id)
    end

    context 'when no namespace secret counts exist' do
      before do
        SecretsManagement::NamespaceSecretCount.delete_all
      end

      it 'does not enqueue any workers' do
        run_worker

        expect(emit_worker_spy).not_to have_received(:bulk_perform_async_with_contexts)
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(secrets_manager_emit_secret_stored_events: false)
      end

      it 'does not enqueue any workers' do
        run_worker

        expect(emit_worker_spy).not_to have_received(:bulk_perform_async_with_contexts)
      end
    end

    context 'when the database is read-only' do
      before do
        allow(Gitlab::Database).to receive(:read_only?).and_return(true)
      end

      it 'does not enqueue any workers' do
        run_worker

        expect(emit_worker_spy).not_to have_received(:bulk_perform_async_with_contexts)
      end
    end
  end

  it_behaves_like 'an idempotent worker'
end
