# frozen_string_literal: true

RSpec.shared_examples 'GitLab Duo administration' do
  include SubscriptionPortalHelpers
  include Features::HandRaiseLeadHelpers

  let_it_be(:user, freeze: false) { create(:user, :with_namespace, company: 'YMCA') }
  let_it_be(:group, freeze: false) { create(:group_with_plan, plan: :premium_plan, owners: user) }

  before do
    stub_signing_key
    stub_application_setting(check_namespace_plan: true)
    stub_subscription_permissions_data(group.id)
    stub_licensed_features(code_suggestions: true)

    sign_in(user)

    visit duo_page

    wait_for_all_requests
  end

  context 'when bulk assign and unassign duo pro seats' do
    let_it_be_with_reload(:add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, :duo_pro, quantity: 10, namespace: group)
    end

    context 'when user is owner' do
      before_all do
        group.add_developer(create(:user, username: 'developer_1'))
        group.add_developer(create(:user, username: 'developer_2'))
        group.add_developer(create(:user, username: 'developer_3'))
      end

      context 'when bulk assigning seats' do
        context 'when success' do
          it 'assigns the selected users' do
            expect(add_on_purchase.assigned_users.size).to eq(0)

            find_by_testid('select-all-users').click
            expect(find_by_testid('select-all-users')).to be_checked

            expect(page).to have_content('Assign seat')
            find_by_testid('assign-seats-button').click
            expect(page).to have_content('Confirm bulk seat assignment')
            action_text = 'This action will assign a GitLab Duo seat to 4 users. Are you sure you want to continue?'
            expect(page).to have_content(action_text)

            find_by_testid('assign-confirmation-button').click
            wait_for_requests

            expect(page).to have_content('4 users have been successfully assigned seats.')
            expect(add_on_purchase.reload.assigned_users.size).to eq(4)
          end
        end

        context 'when failed' do
          before_all do
            add_on_purchase.update!(quantity: 1)
          end

          it 'assigns the selected users' do
            expect(add_on_purchase.assigned_users).to eq([])

            find_by_testid('select-all-users').click
            expect(find_by_testid('select-all-users')).to be_checked

            find_by_testid('assign-seats-button').click

            find_by_testid('assign-confirmation-button').click
            wait_for_requests

            expect(page).to have_content('There are not enough seats to assign the GitLab Duo add-on')
            expect(add_on_purchase.reload.assigned_users).to eq([])
          end
        end
      end

      context 'when bulk unassigning seats' do
        let_it_be(:users, freeze: false) { create_list(:user, 3) }

        before_all do
          users.each do |user|
            group.add_developer(user)
            create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user)
          end
        end

        it 'unassigns the selected users' do
          expect(add_on_purchase.reload.assigned_users.map(&:user)).to eq(users)

          find_by_testid('select-all-users').click
          expect(find_by_testid('select-all-users')).to be_checked

          expect(page).to have_content('Remove seat')
          find_by_testid('unassign-seats-button').click
          expect(page).to have_content('Confirm bulk seat removal')
          action_text = 'This action will remove GitLab Duo seats from 7 users. Are you sure you want to continue?'
          expect(page).to have_content(action_text)

          find_by_testid('unassign-confirmation-button').click
          wait_for_requests

          expect(page).to have_content('7 users have been successfully unassigned a seat.')
          expect(add_on_purchase.reload.assigned_users).to eq([])
        end
      end
    end
  end
end
