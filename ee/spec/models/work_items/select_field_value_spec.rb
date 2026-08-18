# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::SelectFieldValue, feature_category: :team_planning do
  subject(:select_field_value) { build(:work_item_select_field_value) }

  it_behaves_like 'a work item custom field value', factory: :work_item_select_field_value

  describe 'associations' do
    it { is_expected.to belong_to(:custom_field_select_option) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:custom_field_select_option) }

    it 'validates uniqueness of custom_field_select_option' do
      # Prevent errors when validate_uniqueness_of creates duplicate records without going through our model hooks
      select_field_value.namespace_id = create(:group).id

      is_expected.to validate_uniqueness_of(:custom_field_select_option).scoped_to([:work_item_id, :custom_field_id])
    end
  end

  describe '.update_work_item_field!' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    let_it_be(:work_item) { create(:work_item, project: project) }
    let_it_be(:custom_field) do
      create(:custom_field, namespace: group, field_type: 'multi_select', work_item_types: [work_item.work_item_type])
    end

    let_it_be(:multi_select_option_1) { create(:custom_field_select_option, custom_field: custom_field) }
    let_it_be(:multi_select_option_2) { create(:custom_field_select_option, custom_field: custom_field) }
    let_it_be(:multi_select_option_3) { create(:custom_field_select_option, custom_field: custom_field) }

    context 'when there are no existing records' do
      it 'inserts a new record for each selected option' do
        expect do
          described_class.update_work_item_field!(work_item, custom_field, [
            multi_select_option_1, multi_select_option_3
          ].map(&:id))
        end.to change { described_class.count }.by(2)

        expect(described_class.last(2)).to contain_exactly(
          have_attributes({
            work_item_id: work_item.id,
            custom_field_id: custom_field.id,
            custom_field_select_option_id: multi_select_option_1.id
          }),
          have_attributes({
            work_item_id: work_item.id,
            custom_field_id: custom_field.id,
            custom_field_select_option_id: multi_select_option_3.id
          })
        )
      end

      it 'raises an argument error when passing a select option of an unrelated custom field' do
        expect do
          described_class.update_work_item_field!(work_item, custom_field, [
            create(:custom_field_select_option).id
          ])
        end.to raise_error(ArgumentError, /Invalid custom field select option IDs/)
      end
    end

    context 'when there are existing records' do
      before do
        create(:work_item_select_field_value, work_item: work_item, custom_field: custom_field,
          custom_field_select_option: multi_select_option_2)
      end

      it 'inserts and deletes records to match the new selected options' do
        expect do
          described_class.update_work_item_field!(work_item, custom_field, [
            multi_select_option_1, multi_select_option_3
          ].map(&:id))
        end.to change { described_class.count }.by(1)

        expect(described_class.last(2)).to contain_exactly(
          have_attributes({
            work_item_id: work_item.id,
            custom_field_id: custom_field.id,
            custom_field_select_option_id: multi_select_option_1.id
          }),
          have_attributes({
            work_item_id: work_item.id,
            custom_field_id: custom_field.id,
            custom_field_select_option_id: multi_select_option_3.id
          })
        )
      end

      it 'deletes existing records when set to nil' do
        expect do
          described_class.update_work_item_field!(work_item, custom_field, nil)
        end.to change { described_class.count }.by(-1)
      end
    end

    context 'when custom field is a single select' do
      let_it_be(:custom_field) do
        create(:custom_field, namespace: group, field_type: 'single_select',
          work_item_types: [work_item.work_item_type])
      end

      let_it_be(:select_option_1) { create(:custom_field_select_option, custom_field: custom_field) }
      let_it_be(:select_option_2) { create(:custom_field_select_option, custom_field: custom_field) }

      it 'raises an argument error when passing multiple options' do
        expect do
          described_class.update_work_item_field!(work_item, custom_field, [
            select_option_1,
            select_option_2
          ].map(&:id))
        end.to raise_error(ArgumentError, 'A custom field of type single select may only have a single selected option')
      end
    end
  end
end
