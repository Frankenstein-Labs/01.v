# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceStatistic, feature_category: :security_asset_inventories do
  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:traversal_ids) }
    it { is_expected.to validate_numericality_of(:total).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:critical).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:high).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:medium).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:low).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:unknown).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:info).is_greater_than_or_equal_to(0) }
  end

  context 'with loose foreign key on vulnerability_namespace_statistics.namespace_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:group) }
      let_it_be(:model) { create(:vulnerability_namespace_statistic, group: parent) }
    end
  end

  describe '.by_namespace' do
    let_it_be(:group_1) { create(:group, path: 'group1', type: 'Group') }
    let_it_be(:group_2) { create(:group, path: 'group2', type: 'Group') }
    let_it_be(:statistic_1) do
      create(:vulnerability_namespace_statistic, namespace: group_1, total: 2, info: 2)
    end

    let_it_be(:statistic_2) do
      create(:vulnerability_namespace_statistic, namespace: group_2, total: 1, info: 1)
    end

    subject { described_class.by_namespace(group_2) }

    it { is_expected.to match_array([statistic_2]) }
  end
end
