# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::SystemDefined::Status, feature_category: :team_planning do
  subject(:status) { described_class.find(1) }

  describe 'validations' do
    it 'has the correct minimal structure for each item' do
      expect(described_class::ITEMS).to all(include(:id, :name, :color, :category))
    end

    it 'has unique names for all statuses' do
      name_occurrences = described_class::ITEMS.group_by { |item| item[:name].downcase }
      duplicates = name_occurrences.select { |_, items| items.size > 1 }

      error_message = duplicates.map do |name, items|
        item_details = items.map { |item| "ID: #{item[:id]}, Name: '#{item[:name]}'" }.join(", ")
        "Name '#{name}' is used by multiple items: [#{item_details}]"
      end.join("\n")

      expect(duplicates).to be_empty, error_message.empty? ? nil : "Duplicate status names found:\n#{error_message}"
    end
  end

  describe '.find_by_name' do
    let(:work_item) { build_stubbed(:work_item, :task) }
    let(:status_name) { 'in progress' }

    context 'with exact matching' do
      subject { described_class.find_by_name(status_name) }

      it { is_expected.to have_attributes(id: 2, name: 'In progress') }

      context 'when status_name does not resolve to a valid status' do
        let(:status_name) { 'invalid' }

        it { is_expected.to be_nil }
      end
    end

    context 'with partial matching' do
      subject(:result) { described_class.find_by_name('do', partial_match: true) }

      it 'returns all statuses containing the substring' do
        expect(result.map(&:name)).to contain_exactly('To do', 'Done', "Won't do")
      end

      context 'when no status contains the substring' do
        subject { described_class.find_by_name('invalid', partial_match: true) }

        it { is_expected.to be_empty }
      end
    end
  end

  describe '.sort_order_by_id' do
    it 'returns a hash mapping status IDs to their category values' do
      expected_mapping = {
        1 => 2,
        2 => 3,
        3 => 4,
        4 => 5,
        5 => 5
      }

      expect(described_class.sort_order_by_id).to eq(expected_mapping)
    end
  end

  describe '#allowed_for_work_item?' do
    let(:work_item) { build_stubbed(:work_item, :task) }

    subject { described_class.find(1).allowed_for_work_item?(work_item) }

    it { is_expected.to be true }

    context 'when work item is not present' do
      let(:work_item) { nil }

      it { is_expected.to be false }
    end

    context 'when work item type does not have a lifecycle assigned' do
      let(:work_item) { build_stubbed(:work_item, :epic) }

      it { is_expected.to be false }
    end
  end

  describe '#converted_status_in_namespace' do
    let_it_be_with_reload(:namespace) { create(:group) }

    let(:system_defined_open_status) { described_class.find(1) }

    subject { system_defined_open_status.converted_status_in_namespace(namespace) }

    context 'when the group has converted statuses' do
      let_it_be(:open_status) { create(:work_item_custom_status, :open, namespace: namespace) }
      let_it_be(:closed_status) { create(:work_item_custom_status, :closed, namespace: namespace) }

      it 'returns the correct converted status' do
        is_expected.to eq(open_status)
      end
    end

    context 'when the group does not have converted statuses' do
      it 'returns the system defined status' do
        is_expected.to eq(system_defined_open_status)
      end
    end
  end

  describe '#description' do
    it 'returns nil' do
      expect(status.description).to be_nil
    end
  end

  describe '#icon_name' do
    it 'returns the correct icon name for the status category' do
      expect(status.icon_name).to eq('status-waiting')
    end
  end

  describe '#matches_name?' do
    it 'returns true for case-insensitive name match' do
      expect(status.matches_name?('to do')).to be true
      expect(status.matches_name?('TO DO')).to be true
    end

    it 'returns false for non-matching name' do
      expect(status.matches_name?('in progress')).to be false
    end
  end

  describe '#in_use_in_namespace?' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }
    let(:namespace) { group }

    context 'when system-defined status is in use' do
      context 'with group-level current status' do
        let(:work_item) { create(:work_item, namespace: group) }
        let!(:current_status) do
          create(:work_item_current_status, system_defined_status: status, work_item: work_item, namespace: group)
        end

        it 'returns true' do
          expect(status.in_use_in_namespace?(namespace)).to be_truthy
        end
      end

      context 'with project-level current status' do
        let(:work_item) { create(:work_item, project: project) }
        let!(:current_status) do
          create(:work_item_current_status, system_defined_status: status, work_item: work_item,
            namespace: project.namespace)
        end

        it 'returns true' do
          expect(status.in_use_in_namespace?(namespace)).to be_truthy
        end
      end
    end

    context 'when system-defined status is not in use' do
      it 'returns false' do
        expect(status.in_use_in_namespace?(namespace)).to be_falsy
      end
    end

    context 'when work item type IDs are provided' do
      let_it_be(:issue) { create(:work_item, :issue, project: project) }
      let_it_be(:task) { create(:work_item, :task, project: project) }

      let_it_be(:in_progress_status) { described_class.find(2) }

      before do
        create(:work_item_current_status, system_defined_status: in_progress_status, work_item: issue, namespace: group)
      end

      it 'returns true if status is in use for the provided work item type IDs' do
        expect(
          in_progress_status.in_use_in_namespace?(namespace, work_item_type_ids: [issue.work_item_type_id])
        ).to be_truthy
      end

      it 'returns false if status is not in use for the provided work item type IDs' do
        expect(
          in_progress_status.in_use_in_namespace?(namespace, work_item_type_ids: [task.work_item_type_id])
        ).to be_falsy
      end
    end
  end

  it 'has the correct attributes' do
    is_expected.to have_attributes(
      id: 1,
      name: 'To do',
      color: '#737278',
      category: :to_do,
      position: 0
    )
  end

  it 'has default value for position' do
    expect(described_class.new.position).to eq(0)
  end

  describe 'included modules' do
    subject { described_class }

    # AR like methods are tested in this module
    it { is_expected.to include(ActiveRecord::FixedItemsModel::Model) }
    it { is_expected.to include(GlobalID::Identification) }
    it { is_expected.to include(WorkItems::Statuses::SharedConstants) }
    it { is_expected.to include(WorkItems::Statuses::Status) }
  end
end
