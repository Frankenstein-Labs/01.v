# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Minutes::GitlabHostedRunnerMonthlyUsage, factory_default: :keep, feature_category: :hosted_runners do
  let_it_be(:root_namespace) { create_default(:namespace) }
  let_it_be(:project) { create(:project) }
  let_it_be(:runner) { create(:ci_runner, :instance) }
  let(:other_runner) { create(:ci_runner, :instance) }

  subject(:usage) do
    described_class.new(
      project: project,
      root_namespace: project.root_namespace,
      runner: runner,
      billing_month: Date.current.beginning_of_month,
      notification_level: :warning,
      compute_minutes_used: 100.5,
      runner_duration_seconds: 6030
    )
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project).inverse_of(:hosted_runner_monthly_usages) }
    it { is_expected.to belong_to(:root_namespace).class_name('Namespace').inverse_of(:hosted_runner_monthly_usages) }
    it { is_expected.to belong_to(:runner).class_name('Ci::Runner').inverse_of(:hosted_runner_monthly_usages) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:runner).on(:create) }
    it { is_expected.to validate_presence_of(:project).on(:create) }
    it { is_expected.to validate_presence_of(:root_namespace).on(:create) }
    it { is_expected.to validate_presence_of(:billing_month) }
    it { is_expected.to validate_presence_of(:compute_minutes_used) }

    it { is_expected.to validate_numericality_of(:compute_minutes_used).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:runner_duration_seconds).is_greater_than_or_equal_to(0).only_integer }

    describe 'billing_month format' do
      context 'when set to the first day of the month' do
        before do
          usage.billing_month = Date.new(2023, 5, 1)
        end

        it 'is valid' do
          expect(usage).to be_valid
        end
      end

      context 'when not set to the first day of the month' do
        before do
          usage.billing_month = Date.new(2023, 5, 2)
        end

        it 'is invalid' do
          expect(usage).to be_invalid
          expect(usage.errors[:billing_month]).to include('must be the first day of the month')
        end
      end

      context 'when billing_month is blank' do
        before do
          usage.billing_month = nil
        end

        it 'is invalid' do
          expect(usage).to be_invalid
          expect(usage.errors[:billing_month]).to include("can't be blank")
        end
      end
    end
  end

  describe 'scopes' do
    let(:billing_month) { Date.new(2025, 1, 1) }
    let(:namespace1) { create(:namespace) }
    let(:namespace2) { create(:namespace) }

    before do
      create(:ci_hosted_runner_monthly_usage,
        billing_month: billing_month,
        compute_minutes_used: 100,
        runner_duration_seconds: 6000,
        root_namespace: namespace1,
        runner: runner)
      create(:ci_hosted_runner_monthly_usage,
        billing_month: billing_month,
        compute_minutes_used: 200,
        runner_duration_seconds: 12000,
        root_namespace: namespace2,
        runner: other_runner)
    end

    describe '.instance_aggregate' do
      subject(:instance_aggregate) { described_class.instance_aggregate(billing_month, nil).to_a }

      it 'returns the correct aggregate data' do
        expect(instance_aggregate.count).to eq(1)
        expect(instance_aggregate.first.compute_minutes).to eq(300)
        expect(instance_aggregate.first.duration_seconds).to eq(18000)
        expect(instance_aggregate.first.root_namespace_id).to be_nil
      end

      context 'when runner_id is specified' do
        subject(:instance_aggregate) { described_class.instance_aggregate(billing_month, nil, runner.id).to_a }

        it 'returns data only for the specified runner' do
          expect(instance_aggregate.count).to eq(1)
          expect(instance_aggregate.first.compute_minutes).to eq(100)
          expect(instance_aggregate.first.duration_seconds).to eq(6000)
          expect(instance_aggregate.first.root_namespace_id).to be_nil
        end
      end
    end

    describe '.per_root_namespace' do
      subject(:per_root_namespace) { described_class.per_root_namespace(billing_month, nil).to_a }

      it 'returns the correct data per root namespace' do
        expect(per_root_namespace.count).to eq(2)
        expect(per_root_namespace.map(&:root_namespace_id))
          .to match_array([namespace1.id, namespace2.id])

        expect(per_root_namespace.find do |usage|
          usage.root_namespace_id == namespace1.id
        end.compute_minutes).to eq(100)

        expect(per_root_namespace.find do |usage|
          usage.root_namespace_id == namespace2.id
        end.compute_minutes).to eq(200)
      end

      context 'when runner_id is specified' do
        subject(:per_root_namespace) { described_class.per_root_namespace(billing_month, nil, runner.id).to_a }

        it 'returns data only for the specified runner' do
          expect(per_root_namespace.count).to eq(1)
          expect(per_root_namespace.first.root_namespace_id).to eq(namespace1.id)
          expect(per_root_namespace.first.compute_minutes).to eq(100)
          expect(per_root_namespace.first.duration_seconds).to eq(6000)
        end
      end
    end
  end

  describe '.find_or_create_current' do
    let_it_be(:current_month) { Time.current.beginning_of_month }

    subject(:find_or_create_current) do
      described_class.find_or_create_current(
        root_namespace_id: root_namespace.id,
        project_id: project.id,
        runner_id: runner.id
      )
    end

    context 'when usage record already exists' do
      let!(:existing_usage) do
        create(:ci_hosted_runner_monthly_usage,
          root_namespace: root_namespace,
          project: project,
          runner: runner,
          billing_month: current_month,
          compute_minutes_used: 10.5,
          runner_duration_seconds: 100
        )
      end

      it 'returns the existing record' do
        expect(find_or_create_current).to eq(existing_usage)
      end

      it 'does not create a new record' do
        expect { find_or_create_current }.not_to change { described_class.count }
      end

      it 'maintains the existing values' do
        usage = find_or_create_current

        expect(usage.compute_minutes_used).to eq(10.5)
        expect(usage.runner_duration_seconds).to eq(100)
      end

      context 'when unique index violation occurs' do
        before do
          allow(described_class).to receive(:find_or_create_by).and_call_original
          allow(described_class).to receive(:find_by).and_call_original

          # Simulate the race condition by having find_or_create_by attempt to create a duplicate
          # this will result in ActiveRecord::RecordNotUnique error raised and rescued
          allow(described_class).to receive(:exists?).and_return(false)
        end

        it 'finds the existing record' do
          result = described_class.find_or_create_current(
            root_namespace_id: root_namespace.id,
            project_id: project.id,
            runner_id: runner.id
          )

          expect(result.id).to eq(existing_usage.id)
          expect(result.root_namespace_id).to eq(root_namespace.id)
          expect(result.project_id).to eq(project.id)
          expect(result.runner_id).to eq(runner.id)
        end
      end
    end

    context 'when usage record does not exist' do
      it 'creates a new record' do
        expect { find_or_create_current }.to change { described_class.count }.by(1)
      end

      it 'sets the correct attributes' do
        usage = find_or_create_current

        expect(usage).to have_attributes(
          root_namespace_id: root_namespace.id,
          project_id: project.id,
          runner_id: runner.id,
          billing_month: current_month,
          compute_minutes_used: 0.0,
          runner_duration_seconds: 0
        )
      end

      it 'persists the record' do
        expect(find_or_create_current).to be_persisted
      end
    end

    context 'with invalid attributes' do
      subject(:find_or_create_current) do
        described_class.find_or_create_current(
          root_namespace_id: nil,
          project_id: nil,
          runner_id: nil
        )
      end

      it 'raises an error' do
        expect { find_or_create_current }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe '.distinct_runner_ids' do
    let_it_be(:runner1) { create(:ci_runner) }
    let_it_be(:runner2) { create(:ci_runner) }
    let_it_be(:deleted_runner_id) { runner2.id }

    before do
      create(:ci_hosted_runner_monthly_usage, runner: runner1)
      create(:ci_hosted_runner_monthly_usage, runner: runner1) # Duplicate usage for same runner
      create(:ci_hosted_runner_monthly_usage, runner: runner2)
    end

    it 'returns distinct runner IDs' do
      expect(described_class.distinct_runner_ids).to contain_exactly(runner1.id, runner2.id)
    end

    context 'when runner no longer exists' do
      before do
        runner2.destroy!
      end

      it 'includes IDs for runners that no longer exist' do
        expect(Ci::Runner.find_by(id: deleted_runner_id)).to be_nil

        expect(described_class.distinct_runner_ids).to include(deleted_runner_id)
      end
    end
  end

  describe '.distinct_years' do
    before do
      create(:ci_hosted_runner_monthly_usage, billing_month: Date.new(2023, 1, 1))
      create(:ci_hosted_runner_monthly_usage, billing_month: Date.new(2023, 2, 1)) # Same year
      create(:ci_hosted_runner_monthly_usage, billing_month: Date.new(2024, 1, 1))
    end

    it 'returns distinct years' do
      expect(described_class.distinct_years).to contain_exactly(2023, 2024)
    end

    it 'returns years in ascending order' do
      expect(described_class.distinct_years).to eq([2023, 2024])
    end
  end
end
