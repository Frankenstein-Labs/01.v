# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzerNamespaceStatus, feature_category: :security_asset_inventories do
  let_it_be(:parent) { create(:namespace) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:group) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:analyzer_type) }
    it { is_expected.to validate_presence_of(:traversal_ids) }

    it { is_expected.to validate_numericality_of(:success).is_greater_than_or_equal_to(0) }
    it { is_expected.not_to allow_value(nil).for(:success) }

    it { is_expected.to validate_numericality_of(:failure).is_greater_than_or_equal_to(0) }
    it { is_expected.not_to allow_value(nil).for(:failure) }

    it { is_expected.to validate_numericality_of(:stale).is_greater_than_or_equal_to(0) }
    it { is_expected.not_to allow_value(nil).for(:stale) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:analyzer_type).with_values(Enums::Security.analyzer_types_for_status) }
  end

  describe 'scopes' do
    describe '.by_namespace' do
      it 'returns records filtered by namespace' do
        result = create(:analyzer_namespace_status, namespace: parent)

        expect(described_class.by_namespace(parent)).to match_array(result)
      end
    end
  end

  context 'with loose foreign key on analyzer_namespace_statuses.namespace_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:namespace) }
      let_it_be(:model) { create(:analyzer_namespace_status, namespace: parent) }
    end
  end

  describe '#not_configured' do
    let(:group) { create(:group) }
    let(:analyzer_namespace_status) do
      create(:analyzer_namespace_status, group: group, success: 1, failure: 1, stale: 1)
    end

    before do
      allow(group).to receive(:all_unarchived_project_ids).and_return([1, 2, 3, 4, 5])
    end

    it 'returns the count of projects which are not configured for that analyzer type' do
      expect(analyzer_namespace_status.not_configured).to eq(2)
    end

    context 'when the not_configured is lesser than zero' do
      before do
        allow(group).to receive(:all_unarchived_project_ids).and_return([1])
      end

      it 'returns 0' do
        expect(analyzer_namespace_status.not_configured).to eq(0)
      end
    end
  end

  describe '#total_projects_count' do
    let!(:group) { create(:group) }

    let!(:proj1) { create(:project, group: group) }
    let!(:proj2) { create(:project, group: group, archived: project_archived) }

    let!(:analyzer_namespace_status) { create(:analyzer_namespace_status, group: group, success: 0, failure: 0) }

    context 'when a project is archived' do
      let(:project_archived) { true }

      it 'is not included' do
        expect(analyzer_namespace_status.total_projects_count).to eq(1)
      end
    end

    context 'when a project is not archived' do
      let(:project_archived) { false }

      it 'is included' do
        expect(analyzer_namespace_status.total_projects_count).to eq(2)
      end
    end
  end
end
