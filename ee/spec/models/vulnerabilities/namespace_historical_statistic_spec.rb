# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceHistoricalStatistic, feature_category: :vulnerability_management do
  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:letter_grade) }
    it { is_expected.to validate_presence_of(:traversal_ids) }
    it { is_expected.to validate_numericality_of(:total).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:critical).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:high).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:medium).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:low).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:unknown).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:info).is_greater_than_or_equal_to(0) }
    it { is_expected.to define_enum_for(:letter_grade).with_values(%i[a b c d f]) }
  end

  context 'with loose foreign key on vulnerability_namespace_historical_statistics.namespace_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:namespace) }
      let_it_be(:model) { create(:vulnerability_namespace_historical_statistic, namespace: parent) }
    end
  end

  describe '.by_direct_group' do
    let(:parent_group) { create(:group) }
    let(:child_group) { create(:group, parent: parent_group) }
    let!(:historical_statistic) { create(:vulnerability_namespace_historical_statistic, namespace: parent_group) }

    before do
      create(:vulnerability_namespace_historical_statistic, namespace: child_group)
    end

    subject { described_class.by_direct_group(parent_group) }

    it { is_expected.to contain_exactly(historical_statistic) }
  end

  describe '.between_dates' do
    let_it_be(:start_date) { Date.new(2020, 8, 11) }
    let_it_be(:end_date) { Date.new(2020, 8, 13) }
    let_it_be(:group_1) { create(:group, name: 'group1', path: 'group1', type: 'Group') }

    let_it_be(:statistic_1) do
      create(:vulnerability_namespace_historical_statistic, date: start_date - 1.day, namespace: group_1)
    end

    let_it_be(:statistic_2) do
      create(:vulnerability_namespace_historical_statistic, date: start_date, namespace: group_1)
    end

    let_it_be(:statistic_3) do
      create(:vulnerability_namespace_historical_statistic, date: start_date + 1.day, namespace: group_1)
    end

    let_it_be(:statistic_4) do
      create(:vulnerability_namespace_historical_statistic, date: end_date, namespace: group_1)
    end

    subject { described_class.between_dates(start_date, end_date) }

    it { is_expected.to match_array([statistic_2, statistic_3, statistic_4]) }
    it { is_expected.not_to include(statistic_1) }
  end

  describe '.grouped_by_date' do
    let_it_be(:group_1) { create(:group, name: 'group1', path: 'group1', type: 'Group') }
    let_it_be(:group_2) { create(:group, name: 'group2', path: 'group2', type: 'Group', traversal_ids: [12]) }

    let_it_be(:date_1) { Date.new(2020, 8, 10) }
    let_it_be(:date_2) { Date.new(2020, 8, 11) }

    let_it_be(:statistic_1) do
      create(:vulnerability_namespace_historical_statistic, date: date_1, namespace: group_1, critical: 3, total: 3)
    end

    let_it_be(:statistic_2) do
      create(:vulnerability_namespace_historical_statistic, date: date_1, namespace: group_2, medium: 2, total: 2,
        traversal_ids: group_2.traversal_ids)
    end

    let_it_be(:statistic_3) do
      create(:vulnerability_namespace_historical_statistic, date: date_2, namespace: group_1, low: 1, total: 1)
    end

    let(:expected_number_of_values_per_date) do
      {
        Date.new(2020, 8, 10) => 2,
        Date.new(2020, 8, 11) => 1
      }
    end

    let(:expected_history_order) do
      [
        { id: nil, 'total' => 1, 'critical' => 0, 'high' => 0, 'medium' => 0, 'low' => 1, 'unknown' => 0, 'info' => 0,
          'date' => date_2 },
        { id: nil, 'total' => 5, 'critical' => 3, 'high' => 0, 'medium' => 2, 'low' => 0, 'unknown' => 0, 'info' => 0,
          'date' => date_1 }
      ].as_json
    end

    it 'return the correct number of values for each date' do
      expect(described_class.grouped_by_date.count).to match_array(expected_number_of_values_per_date)
    end

    it 'returns values in the correct order' do
      expect(described_class.grouped_by_date.aggregated_by_date.as_json).to match_array(expected_history_order)
    end
  end

  describe '.aggregated_by_date' do
    let_it_be(:group_1) { create(:group, name: 'group1', path: 'group1', type: 'Group') }
    let_it_be(:group_2) { create(:group, name: 'group2', path: 'group2', type: 'Group', traversal_ids: [12]) }
    let_it_be(:date_1) { Date.new(2020, 8, 10) }
    let_it_be(:date_2) { Date.new(2020, 8, 11) }

    let_it_be(:statistic_1) do
      create(:vulnerability_namespace_historical_statistic, date: date_1, total: 21, info: 1, unknown: 2, low: 3,
        medium: 4, high: 5, critical: 6, namespace: group_1)
    end

    let_it_be(:statistic_2) do
      create(:vulnerability_namespace_historical_statistic, date: date_1, total: 21, info: 1, unknown: 2, low: 3,
        medium: 4, high: 5, critical: 6, namespace: group_2, traversal_ids: group_2.traversal_ids)
    end

    let_it_be(:statistic_3) do
      create(:vulnerability_namespace_historical_statistic, date: date_2, total: 57, info: 7, unknown: 8, low: 9,
        medium: 10, high: 11, critical: 12, namespace: group_1)
    end

    let(:expected_collection) do
      [
        { 'id' => nil, 'date' => '2020-08-10', 'info' => 2, 'unknown' => 4, 'low' => 6, 'medium' => 8, 'high' => 10,
          'critical' => 12, 'total' => 42 },
        { 'id' => nil, 'date' => '2020-08-11', 'info' => 7, 'unknown' => 8, 'low' => 9, 'medium' => 10, 'high' => 11,
          'critical' => 12, 'total' => 57 }
      ]
    end

    subject { described_class.grouped_by_date.aggregated_by_date.as_json }

    it { is_expected.to match_array(expected_collection) }
  end

  describe '.for_namespace_and_descendants' do
    let_it_be(:group_1) { create(:group, name: 'group1', path: 'group1', type: 'Group', traversal_ids: [12, 13, 14]) }
    let_it_be(:group_2) { create(:group, name: 'group2', path: 'group2', type: 'Group', traversal_ids: [12]) }
    let_it_be(:group_3) { create(:group, name: 'group3', path: 'group3', type: 'Group', traversal_ids: [15]) }
    let_it_be(:date_1) { Date.new(2020, 8, 10) }
    let_it_be(:date_2) { Date.new(2020, 8, 11) }
    let_it_be(:statistic_1) do
      create(:vulnerability_namespace_historical_statistic, date: date_1, namespace: group_1, total: 21, info: 1,
        unknown: 2, low: 3, medium: 4, high: 5, critical: 6)
    end

    let_it_be(:statistic_2) do
      create(:vulnerability_namespace_historical_statistic, date: date_1, namespace: group_2,
        traversal_ids: group_2.traversal_ids, total: 21, info: 1, unknown: 2, low: 3, medium: 4, high: 5, critical: 6)
    end

    let_it_be(:statistic_3) do
      create(:vulnerability_namespace_historical_statistic, date: date_2, namespace: group_1, total: 21, info: 1,
        unknown: 2, low: 3, medium: 4, high: 5, critical: 6)
    end

    let_it_be(:statistic_4) do
      create(:vulnerability_namespace_historical_statistic, date: date_1, namespace: group_3, total: 21, info: 1,
        unknown: 2, low: 3, medium: 4, high: 5, critical: 6)
    end

    subject { described_class.for_namespace_and_descendants(group_2) }

    it { is_expected.to match_array([statistic_1, statistic_2, statistic_3]) }
  end
end
