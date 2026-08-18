# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Settings > Work Items - removing statuses', :js, feature_category: :team_planning do
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, owners: user) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:in_progress_status_id) { build(:work_item_system_defined_status, :in_progress).id }

  before do
    stub_licensed_features(work_item_status: true)
  end

  shared_examples 'removing non-default status' do
    context 'when removing non-default status with items to a default status' do
      let!(:in_progress_issue) { create(:issue, project: project) }
      let!(:in_progress_issue_current_status) do
        create(:work_item_current_status, work_item_id: in_progress_issue.id,
          system_defined_status_id: in_progress_status_id)
      end

      it 'deletes non-default status and moves items to the default status' do
        sign_in(user)
        visit settings_path

        within_testid('lifecycle-detail') do
          expect(page).to have_testid('work-item-status-badge', text: 'In progress')
        end

        click_button 'Edit statuses'

        within_testid('category-to_do') do
          expect(page).to have_testid('status-badge', text: 'To do')
        end

        within_testid('category-in_progress') do
          expect(page).to have_testid('status-badge', text: 'In progress')

          click_button('More actions')
          click_button('Remove status')
        end

        within('#remove-status-modal') do
          expect(page).to have_css('h2', text: 'Remove status')
          expect(page).to have_text("Select a new status to use for any items currently using this status.")
          expect(page).to have_button('To do')

          click_button('Remove status')
        end

        within_testid('lifecycle-detail') do
          expect(page).to have_no_testid('work-item-status-badge', text: 'In progress')
        end

        click_button 'Edit statuses'

        within_testid('category-to_do') do
          expect(page).to have_testid('status-badge', text: 'To do')
        end

        within_testid('category-in_progress') do
          expect(page).to have_no_testid('status-badge')
        end
      end
    end
  end

  context 'when removing non-default status' do
    let(:settings_path) { group_settings_work_items_path(group, anchor: 'js-custom-status-settings') }

    it_behaves_like 'removing non-default status'
  end
end
