# frozen_string_literal: true

RSpec.shared_context 'with group configured with custom fields' do
  let_it_be(:group, freeze: false) { create(:group) }

  let_it_be(:issue_type) { build(:work_item_system_defined_type, :issue) }
  let_it_be(:task_type) { build(:work_item_system_defined_type, :task) }

  let_it_be(:text_field, freeze: false) do
    create(:custom_field, namespace: group, field_type: 'text', name: 'Custom field text',
      work_item_types: [issue_type])
  end

  let_it_be(:number_field, freeze: false) do
    create(:custom_field, namespace: group, field_type: 'number', name: 'B number field',
      work_item_types: [issue_type])
  end

  let_it_be(:date_field, freeze: false) do
    create(:custom_field, field_type: 'date', namespace: group, name: 'Custom Date',
      work_item_types: [issue_type])
  end

  let_it_be(:select_field, freeze: false) do
    create(
      :custom_field,
      namespace: group,
      field_type: 'single_select',
      name: 'A single select field',
      work_item_types: [
        issue_type, task_type
      ]
    )
  end

  let_it_be(:select_option_1, freeze: false) { create(:custom_field_select_option, custom_field: select_field) }
  let_it_be(:select_option_2, freeze: false) { create(:custom_field_select_option, custom_field: select_field) }

  let_it_be(:multi_select_field, freeze: false) do
    create(
      :custom_field,
      namespace: group,
      field_type: 'multi_select',
      name: 'Double (multi) select field',
      work_item_types: [
        issue_type, task_type
      ]
    )
  end

  let_it_be(:multi_select_option_1, freeze: false) do
    create(:custom_field_select_option, custom_field: multi_select_field)
  end

  let_it_be(:multi_select_option_2, freeze: false) do
    create(:custom_field_select_option, custom_field: multi_select_field)
  end

  let_it_be(:multi_select_option_3, freeze: false) do
    create(:custom_field_select_option, custom_field: multi_select_field)
  end

  let_it_be(:archived_field, freeze: false) do
    create(:custom_field, :archived, namespace: group, field_type: 'text', work_item_types: [issue_type])
  end

  let_it_be(:field_on_other_type, freeze: false) do
    create(:custom_field, namespace: group, field_type: 'text', work_item_types: [task_type])
  end
end
