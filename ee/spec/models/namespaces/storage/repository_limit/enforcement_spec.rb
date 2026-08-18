# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Storage::RepositoryLimit::Enforcement, feature_category: :consumables_cost_management do
  using RSpec::Parameterized::TableSyntax

  let(:namespace) { build_stubbed(:group, additional_purchased_storage_size: additional_purchased_storage_size) }
  let(:total_repository_size_excess) { 50.megabytes }
  let(:additional_purchased_storage_size) { 100 }
  let(:model) { described_class.new(namespace) }
  let(:root_namespace) { namespace }

  before do
    allow(root_namespace).to receive(:total_repository_size_excess).and_return(total_repository_size_excess)
  end

  describe '#above_size_limit?' do
    subject { model.above_size_limit? }

    before do
      allow(model).to receive(:enforce_limit?) { enforce_limit }
    end

    context 'when limit enforcement is off' do
      let(:enforce_limit) { false }

      it { is_expected.to be false }
    end

    context 'when limit enforcement is on' do
      let(:enforce_limit) { true }

      context 'when below limit' do
        it { is_expected.to be false }
      end

      context 'when above limit' do
        let(:total_repository_size_excess) { 101.megabytes }

        it { is_expected.to be true }
      end
    end
  end

  describe '#usage_ratio' do
    subject { model.usage_ratio }

    it { is_expected.to eq(0.5) }

    context 'when limit is 0' do
      let(:additional_purchased_storage_size) { 0 }

      context 'when current size is greater than 0' do
        it { is_expected.to eq(1) }
      end

      context 'when current size is less than 0' do
        let(:total_repository_size_excess) { 0 }

        it { is_expected.to eq(0) }
      end
    end
  end

  describe '#current_size' do
    subject { model.current_size }

    it { is_expected.to eq(total_repository_size_excess) }

    context 'when it is a subgroup of the namespace' do
      let(:subgroup) { build_stubbed(:group, parent: namespace) }
      let(:model) { described_class.new(subgroup) }
      let(:root_namespace) { subgroup.root_ancestor }

      it { is_expected.to eq(total_repository_size_excess) }
    end
  end

  describe '#limit' do
    subject { model.limit }

    context 'when there is additional purchased storage and a plan' do
      let(:additional_purchased_storage_size) { 10_000 }

      it { is_expected.to eq(10_000.megabytes) }
    end

    context 'when there is no additionl purchased storage' do
      let(:additional_purchased_storage_size) { 0 }

      it { is_expected.to eq(0.megabytes) }
    end
  end

  describe '#enforce_limit?' do
    it 'returns true if automatic_purchased_storage_allocation is enabled' do
      stub_application_setting(automatic_purchased_storage_allocation: true)

      expect(model.enforce_limit?).to be true
    end

    it 'returns false if automatic_purchased_storage_allocation is disabled' do
      stub_application_setting(automatic_purchased_storage_allocation: false)

      expect(model.enforce_limit?).to be false
    end
  end

  describe '#enforcement_type' do
    it 'returns :project_repository_limit' do
      expect(model.enforcement_type).to eq(:project_repository_limit)
    end
  end

  describe '#exceeded_size' do
    context 'when given a parameter' do
      where(:change_size, :expected_excess_size) do
        150.megabytes | 100.megabytes
        60.megabytes  | 10.megabytes
        51.megabytes  | 1.megabyte
        50.megabytes  | 0
        10.megabytes  | 0
        0             | 0
      end

      with_them do
        it 'returns the size in bytes that the change exceeds the limit' do
          expect(model.exceeded_size(change_size)).to eq(expected_excess_size)
        end
      end
    end

    context 'without a parameter' do
      where(:total_repository_size_excess, :expected_excess_size) do
        0             | 0
        50.megabytes  | 0
        100.megabytes | 0
        101.megabytes | 1.megabyte
        170.megabytes | 70.megabytes
      end

      with_them do
        it 'returns the size in bytes that the current storage size exceeds the limit' do
          expect(model.exceeded_size).to eq(expected_excess_size)
        end
      end
    end
  end

  describe '#subject_to_high_limit?', :saas do
    where :plan_name, :is_subject_to_high_limit do
      :default_plan                      | false
      :free_plan                         | false
      :bronze_plan                       | true
      :silver_plan                       | true
      :premium_plan                      | true
      :gold_plan                         | true
      :ultimate_plan                     | true
      :ultimate_trial_plan               | false
      :ultimate_trial_paid_customer_plan | true
      :premium_trial_plan                | false
      :opensource_plan                   | true
    end

    with_them do
      let(:namespace) { create(:group_with_plan, plan: plan_name) }

      before do
        namespace.actual_plan.actual_limits.update!(repository_size: 10)
      end

      it { expect(model.subject_to_high_limit?).to be is_subject_to_high_limit }
    end
  end

  describe '#has_projects_over_high_limit_warning_threshold?', :saas do
    let_it_be_with_refind(:namespace) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be_with_refind(:project_1) { create(:project, namespace: namespace) }
    let_it_be_with_refind(:project_2) { create(:project, namespace: namespace) }

    describe 'when group is subject to high limit' do
      where :project_1_size, :project_2_size, :is_over_threshold do
        91.gigabytes | 5.gigabytes | true
        91.gigabytes | 105.gigabytes | true
        80.gigabytes | 75.gigabytes | false
      end

      with_them do
        before do
          namespace.actual_plan.actual_limits.update!(repository_size: 100.gigabytes)
          project_1.statistics.update!(repository_size: project_1_size)
          project_2.statistics.update!(repository_size: project_2_size)
        end

        it 'returns the expected boolean value' do
          expect(model.has_projects_over_high_limit_warning_threshold?).to be is_over_threshold
        end
      end
    end

    describe 'when group is NOT subject to high limit' do
      let_it_be_with_refind(:namespace) { create(:group_with_plan, plan: :free_plan) }

      before do
        namespace.actual_plan.actual_limits.update!(repository_size: 100.gigabytes)
        project_1.statistics.update!(repository_size: 91.gigabytes)
      end

      it 'returns false' do
        expect(model.has_projects_over_high_limit_warning_threshold?).to be false
      end
    end
  end
end
