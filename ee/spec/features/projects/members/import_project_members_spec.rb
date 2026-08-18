# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects > Members > Import project members', :js, feature_category: :groups_and_projects do
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:user_mike) { create(:user, name: 'Mike') }
  let_it_be_with_refind(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:source_project) { create(:project) }

  before_all do
    group.add_owner(user)
    project.add_developer(create(:user))
    source_project.add_owner(user)
    source_project.add_reporter(user_mike)
  end

  before do
    sign_in(user)

    visit(project_project_members_path(project))
  end

  describe 'block seat overages', :saas do
    let_it_be(:subscription) { create(:gitlab_subscription, :premium, namespace: group, seats: 2) }

    context 'when block seat overages is enabled for the group' do
      before do
        group.namespace_settings.update!(seat_control: :block_overages)
      end

      context 'when the user is a group owner' do
        before_all do
          group.add_owner(user)
        end

        it 'shows a CTA to purchase more seats' do
          click_on 'Import from a project'
          click_on 'Select a project'
          select_listbox_item(source_project.name_with_namespace)

          click_button 'Import project members'

          within import_project_members_modal_selector do
            expect(page).to have_text('There are not enough available seats to invite this many users.')
            expect(page).to have_content('You must purchase more seats for your subscription before ' \
                                         'this amount of users can be added.')
            expect(page).to have_link 'Purchase more seats'
          end
        end
      end

      context 'when the user is not a group owner' do
        before_all do
          group.add_maintainer(user)
        end

        it 'does not show a CTA to purchase more seats' do
          click_on 'Import from a project'
          click_on 'Select a project'
          select_listbox_item(source_project.name_with_namespace)

          click_button 'Import project members'

          within import_project_members_modal_selector do
            expect(page).to have_text('There are not enough available seats to invite this many users.')
            expect(page).not_to have_content('You must purchase more seats for your subscription before ' \
                                             'this amount of users can be added.')
            expect(page).not_to have_link 'Purchase more seats'
          end
        end
      end
    end

    context 'when block seat overages is disabled for the group', :saas do
      before_all do
        group.add_owner(user)
      end

      before do
        group.namespace_settings.update!(seat_control: :off)
      end

      it 'allows adding the users' do
        click_on 'Import from a project'
        click_on 'Select a project'
        select_listbox_item(source_project.name_with_namespace)

        click_button 'Import project members'

        expect(page).to have_text('Members were successfully added')
        expect(page).not_to have_selector(import_project_members_modal_selector)
      end
    end
  end

  def import_project_members_modal_selector
    '[data-testid="import-project-members-modal"]'
  end
end
