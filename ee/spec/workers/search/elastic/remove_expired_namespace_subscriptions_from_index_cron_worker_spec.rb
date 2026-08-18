# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::RemoveExpiredNamespaceSubscriptionsFromIndexCronWorker, :saas,
  feature_category: :global_search do
  subject(:worker) { described_class.new }

  it_behaves_like 'an idempotent worker' do
    it 'calls ::Search::Elastic::DestroyExpiredSubscriptionService service' do
      expect_next_instance_of(::Search::Elastic::DestroyExpiredSubscriptionService) do |service|
        expect(service).to receive(:execute).and_return(5)
      end
      expect(worker).to receive(:log_extra_metadata_on_done).with(:namespaces_removed_count, 5)
      expect(worker).to receive(:log_extra_metadata_on_done).with(:cap_reached, false)

      worker.perform
    end
  end

  context 'when not com?' do
    before do
      allow(::Gitlab).to receive(:com?).and_return(false)
    end

    it 'does nothing' do
      expect(::Search::Elastic::DestroyExpiredSubscriptionService).not_to receive(:new)

      expect(worker.perform).to be_nil
    end
  end
end
