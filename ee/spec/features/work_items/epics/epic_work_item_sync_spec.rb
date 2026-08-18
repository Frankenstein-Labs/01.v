# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Epic Work Item sync', :js, feature_category: :portfolio_management do
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:parent_epic) { create(:epic, group: group) }

  let_it_be(:description) { 'My synced epic' }
  let_it_be(:epic_title) { 'New epic title' }
  let_it_be(:updated_title) { 'Another title' }
  let_it_be(:updated_description) { 'Updated description' }
  let_it_be(:start_date) { 1.day.after(Time.current).to_date }
  let_it_be(:due_date) { 5.days.after(start_date) }
  let(:description_input) do
    "#{description}\n/set_parent #{parent_epic.to_reference}\n"
  end

  before_all do
    group.add_developer(user)
  end

  before do
    stub_licensed_features(epics: true, subepics: true, epic_colors: true)
    sign_in(user)
  end

  describe 'from work item to epic' do
    before do
      # TODO: remove threshold after epic-work item sync
      # issue: https://gitlab.com/gitlab-org/gitlab/-/issues/438295
      allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(130)
    end

    subject(:create_epic_work_item) do
      visit group_epics_path(group)
      find_by_testid('new-epic-button').click
      find_by_testid('work-item-title-input').fill_in with: epic_title
      find_by_testid('markdown-editor-form-field').native.send_keys(description_input)
      find_by_testid('confidential-checkbox').set(true)

      click_button 'Create Epic'
      expect(page).to have_content(epic_title)
    end

    it 'creates an epic work item on the /new page' do
      visit new_group_epic_path(group)

      find_by_testid('work-item-title-input').fill_in with: epic_title
      find_by_testid('markdown-editor-form-field').native.send_keys(description_input)
      find_by_testid('confidential-checkbox').set(true)

      click_button 'Create Epic'

      wait_for_requests

      expect(find_by_testid('work-item-title').text).to eq(epic_title)
    end

    it 'creates work item and a legacy epic that are in sync' do
      expect { create_epic_work_item }.to change { Epic.count }.by(1).and change { WorkItem.count }.by(1)

      wait_for_requests
      # We don't show the new epic work item in the list immediately.
      visit group_epics_path(group)
      expect(find('a', text: epic_title)).to be_visible

      work_item = WorkItem.last
      epic = work_item.synced_epic

      visit group_work_item_path(group, work_item.iid)
      expect(find_by_testid('work-item-title').text).to eq(work_item.title)

      expect(work_item.title).to eq(epic_title)
      expect(work_item.description).to eq(description)
      expect(work_item).to be_confidential
      expect(Gitlab::EpicWorkItemSync::Diff.new(epic, epic.work_item, strict_equal: true).attributes).to be_empty
    end

    it 'updates the legacy epic when the work item is updated', :sidekiq_inline,
      quarantine: {
        issue: [
          'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/2480',
          'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/3181'
        ]
      } do
      create_epic_work_item
      wait_for_requests

      work_item = WorkItem.last
      visit group_work_item_path(group, work_item.iid)

      find_by_testid('work-item-edit-form-button').click
      find_by_testid('work-item-title-input').fill_in with: updated_title
      fill_in 'work-item-description', with: updated_description
      click_button 'Save changes'
      wait_for_requests

      find_by_testid('work-item-actions-dropdown').click
      find_by_testid('confidentiality-toggle-action').click
      wait_for_requests

      within_testid('work-item-due-dates') do
        click_button 'Edit'
        fill_in 'Start', with: start_date.iso8601
        fill_in 'Due', with: due_date.iso8601
        click_button 'Apply'
      end

      within_testid('work-item-color') do
        click_button 'Edit'
        click_link 'Dark red'
      end

      within_testid('work-item-parent') do
        click_button 'Edit'
        send_keys(parent_epic.title)
        select_listbox_item(parent_epic.title)
      end

      work_item.reload
      epic = work_item.synced_epic

      expect(work_item.title).to eq(updated_title)
      expect(work_item.description).to eq(updated_description)
      expect(work_item).not_to be_confidential
      expect(work_item.work_item_parent).to eq(parent_epic.work_item)
      expect(work_item.color.color.to_s).to eq('#c91c00')

      expect(Gitlab::EpicWorkItemSync::Diff.new(epic, epic.work_item, strict_equal: true).attributes).to be_empty
    end
  end
end
