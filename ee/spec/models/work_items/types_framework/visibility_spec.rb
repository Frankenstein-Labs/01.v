# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::TypesFramework::Visibility, feature_category: :team_planning do
  subject(:visibility) { build(:work_item_type_visibility) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
  end

  describe 'validations' do
    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:work_item_type_id) }
    it { is_expected.to validate_uniqueness_of(:work_item_type_id).scoped_to(:namespace_id) }
    it { is_expected.to allow_values(true, false).for(:enabled) }
    it { is_expected.to allow_values(true, false).for(:propagate) }

    it_behaves_like 'validates work item type ID'
  end

  describe '.resolve_for_namespace' do
    let_it_be(:root)  { create(:group) }
    let_it_be(:child) { create(:group, parent: root) }
    let_it_be(:grand) { create(:group, parent: child) }

    let_it_be(:issue_type_id)    { build(:work_item_system_defined_type, :issue).id }
    let_it_be(:task_type_id)     { build(:work_item_system_defined_type, :task).id }
    let_it_be(:incident_type_id) { build(:work_item_system_defined_type, :incident).id }

    subject(:result) { described_class.resolve_for_namespace(grand) }

    it 'returns empty hash when no visibility rows exist' do
      expect(result).to eq({})
    end

    it 'applies a self override (propagate: false) only to that namespace' do
      create(:work_item_type_visibility, namespace: grand, work_item_type_id: issue_type_id,
        enabled: false, propagate: false)

      expect(described_class.resolve_for_namespace(grand)[issue_type_id]).to be false
      expect(described_class.resolve_for_namespace(child)[issue_type_id]).to be_nil
    end

    it 'applies a propagating ancestor row to all descendants' do
      create(:work_item_type_visibility, namespace: root, work_item_type_id: task_type_id,
        enabled: false, propagate: true)

      expect(described_class.resolve_for_namespace(child)[task_type_id]).to be false
      expect(described_class.resolve_for_namespace(grand)[task_type_id]).to be false
    end

    it 'self override wins over a propagating ancestor' do
      create(:work_item_type_visibility, namespace: root, work_item_type_id: issue_type_id,
        enabled: false, propagate: true)
      create(:work_item_type_visibility, namespace: grand, work_item_type_id: issue_type_id,
        enabled: true, propagate: false)

      expect(described_class.resolve_for_namespace(grand)[issue_type_id]).to be true
    end

    it 'closer propagating ancestor wins over a farther one' do
      create(:work_item_type_visibility, namespace: root, work_item_type_id: incident_type_id,
        enabled: false, propagate: true)
      create(:work_item_type_visibility, namespace: child, work_item_type_id: incident_type_id,
        enabled: true, propagate: true)

      expect(described_class.resolve_for_namespace(grand)[incident_type_id]).to be true
    end

    it 'non-propagating ancestor row does not apply to descendants' do
      create(:work_item_type_visibility, namespace: root, work_item_type_id: task_type_id,
        enabled: false, propagate: false)

      expect(described_class.resolve_for_namespace(child)[task_type_id]).to be_nil
      expect(described_class.resolve_for_namespace(grand)[task_type_id]).to be_nil
    end
  end
end
