# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Cleanup::Policy, feature_category: :virtual_registry do
  subject(:policy) { build(:virtual_registries_cleanup_policy) }

  it { is_expected.to be_a(Schedulable) }

  describe 'associations' do
    it { is_expected.to belong_to(:group) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(scheduled: 0, running: 1, failed: 2) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_uniqueness_of(:group) }
    it { is_expected.to validate_inclusion_of(:enabled).in_array([true, false]) }
    it { is_expected.to validate_inclusion_of(:notify_on_success).in_array([true, false]) }
    it { is_expected.to validate_inclusion_of(:notify_on_failure).in_array([true, false]) }
    it { is_expected.to validate_numericality_of(:last_run_deleted_size).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_length_of(:failure_message).is_at_most(255) }

    it 'validates last_run_deleted_entries_count' do
      is_expected.to validate_numericality_of(:last_run_deleted_entries_count)
        .only_integer.is_greater_than_or_equal_to(0)
    end

    it 'validates keep_n_days_after_download' do
      is_expected.to validate_numericality_of(:keep_n_days_after_download)
        .only_integer.is_greater_than(0).is_less_than_or_equal_to(365)
    end

    it { is_expected.to validate_inclusion_of(:cadence).in_array([1, 7, 14, 30, 90]) }

    describe '#last_run_detailed_metrics' do
      it 'allows valid JSON according to the schema' do
        valid_metrics = {
          'maven' => {
            'deleted_entries_count' => 100,
            'deleted_size' => 2048
          }
        }

        is_expected.to allow_value(valid_metrics).for(:last_run_detailed_metrics)
      end

      it 'disallows invalid JSON according to the schema' do
        invalid_metrics = {
          'docker' => {
            'deleted_entries_count' => -10,
            'deleted_size' => 'large'
          }
        }

        is_expected.not_to allow_value(invalid_metrics).for(:last_run_detailed_metrics)
          .with_message(/docker` is a disallowed additional property/)
      end
    end
  end

  describe '.next_runnable_schedule' do
    let!(:policy) do
      create(:virtual_registries_cleanup_policy, :enabled).tap { |p| p.update_column(:next_run_at, 1.day.ago) }
    end

    let!(:running_policy) do
      create(:virtual_registries_cleanup_policy, :enabled, :running).tap do |p|
        p.update_column(:next_run_at, 1.day.ago)
      end
    end

    let!(:future_policy) do
      create(:virtual_registries_cleanup_policy, :enabled).tap { |p| p.update_column(:next_run_at, 1.day.from_now) }
    end

    let!(:disabled_policy) { create(:virtual_registries_cleanup_policy) }

    subject { described_class.next_runnable_schedule }

    it { is_expected.to eq(policy) }
  end

  describe '.find_for_group' do
    let_it_be(:group) { create(:group) }

    subject(:find_for_group) { described_class.find_for_group(group) }

    context 'when a policy exists for the group' do
      let_it_be(:expected_policy) { create(:virtual_registries_cleanup_policy, group: group) }
      let_it_be(:other_policy) { create(:virtual_registries_cleanup_policy) }

      it { is_expected.to eq(expected_policy) }
    end

    context 'when a policy does not exist for the group' do
      it { is_expected.to be_a_new(described_class) }
      it { is_expected.to have_attributes(group: group, enabled: false) }
    end
  end

  describe 'scopes' do
    describe '.for_group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:policy) { create(:virtual_registries_cleanup_policy, group:) }
      let_it_be(:other_policy) { create(:virtual_registries_cleanup_policy) }

      subject { described_class.for_group(group) }

      it { is_expected.to contain_exactly(policy) }
    end
  end

  describe 'declarative policy' do
    it 'delegates to GroupPolicy' do
      declarative_policy = DeclarativePolicy.policy_for(build(:user), policy)

      expect(declarative_policy).to be_a(VirtualRegistries::Policies::GroupPolicy)
    end
  end
end
