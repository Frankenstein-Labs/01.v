# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::NumberFieldValue, feature_category: :team_planning do
  subject(:number_field_value) { build(:work_item_number_field_value) }

  it_behaves_like 'a work item custom field value', factory: :work_item_number_field_value

  describe 'validations' do
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_numericality_of(:value) }
  end

  describe '.update_work_item_field!' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    let_it_be(:work_item) { create(:work_item, project: project) }
    let_it_be(:custom_field) do
      create(:custom_field, namespace: group, field_type: 'number', work_item_types: [work_item.work_item_type])
    end

    context 'when there is no existing record' do
      it 'inserts a new record' do
        expect do
          described_class.update_work_item_field!(work_item, custom_field, 100)
        end.to change { described_class.count }.by(1)

        expect(described_class.last).to have_attributes({
          work_item_id: work_item.id,
          custom_field_id: custom_field.id,
          value: 100
        })
      end

      it 'retries in case of a race condition' do
        expect_next_instance_of(described_class) do |field_value|
          field_value.errors.add(:custom_field, :taken)
          expect(field_value).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(field_value))
        end

        expect_next_instance_of(described_class) do |field_value|
          expect(field_value).to receive(:update!).and_call_original
        end

        described_class.update_work_item_field!(work_item, custom_field, 100)
      end

      context 'when there is a validation error' do
        it 'raises an error' do
          expect do
            described_class.update_work_item_field!(work_item, custom_field, 'some string')
          end.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Value is not a number')
        end
      end
    end

    context 'when there is an existing record' do
      let!(:existing_field_value) do
        create(:work_item_number_field_value, work_item: work_item, custom_field: custom_field, value: 50)
      end

      it 'updates the existing record' do
        described_class.update_work_item_field!(work_item, custom_field, 100)

        expect(existing_field_value.reload.value).to eq(100)
      end

      it 'deletes the record when value is set to nil' do
        expect do
          described_class.update_work_item_field!(work_item, custom_field, nil)
        end.to change { described_class.count }.by(-1)

        expect { existing_field_value.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
