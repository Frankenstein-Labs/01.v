# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work Item Custom Fields', :js, feature_category: :team_planning do
  # Import custom fields setup
  include_context 'with group configured with custom fields'

  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:work_item) { create(:work_item, work_item_type: issue_type, project: project) }
  let_it_be(:user) { create(:user) }

  before_all do
    project.add_maintainer(user)
  end

  before do
    stub_licensed_features(custom_fields: true)
    sign_in(user)
  end

  context 'when existing values exist' do
    before_all do
      # Create field values
      create(:work_item_text_field_value, work_item: work_item, custom_field: text_field, value: 'Sample text')

      create(:work_item_number_field_value, work_item: work_item, custom_field: number_field, value: 5)

      create(:work_item_select_field_value, work_item: work_item, custom_field: select_field,
        custom_field_select_option: select_option_1)

      create(:work_item_select_field_value, work_item: work_item, custom_field: multi_select_field,
        custom_field_select_option: multi_select_option_2)
      create(:work_item_select_field_value, work_item: work_item, custom_field: multi_select_field,
        custom_field_select_option: multi_select_option_3)
    end

    it 'displays fields as read-only for users without update permissions' do
      project.add_guest(user)

      visit project_work_item_path(project, work_item)

      within_testid('work-item-custom-field') do
        expect(page).not_to have_text('Edit')
      end
    end
  end

  it 'persists custom field values correctly' do
    visit project_work_item_path(project, work_item)

    within_testid('work-item-custom-field') do
      page.within(':scope > :nth-child(1)') do
        expect(page).to have_text('None')

        click_button('Edit')
        find('.gl-new-dropdown-item', text: select_option_1.value).click

        expect(page).to have_text(select_option_1.value)
      end

      page.within(':scope > :nth-child(2)') do
        expect(page).to have_text('None')

        click_button('Edit')

        expect(page).to have_field('custom-field-number-input', placeholder: 'Enter a number')
        fill_in('custom-field-number-input', with: "5\n")

        expect(page).to have_text('5')
      end

      page.within(':scope > :nth-child(3)') do
        expect(page).to have_text('None')

        click_button('Edit')

        expect(page).to have_field('custom-field-text-input', placeholder: 'Enter text')
        fill_in('custom-field-text-input', with: "Sample text\n")

        expect(page).to have_text('Sample text')
      end

      page.within(':scope > :nth-child(4)') do
        expect(page).to have_text('None')

        click_button('Edit')
        find('.gl-new-dropdown-item', text: multi_select_option_2.value).click
        find('.gl-new-dropdown-item', text: multi_select_option_3.value).click
        find('.gl-new-dropdown').click

        expect(page).to have_text(multi_select_option_2.value)
        expect(page).to have_text(multi_select_option_3.value)
      end
    end

    page.refresh

    within_testid('work-item-custom-field') do
      expect(page).to have_css(':scope > :nth-child(1)', text: select_option_1.value)

      expect(page).to have_css(':scope > :nth-child(2)', text: '5')

      expect(page).to have_css(':scope > :nth-child(3)', text: 'Sample text')

      expect(page).to have_css(':scope > :nth-child(4)', text: multi_select_option_2.value)
      expect(page).to have_css(':scope > :nth-child(4)', text: multi_select_option_3.value)
    end
  end
end
