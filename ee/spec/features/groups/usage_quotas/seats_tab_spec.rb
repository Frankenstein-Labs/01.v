# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Usage quotas > Seats tab', :with_trial_types, :js, :saas, feature_category: :seat_cost_management do
  include Spec::Support::Helpers::ModalHelpers
  include Features::MembersHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:user_from_sub_group) { create(:user) }
  let_it_be(:shared_group) { create(:group) }
  let_it_be(:shared_group_developer) { create(:user) }

  before do
    stub_signing_key
    stub_application_setting(check_namespace_plan: true)
    stub_subscription_permissions_data(group.id)

    group.add_owner(user)
    group.add_maintainer(maintainer)

    sub_group.add_maintainer(user_from_sub_group)

    shared_group.add_developer(shared_group_developer)
    create(:group_group_link, { shared_with_group: shared_group, shared_group: group })

    sign_in(user)
  end

  context 'with seat usage table' do
    before do
      visit group_seat_usage_path(group)
      wait_for_requests
    end

    it 'displays correct number of users' do
      within member_table_selector do
        expect(all('tbody tr').count).to eq(4)
      end
    end

    context 'with seat usage details table' do
      it 'expands the details on click' do
        first('[data-testid*="toggle-seat-usage-details-"]').click

        wait_for_requests

        expect(page).to have_selector('[data-testid="seat-usage-details"]')
      end

      it 'hides the details table on click' do
        # expand the details table first
        first('[data-testid*="toggle-seat-usage-details-"]').click

        wait_for_requests

        # and collapse it
        first('[data-testid*="toggle-seat-usage-details-"]').click

        expect(page).not_to have_selector('[data-testid="seat-usage-details"]')
      end
    end
  end

  context 'when removing user' do
    before do
      visit group_seat_usage_path(group)
      wait_for_requests
    end

    shared_examples 'a modal to confirm removal' do
      before do
        remove_user(maintainer)
      end

      it 'has disabled the remove button' do
        within billable_member_modal_selector do
          expect(page).to have_button('Remove user', disabled: true)
        end
      end

      it 'enables the remove button when user enters valid username' do
        within billable_member_modal_selector do
          find('input').fill_in(with: maintainer.username)
          find('input').send_keys(:tab)

          expect(page).to have_button('Remove user', disabled: false)
        end
      end

      it 'does not enable button when user enters invalid username' do
        within billable_member_modal_selector do
          find('input').fill_in(with: 'invalid username')
          find('input').send_keys(:tab)

          expect(page).to have_button('Remove user', disabled: true)
        end
      end

      it 'does not display the error modal' do
        expect(page).not_to have_content('Cannot remove user')
      end
    end

    it_behaves_like 'a modal to confirm removal'

    context 'when the namespace is in a read_only state' do
      let_it_be(:group) { create(:group_with_plan, :private, plan: :free_plan) }

      before do
        stub_ee_application_setting(dashboard_limit_enabled: true)

        # group_seat_usage_path does some admin_group_member check then
        # redirects to the below path where we only check read.
        # This is strangely more restrictive then going to the
        # usage_quotas controller directly with an anchor...so we'll
        # just do that since admin_group_member is prevented in
        # read_only mode.
        visit group_usage_quotas_path(group, anchor: 'seats-quota-tab')

        wait_for_requests
      end

      it_behaves_like 'a modal to confirm removal'
    end

    context 'when removing a user from a sub-group' do
      it 'updates the seat table of the parent group' do
        within member_table_selector do
          expect(all('tbody tr').count).to eq(4)
        end

        visit group_group_members_path(sub_group)

        show_actions_for_username(user_from_sub_group)
        click_button _('Remove member')

        within_modal do
          click_button _('Remove member')
        end

        expect(page).to have_content('User was successfully removed from group.')

        visit group_seat_usage_path(group)

        wait_for_all_requests

        within member_table_selector do
          expect(all('tbody tr').count).to eq(3)
        end
      end
    end

    context 'when cannot remove the user' do
      let(:shared_user_row) do
        within member_table_selector do
          find('tr', text: shared_group_developer.name)
        end
      end

      it 'displays an error modal' do
        within shared_user_row do
          click_button 'Remove user'
        end

        expect(page).to have_content('Cannot remove user')
      end
    end

    context 'with max seats and seats owed calculated' do
      let_it_be(:gitlab_subscription, freeze: false) do
        create(:gitlab_subscription, :ultimate, seats: 1, namespace: group)
      end

      let_it_be(:guest) { create(:user) }

      before do
        group.add_guest(guest)

        refresh_subscription_seats

        page.refresh
        wait_for_requests
      end

      it 'correctly shows seat usage and counts' do
        expect(page).to have_content('4 / 1 Seats in use / Seats in subscription')
        expect(page.text).to include('4 Max seats used')
        expect(page.text).to include('3 Seats owed')

        within member_table_selector do
          expect(page.text).to include(user.name)
          expect(page.text).to include(maintainer.name)
          expect(page.text).to include(user_from_sub_group.name)
          expect(page.text).to include(shared_group_developer.name)
          expect(page.text).not_to include(guest.name)
        end
      end
    end
  end

  context 'when adding seats' do
    before do
      visit group_seat_usage_path(group)
      wait_for_requests

      click_button 'Add seats'
    end

    it 'does not open modal', quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24088' do
      expect(page).not_to have_selector('[data-testid="limited-access-modal-id"]')
    end

    context 'when user is allowed to add seats' do
      it 'does not open modal',
        quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24088' do
        expect(page).not_to have_selector('[data-testid="limited-access-modal-id"]')
      end
    end

    context 'when user is not allowed to add seats' do
      before do
        stub_subscription_permissions_data(group.id, can_add_seats: false, can_renew: false)

        visit group_seat_usage_path(group)
        wait_for_requests

        click_button 'Add seats'
      end

      it 'opens limited access modal' do
        expect(page).to have_selector('[data-testid="limited-access-modal-id"]')
        expect(page).to have_content('Changes to subscriptions from GitLab partners require assistance')
      end
    end
  end

  context 'with a public group' do
    let_it_be(:group) { create(:group_with_plan, plan: :free_plan) }

    context 'when on a free plan' do
      before do
        allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |instance|
          allow(instance).to receive(:execute).and_return([{ 'code' => 'free', 'id' => 'free-plan-id' }])
        end

        visit group_seat_usage_path(group)
        wait_for_requests
      end

      it 'has correct `Explore paid plans` link' do
        expect(page).to have_link("Explore paid plans")
      end
    end
  end

  context 'with free user limit' do
    let(:awaiting_user_names) { awaiting_members.map { |m| m.user.name } }
    let(:active_user_names) { active_members.map { |m| m.user.name } }

    let_it_be(:group) { create(:group, :private) }
    let_it_be(:awaiting_members) { create_list(:group_member, 3, :awaiting, source: group) }
    let_it_be(:active_members) { create_list(:group_member, 1, source: group) }

    before do
      stub_ee_application_setting(dashboard_limit_enabled: true)
      stub_ee_application_setting(dashboard_limit: 5)
      allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |instance|
        allow(instance).to receive(:execute).and_return([{ 'code' => 'ultimate', 'id' => 'ultimate-plan-id' }])
      end

      visit group_seat_usage_path(group)
      wait_for_requests
    end

    context 'when on a free plan' do
      it 'has correct seats in use and plans link' do
        expect(page).to have_content("4 / 5 Seats in use / Seats available")
        expect(page).to have_link("Explore plans")
      end
    end

    context 'when on a paid plan' do
      let_it_be(:gitlab_subscription, freeze: false) do
        create(:gitlab_subscription, seats_in_use: 4, seats: 10, namespace: group)
      end

      it 'shows active users' do
        expect(page.text).not_to include(*awaiting_user_names)
        expect(page.text).to include(*active_user_names)
        expect(page).to have_content("4 / 10 Seats in use / Seats in subscription")
      end
    end

    context 'when on a paid expired plan and over limit that is now free' do
      let_it_be(:gitlab_subscription, freeze: false) { create(:gitlab_subscription, :expired, :free, namespace: group) }

      let_it_be(:active_members) do
        create_list(:group_member, 2, source: group)
      end

      it 'shows usage quota alert' do
        expect(page).to have_content('Your free group is now limited to')
        expect(page).to have_link('upgrade')

        find_by_testid('free-group-limited-dismiss').click
        expect(page).not_to have_content('Your free group is now limited to')

        page.refresh
        expect(page).not_to have_content('Your free group is now limited to')
      end
    end

    context 'when on a trial' do
      let_it_be(:gitlab_subscription, freeze: false) do
        create(:gitlab_subscription, :active_trial, seats_in_use: 4, seats: 10, namespace: group)
      end

      it 'shows active users' do
        expect(page.text).not_to include(*awaiting_user_names)
        expect(page.text).to include(*active_user_names)
        expect(page).to have_content("4 / Unlimited Seats in use / Seats in subscription")
      end
    end
  end

  context 'when over storage limit' do
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:active_members) { create_list(:group_member, 3, source: group) }

    before do
      stub_application_setting(check_namespace_plan: true)

      allow_next_found_instance_of(Group) do |instance|
        allow(instance).to receive(:over_storage_limit?).and_return true
      end
    end

    it 'shows active users' do
      visit group_seat_usage_path(group)
      wait_for_requests

      active_user_names =  active_members.map { |m| m.user.name }

      expect(page.text).to include(*active_user_names)
    end
  end

  def billable_member_modal_selector
    '[data-testid="remove-billable-member-modal"]'
  end

  def member_table_selector
    '[data-testid="subscription-users"]'
  end

  def remove_user(user)
    within member_table_selector do
      within find('tr', text: user.name) do
        click_button 'Remove user'
      end
    end
  end

  def confirm_remove_user(user)
    within billable_member_modal_selector do
      find('input').fill_in(with: user.username)
      find('input').send_keys(:tab)

      click_button('Remove user')
    end
  end

  def refresh_subscription_seats
    gitlab_subscription.refresh_seat_attributes
    gitlab_subscription.save!
  end
end
