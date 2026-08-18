# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Callbacks::CustomFields, feature_category: :team_planning do
  include_context 'with group configured with custom fields'

  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:work_item) { create(:work_item, work_item_type: issue_type, project: project) }

  let_it_be(:current_user) { create(:user, reporter_of: group) }

  let(:callback) { described_class.new(issuable: work_item, current_user: current_user, params: params) }
  let(:date) { generate(:sequential_date).to_date }

  let(:params) do
    [
      { custom_field_id: text_field.id, text_value: 'some text' },
      { custom_field_id: number_field.id, number_value: 100 },
      { custom_field_id: date_field.id, date_value: date },
      { custom_field_id: select_field.id, selected_option_ids: [select_option_1.id] },
      { custom_field_id: multi_select_field.id, selected_option_ids: [
        multi_select_option_1.id, multi_select_option_2.id
      ] }
    ]
  end

  before do
    stub_licensed_features(custom_fields: true)
  end

  describe '#after_save' do
    subject(:after_save_callback) { callback.after_save }

    context "when params have no values" do
      let(:params) do
        [
          { custom_field_id: select_field.id },
          { custom_field_id: multi_select_field.id },
          { custom_field_id: text_field.id },
          { custom_field_id: number_field.id },
          { custom_field_id: date_field.id }
        ]
      end

      it "does not raise any error" do
        expect { after_save_callback }.not_to raise_error
      end

      it "does not creates system notes" do
        expect { after_save_callback }.not_to change { Note.count }
      end
    end

    it 'sets the custom field values for the work item' do
      after_save_callback

      expect(custom_field_values_for(text_field).first.value).to eq('some text')
      expect(custom_field_values_for(number_field).first.value).to eq(100)
      expect(custom_field_values_for(date_field).first.value).to eq(date)
      expect(custom_field_values_for(select_field).first.custom_field_select_option_id).to eq(select_option_1.id)
      expect(custom_field_values_for(multi_select_field)).to contain_exactly(
        have_attributes(custom_field_select_option_id: multi_select_option_1.id),
        have_attributes(custom_field_select_option_id: multi_select_option_2.id)
      )
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { 'change_work_item_custom_field_value' }
      let(:category) { described_class.name }
      let(:namespace) { group }
      let(:user) { current_user }
    end

    context 'when there are existing values' do
      before do
        create(:work_item_text_field_value, work_item: work_item, custom_field: text_field, value: 'existing text')
        create(:work_item_number_field_value, work_item: work_item, custom_field: number_field, value: 50)
      end

      let(:params) do
        [
          { custom_field_id: number_field.id, number_value: 100 }
        ]
      end

      it 'updates the given fields and leaves others as-is' do
        after_save_callback

        expect(custom_field_values_for(text_field).first.value).to eq('existing text')
        expect(custom_field_values_for(number_field).first.value).to eq(100)
      end
    end

    context "when the new value and the previous value are the same" do
      before do
        create(:work_item_text_field_value, work_item: work_item, custom_field: text_field, value: 'some text')
        create(:work_item_number_field_value, work_item: work_item, custom_field: number_field, value: 100)
        create(:work_item_date_field_value, work_item: work_item, custom_field: date_field, value: date)
        create(:work_item_select_field_value, work_item: work_item, custom_field: select_field,
          custom_field_select_option: select_option_1)
        create(:work_item_select_field_value, work_item: work_item, custom_field: multi_select_field,
          custom_field_select_option: multi_select_option_1)
        create(:work_item_select_field_value, work_item: work_item, custom_field: multi_select_field,
          custom_field_select_option: multi_select_option_2)
      end

      it "does not update the custom field value" do
        expect(::WorkItems::NumberFieldValue).not_to receive(:update_work_item_field!)
        expect(::WorkItems::TextFieldValue).not_to receive(:update_work_item_field!)
        expect(::WorkItems::DateFieldValue).not_to receive(:update_work_item_field!)
        expect(::WorkItems::SelectFieldValue).not_to receive(:update_work_item_field!)

        after_save_callback
      end

      it "does not creates system notes" do
        expect { after_save_callback }.not_to change { Note.count }
      end

      it "does not call the create system note method" do
        expect(callback).not_to receive(:create_number_field_system_note)
        expect(callback).not_to receive(:create_text_field_system_note)
        expect(callback).not_to receive(:create_date_field_system_note)
        expect(callback).not_to receive(:create_select_field_type_system_note)
        expect(callback).not_to receive(:create_select_field_type_system_note)

        after_save_callback
      end
    end

    context "for system notes" do
      context "when we change the value" do
        it "creates system notes for each param" do
          expect { after_save_callback }.to change { Note.count }.from(0).to(5)
        end

        it "calls the create note method with correct params" do
          expect(callback).to receive(:create_text_field_system_note).with(text_field, 'some text', nil)
          expect(callback).to receive(:create_number_field_system_note).with(number_field, 100, nil)
          expect(callback).to receive(:create_date_field_system_note).with(date_field, date, nil)
          expect(callback).to receive(:create_select_field_system_note).with(select_field,
            [select_option_1.value], [])
          expect(callback).to receive(:create_select_field_system_note).with(multi_select_field,
            [multi_select_option_1.value, multi_select_option_2.value], []
          )

          after_save_callback
        end
      end

      context "when we remove the value" do
        let(:params) do
          [
            { custom_field_id: text_field.id, text_value: nil },
            { custom_field_id: number_field.id, number_value: nil },
            { custom_field_id: date_field.id, date_value: nil },
            { custom_field_id: select_field.id, selected_option_ids: [] },
            { custom_field_id: multi_select_field.id, selected_option_ids: [] }
          ]
        end

        before do
          create(:work_item_text_field_value, work_item: work_item, custom_field: text_field, value: 'existing text')
          create(:work_item_number_field_value, work_item: work_item, custom_field: number_field, value: 50)
          create(:work_item_date_field_value, work_item: work_item, custom_field: date_field, value: date)
          create(:work_item_select_field_value, work_item: work_item, custom_field: select_field,
            custom_field_select_option: select_option_1)
          create(:work_item_select_field_value, work_item: work_item, custom_field: multi_select_field,
            custom_field_select_option: multi_select_option_1)
          create(:work_item_select_field_value, work_item: work_item, custom_field: multi_select_field,
            custom_field_select_option: multi_select_option_2)
        end

        it "creates system notes for each param" do
          expect { after_save_callback }.to change { Note.count }.from(0).to(5)
        end

        it "calls the create system note method with correct params" do
          expect(callback).to receive(:create_text_field_system_note).with(text_field, nil, 'existing text')
          expect(callback).to receive(:create_number_field_system_note).with(number_field, nil, 50)
          expect(callback).to receive(:create_date_field_system_note).with(date_field, nil, date)
          expect(callback).to receive(:create_select_field_system_note).with(select_field,
            [], [select_option_1.value])
          expect(callback).to receive(:create_select_field_system_note).with(multi_select_field,
            [], [multi_select_option_1.value, multi_select_option_2.value]
          )

          after_save_callback
        end
      end
    end

    context 'when the widget is excluded in the new type' do
      let(:params) { { excluded_in_new_type: true } }

      before do
        create(:work_item_text_field_value, work_item: work_item, custom_field: text_field, value: 'existing')
        create(:work_item_number_field_value, work_item: work_item, custom_field: number_field, value: 42)
        create(:work_item_date_field_value, work_item: work_item, custom_field: date_field, value: date)
        create(:work_item_select_field_value, work_item: work_item, custom_field: select_field,
          custom_field_select_option: select_option_1)
      end

      it 'does not raise an error' do
        expect { after_save_callback }.not_to raise_error
      end

      it 'clears all existing custom field values' do
        expect { after_save_callback }
          .to change { custom_field_values_for(text_field).count }.from(1).to(0)
          .and change { custom_field_values_for(number_field).count }.from(1).to(0)
          .and change { custom_field_values_for(date_field).count }.from(1).to(0)
          .and change { custom_field_values_for(select_field).count }.from(1).to(0)
      end
    end

    context 'when user does not have access' do
      let(:current_user) { create(:user) }

      it 'does not set any custom field values' do
        after_save_callback

        expect(custom_field_values_for(text_field)).to be_empty
        expect(custom_field_values_for(number_field)).to be_empty
        expect(custom_field_values_for(date_field)).to be_empty
        expect(custom_field_values_for(select_field)).to be_empty
        expect(custom_field_values_for(multi_select_field)).to be_empty
      end
    end

    context 'when custom field ID is invalid' do
      let(:params) do
        [
          { custom_field_id: non_existing_record_id, text_value: 'some text' }
        ]
      end

      it 'raises an error' do
        expect { after_save_callback }.to raise_error(Issuable::Callbacks::Base::Error, /Invalid custom field ID/)
      end
    end

    context 'when there are validation errors' do
      let(:params) do
        [
          { custom_field_id: number_field.id, number_value: 'some text' }
        ]
      end

      it 'raises an error' do
        expect do
          after_save_callback
        end.to raise_error(Issuable::Callbacks::Base::Error, 'Validation failed: Value is not a number')
      end
    end

    context 'with unsupported custom field type' do
      let(:invalid_field) do
        create(:custom_field, namespace: group, work_item_types: [issue_type]).tap do |f|
          f.update_column(:field_type, -1)
        end
      end

      let(:params) do
        [
          { custom_field_id: invalid_field.id, text_value: 'some text' }
        ]
      end

      it 'raises an error' do
        expect do
          after_save_callback
        end.to raise_error(Issuable::Callbacks::Base::Error, /\AUnsupported field type/)
      end
    end
  end

  context "for create system note methods" do
    let(:issuables_service) { instance_double(::SystemNotes::IssuablesService) }

    before do
      allow(::SystemNotes::IssuablesService).to receive(:new).with(noteable: work_item, container: work_item.namespace,
        author: current_user).and_return(issuables_service)
    end

    describe '#create_text_field_system_note' do
      subject(:create_text_field_system_note) do
        callback.send(:create_text_field_system_note, text_field, 'New value', 'Old value')
      end

      it 'calls SystemNoteService with correct parameters' do
        expect(issuables_service).to receive(:change_custom_field_text_type_note)
          .with(text_field, value: 'New value', previous_value: 'Old value')

        create_text_field_system_note
      end
    end

    describe '#create_number_field_system_note' do
      subject(:create_number_field_system_note) do
        callback.send(:create_number_field_system_note, number_field, 5.0, 4.0)
      end

      it 'calls SystemNoteService with correct parameters' do
        expect(issuables_service).to receive(:change_custom_field_number_type_note)
          .with(number_field, value: 5.0, previous_value: 4.0)

        create_number_field_system_note
      end
    end

    describe '#create_date_field_system_note' do
      let(:other_date) { generate(:sequential_date).to_date }

      subject(:create_date_field_system_note) do
        callback.send(:create_date_field_system_note, date_field, date, other_date)
      end

      it 'calls SystemNoteService with correct parameters' do
        expect(issuables_service).to receive(:change_custom_field_date_type_note)
          .with(date_field, value: date, previous_value: other_date)

        create_date_field_system_note
      end
    end

    describe '#create_select_field_system_note' do
      subject(:create_select_field_system_note) do
        callback.send(:create_select_field_system_note, multi_select_field, ['Option 1', 'Option 2'], ['Option 3'])
      end

      context "when we change values" do
        it 'calls SystemNoteService with correct parameters' do
          expect(issuables_service).to receive(:change_custom_field_select_type_note)
            .with(multi_select_field,
              new_options: ['Option 1', 'Option 2'],
              previous_options: ['Option 3']
            )

          create_select_field_system_note
        end
      end
    end
  end

  def custom_field_values_for(custom_field)
    value_class = if custom_field.field_type_text?
                    WorkItems::TextFieldValue
                  elsif custom_field.field_type_number?
                    WorkItems::NumberFieldValue
                  elsif custom_field.field_type_select?
                    WorkItems::SelectFieldValue
                  elsif custom_field.field_type_date?
                    WorkItems::DateFieldValue
                  end

    value_class.where(work_item: work_item, custom_field: custom_field)
  end
end
