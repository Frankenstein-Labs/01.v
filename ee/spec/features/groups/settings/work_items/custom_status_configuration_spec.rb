# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Settings > Work Items', :js, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:maintainer) { create(:user, maintainer_of: [group, subgroup]) }
  let_it_be(:developer) { create(:user, developer_of: [group, subgroup]) }
  let(:user) { maintainer }

  before do
    stub_licensed_features(work_item_status: true)
  end

  shared_examples 'prevents access' do
    it 'returns 404' do
      sign_in(user)
      visit settings_path

      expect(page).to have_content('404: Page not found')
    end
  end

  shared_examples 'custom status management' do
    context 'when user is authorized' do
      before do
        sign_in(user)
        visit settings_path
      end

      def add_custom_status(name, description)
        click_button('Add status')
        fill_in 'Name', with: name
        click_button('Add description')
        find_field('Description')
        fill_in 'Description', with: description
        click_button('Save')
        expect(page).to have_content description
      end

      it 'can add statuses' do
        click_button('Edit statuses')
        within_testid('category-triage') do
          click_button('Add status')
          fill_in 'Name', with: 'Triage custom status'
          click_button('Add description')
          fill_in 'Description', with: 'Deciding what to do with things'
          click_button('Save')
        end

        click_button('Edit statuses')
        within_testid('category-to_do') do
          add_custom_status('To do custom status', 'Things to do')
        end

        within_testid('category-in_progress') do
          add_custom_status('In progress custom status', 'Things in progress')
        end

        within_testid('category-done') do
          add_custom_status('Done custom status', 'Things done')
        end

        within_testid('category-canceled') do
          add_custom_status('Canceled custom status', 'Things canceled')
        end

        within_testid('lifecycle-detail') do
          expect(page).to have_text('Triage custom status')
          expect(page).to have_text('To do custom status')
          expect(page).to have_text('In progress custom status')
          expect(page).to have_text('Done custom status')
          expect(page).to have_text('Canceled custom status')
        end
      end

      it 'can edit and remove statuses' do
        click_button('Edit statuses')
        within_testid('category-triage') do
          click_button('Add status')
          fill_in 'Name', with: 'Edit me'
          click_button('Add description')
          fill_in 'Description', with: 'Change is inevitable'
          click_button('Save')
        end

        within_testid('lifecycle-detail') do
          expect(page).to have_text('Edit me')
        end

        click_button('Edit statuses')
        within_testid('category-triage') do
          click_button('More actions')
          click_button('Edit status')
          fill_in 'Name', with: 'Delete me'
          click_button('Update')
        end
        click_button('Close', match: :first)

        within_testid('lifecycle-detail') do
          expect(page).to have_text('Delete me')
          expect(page).not_to have_text('Edit me')
        end

        click_button('Edit statuses')
        within_testid('category-triage') do
          click_button('More actions')
          click_button('Remove status')
        end
        click_button('Remove')
        click_button('Close', match: :first)

        within_testid('lifecycle-detail') do
          expect(page).not_to have_text('Edit me')
          expect(page).not_to have_text('Delete me')
        end
      end
    end

    context 'when user is not authorized' do
      it_behaves_like 'prevents access' do
        let(:user) { developer }
      end
    end

    context 'without the licensed feature' do
      before do
        stub_licensed_features(work_item_status: false)
      end

      it_behaves_like 'prevents access'
    end
  end

  context 'with root group' do
    let(:target_group) { group }

    let(:settings_path) { group_settings_work_items_path(target_group, anchor: 'js-custom-status-settings') }

    it_behaves_like 'custom status management'
  end

  context 'with subgroup' do
    let(:target_group) { subgroup }
    let(:settings_path) { group_settings_work_items_path(target_group) }

    before do
      sign_in(maintainer)
      visit settings_path
    end

    it 'does not show Edit status button for default statuses' do
      expect(page).not_to have_button('Edit statuses')
    end
  end
end
