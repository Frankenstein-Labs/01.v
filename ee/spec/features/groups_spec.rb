# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group', :with_trial_types, :with_current_organization, feature_category: :groups_and_projects do
  include NamespaceStorageHelpers
  include FreeUserCapHelpers

  describe 'group edit', :js do
    let_it_be(:user) { create(:user) }

    let_it_be(:group) do
      create(:group, :public).tap do |g|
        g.add_owner(user)
      end
    end

    let(:path) { edit_group_path(group, anchor: 'js-permissions-settings') }
    let(:group_wiki_licensed_feature) { true }

    before do
      stub_licensed_features(group_wikis: group_wiki_licensed_feature)

      sign_in(user)

      visit path
    end

    context 'when licensed feature group wikis is not enabled' do
      let(:group_wiki_licensed_feature) { false }

      it 'does not show the wiki settings menu' do
        expect(page).not_to have_content('Group-level wiki is disabled.')
      end
    end

    context 'wiki_access_level setting' do
      it 'saves new settings', :aggregate_failures do
        expect(page).to have_content('Group-level wiki is disabled.')

        [Featurable::PRIVATE, Featurable::DISABLED, Featurable::ENABLED].each do |wiki_access_level|
          find(
            ".js-general-permissions-form "\
              "#group_group_feature_attributes_wiki_access_level_#{wiki_access_level}").click

          within_testid('permissions-settings') do
            click_button 'Save changes'
          end

          expect(page).to have_content 'successfully updated'
          expect(group.reload.group_feature.wiki_access_level).to eq wiki_access_level
        end
      end
    end
  end

  describe 'storage pre-enforcement alert', :js do
    let_it_be_with_refind(:group) { create(:group, :with_root_storage_statistics) }
    let_it_be_with_refind(:user) { create(:user) }
    let_it_be(:storage_banner_text) { "A namespace storage limit of 5 GiB will soon be enforced" }

    before do
      stub_ee_application_setting(automatic_purchased_storage_allocation: true)
      stub_saas_features(namespaces_storage_limit: true)

      set_used_storage(group, megabytes: 13)
      set_notification_limit(group, megabytes: 12)
      set_dashboard_limit(group, megabytes: 5_120, enabled: false)
      group.add_guest(user)
      sign_in(user)
    end

    context 'when the group is over the notification_limit' do
      it 'displays the alert in the group page' do
        visit group_path(group)
        expect(page).to have_text storage_banner_text
      end

      context 'when the group does not reach the notification_limit' do
        before do
          set_notification_limit(group, megabytes: 13)
        end

        it 'does not display the alert' do
          visit group_path(group)
          expect(page).not_to have_text storage_banner_text
        end
      end
    end
  end

  describe 'combined storage and users pre-enforcement alert', :saas do
    let_it_be_with_refind(:group) do
      create(:group_with_plan, :with_root_storage_statistics, :private, plan: :free_plan,
        name: 'over_storage_and_users')
    end

    let_it_be_with_refind(:user) { create(:user) }
    let(:alert) do
      'Your Free top-level group, over_storage_and_users, has more than 5 users and uses more than 5 GiB of data'
    end

    before do
      set_notification_limit(group, megabytes: 10_000)
      set_dashboard_limit(group, megabytes: 5_000)
      stub_ee_application_setting(should_check_namespace_plan: true, automatic_purchased_storage_allocation: true)
      stub_feature_flags(free_user_cap_enforcement_promo_cta: false)
    end

    context 'when owner' do
      before do
        group.add_owner(user)
        sign_in(user)
        exceed_user_cap(group)
        enforce_free_user_caps
      end

      context 'when the group is over both storage notification and users limits' do
        before do
          set_used_storage(group, megabytes: 11_000)
        end

        it 'displays the alert with CTAs' do
          visit group_path(group)

          expect(page).to have_text alert
          expect(page).to have_text 'Explore paid plans'
          expect(page).to have_text 'Manage usage'
        end
      end

      context 'when the group is not over one of the limits' do
        before do
          set_used_storage(group, megabytes: 9_000)
        end

        it 'does not display the alert' do
          visit group_path(group)

          expect(page).not_to have_text alert
        end
      end
    end

    context 'when non owner' do
      before do
        group.add_maintainer(user)
        sign_in(user)
        exceed_user_cap(group)
        enforce_free_user_caps
      end

      context 'when the group is over both storage notification and users limits' do
        before do
          set_used_storage(group, megabytes: 11_000)
        end

        it 'displays the alert without CTAs' do
          visit group_path(group)

          expect(page).to have_text alert
          expect(page).not_to have_text 'Explore paid plans'
          expect(page).not_to have_text 'Manage usage'
        end
      end

      context 'when the group is not over one of the limits' do
        before do
          set_used_storage(group, megabytes: 9_000)
        end

        it 'does not display the alert' do
          visit group_path(group)

          expect(page).not_to have_text alert
        end
      end
    end
  end

  describe 'identity verification', :js, :saas do
    let_it_be_with_reload(:user) do
      create(
        :user, :identity_verification_eligible, :with_sign_ins,
        organizations: [current_organization]
      )
    end

    before do
      sign_in(user)
      visit new_group_path
      click_link 'Create group'
    end

    context 'when the user has reached the maximum number of created groups' do
      before do
        create_list(:group, ::Gitlab::CurrentSettings.unverified_account_group_creation_limit, creator: user)
      end

      context 'when the user has not completed identity verification' do
        it 'renders new group form with validation errors' do
          fill_in 'Group name', with: 'identity-verification-group'
          fill_in 'Group URL', with: 'identity_verification_group'
          click_button 'Create group'

          expect(page).to have_current_path(groups_path, ignore_query: true)
          expect(page).to have_text('Before you can create additional groups, we need to verify your account.')
        end
      end

      context 'when user is a member of a paid namespace' do
        before do
          create(:group_with_plan, plan: :ultimate_plan, developers: user)
        end

        it 'creates the group' do
          fill_in 'Group name', with: 'Paid user group'
          click_button 'Create group'

          expect(page).to have_selector 'h1', text: 'Paid user group'
        end
      end

      context 'when the user has completed identity verification' do
        before do
          create(:phone_number_validation, :validated, user: user)
        end

        it 'creates the group' do
          fill_in 'Group name', with: 'identity-verification-group'
          fill_in 'Group URL', with: 'identity_verification_group'
          click_button 'Create group'

          expect(page).to have_selector 'h1', text: 'identity-verification-group'
        end
      end

      context 'when creating a subgroup' do
        let_it_be(:group) { create(:group, path: 'parent', organization: current_organization, owners: user) }

        before do
          visit new_group_path(parent_id: group.id, anchor: 'create-group-pane')
        end

        it 'creates the group', :js do
          fill_in 'Subgroup name', with: 'identity-verification-subgroup'
          click_button 'Create subgroup'

          expect(page).to have_current_path(group_path('parent/identity-verification-subgroup'), ignore_query: true)
          expect(page).to have_selector 'h1', text: 'identity-verification-subgroup'
        end
      end
    end

    context 'when the user has not reached the maximum number of created groups' do
      it 'creates the group' do
        fill_in 'Group name', with: 'identity-verification-group'
        fill_in 'Group URL', with: 'identity_verification_group'
        click_button 'Create group'

        expect(page).to have_selector 'h1', text: 'identity-verification-group'
      end
    end
  end
end
