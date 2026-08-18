# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::TypeCustomField, feature_category: :team_planning do
  subject(:work_item_type_custom_field) { build(:work_item_type_custom_field) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:custom_field) }
  end

  describe 'validations' do
    it 'validates presence of namespace' do
      # prevents copy_namespace_from_custom_field from interfering with the test
      work_item_type_custom_field.custom_field = nil

      is_expected.to validate_presence_of(:namespace)
    end

    it { is_expected.to validate_presence_of(:work_item_type) }
    it { is_expected.to validate_presence_of(:custom_field) }

    it 'validates uniqueness of custom_field', :aggregate_failures do
      type = build(:work_item_system_defined_type, :issue)
      existing_record = create(:work_item_type_custom_field, work_item_type: type)

      expect(
        build(:work_item_type_custom_field,
          work_item_type: existing_record.work_item_type,
          custom_field: existing_record.custom_field
        )
      ).to be_invalid

      expect(
        build(:work_item_type_custom_field,
          work_item_type: existing_record.work_item_type,
          custom_field: build(:custom_field)
        )
      ).to be_valid

      expect(
        build(:work_item_type_custom_field,
          work_item_type: build(:work_item_system_defined_type, :task),
          custom_field: existing_record.custom_field
        )
      ).to be_valid
    end

    it_behaves_like 'validates work item type ID'
  end

  describe '#copy_namespace_from_custom_field' do
    let(:custom_field) { build(:custom_field) }

    it 'copies namespace_id from the associated custom field' do
      expect(work_item_type_custom_field.namespace_id).to be_nil

      work_item_type_custom_field.custom_field = custom_field
      work_item_type_custom_field.valid?

      expect(work_item_type_custom_field.namespace_id).to eq(custom_field.namespace_id)
    end
  end
end
