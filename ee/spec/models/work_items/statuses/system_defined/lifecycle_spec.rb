# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::SystemDefined::Lifecycle, feature_category: :team_planning do
  let_it_be(:issue_type) { build(:work_item_system_defined_type, :issue) }
  let_it_be(:task_type) { build(:work_item_system_defined_type, :task) }
  let_it_be(:organization) { create(:organization) }
  let_it_be(:group) { create(:group, organization: organization) }

  subject(:lifecycle) { described_class.find(1) }

  describe 'validations' do
    it 'has the correct structure for each item' do
      expected_attributes = [
        :id, :name, :work_item_base_types, :status_ids,
        :default_open_status_id, :default_closed_status_id,
        :default_duplicate_status_id
      ]
      described_class::ITEMS.each do |item|
        expect(item).to include(*expected_attributes)
        expect(item[:status_ids]).to be_an(Array)
        expect(item[:work_item_base_types]).to be_an(Array)
      end
    end
  end

  describe '.of_work_item_base_type' do
    it 'returns the correct lifecycle for a given base type' do
      expect(described_class.of_work_item_base_type(:issue).id).to eq(1)
    end
  end

  describe '#for_base_type?' do
    it 'returns true for matching base types' do
      expect(lifecycle.for_base_type?(:issue)).to be true
      expect(lifecycle.for_base_type?(:task)).to be true
    end

    it 'returns false for non-matching base types' do
      expect(lifecycle.for_base_type?(:epic)).to be false
      expect(lifecycle.for_base_type?(:requirement)).to be false
      expect(lifecycle.for_base_type?(:ticket)).to be false
    end
  end

  describe '#work_item_types' do
    it 'returns work item types for the lifecycle base types without a namespace' do
      expect(lifecycle.work_item_types).to contain_exactly(issue_type, task_type)
    end

    it 'returns work item types for the lifecycle base types with a namespace' do
      custom_work_item_type = create(:work_item_custom_type, :with_organization, organization: organization)

      expect(lifecycle.work_item_types(group)).to contain_exactly(issue_type, task_type, custom_work_item_type)
    end
  end

  describe '#statuses' do
    let(:statuses) { lifecycle.statuses }

    it 'returns statuses for the lifecycle' do
      expect(statuses).to be_an(Array)
      expect(statuses.first).to be_an(WorkItems::Statuses::SystemDefined::Status)
      expect(statuses.map(&:id)).to contain_exactly(1, 2, 3, 4, 5)
    end
  end

  describe '#has_status_id?' do
    let(:status_id) { 2 }

    subject { described_class.find(1).has_status_id?(status_id) }

    it { is_expected.to be true }

    context 'when status id is not in lifecycle' do
      let(:status_id) { 99 }

      it { is_expected.to be false }
    end
  end

  describe 'default status methods' do
    {
      default_open_status: 1,
      default_closed_status: 3,
      default_duplicate_status: 5
    }.each do |method_name, expected_id|
      it "returns assigned status for ##{method_name}" do
        status = lifecycle.public_send(method_name)
        expect(status).to be_an(WorkItems::Statuses::SystemDefined::Status)
        expect(status.id).to eq(expected_id)
      end
    end
  end

  describe '#default_statuses' do
    it 'returns an array of default statuses' do
      expect(lifecycle.default_statuses).to contain_exactly(
        lifecycle.default_open_status,
        lifecycle.default_closed_status,
        lifecycle.default_duplicate_status
      )
    end
  end

  it 'has the correct attributes' do
    is_expected.to have_attributes(
      id: 1,
      name: 'Default',
      work_item_base_types: [:issue, :task]
    )
  end

  describe 'included modules' do
    subject { described_class }

    # AR like methods are tested in this module
    it { is_expected.to include(ActiveRecord::FixedItemsModel::Model) }
    it { is_expected.to include(GlobalID::Identification) }
  end

  describe '#default_status_for_work_item' do
    subject(:default_status) { lifecycle.default_status_for_work_item(work_item) }

    context 'for open work item' do
      let(:work_item) { build(:work_item, :opened) }

      it 'returns correct status' do
        is_expected.to eq(lifecycle.default_open_status)
      end
    end

    context 'for duplicated work item' do
      let(:work_item) { build(:work_item, :closed, duplicated_to_id: 1) }

      it 'returns correct status' do
        is_expected.to eq(lifecycle.default_duplicate_status)
      end
    end

    context 'for closed work item' do
      let(:work_item) { build(:work_item, :closed) }

      it 'returns correct status' do
        is_expected.to eq(lifecycle.default_closed_status)
      end
    end
  end
end
