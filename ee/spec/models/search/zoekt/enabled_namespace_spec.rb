# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::EnabledNamespace, feature_category: :global_search do
  let_it_be(:namespace) { create(:group) }

  subject { build(:zoekt_enabled_namespace, namespace: namespace) }

  describe 'relations' do
    it { is_expected.to belong_to(:namespace).inverse_of(:zoekt_enabled_namespace) }
    it { is_expected.to have_many(:indices) }
    it { is_expected.to have_many(:replicas) }
    it { is_expected.to have_many(:nodes).through(:indices) }
  end

  describe 'validations' do
    it 'only allows root namespaces to be indexed' do
      subgroup = create(:group, parent: namespace)

      expect(described_class.new(namespace: subgroup)).to be_invalid
    end

    describe 'number_of_replicas_override' do
      it 'allows nil value' do
        enabled_namespace = build(:zoekt_enabled_namespace, number_of_replicas_override: nil)

        expect(enabled_namespace).to be_valid
      end

      it 'allows positive values' do
        enabled_namespace = build(:zoekt_enabled_namespace, number_of_replicas_override: 1)

        expect(enabled_namespace).to be_valid
      end

      it 'does not allow zero' do
        enabled_namespace = build(:zoekt_enabled_namespace, number_of_replicas_override: 0)

        expect(enabled_namespace).to be_invalid
        expect(enabled_namespace.errors[:number_of_replicas_override]).to include('must be greater than 0')
      end

      it 'does not allow negative values' do
        enabled_namespace = build(:zoekt_enabled_namespace, number_of_replicas_override: -1)

        expect(enabled_namespace).to be_invalid
        expect(enabled_namespace.errors[:number_of_replicas_override]).to include('must be greater than 0')
      end
    end
  end

  describe 'scopes' do
    let_it_be(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }

    describe '.for_root_namespace_id' do
      let_it_be(:another_zoekt_enabled_namespace) { create(:zoekt_enabled_namespace) }

      it 'returns records for the specified namespace' do
        expect(described_class.for_root_namespace_id(namespace.id).count).to eq(1)
      end
    end

    describe '.preload_storage_statistics' do
      it 'returns Search::Zoekt::EnabledNamespace with missing zoekt index' do
        result = described_class.preload_storage_statistics.first
        expect(result.association(:namespace)).to be_loaded
        expect(result.namespace.association(:root_storage_statistics)).to be_loaded
        result = described_class.first
        expect(result.association(:namespace)).not_to be_loaded
        expect(result.namespace.association(:root_storage_statistics)).not_to be_loaded
      end
    end

    describe '.recent' do
      it 'returns ordered by id desc' do
        zoekt_enabled_namespace_2 = create(:zoekt_enabled_namespace)

        expect(described_class.recent).to match([zoekt_enabled_namespace_2, zoekt_enabled_namespace])
      end
    end

    describe '.search_enabled' do
      it 'returns namespaces that are enabled for search' do
        create(:zoekt_enabled_namespace, search: false)

        expect(described_class.search_enabled.count).to eq(1)
      end
    end

    describe '.with_limit' do
      it 'returns only the amount of records requested' do
        create(:zoekt_enabled_namespace)

        expect(described_class.with_limit(1).count).to eq(1)
      end
    end

    describe '.with_missing_indices' do
      let_it_be(:zoekt_enabled_namespace2) { create(:zoekt_enabled_namespace) }

      before do
        create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace2)
      end

      it 'returns Search::Zoekt::EnabledNamespace with missing zoekt index' do
        expect(described_class.with_missing_indices).to contain_exactly(zoekt_enabled_namespace)
      end
    end

    describe '.with_all_ready_indices' do
      let_it_be(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace) } # With all ready indices
      let_it_be(:zoekt_enabled_namespace2) { create(:zoekt_enabled_namespace) } # With some non ready indices
      let_it_be(:zoekt_enabled_namespace3) { create(:zoekt_enabled_namespace) } # Without any indices

      subject(:collection) { described_class.with_all_ready_indices }

      before do
        create(:zoekt_index, :ready, zoekt_enabled_namespace: zoekt_enabled_namespace)
        create(:zoekt_index, :ready, zoekt_enabled_namespace: zoekt_enabled_namespace2)
        create(:zoekt_index, :pending, zoekt_enabled_namespace: zoekt_enabled_namespace2)
      end

      it 'returns Search::Zoekt::EnabledNamespace with all ready indices' do
        expect(collection).to include(zoekt_enabled_namespace)
        expect(collection).not_to include(zoekt_enabled_namespace2)
        expect(collection).not_to include(zoekt_enabled_namespace3)
      end
    end

    shared_context 'with mismatched replica namespaces' do
      let_it_be(:namespace1) { create(:group) }
      let_it_be(:namespace2) { create(:group) }
      let_it_be(:namespace3) { create(:group) }
      let_it_be(:namespace4) { create(:group) }

      let_it_be(:enabled_namespace_with_too_many) do
        create(:zoekt_enabled_namespace, namespace: namespace1, number_of_replicas_override: 2)
      end

      let_it_be(:enabled_namespace_with_too_few) do
        create(:zoekt_enabled_namespace, namespace: namespace2)
      end

      let_it_be(:enabled_namespace_with_exact_replicas) do
        create(:zoekt_enabled_namespace, namespace: namespace3)
      end

      let_it_be(:enabled_namespace_with_no_replicas) do
        create(:zoekt_enabled_namespace, namespace: namespace4)
      end

      let(:namespace_ids) do
        [
          enabled_namespace_with_too_many.id,
          enabled_namespace_with_too_few.id,
          enabled_namespace_with_exact_replicas.id,
          enabled_namespace_with_no_replicas.id
        ]
      end

      before do
        stub_const('Search::Zoekt::Settings', Class.new)
        allow(Search::Zoekt::Settings).to receive(:default_number_of_replicas).and_return(2)
      end

      before_all do
        create_list(:zoekt_replica, 3, zoekt_enabled_namespace: enabled_namespace_with_too_many)
        create(:zoekt_replica, zoekt_enabled_namespace: enabled_namespace_with_too_few)
        create_list(:zoekt_replica, 2, zoekt_enabled_namespace: enabled_namespace_with_exact_replicas)
      end
    end

    describe '.with_mismatched_replicas' do
      include_context 'with mismatched replica namespaces'

      subject(:collection) { described_class.id_in(namespace_ids).with_mismatched_replicas }

      it 'returns enabled namespaces with too many replicas' do
        expect(collection).to include(enabled_namespace_with_too_many)
      end

      it 'returns enabled namespaces with too few replicas' do
        expect(collection).to include(enabled_namespace_with_too_few)
      end

      it 'does not return namespaces with exact number of replicas' do
        expect(collection).not_to include(enabled_namespace_with_exact_replicas)
      end

      it 'returns namespaces with zero replicas' do
        expect(collection).to include(enabled_namespace_with_no_replicas)
      end
    end

    describe '.each_batch_with_mismatched_replicas' do
      include_context 'with mismatched replica namespaces'

      it 'yields enabled namespaces with mismatched replicas' do
        yielded = []
        described_class.id_in(namespace_ids).each_batch_with_mismatched_replicas { |ns| yielded << ns }

        expect(yielded).to contain_exactly(
          enabled_namespace_with_too_many,
          enabled_namespace_with_too_few,
          enabled_namespace_with_no_replicas
        )
      end

      it 'does not yield namespaces with exact number of replicas' do
        yielded = []
        described_class.id_in(namespace_ids).each_batch_with_mismatched_replicas { |ns| yielded << ns }

        expect(yielded).not_to include(enabled_namespace_with_exact_replicas)
      end

      it 'processes records in batches' do
        expect(described_class).to receive(:each_batch).with(of: 5000).and_call_original

        described_class.each_batch_with_mismatched_replicas(batch_size: 5000) { |_ns| true }
      end

      context 'when custom batch size is provided' do
        it 'uses the provided batch size' do
          expect(described_class).to receive(:each_batch).with(of: 100).and_call_original

          described_class.each_batch_with_mismatched_replicas(batch_size: 100) { |_ns| true }
        end
      end
    end

    describe '.destroy_namespaces_with_expired_subscriptions!', :saas do
      subject(:destroy_namespaces) { described_class.destroy_namespaces_with_expired_subscriptions! }

      let_it_be(:expired_date) { Time.zone.today - Search::Zoekt::EXPIRED_SUBSCRIPTION_GRACE_PERIOD }
      let_it_be(:expired_subscription) { create(:gitlab_subscription, :ultimate, end_date: expired_date - 1.day) }
      let_it_be(:grace_period_subscription) { create(:gitlab_subscription, :ultimate, end_date: expired_date + 1.day) }
      let_it_be(:ultimate_subscription) { create(:gitlab_subscription, :ultimate) }
      let_it_be(:trial_subscription) { create(:gitlab_subscription, :ultimate, :active_trial) }
      let_it_be(:expired_trial) do
        create(
          :gitlab_subscription,
          :gold,
          trial: true,
          trial_starts_on: 1.year.ago,
          trial_ends_on: expired_date - 1.day
        )
      end

      let_it_be(:grace_period_trial) do
        create(
          :gitlab_subscription,
          :ultimate,
          trial: true,
          trial_starts_on: 1.year.ago,
          trial_ends_on: expired_date + 1.day
        )
      end

      let_it_be(:zoekt_enabled_namespace_ultimate_expired) do
        create(:zoekt_enabled_namespace, namespace: expired_subscription.namespace)
      end

      let_it_be(:zoekt_enabled_namespace_ultimate_grace_period) do
        create(:zoekt_enabled_namespace, namespace: grace_period_subscription.namespace)
      end

      let_it_be(:zoekt_enabled_namespace_ultimate) do
        create(:zoekt_enabled_namespace, namespace: ultimate_subscription.namespace)
      end

      let_it_be(:zoekt_enabled_namespace_trial) do
        create(:zoekt_enabled_namespace, namespace: trial_subscription.namespace)
      end

      let_it_be(:_zoekt_enabled_namespace_trial_expired) do
        create(:zoekt_enabled_namespace, namespace: expired_trial.namespace)
      end

      let_it_be(:zoekt_enabled_namespace_trial_grace_period) do
        create(:zoekt_enabled_namespace, namespace: grace_period_trial.namespace)
      end

      it 'destroys expired subscriptions' do
        expect { destroy_namespaces }.to change { ::Search::Zoekt::EnabledNamespace.count }.by(-3)
        expect(described_class.all).to contain_exactly(
          zoekt_enabled_namespace_ultimate_grace_period,
          zoekt_enabled_namespace_ultimate,
          zoekt_enabled_namespace_trial,
          zoekt_enabled_namespace_trial_grace_period
        )
      end
    end
  end

  describe '.update_last_used_storage_bytes!' do
    let_it_be_with_reload(:enabled_namespace) { create(:zoekt_enabled_namespace) }

    subject(:update_last_used_storage_bytes) { described_class.update_last_used_storage_bytes! }

    context 'when there are no replicas or indices' do
      it 'updates metadata with zero bytes' do
        expect { update_last_used_storage_bytes }
          .to change { enabled_namespace.reload.metadata['last_used_storage_bytes'] }
          .from(nil).to(0)
      end
    end

    context 'when there are replicas and indices with storage bytes' do
      let_it_be(:replica1) { create(:zoekt_replica, zoekt_enabled_namespace: enabled_namespace) }
      let_it_be(:replica2) { create(:zoekt_replica, zoekt_enabled_namespace: enabled_namespace) }

      before do
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica1, used_storage_bytes: 100)
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica1, used_storage_bytes: 200)
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica2, used_storage_bytes: 150)
      end

      it 'updates metadata with the maximum sum of used storage bytes' do
        expect { update_last_used_storage_bytes }
          .to change { enabled_namespace.reload.metadata['last_used_storage_bytes'] }
          .from(nil).to(300)
      end
    end

    context 'when there are replicas with no indices' do
      before do
        create(:zoekt_replica, zoekt_enabled_namespace: enabled_namespace)
      end

      it 'updates metadata with zero bytes' do
        expect { update_last_used_storage_bytes }
          .to change { enabled_namespace.reload.metadata['last_used_storage_bytes'] }
          .from(nil).to(0)
      end
    end

    context 'when there are multiple replicas with different total storage bytes' do
      let_it_be(:replica1) { create(:zoekt_replica, zoekt_enabled_namespace: enabled_namespace) }
      let_it_be(:replica2) { create(:zoekt_replica, zoekt_enabled_namespace: enabled_namespace) }
      let_it_be(:replica3) { create(:zoekt_replica, zoekt_enabled_namespace: enabled_namespace) }

      before do
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica1, used_storage_bytes: 100)
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica2, used_storage_bytes: 200)
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica2, used_storage_bytes: 300)
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica3, used_storage_bytes: 150)
      end

      it 'updates metadata with the maximum sum of used storage bytes' do
        expect { update_last_used_storage_bytes }
          .to change { enabled_namespace.reload.metadata['last_used_storage_bytes'] }
          .from(nil).to(500)
      end
    end

    context 'when metadata already contains last_used_storage_bytes' do
      before do
        enabled_namespace.update_column(:metadata, { last_used_storage_bytes: 1000, other_key: 'value' })
        create(:zoekt_replica, zoekt_enabled_namespace: enabled_namespace) do |replica|
          create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica, used_storage_bytes: 500)
        end
      end

      it 'updates only the last_used_storage_bytes in metadata' do
        expect { update_last_used_storage_bytes }
          .to change { enabled_namespace.reload.metadata['last_used_storage_bytes'] }
          .from(1000).to(500)

        expect(enabled_namespace.metadata['other_key']).to eq('value')
      end
    end
  end

  describe '.with_rollout_blocked', :freeze_time do
    let_it_be(:setting) { create(:application_setting) }
    let_it_be(:new_failed) { create(:zoekt_enabled_namespace, last_rollout_failed_at: Time.current.iso8601) }
    let_it_be(:old_failed) { create(:zoekt_enabled_namespace, last_rollout_failed_at: 2.days.ago.iso8601) }
    let_it_be(:never_failed) { create(:zoekt_enabled_namespace) }

    context 'when setting rollout_retry_interval is nil' do
      before do
        allow(::Search::Zoekt::Settings).to receive(:rollout_retry_interval).and_return(nil)
      end

      it 'returns records with last_rollout_failed_at is set' do
        expect(described_class.with_rollout_blocked).to include(new_failed, old_failed)
        expect(described_class.with_rollout_blocked).not_to include(never_failed)
      end
    end

    it 'returns records with last_rollout_failed_at set newer than rollout_retry_interval' do
      allow(::Search::Zoekt::Settings).to receive(:rollout_retry_interval).and_return(1.day)
      expect(described_class.with_rollout_blocked).to include(new_failed)
      expect(described_class.with_rollout_blocked).not_to include(*[old_failed, never_failed])
    end
  end

  describe '.with_rollout_allowed' do
    let_it_be(:setting) { create(:application_setting) }
    let_it_be(:new_failed) { create(:zoekt_enabled_namespace, last_rollout_failed_at: Time.current.iso8601) }
    let_it_be(:old_failed) { create(:zoekt_enabled_namespace, last_rollout_failed_at: 2.days.ago.iso8601) }
    let_it_be(:never_failed) { create(:zoekt_enabled_namespace) }

    context 'when setting rollout_retry_interval is nil' do
      before do
        allow(::Search::Zoekt::Settings).to receive(:rollout_retry_interval).and_return(nil)
      end

      it 'returns records with last_rollout_failed_at is not set' do
        expect(described_class.with_rollout_allowed).to include(never_failed)
        expect(described_class.with_rollout_allowed).not_to include(*[old_failed, new_failed])
      end
    end

    it 'returns with last_rollout_failed_at is nil or set to older than DEFAULT_ROLLOUT_RETRY_INTERVAL' do
      expect(described_class.with_rollout_allowed).to include(*[never_failed, old_failed])
      expect(described_class.with_rollout_allowed).not_to include(new_failed)
    end
  end

  describe '#number_of_replicas' do
    let_it_be(:_) { create(:application_setting) }

    before do
      stub_ee_application_setting(zoekt_default_number_of_replicas: 2)
    end

    context 'when number_of_replicas is not set for the namespace' do
      subject(:np) { create(:zoekt_enabled_namespace, namespace: namespace) }

      it 'returns the number from application settings' do
        expect(np.number_of_replicas).to eq(2)
      end
    end

    context 'when the number_of_replicas is set for the namespace' do
      subject(:np) { create(:zoekt_enabled_namespace, namespace: namespace, number_of_replicas_override: 3) }

      it 'returns the number of replicas set for the namespace' do
        expect(np.number_of_replicas).to eq(3)
      end
    end
  end
end
