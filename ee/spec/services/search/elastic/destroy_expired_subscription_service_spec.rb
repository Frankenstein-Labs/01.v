# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::DestroyExpiredSubscriptionService, :saas, feature_category: :global_search do
  describe '#execute' do
    let_it_be(:not_expired_subscription1) { create(:gitlab_subscription, :bronze, end_date: Time.zone.today + 2) }
    let_it_be(:not_expired_subscription2) { create(:gitlab_subscription, :bronze, end_date: Time.zone.today + 100) }
    let_it_be(:recently_expired_subscription) { create(:gitlab_subscription, :bronze, end_date: Time.zone.today - 4) }
    let_it_be(:expired_subscription1) { create(:gitlab_subscription, :bronze, end_date: Time.zone.today - 31) }
    let_it_be(:expired_subscription2) { create(:gitlab_subscription, :bronze, end_date: Time.zone.today - 35) }

    subject(:service) { described_class.new }

    before do
      ElasticsearchIndexedNamespace.safe_find_or_create_by!(namespace_id: not_expired_subscription1.namespace_id)
      ElasticsearchIndexedNamespace.safe_find_or_create_by!(namespace_id: not_expired_subscription2.namespace_id)
      ElasticsearchIndexedNamespace.safe_find_or_create_by!(namespace_id: recently_expired_subscription.namespace_id)
      ElasticsearchIndexedNamespace.safe_find_or_create_by!(namespace_id: expired_subscription1.namespace_id)
      ElasticsearchIndexedNamespace.safe_find_or_create_by!(namespace_id: expired_subscription2.namespace_id)
    end

    it 'finds the subscriptions that expired over a week ago that are in the index and deletes them' do
      expected_args = [
        [expired_subscription1.namespace_id, :delete],
        [expired_subscription2.namespace_id, :delete]
      ]
      expect(ElasticNamespaceIndexerWorker).to receive(:bulk_perform_in)
        .with(described_class::DELAY_INTERVAL, expected_args)

      expect(service.execute).to eq(2)

      expect(ElasticsearchIndexedNamespace.all.pluck(:namespace_id)).to contain_exactly(
        not_expired_subscription1.namespace_id,
        not_expired_subscription2.namespace_id,
        recently_expired_subscription.namespace_id
      )
    end

    it "does not process more records than #{described_class}::MAX_NAMESPACES_TO_REMOVE" do
      stub_const("#{described_class}::MAX_NAMESPACES_TO_REMOVE", 1)
      expect(ElasticNamespaceIndexerWorker).to receive(:bulk_perform_in)
        .with(described_class::DELAY_INTERVAL, an_object_having_attributes(size: 1))

      expect { described_class.new.execute }
        .to change { ElasticsearchIndexedNamespace.count }.by(-1)
    end

    it 'sends deletes to the database in batches' do
      stub_const("#{described_class}::DELETE_BATCH_SIZE", 1)

      expect(ElasticsearchIndexedNamespace).to receive(:primary_key_in).twice.and_call_original

      expect { described_class.new.execute }
        .to change { ElasticsearchIndexedNamespace.count }.by(-2)
    end

    context 'when the exclusive lease is already locked' do
      it 'does nothing' do
        expect(service).to receive(:in_lock).with(described_class.name.underscore, ttl: 1.hour, retries: 0)
        expect(ElasticNamespaceIndexerWorker).not_to receive(:perform_async)

        expect(service.execute).to eq(0)
      end
    end

    context 'when not on .com?' do
      it 'does nothing' do
        allow(Gitlab).to receive(:com?).and_return(false)
        expect(ElasticNamespaceIndexerWorker).not_to receive(:perform_async)

        expect(service.execute).to eq(0)
      end
    end
  end
end
