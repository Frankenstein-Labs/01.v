# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group > Settings > Packages and registries', :aggregate_failures,
  feature_category: :package_registry do
  include WaitForRequests

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: group) }

  describe 'Virtual registry' do
    before do
      stub_configuration
      sign_in(user)
    end

    context 'when user is not authorised' do
      it 'cleanup policy page renders 404' do
        visit_virtual_registry_cleanup_policy_page

        expect(page).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is authorised', :js do
      before_all do
        group.add_owner(user)
      end

      it 'sub-group settings page does not have section' do
        visit_sub_group_settings_page

        expect(page).not_to have_selector('h2', text: 'Virtual registry')
      end

      it 'group settings page has section and toggling off setting disallows access' do
        visit_settings_page
        wait_for_requests

        expect(page).to have_selector('h2', text: 'Virtual registry')

        within_testid 'virtual-registries-setting' do
          click_button class: 'gl-toggle'
        end

        expect(find('.gl-toast')).to have_content('Settings saved successfully.')

        visit group_virtual_registries_path(group)
        expect(page).to have_content 'Page not found'
      end

      context 'when the setting is already disabled for the group' do
        before do
          create(:virtual_registries_setting, :disabled, group: group)
        end

        it 'still renders the toggle so the setting can be re-enabled' do
          visit_settings_page
          wait_for_requests

          expect(page).to have_selector('h2', text: 'Virtual registry')

          within_testid 'virtual-registries-setting' do
            expect(page).to have_button(class: 'gl-toggle')
          end
        end
      end

      describe 'cleanup policy form' do
        it 'cleanup policy page has a page title set' do
          visit_virtual_registry_cleanup_policy_page

          expect(page).to have_selector('h1', text: 'Virtual registry cache cleanup policy')

          within_testid('super-sidebar') do
            expect(page).to have_selector('button[aria-expanded="true"]', text: 'Settings')
            expect(page).to have_selector('[aria-current="page"]', text: 'Packages and registries')
          end
        end

        it 'renders the cleanup policy form fields' do
          visit_virtual_registry_cleanup_policy_page
          wait_for_requests

          expect(page).to have_content('Enable cleanup policy')
          expect(page).to have_content('Run cleanup')
          expect(page).to have_content('Delete caches not accessed in the last (days)')
          expect(page).to have_content('Email notifications')
          expect(page).to have_button('Save changes')
          expect(page).to have_button('Cancel')
        end

        context 'without an existing policy' do
          it 'creates a new cleanup policy and redirects with success alert' do
            visit_virtual_registry_cleanup_policy_page
            wait_for_requests

            click_button class: 'gl-toggle'
            select 'Every month', from: 'cadence-select'
            fill_in 'keep-n-days-input', with: '14'
            click_button 'Save changes'
            wait_for_requests

            expect(page).to have_current_path(group_settings_packages_and_registries_path(group))
            expect(page).to have_content('Cleanup policy has been successfully saved.')
            expect(page).to have_content('every month')
            expect(page).to have_content('14 days')
          end
        end

        context 'with an existing policy' do
          before_all do
            create(:virtual_registries_cleanup_policy, :enabled, group: group,
              cadence: 7, keep_n_days_after_download: 30)
          end

          it 'updates the policy and redirects with success alert' do
            visit_virtual_registry_cleanup_policy_page
            wait_for_requests

            select 'Every two weeks', from: 'cadence-select'
            fill_in 'keep-n-days-input', with: '60'
            click_button 'Save changes'
            wait_for_requests

            expect(page).to have_current_path(group_settings_packages_and_registries_path(group))
            expect(page).to have_content('Cleanup policy has been successfully saved.')
            expect(page).to have_content('every two weeks')
            expect(page).to have_content('60 days')
          end
        end

        it 'redirects to settings page on cancel' do
          visit_virtual_registry_cleanup_policy_page
          wait_for_requests

          click_button 'Cancel'

          expect(page).to have_current_path(group_settings_packages_and_registries_path(group))
        end
      end
    end
  end

  private

  def stub_configuration
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
  end

  def visit_settings_page
    visit group_settings_packages_and_registries_path(group)
  end

  def visit_sub_group_settings_page
    visit group_settings_packages_and_registries_path(sub_group)
  end

  def visit_virtual_registry_cleanup_policy_page
    visit group_settings_packages_and_registries_virtual_registry_cleanup_policy_index_path(group)
  end
end
