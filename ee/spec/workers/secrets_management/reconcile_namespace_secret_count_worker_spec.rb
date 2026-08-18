# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ReconcileNamespaceSecretCountWorker, feature_category: :secrets_management do
  let_it_be(:group) { create(:group) }
  let(:namespace_id) { group.id }
  let(:job_args) { [namespace_id] }

  describe '#perform' do
    it 'delegates to the refresh service with the given namespace id and no current_user' do
      expect(SecretsManagement::NamespaceSecretCounts::RefreshService)
        .to receive(:execute_for_namespace_id)
        .with(namespace_id, current_user_id: nil)

      described_class.new.perform(namespace_id)
    end

    it 'forwards the current_user_id when the second argument is provided' do
      user = create(:user)

      expect(SecretsManagement::NamespaceSecretCounts::RefreshService)
        .to receive(:execute_for_namespace_id)
        .with(namespace_id, current_user_id: user.id)

      described_class.new.perform(namespace_id, user.id)
    end

    # Sidekiq jobs enqueued before the second argument was added pass only the
    # namespace_id; the worker must remain backwards compatible with that shape.
    it 'is backwards compatible with single-arg payloads' do
      allow(SecretsManagement::NamespaceSecretCounts::RefreshService)
        .to receive(:execute_for_namespace_id)

      described_class.new.perform(namespace_id)

      expect(SecretsManagement::NamespaceSecretCounts::RefreshService)
        .to have_received(:execute_for_namespace_id).with(namespace_id, current_user_id: nil)
    end
  end

  # The dedup middleware itself is exercised by Sidekiq tests upstream;
  # here we assert that we have configured the strategy that prevents the
  # race conditions described in the worker source: two concurrent jobs
  # for the same namespace where the second could overwrite a fresh count
  # with a stale one.
  describe 'deduplication' do
    it 'is configured to dedup until executed including scheduled' do
      expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
      expect(described_class.get_deduplication_options).to include(including_scheduled: true)
    end

    describe '.idempotency_arguments' do
      it 'narrows the dedup key to namespace_id only' do
        expect(described_class.idempotency_arguments([42, 7])).to eq([42])
        expect(described_class.idempotency_arguments([42, 99])).to eq([42])
        expect(described_class.idempotency_arguments([42, nil])).to eq([42])
        expect(described_class.idempotency_arguments([42])).to eq([42])
      end
    end
  end

  it_behaves_like 'an idempotent worker' do
    it 'converges to a single count row regardless of how many times it runs' do
      perform_idempotent_work

      expect(SecretsManagement::NamespaceSecretCount.where(namespace_id: namespace_id).count).to be <= 1
    end
  end
end
