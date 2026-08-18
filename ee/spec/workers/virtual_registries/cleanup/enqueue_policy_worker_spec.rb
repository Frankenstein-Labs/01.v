# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Cleanup::EnqueuePolicyWorker, feature_category: :virtual_registry do
  let(:worker) { described_class.new }

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky
  it_behaves_like 'an idempotent worker'

  it 'has the correct worker attributes' do
    expect(described_class.get_feature_category).to eq(:virtual_registry)
    expect(described_class.get_urgency).to eq(:low)
  end

  describe '#perform' do
    subject(:perform) { worker.perform }

    shared_examples 'not enqueuing cleanup jobs' do
      it 'does not enqueue cleanup policy jobs' do
        expect(VirtualRegistries::Cleanup::ExecutePolicyWorker).not_to receive(:perform_with_capacity)
        expect(worker).not_to receive(:log_extra_metadata_on_done)

        perform
      end
    end

    context 'when there are no runnable cleanup policies' do
      it_behaves_like 'not enqueuing cleanup jobs'
    end

    context 'when there are runnable cleanup policies' do
      before do
        # Create runnable policies (enabled and past next_run_at)
        create(:virtual_registries_cleanup_policy, :enabled).tap do |policy|
          policy.update_column(:next_run_at, 1.hour.ago)
        end
        create(:virtual_registries_cleanup_policy, :enabled).tap do |policy|
          policy.update_column(:next_run_at, 30.minutes.ago)
        end

        # Create non-runnable policies
        create(:virtual_registries_cleanup_policy) # disabled
        create(:virtual_registries_cleanup_policy, :enabled).tap do |policy|
          policy.update_column(:next_run_at, 1.hour.from_now) # future run time
        end
        create(:virtual_registries_cleanup_policy, :enabled, :running).tap do |policy|
          policy.update_column(:next_run_at, 1.hour.ago) # running status
        end
      end

      it 'enqueues cleanup policy jobs' do
        expect(VirtualRegistries::Cleanup::ExecutePolicyWorker).to receive(:perform_with_capacity)
        expect(worker).to receive(:log_extra_metadata_on_done).with(:pending_cleanup_policies_count, 2)

        perform
      end

      it 'executes with the correct context' do
        expect(worker).to receive(:with_context).with(
          related_class: described_class,
          caller_id: described_class.name
        ).and_call_original

        perform
      end
    end
  end
end
