# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::CopyCustomFieldValuesService, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:other_project) { create(:project, group: group) }

  let_it_be(:work_item) { create(:work_item, project: project) }
  let_it_be(:target_work_item) { create(:work_item, project: other_project) }
  let_it_be(:date_value) { Date.new(2026, 5, 7) }

  include_context 'with group configured with custom fields'

  subject(:service) { described_class.new(work_item: source, target_work_item: target) }

  before do
    create(:work_item_text_field_value, work_item: work_item, custom_field: text_field, value: 'Sample text')
    create(:work_item_number_field_value, work_item: work_item, custom_field: number_field, value: 42)
    create(:work_item_select_field_value, work_item: work_item, custom_field: select_field,
      custom_field_select_option: select_option_1)
    create(:work_item_date_field_value, work_item: work_item, custom_field: date_field, value: date_value)
  end

  describe '#execute' do
    context 'when source and target are in different root namespaces' do
      let_it_be(:other_namespace_project) { create(:project, group: create(:group)) }
      let_it_be(:other_namespace_work_item) { create(:work_item, project: other_namespace_project) }

      let(:source) { work_item }
      let(:target) { other_namespace_work_item }

      it 'does not copy any field values' do
        expect { service.execute }.not_to change { WorkItems::TextFieldValue.count }
        expect { service.execute }.not_to change { WorkItems::NumberFieldValue.count }
        expect { service.execute }.not_to change { WorkItems::SelectFieldValue.count }
        expect { service.execute }.not_to change { WorkItems::DateFieldValue.count }
      end
    end

    context 'when source and target are in the same root namespace' do
      let(:source) { work_item }
      let(:target) { target_work_item }

      it 'copies all field values' do
        expect { service.execute }.to change { WorkItems::TextFieldValue.count }.by(1)
                                  .and change { WorkItems::NumberFieldValue.count }.by(1)
                                  .and change { WorkItems::SelectFieldValue.count }.by(1)
                                  .and change { WorkItems::DateFieldValue.count }.by(1)
      end

      it 'copies attributes for work item and namespace correctly' do
        service.execute

        text_field_value = WorkItems::TextFieldValue.last
        expect(text_field_value.work_item).to eq(target_work_item)
        expect(text_field_value.namespace).to eq(target_work_item.namespace)
      end

      it 'assigns correct work_item_id to copied field values' do
        service.execute

        expect(WorkItems::TextFieldValue.last.work_item_id).to eq(target_work_item.id)
        expect(WorkItems::NumberFieldValue.last.work_item_id).to eq(target_work_item.id)
        expect(WorkItems::SelectFieldValue.last.work_item_id).to eq(target_work_item.id)
        expect(WorkItems::DateFieldValue.last.work_item_id).to eq(target_work_item.id)
      end

      it 'copies field values with correct values' do
        service.execute

        expect(WorkItems::TextFieldValue.for_work_item(target_work_item.id).first.value).to eq('Sample text')
        expect(WorkItems::NumberFieldValue.for_work_item(target_work_item.id).first.value).to eq(42)
        expect(WorkItems::SelectFieldValue.for_work_item(target_work_item.id).first.custom_field_select_option_id)
          .to eq(select_option_1.id)
        expect(WorkItems::DateFieldValue.for_work_item(target_work_item.id).first.value).to eq(date_value)
      end
    end
  end

  context 'when source and target are Issue object' do
    let!(:source) { create(:issue, project: project) }
    let(:target) { create(:issue, project: other_project) }

    before do
      create(:work_item_text_field_value, work_item_id: source.id, custom_field: text_field, value: 'Issue text')
    end

    it 'finds the work item and copies field values' do
      expect { service.execute }.to change { WorkItems::TextFieldValue.count }.by(1)
    end

    it 'assigns correct work_item_id to copied field values' do
      service.execute

      new_value = WorkItems::TextFieldValue.last

      expect(new_value.work_item_id).to eq(target.id)
      expect(new_value.value).to eq("Issue text")
    end
  end
end
