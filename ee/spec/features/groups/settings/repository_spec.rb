# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'EE Group Repository settings', :js, feature_category: :source_code_management do
  include WaitForRequests

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group, owners: user) }

  before do
    sign_in(user)
  end

  context 'in General subsection' do
    context 'when web-based commit signing is available',
      :saas_repositories_web_based_commit_signing do
      before do
        visit group_settings_repository_path(group)
        wait_for_requests
      end

      it 'shows the setting section' do
        expect(page).to have_selector('#js-general-settings')
      end

      it 'shows web-based commit signing section' do
        expect(page).to have_css('[data-testid="web-based-commit-signing-checkbox"]')
        expect(page).to have_unchecked_field('Sign web-based commits')
      end

      it 'persists the checkbox value after checking and reloading' do
        expect(page).to have_unchecked_field('Sign web-based commits')

        check 'Sign web-based commits'
        wait_for_requests

        visit group_settings_repository_path(group)
        wait_for_requests

        expect(page).to have_checked_field('Sign web-based commits')
      end
    end

    context 'when SaaS feature is not available' do
      before do
        stub_saas_features(repositories_web_based_commit_signing: false)
        visit group_settings_repository_path(group)
        wait_for_requests
      end

      it 'does not show the setting section' do
        expect(page).not_to have_selector('#js-general-settings')
      end
    end

    context 'when group is a subgroup', :saas_repositories_web_based_commit_signing do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: parent_group, owners: user) }

      before do
        visit group_settings_repository_path(subgroup)
        wait_for_requests
      end

      it 'does not show the setting section' do
        expect(page).not_to have_selector('#js-general-settings')
      end
    end
  end

  context 'in Protected branches subsection' do
    def access_levels_dropdown_contents
      within('#js-protected-branches-settings') do
        click_button 'Add protected branch'
        find('.gl-dropdown-toggle.js-allowed-to-merge:not([disabled])').click
        wait_for_all_requests

        page.find('.gl-dropdown-contents')
      end
    end

    context 'when feature `group_protected_branches` is enabled' do
      before do
        stub_licensed_features(group_protected_branches: true)
        visit group_settings_repository_path(group)
      end

      it 'shows the setting section' do
        expect(page).to have_selector('#js-protected-branches-settings')
      end

      it 'does not show users in the access levels dropdown' do
        expect(access_levels_dropdown_contents).not_to have_content('Users')
      end

      context 'with custom roles for protected branches' do
        before do
          stub_licensed_features(group_protected_branches: true, custom_roles: true)
          stub_saas_features(gitlab_com_subscriptions: true)
          visit group_settings_repository_path(group)
        end

        context 'when enabled' do
          before do
            create(:member_role, namespace: group)
          end

          # The custom_roles_for_protected_branches feature flag is enabled by default in tests.
          it 'shows custom roles in the access levels dropdown' do
            expect(access_levels_dropdown_contents).to have_content('Custom roles')
          end
        end

        context 'when disabled' do
          before do
            stub_feature_flags(custom_roles_for_protected_branches: false)
            visit group_settings_repository_path(group)
          end

          it 'does not show custom roles in the access levels dropdown' do
            expect(access_levels_dropdown_contents).not_to have_content('Custom roles')
          end
        end
      end
    end

    context 'when feature `group_protected_branches` is not enabled' do
      before do
        visit group_settings_repository_path(group)
      end

      it 'does not show the setting section' do
        expect(page).not_to have_selector('#js-protected-branches-settings')
      end
    end
  end
end
