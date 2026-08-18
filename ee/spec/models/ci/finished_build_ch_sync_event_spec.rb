# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::FinishedBuildChSyncEvent, feature_category: :fleet_visibility do
  let_it_be(:project, freeze: false) { create(:project) }
  let_it_be_with_reload(:build1) { create(:ci_build, :success, project: project, finished_at: 2.hours.ago) }
  let_it_be(:build2, freeze: false) { create(:ci_build, :failed, project: project, finished_at: 1.hour.ago) }
  let_it_be(:build3, freeze: false) { create(:ci_build, :failed, project: project, finished_at: 1.hour.ago) }

  describe 'validations' do
    subject(:event) { create_ci_build_sync_event(build1) }

    it { is_expected.to validate_presence_of(:build_id) }
    it { is_expected.to validate_presence_of(:build_finished_at) }
    it { is_expected.to validate_presence_of(:project_id) }
  end

  describe '.upsert_from_build', :aggregate_failures do
    let(:build) { build1 }

    subject(:upsert_from_build) { described_class.upsert_from_build(build) }

    it 'inserts missing record' do
      expect(upsert_from_build).to be_a(ActiveRecord::Result)

      expect(described_class.find_by(build_id: build.id)).to have_attributes(
        build_id: build.id, build_finished_at: build.finished_at, project_id: build.project_id, processed: false)
    end

    it 'updates existing record', :freeze_time do
      build_ci_build_sync_event(build)
      build.finished_at = Time.current

      expect(upsert_from_build).to be_a(ActiveRecord::Result)
      expect(upsert_from_build).to have_attributes(
        rows: [[build.id, described_class.all.pick('MAX(partition)')]])

      expect(described_class.find_by(build_id: build.id)).to have_attributes(
        build_id: build.id, build_finished_at: Time.current, project_id: build.project_id, processed: false)
    end
  end

  describe 'setting of project_id' do
    let(:build) { build1 }

    subject(:event) { build_ci_build_sync_event(build) }

    it 'sets the project_id before validation' do
      expect(event.project_id).to eq(event.build.project_id)
    end

    context 'if project_id is already set' do
      let_it_be(:another_project, freeze: false) { create(:project) }
      let_it_be(:build, freeze: false) { create(:ci_build, :success, project: another_project) }

      it 'does not override the project_id' do
        expect(event.project_id).to eq(another_project.id)
      end
    end
  end

  context 'with loose foreign key on p_ci_finished_build_ch_sync_events.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let(:parent) { project }
      let!(:build) { create(:ci_build, :success, project: project) }
      let!(:model) { build_ci_build_sync_event(build).tap(&:save) }
    end
  end

  describe '.for_partition', :freeze_time do
    subject(:scope) { described_class.for_partition(partition) }

    let_it_be(:partition_manager, freeze: false) { Gitlab::Database::Partitioning::PartitionManager.new(described_class) }

    around do |example|
      Gitlab::Database::SharedModel.using_connection(Ci::ApplicationRecord.connection) do
        example.run
      end
    end

    before do
      create_ci_build_sync_event(build1, processed: true)
      create_ci_build_sync_event(build2, processed: true)

      travel(described_class::PARTITION_DURATION + 1.second)

      partition_manager.sync_partitions
      create_ci_build_sync_event(build3)
    end

    context 'when partition = 1' do
      let(:partition) { 1 }

      it { is_expected.to match_array(described_class.where(build_id: [build1, build2])) }
    end

    context 'when partition = 2' do
      let(:partition) { 2 }

      it { is_expected.to match_array(described_class.where(build_id: build3)) }
    end
  end

  describe 'sliding_list partitioning' do
    let(:partition_manager) { Gitlab::Database::Partitioning::PartitionManager.new(described_class) }
    let(:partitioning_strategy) { described_class.partitioning_strategy }

    around do |example|
      Gitlab::Database::SharedModel.using_connection(Ci::ApplicationRecord.connection) do
        example.run
      end
    end

    describe 'next_partition_if callback' do
      let(:active_partition) { partitioning_strategy.active_partition }

      subject(:value) { partitioning_strategy.next_partition_if.call(active_partition) }

      context 'when the partition is empty' do
        it { is_expected.to be(false) }
      end

      context 'when the partition has records' do
        before do
          create_ci_build_sync_event(build1, processed: true)
          create_ci_build_sync_event(build2, processed: true)
        end

        it { is_expected.to be(false) }
      end

      context 'when the first record of the partition is older than PARTITION_DURATION' do
        let_it_be(:build1, freeze: false) do
          create(:ci_build, :success, project: project, finished_at: (described_class::PARTITION_DURATION + 1.day).ago)
        end

        let_it_be(:build2, freeze: false) { create(:ci_build, :failed, project: project, finished_at: 1.minute.ago) }

        before do
          create_ci_build_sync_event(build1)
          create_ci_build_sync_event(build2)
        end

        it { is_expected.to be(true) }
      end
    end

    describe 'detach_partition_if callback' do
      let(:active_partition) { partitioning_strategy.active_partition }

      subject(:value) { partitioning_strategy.detach_partition_if.call(active_partition) }

      context 'when the partition is empty' do
        it { is_expected.to be(true) }
      end

      context 'when the partition contains unprocessed records' do
        before do
          travel_to DateTime.new(2023, 12, 10) # use fixed date to avoid leap day failures

          create_ci_build_sync_event(create(:ci_build, finished_at: 2.hours.ago), processed: true)
          create_ci_build_sync_event(create(:ci_build, finished_at: 10.minutes.ago))
          create_ci_build_sync_event(create(:ci_build, finished_at: 1.minute.ago))
        end

        it { is_expected.to be(false) }

        context 'when almost all the records are too old' do
          before do
            travel(30.days - 2.minutes)
          end

          it { is_expected.to be(false) }
        end

        context 'when all the records are too old' do
          before do
            travel(30.days)
          end

          it { is_expected.to be(true) }
        end
      end

      context 'when the partition contains only processed records' do
        before do
          create_ci_build_sync_event(build1, processed: true)
          create_ci_build_sync_event(build2, processed: true)
        end

        it { is_expected.to be(true) }
      end
    end

    describe 'the behavior of the strategy' do
      it 'moves records to new partitions as time passes', :freeze_time do
        # We start with partition 1
        expect(partitioning_strategy.current_partitions.map(&:value)).to contain_exactly(1)

        # it's not a day old yet so no new partitions are created
        partition_manager.sync_partitions

        expect(partitioning_strategy.current_partitions.map(&:value)).to contain_exactly(1)

        # add one record so the next partition will be created
        build = create(:ci_build, :success, project: project, finished_at: Time.current)
        create_ci_build_sync_event(build)

        # after traveling forward a day
        travel(described_class::PARTITION_DURATION + 1.second)

        # a new partition is created
        partition_manager.sync_partitions

        expect(partitioning_strategy.current_partitions.map(&:value)).to contain_exactly(1, 2)

        # and we can insert to the new partition
        expect do
          create_ci_build_sync_event(create(:ci_build, :success, project: project, finished_at: Time.current))
        end.not_to raise_error

        # after processing old records
        described_class.for_partition([1, 2]).update_all(processed: true)

        partition_manager.sync_partitions

        # the old one is removed
        expect(partitioning_strategy.current_partitions.map(&:value)).to contain_exactly(2)

        # and we only have the newly created partition left.
        expect(described_class.count).to eq(1)
      end
    end
  end

  describe 'sorting' do
    let_it_be(:event3, freeze: false) { create_ci_build_sync_event(build3, processed: true) }
    let_it_be(:event1, freeze: false) { create_ci_build_sync_event(build1) }
    let_it_be(:event2, freeze: false) { create_ci_build_sync_event(build2, processed: true) }

    describe '.order_by_build_id' do
      subject(:scope) { described_class.order_by_build_id }

      it { is_expected.to eq([event1, event2, event3]) }
    end
  end

  describe 'scopes' do
    let_it_be(:event1, freeze: false) { create_ci_build_sync_event(build1, processed: true) }
    let_it_be(:event2, freeze: false) { create_ci_build_sync_event(build2) }
    let_it_be(:event3, freeze: false) { create_ci_build_sync_event(build3, processed: true) }

    describe '.pending' do
      subject(:scope) { described_class.pending }

      it { is_expected.to contain_exactly(event2) }
    end
  end

  def build_ci_build_sync_event(build, **extra_attrs)
    described_class.new(build_id: build.id, project_id: build.project_id, build_finished_at: build.finished_at,
      **extra_attrs)
  end

  def create_ci_build_sync_event(build, **extra_attrs)
    build_ci_build_sync_event(build, **extra_attrs).tap(&:save!)
  end
end
