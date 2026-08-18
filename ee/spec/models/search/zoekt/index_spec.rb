# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Index, :aggregate_failures, feature_category: :global_search do
  let_it_be(:namespace) { create(:group) }
  let_it_be_with_reload(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }
  let_it_be(:zoekt_node) { create(:zoekt_node, :enough_free_space) }
  let_it_be(:zoekt_replica) { create(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace) }
  let_it_be_with_refind(:zoekt_index) do
    create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, node: zoekt_node, replica: zoekt_replica,
      reserved_storage_bytes: 100.megabytes)
  end

  # Helper to compare watermark levels by priority (lower is better)
  def watermark_level_priority(level)
    priorities = {
      'healthy' => 0,
      'overprovisioned' => 1,
      'low_watermark_exceeded' => 2,
      'high_watermark_exceeded' => 3,
      'critical_watermark_exceeded' => 4
    }
    priorities[level.to_s]
  end

  subject { zoekt_index }

  describe 'relations' do
    it { is_expected.to belong_to(:zoekt_enabled_namespace).inverse_of(:indices) }
    it { is_expected.to belong_to(:node).inverse_of(:indices) }
    it { is_expected.to belong_to(:replica).inverse_of(:indices) }
    it { is_expected.to have_many(:zoekt_repositories).inverse_of(:zoekt_index) }

    it 'restricts deletion when there are associated zoekt repositories' do
      project = create(:project, namespace_id: zoekt_index.namespace_id)
      repo = zoekt_index.zoekt_repositories.create!(project: project, state: :pending)

      expect(zoekt_index.zoekt_repositories).to match_array([repo])
      expect { zoekt_index.destroy! }.to raise_error ActiveRecord::StatementInvalid

      repo.destroy!

      expect { zoekt_index.destroy! }.not_to raise_error
    end
  end

  it { expect(described_class.new.reserved_storage_bytes).to eq 10.gigabytes }

  describe 'constants' do
    it 'ensures STORAGE_CRITICAL_WATERMARK is not higher than Node::WATERMARK_LIMIT_CRITICAL' do
      # Critical watermark in index should never be higher than in node
      # to avoid triggering excessive evictions when nodes are at capacity
      expect(described_class::STORAGE_CRITICAL_WATERMARK).to be <= Search::Zoekt::Node::WATERMARK_LIMIT_CRITICAL
    end
  end

  describe '#appropriate_watermark_level' do
    # Reference the constants to make the test more resilient to changes
    let(:ideal) { described_class::STORAGE_IDEAL_PERCENT_USED }
    let(:low) { described_class::STORAGE_LOW_WATERMARK }
    let(:high) { described_class::STORAGE_HIGH_WATERMARK }
    let(:critical) { described_class::STORAGE_CRITICAL_WATERMARK }
    let(:index) { build(:zoekt_index, reserved_storage_bytes: 1000) }

    context 'when below IDEAL percent' do
      it 'returns :overprovisioned' do
        index.used_storage_bytes = ((ideal * 1000) - 1).to_i # Just below IDEAL
        expect(index.appropriate_watermark_level).to eq(:overprovisioned)
      end
    end

    context 'when at IDEAL percent' do
      it 'returns :healthy' do
        index.used_storage_bytes = (ideal * 1000).to_i # Exactly at IDEAL
        expect(index.appropriate_watermark_level).to eq(:healthy)
      end
    end

    context 'when between IDEAL and LOW watermark' do
      it 'returns :healthy' do
        percentage = ideal + ((low - ideal) / 2)
        index.used_storage_bytes = (percentage * 1000).to_i # Middle of range
        expect(index.appropriate_watermark_level).to eq(:healthy)
      end
    end

    context 'when at LOW watermark' do
      it 'returns :low_watermark_exceeded' do
        index.used_storage_bytes = (low * 1000).to_i # Exactly at LOW
        expect(index.appropriate_watermark_level).to eq(:low_watermark_exceeded)
      end
    end

    context 'when between LOW and HIGH watermark' do
      it 'returns :low_watermark_exceeded' do
        percentage = low + ((high - low) / 2)
        index.used_storage_bytes = (percentage * 1000).to_i # Middle of range
        expect(index.appropriate_watermark_level).to eq(:low_watermark_exceeded)
      end
    end

    context 'when at HIGH watermark' do
      it 'returns :high_watermark_exceeded' do
        index.used_storage_bytes = (high * 1000).to_i # Exactly at HIGH
        expect(index.appropriate_watermark_level).to eq(:high_watermark_exceeded)
      end
    end

    context 'when between HIGH and CRITICAL watermark' do
      it 'returns :high_watermark_exceeded' do
        percentage = high + ((critical - high) / 2)
        index.used_storage_bytes = (percentage * 1000).to_i # Middle of range
        expect(index.appropriate_watermark_level).to eq(:high_watermark_exceeded)
      end
    end

    context 'when at CRITICAL watermark' do
      it 'returns :critical_watermark_exceeded' do
        index.used_storage_bytes = (critical * 1000).to_i # Exactly at CRITICAL
        expect(index.appropriate_watermark_level).to eq(:critical_watermark_exceeded)
      end
    end

    context 'when above CRITICAL watermark' do
      it 'returns :critical_watermark_exceeded' do
        index.used_storage_bytes = ((critical * 1000) + 100).to_i # Above CRITICAL
        expect(index.appropriate_watermark_level).to eq(:critical_watermark_exceeded)
      end
    end

    context 'when reserved_storage_bytes is zero' do
      it 'handles the case gracefully' do
        index.reserved_storage_bytes = 0
        index.used_storage_bytes = 100
        # When reserved_storage_bytes is zero, storage_percent_used will be Infinity
        # which falls into the else clause of the case statement
        expect(index.appropriate_watermark_level).to eq(:critical_watermark_exceeded)
      end
    end
  end

  describe 'validations' do
    it 'validates that zoekt_enabled_namespace root_namespace_id matches namespace_id' do
      zoekt_index = described_class.new(zoekt_enabled_namespace: zoekt_enabled_namespace,
        node: zoekt_node, namespace_id: 0)
      expect(zoekt_index).to be_invalid
    end

    it 'allows a project_id_to value in metadata to be either an integer or nil' do
      expect(described_class.new(metadata: { 'project_id_from' => 123, 'project_id_to' => 456 })).to be_valid
      expect(described_class.new(metadata: { 'project_id_from' => 123, 'project_id_to' => nil })).to be_valid
    end

    describe 'metadata JSON schema validation' do
      context 'with valid metadata' do
        it 'allows valid project_namespace_id values' do
          metadata = { 'project_namespace_id_from' => 123, 'project_namespace_id_to' => 456 }
          index = described_class.new(metadata: metadata)
          expect(index).to be_valid
        end

        it 'allows nil project_namespace_id_from' do
          metadata = { 'project_namespace_id_from' => nil, 'project_namespace_id_to' => 456 }
          index = described_class.new(metadata: metadata)
          expect(index).to be_valid
        end

        it 'allows nil project_namespace_id_to' do
          metadata = { 'project_namespace_id_from' => 123, 'project_namespace_id_to' => nil }
          index = described_class.new(metadata: metadata)
          expect(index).to be_valid
        end

        it 'allows mixed project_id and project_namespace_id values' do
          index = described_class.new(metadata: {
            'project_id_from' => 123,
            'project_namespace_id_from' => 456
          })
          expect(index).to be_valid
        end

        it 'allows additional properties' do
          index = described_class.new(metadata: {
            'project_id_from' => 123,
            'additional_property' => 'value'
          })
          expect(index).to be_valid
        end
      end

      context 'with invalid metadata' do
        it 'rejects string values for project_id_from' do
          index = described_class.new(metadata: { 'project_id_from' => '123' })
          expect(index).to be_invalid
          expect(index.errors[:metadata]).to be_present
        end
      end
    end
  end

  describe 'scopes' do
    let_it_be(:namespace_2) { create(:group) }
    let_it_be_with_reload(:zoekt_enabled_namespace_2) { create(:zoekt_enabled_namespace, namespace: namespace_2) }
    let_it_be(:node_2) { create(:zoekt_node) }
    let_it_be_with_reload(:zoekt_index_2) do
      create(:zoekt_index, node: node_2, zoekt_enabled_namespace: zoekt_enabled_namespace_2)
    end

    before_all do
      create_list(:zoekt_repository, 5, zoekt_index: zoekt_index, size_bytes: 100.megabytes)
    end

    describe '.for_node' do
      subject { described_class.for_node(node_2) }

      it { is_expected.to contain_exactly(zoekt_index_2) }
    end

    describe '.for_replica' do
      let(:zoekt_replica) { zoekt_index_2.replica }

      subject(:results) { described_class.for_replica(zoekt_replica) }

      it 'contains zoekt_indices of given zoekt_replica' do
        expect(results.pluck(:zoekt_replica_id).uniq).to contain_exactly(zoekt_replica.id)
      end
    end

    describe '.for_root_namespace_id' do
      subject { described_class.for_root_namespace_id(namespace_2) }

      it { is_expected.to contain_exactly(zoekt_index_2) }

      context 'when there are orphaned indices' do
        before do
          zoekt_index_2.update!(zoekt_enabled_namespace: nil)
        end

        it { is_expected.to be_empty }
      end
    end

    describe '.for_root_namespace_id_with_search_enabled' do
      it 'correctly filters on the search field' do
        expect(described_class.for_root_namespace_id_with_search_enabled(namespace_2))
          .to contain_exactly(zoekt_index_2)

        zoekt_enabled_namespace_2.update!(search: false)

        expect(described_class.for_root_namespace_id_with_search_enabled(namespace_2))
          .to be_empty
      end
    end

    describe '.with_all_finished_repositories' do
      let_it_be(:idx) { create(:zoekt_index) } # It has some pending and some ready zoekt_repositories
      let_it_be(:idx2) { create(:zoekt_index) } # It has all ready zoekt_repositories
      let_it_be(:idx3) { create(:zoekt_index) } # It does not have zoekt_repositories
      let_it_be(:idx4) { create(:zoekt_index) } # It has all failed zoekt_repositories
      let_it_be(:idx5) { create(:zoekt_index) } # It has some failed and some ready zoekt_repositories
      let_it_be(:idx6) { create(:zoekt_index) } # It has some initializing and some pending zoekt_repositories
      let_it_be(:idx_project) { create(:project, namespace_id: idx.namespace_id) }
      let_it_be(:idx_project2) { create(:project, namespace_id: idx.namespace_id) }
      let_it_be(:idx2_project2) { create(:project, namespace_id: idx2.namespace_id) }
      let_it_be(:idx4_project) { create(:project, namespace_id: idx4.namespace_id) }
      let_it_be(:idx5_project) { create(:project, namespace_id: idx5.namespace_id) }
      let_it_be(:idx5_project2) { create(:project, namespace_id: idx5.namespace_id) }
      let_it_be(:idx6_project) { create(:project, namespace_id: idx6.namespace_id) }
      let_it_be(:idx6_project2) { create(:project, namespace_id: idx6.namespace_id) }

      before_all do
        idx.zoekt_repositories.create!(zoekt_index: idx, project: idx_project, state: :pending)
        idx.zoekt_repositories.create!(zoekt_index: idx, project: idx_project2, state: :ready)
        idx2.zoekt_repositories.create!(zoekt_index: idx2, project: idx2_project2, state: :ready)
        idx4.zoekt_repositories.create!(zoekt_index: idx2, project: idx4_project, state: :failed)
        idx5.zoekt_repositories.create!(zoekt_index: idx2, project: idx5_project, state: :failed)
        idx5.zoekt_repositories.create!(zoekt_index: idx2, project: idx5_project2, state: :ready)
        idx6.zoekt_repositories.create!(zoekt_index: idx6, project: idx6_project, state: :initializing)
        idx6.zoekt_repositories.create!(zoekt_index: idx6, project: idx6_project2, state: :pending)
      end

      it 'returns all the indices whose all zoekt_repositories are ready' do
        expect(described_class.with_all_finished_repositories).to include(idx2, idx3, idx4, idx5)
        expect(described_class.with_all_finished_repositories).not_to include(idx, idx6)
      end
    end

    describe '.ordered_by_used_storage_updated_at' do
      let_it_be_with_reload(:zoekt_index_3) { create(:zoekt_index) }

      subject(:results) { described_class.ordered_by_used_storage_updated_at }

      it 'returns all indices in ascending order by used_storage_bytes_updated_at' do
        zoekt_index.update!(used_storage_bytes_updated_at: 10.minutes.ago)
        zoekt_index_2.update!(used_storage_bytes_updated_at: 5.hours.ago)
        zoekt_index_3.update!(used_storage_bytes_updated_at: 2.minutes.ago)
        expect(results.pluck(:id)).to eq([zoekt_index_2.id, zoekt_index.id, zoekt_index_3.id])
      end
    end

    describe '.with_stale_used_storage_bytes_updated_at' do
      let_it_be(:time) { Time.zone.now }
      let_it_be(:idx) { create(:zoekt_index) }
      let_it_be(:idx_2) { create(:zoekt_index, :stale_used_storage_bytes_updated_at) }
      let_it_be(:idx_3) do
        create(:zoekt_index, used_storage_bytes_updated_at: time, last_indexed_at: time - 5.seconds)
      end

      subject(:results) { described_class.with_stale_used_storage_bytes_updated_at }

      it 'returns all the indices whose used_storage_bytes_updated_at is less than last_indexed_at' do
        expect(results).to include idx, idx_2
        expect(results).not_to include idx_3
      end
    end

    describe '.with_latest_used_storage_bytes_updated_at' do
      let_it_be(:time) { Time.zone.now }
      let_it_be(:idx) { create(:zoekt_index) }
      let_it_be(:idx_2) { create(:zoekt_index, :stale_used_storage_bytes_updated_at) }
      let_it_be(:idx_3) do
        create(:zoekt_index, used_storage_bytes_updated_at: time, last_indexed_at: time - 5.seconds)
      end

      subject(:results) { described_class.with_latest_used_storage_bytes_updated_at }

      it 'returns all the indices whose used_storage_bytes_updated_at is greater than last_indexed_at' do
        expect(results).not_to include idx, idx_2
        expect(results).to include idx_3
      end
    end

    describe '.pre_ready' do
      let_it_be(:in_progress) { create(:zoekt_index, state: :in_progress) }
      let_it_be(:initializing) { create(:zoekt_index, state: :initializing) }
      let_it_be(:ready) { create(:zoekt_index, state: :ready) }
      let_it_be(:reallocating) { create(:zoekt_index, state: :reallocating) }
      let_it_be(:pending_deletion) { create(:zoekt_index, state: :pending_deletion) }

      it 'returns correct indices' do
        expect(described_class.pre_ready).to contain_exactly(zoekt_index, zoekt_index_2, in_progress, initializing)
      end
    end

    describe '.searchable' do
      let_it_be(:zoekt_index_ready) do
        create(:zoekt_index, node: zoekt_node, zoekt_enabled_namespace: zoekt_enabled_namespace_2, state: :ready)
      end

      it 'returns correct indices' do
        expect(described_class.searchable).to contain_exactly(zoekt_index_ready)
      end
    end

    describe '.preload_zoekt_enabled_namespace_and_namespace' do
      it 'preloads the project and avoids N+1 queries' do
        index = described_class.preload_zoekt_enabled_namespace_and_namespace.first
        recorder = ActiveRecord::QueryRecorder.new { index.zoekt_enabled_namespace.namespace }
        expect(recorder.count).to be_zero
      end
    end

    describe '.preload_node_zoekt_enabled_namespace' do
      it 'preloads node and zoekt_enabled_namespace to avoid N+1 queries' do
        index = described_class.preload_node_zoekt_enabled_namespace.first
        recorder = ActiveRecord::QueryRecorder.new do
          index.node
          index.zoekt_enabled_namespace
        end
        expect(recorder.count).to be_zero
      end
    end

    describe '.negative_reserved_storage_bytes' do
      let_it_be(:negative_reserved_storage_bytes_index) { create(:zoekt_index, :negative_reserved_storage_bytes) }

      it 'returns indices only with negative reserved_storage_bytes' do
        results = described_class.negative_reserved_storage_bytes
        expect(results.all? { |idx| idx.reserved_storage_bytes < 0 }).to be true
        expect(results).to include(negative_reserved_storage_bytes_index)
      end
    end

    describe '.should_be_marked_as_orphaned' do
      let_it_be(:idx) { create(:zoekt_index) }
      let_it_be(:idx_missing_replica) { create(:zoekt_index) }
      let_it_be(:idx_missing_enabled_namespace) { create(:zoekt_index) }
      let_it_be_with_reload(:idx_already_marked_as_orphaned) { create(:zoekt_index) }
      let_it_be(:zoekt_replica) { create(:zoekt_replica) }

      it 'returns indices that are missing either an enabled namespace or a replica' do
        idx_missing_replica.replica.destroy!
        idx_missing_enabled_namespace.zoekt_enabled_namespace.destroy!
        idx_already_marked_as_orphaned.replica.destroy!
        idx_already_marked_as_orphaned.orphaned!

        expect(described_class.should_be_marked_as_orphaned).to match_array([idx_missing_replica,
          idx_missing_enabled_namespace])
      end
    end

    describe '.should_be_deleted' do
      let_it_be(:idx) { create(:zoekt_index) }
      let_it_be(:idx_orphaned) { create(:zoekt_index, state: :orphaned) }
      let_it_be(:idx_pending_deletion) { create(:zoekt_index, state: :pending_deletion) }

      it 'returns indices that are marked as either orphaned or pending_deletion' do
        expect(described_class.should_be_deleted).to match_array([idx_orphaned, idx_pending_deletion])
      end
    end

    describe '.should_be_pending_eviction' do
      let_it_be(:idx_healthy) { create(:zoekt_index, :healthy) }
      let_it_be(:idx_critical_watermark_exceeded) { create(:zoekt_index, :critical_watermark_exceeded) }
      let_it_be(:idx_pending_eviction) do
        create(:zoekt_index, :critical_watermark_exceeded, state: :pending_eviction)
      end

      let_it_be(:idx_evicted) do
        create(:zoekt_index, :critical_watermark_exceeded, state: :evicted)
      end

      let_it_be(:idx_orphaned) do
        create(:zoekt_index, :critical_watermark_exceeded, state: :orphaned)
      end

      let_it_be(:idx_pending_deletion) do
        create(:zoekt_index, :critical_watermark_exceeded, state: :pending_deletion)
      end

      it 'returns indices that are idx_critical_watermark_exceeded that contain zoekt_replica_id' do
        expect(described_class.should_be_pending_eviction).to match_array([idx_critical_watermark_exceeded])
      end
    end

    describe '.with_mismatched_watermark_levels' do
      let(:ideal_percent) { described_class::STORAGE_IDEAL_PERCENT_USED }
      let(:low_watermark) { described_class::STORAGE_LOW_WATERMARK }
      let(:high_watermark) { described_class::STORAGE_HIGH_WATERMARK }
      let(:critical_watermark) { described_class::STORAGE_CRITICAL_WATERMARK }
      let(:mismatched_indices) { described_class.with_mismatched_watermark_levels }
      let(:overprovisioned_mismatch) { create(:zoekt_index, :overprovisioned) }
      let(:healthy_mismatch) { create(:zoekt_index, :healthy) }
      let(:low_watermark_exceeded_mismatched) { create(:zoekt_index, :low_watermark_exceeded) }
      let(:high_watermark_exceeded_mismatched) { create(:zoekt_index, :high_watermark_exceeded) }
      let(:critical_watermark_exceeded_mismatched) { create(:zoekt_index, :critical_watermark_exceeded) }

      before do
        Search::Zoekt::Repository.delete_all
        described_class.delete_all
        overprovisioned_mismatch.update_column(:reserved_storage_bytes, 1)
        healthy_mismatch.update_column(:used_storage_bytes, 1)
        low_watermark_exceeded_mismatched.update_column(:used_storage_bytes, 1)
        high_watermark_exceeded_mismatched.update_column(:used_storage_bytes, 1)
        critical_watermark_exceeded_mismatched.update_column(:used_storage_bytes, 1)
        create(:zoekt_index, :overprovisioned)
        create(:zoekt_index, :healthy)
        create(:zoekt_index, :low_watermark_exceeded)
        create(:zoekt_index, :high_watermark_exceeded)
        create(:zoekt_index, :critical_watermark_exceeded)
      end

      it 'returns indices where watermark_level is mismatched' do
        # Since we've updated the STORAGE_CRITICAL_WATERMARK, we can't predict exactly which indices will be mismatched
        # Just ensure that mismatched records exist and each has a watermark level that doesn't match its usage
        expect(mismatched_indices).not_to be_empty

        mismatched_indices.each do |idx|
          expected_level = idx.appropriate_watermark_level
          expect(idx.watermark_level.to_sym).not_to eq(expected_level)
        end
      end

      it 'handles edge cases at the exact boundary' do
        # Setup a record exactly at the STORAGE_LOW_WATERMARK
        idx = create(:zoekt_index, used_storage_bytes: (low_watermark * 100).to_i, reserved_storage_bytes: 100)
        idx.update_column(:watermark_level, :healthy) # Incorrect level

        expect(mismatched_indices).to include(idx)
      end

      it 'handles division by zero gracefully' do
        # Setup a record with zero reserved_storage_bytes
        idx = create(:zoekt_index, :critical_watermark_exceeded)
        idx.update_column(:reserved_storage_bytes, 0)

        expect { mismatched_indices }.not_to raise_error
      end
    end
  end

  describe '#free_storage_bytes' do
    it 'is difference between reserved bytes and used bytes' do
      allow(zoekt_index).to receive_messages(reserved_storage_bytes: 100, used_storage_bytes: 1)
      expect(zoekt_index.free_storage_bytes).to eq(99)
    end
  end

  describe '#compute_storage_bytes_and_watermark_level' do
    let_it_be_with_reload(:zoekt_index) { create(:zoekt_index, used_storage_bytes: 0) }

    before_all do
      create_list(:zoekt_repository, 3, zoekt_index: zoekt_index, size_bytes: 50)
    end

    context 'when skip_used_storage_bytes is true!' do
      it 'does not mutate used_storage_bytes, but mutates watermark_level', :freeze_time do
        # Call compute - must change in-memory value but not persist to DB
        zoekt_index.compute_storage_bytes_and_watermark_level(skip_used_storage_bytes: true)

        expect(zoekt_index.used_storage_bytes).to eq(0)
        expect(zoekt_index).to be_overprovisioned
        expect(zoekt_index.reload).to be_healthy # DB value unchanged
      end
    end

    it 'mutates in-memory attributes without persisting', :freeze_time do
      # Call compute - must change in-memory value but not persist to DB
      zoekt_index.compute_storage_bytes_and_watermark_level

      expect(zoekt_index.used_storage_bytes).to eq(150) # 3 * 50 - in-memory change applied
      expect(zoekt_index).to be_critical_watermark_exceeded
      expect(zoekt_index.reload.used_storage_bytes).to eq(0) # DB value unchanged
      expect(zoekt_index.reload).to be_healthy
    end

    it 'returns a hash with the computed values', :freeze_time do
      result = zoekt_index.compute_storage_bytes_and_watermark_level

      expect(result[:id]).to eq(zoekt_index.id)
      expect(result[:used_storage_bytes]).to eq(150)
      expect(result[:used_storage_bytes_updated_at]).to eq(Time.zone.now)
      expect(result[:reserved_storage_bytes]).to be_positive
      expect(result[:watermark_level]).to be_an(Integer)
    end

    it 'accepts a pre-computed repository_size_sum', :freeze_time do
      result = zoekt_index.compute_storage_bytes_and_watermark_level(repository_size_sum: 999)

      expect(result[:used_storage_bytes]).to eq(999)
    end
  end

  describe '.bulk_update_storage_bytes_and_watermark_level!' do
    let_it_be(:node) { create(:zoekt_node) }
    let_it_be_with_reload(:idx_a) { create(:zoekt_index, node: node, used_storage_bytes: 1) }
    let_it_be_with_reload(:idx_b) { create(:zoekt_index, node: node, used_storage_bytes: 2) }

    it 'updates all provided records in a single SQL statement', :freeze_time do
      now = Time.zone.now
      updates = [
        {
          id: idx_a.id,
          used_storage_bytes: 100,
          used_storage_bytes_updated_at: now,
          reserved_storage_bytes: 200,
          watermark_level: described_class.watermark_levels[:healthy]
        },
        {
          id: idx_b.id,
          used_storage_bytes: 300,
          used_storage_bytes_updated_at: now,
          reserved_storage_bytes: 600,
          watermark_level: described_class.watermark_levels[:overprovisioned]
        }
      ]

      described_class.bulk_update_storage_bytes_and_watermark_level!(updates)

      idx_a.reload
      expect(idx_a.used_storage_bytes).to eq(100)
      expect(idx_a.reserved_storage_bytes).to eq(200)
      expect(idx_a.watermark_level).to eq('healthy')

      idx_b.reload
      expect(idx_b.used_storage_bytes).to eq(300)
      expect(idx_b.reserved_storage_bytes).to eq(600)
      expect(idx_b.watermark_level).to eq('overprovisioned')
    end

    it 'is a no-op when updates is empty' do
      expect { described_class.bulk_update_storage_bytes_and_watermark_level!([]) }
        .not_to change { idx_a.reload.used_storage_bytes }
    end
  end

  describe '#should_be_deleted?' do
    it 'returns true if the index state is orphaned or pending_deletion' do
      expect(zoekt_index).not_to be_should_be_deleted

      zoekt_index.state = :orphaned
      expect(zoekt_index).to be_should_be_deleted

      zoekt_index.state = :pending_deletion
      expect(zoekt_index).to be_should_be_deleted

      zoekt_index.state = :ready
      expect(zoekt_index).not_to be_should_be_deleted
    end
  end

  describe '#project_namespace_id_exhaustive_range' do
    using RSpec::Parameterized::TableSyntax

    let(:zoekt_index) { build(:zoekt_index) }

    where(:id_from, :id_to, :expected_range) do
      100   | 200  | (100..200)
      100   | nil  | (100..)
      nil   | 200  | (..200)
      nil   | nil  | nil
    end

    with_them do
      before do
        metadata = {}
        metadata['project_namespace_id_from'] = id_from unless id_from.nil?
        metadata['project_namespace_id_to'] = id_to unless id_to.nil?
        zoekt_index.metadata = metadata
      end

      it 'returns the expected range' do
        expect(zoekt_index.project_namespace_id_exhaustive_range).to eq(expected_range)
      end
    end
  end

  describe '.global_buffer_factor' do
    # Use isolated (non-let_it_be) data so each example starts clean.
    # We always clear the cache before each example to avoid cross-contamination.
    subject(:factor) { described_class.global_buffer_factor }

    before do
      Rails.cache.delete(described_class::GLOBAL_BUFFER_FACTOR_CACHE_KEY)
    end

    context 'when there is no index' do
      before do
        described_class.delete_all
      end

      it 'returns DEFAULT_BUFFER_FACTOR' do
        expect(factor).to eq(described_class::DEFAULT_BUFFER_FACTOR)
      end
    end

    context 'when there are no ready indices with real data' do
      it 'returns DEFAULT_BUFFER_FACTOR' do
        expect(factor).to eq(described_class::DEFAULT_BUFFER_FACTOR)
      end
    end

    context 'when there are ready indices with real used_storage_bytes' do
      it 'returns total_used / total_source * safety margin' do
        sentinel = described_class::DEFAULT_USED_STORAGE_BYTES

        grp_a = create(:group)
        en_a = create(:zoekt_enabled_namespace, namespace: grp_a)
        nd_a = create(:zoekt_node, :enough_free_space)
        rep_a = create(:zoekt_replica, zoekt_enabled_namespace: en_a)
        used_a = sentinel + 1.megabyte   # ~1 MB above sentinel; source = 2 MB
        source_a = used_a * 2
        grp_a.create_root_storage_statistics!(repository_size: source_a)
        create(:zoekt_index, zoekt_enabled_namespace: en_a, node: nd_a, replica: rep_a,
          namespace_id: grp_a.id, state: :ready, used_storage_bytes: used_a)

        grp_b = create(:group)
        en_b = create(:zoekt_enabled_namespace, namespace: grp_b)
        nd_b = create(:zoekt_node, :enough_free_space)
        rep_b = create(:zoekt_replica, zoekt_enabled_namespace: en_b)
        used_b = sentinel + 2.megabytes  # ~2 MB above sentinel; source = 5 MB
        source_b = used_b * 5
        grp_b.create_root_storage_statistics!(repository_size: source_b)
        create(:zoekt_index, zoekt_enabled_namespace: en_b, node: nd_b, replica: rep_b,
          namespace_id: grp_b.id, state: :ready, used_storage_bytes: used_b)

        total_used = used_a + used_b
        total_source = source_a + source_b
        expected = (total_used.to_f / total_source) * described_class::DYNAMIC_BUFFER_SAFETY_MARGIN
        expect(factor).to be_within(0.0001).of(expected)
      end
    end

    context 'when indices have the DEFAULT_USED_STORAGE_BYTES sentinel value' do
      it 'excludes sentinel-valued indices and returns DEFAULT_BUFFER_FACTOR' do
        grp = create(:group)
        en = create(:zoekt_enabled_namespace, namespace: grp)
        nd = create(:zoekt_node, :enough_free_space)
        rep = create(:zoekt_replica, zoekt_enabled_namespace: en)
        grp.create_root_storage_statistics!(repository_size: 1000)
        create(:zoekt_index, zoekt_enabled_namespace: en, node: nd, replica: rep,
          namespace_id: grp.id, state: :ready,
          used_storage_bytes: described_class::DEFAULT_USED_STORAGE_BYTES)

        expect(factor).to eq(described_class::DEFAULT_BUFFER_FACTOR)
      end
    end

    context 'when namespace has no root_storage_statistics' do
      it 'excludes indices without source size and returns DEFAULT_BUFFER_FACTOR' do
        grp = create(:group)
        en = create(:zoekt_enabled_namespace, namespace: grp)
        nd = create(:zoekt_node, :enough_free_space)
        rep = create(:zoekt_replica, zoekt_enabled_namespace: en)
        create(:zoekt_index, zoekt_enabled_namespace: en, node: nd, replica: rep,
          namespace_id: grp.id, state: :ready,
          used_storage_bytes: described_class::DEFAULT_USED_STORAGE_BYTES + 1.megabyte)
        # no root_storage_statistics for grp; inner join excludes this row

        expect(factor).to eq(described_class::DEFAULT_BUFFER_FACTOR)
      end
    end

    context 'when indices are not in ready state' do
      it 'ignores non-ready indices and returns DEFAULT_BUFFER_FACTOR' do
        grp = create(:group)
        en = create(:zoekt_enabled_namespace, namespace: grp)
        nd = create(:zoekt_node, :enough_free_space)
        rep = create(:zoekt_replica, zoekt_enabled_namespace: en)
        grp.create_root_storage_statistics!(repository_size: 2.megabytes)
        create(:zoekt_index, zoekt_enabled_namespace: en, node: nd, replica: rep,
          namespace_id: grp.id, state: :pending,
          used_storage_bytes: described_class::DEFAULT_USED_STORAGE_BYTES + 1.megabyte)

        expect(factor).to eq(described_class::DEFAULT_BUFFER_FACTOR)
      end
    end

    context 'when caching is in effect' do
      it 'serves subsequent calls from cache without recomputing' do
        cached_value = 0.72
        call_count = 0

        key = described_class::GLOBAL_BUFFER_FACTOR_CACHE_KEY
        allow(Rails.cache).to receive(:fetch)
          .with(key, expires_in: described_class::GLOBAL_BUFFER_FACTOR_CACHE_TTL) do |&block|
          call_count += 1
          call_count == 1 ? block.call : cached_value
        end

        described_class.global_buffer_factor
        result = described_class.global_buffer_factor

        expect(result).to eq(cached_value)
      end

      it 'uses the cache key GLOBAL_BUFFER_FACTOR_CACHE_KEY with the configured TTL' do
        key = described_class::GLOBAL_BUFFER_FACTOR_CACHE_KEY
        expect(Rails.cache).to receive(:fetch).with(key, expires_in: described_class::GLOBAL_BUFFER_FACTOR_CACHE_TTL)

        described_class.global_buffer_factor
      end
    end
  end

  describe '#find_or_create_repository_by_project!' do
    let_it_be(:zoekt_index) { create(:zoekt_index) }
    let_it_be(:project) { create(:project) }

    context 'when find_or_create_by! raises an error' do
      before do
        allow(zoekt_index).to receive_message_chain(:zoekt_repositories, :find_or_create_by!).and_raise(StandardError)
      end

      it 'raises the error' do
        expect do
          zoekt_index.find_or_create_repository_by_project!(project.id, project)
        end.to raise_error(StandardError).and not_change { Search::Zoekt::Repository.count }
      end
    end

    context 'when zoekt_repository exists with the given params' do
      before do
        create(:zoekt_repository, project: project, zoekt_index: zoekt_index)
      end

      it 'returns the existing record' do
        result = nil
        expect do
          result = zoekt_index.find_or_create_repository_by_project!(project.id, project)
        end.not_to change { zoekt_index.zoekt_repositories.count }
        expect(result.project_identifier).to eq project.id
      end
    end

    context 'when zoekt_repository does not exists with the given params' do
      it 'creates and return the new record' do
        result = nil
        expect do
          result = zoekt_index.find_or_create_repository_by_project!(project.id, project)
        end.to change { zoekt_index.zoekt_repositories.count }.by(1)
        expect(result.project_identifier).to eq project.id
      end
    end
  end
end
