# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin::Users', :with_current_organization, feature_category: :user_profile do
  include Features::AdminUsersHelpers
  include Spec::Support::Helpers::ModalHelpers

  let_it_be(:admin) { create(:admin) }
  let(:user) { create(:user) }

  before do
    sign_in(admin)
    enable_admin_mode!(admin)
  end

  describe 'GET /admin/users/edit' do
    let(:path_to_visit) { edit_admin_user_path(user) }
    let(:submit_button_selector) { _('Save changes') }

    describe 'password complexity', :js do
      let(:password_input_selector) { :user_password }

      it 'does not render any rule' do
        visit path_to_visit

        expect(page).not_to have_selector('[data-testid="password-rule-text"]')
      end

      context 'when all password complexity rules are enabled' do
        include_context 'with all password complexity rules enabled'
        let(:password) { '12345aA.' }

        it 'updates user password' do
          visit path_to_visit

          expect(page).to have_selector('[data-testid="password-rule-text"]', count: 0)

          fill_in :user_password, with: password
          fill_in :user_password_confirmation, with: password

          expect(page).to have_selector('[data-testid="password-rule-text"]', count: 4)

          click_button submit_button_selector

          expect(page).to have_content(_('User was successfully updated.'))
          expect(page).to have_current_path(admin_user_path(user), ignore_query: true)
        end

        context 'without filling password' do
          let(:new_user_name) { FFaker::Name.name }

          it 'allows admin to update user info' do
            visit path_to_visit

            expect(page).to have_selector('[data-testid="password-rule-text"]', count: 0)

            fill_in 'user_name', with: new_user_name
            click_button submit_button_selector

            expect(page).to have_content(_('User was successfully updated.'))
            expect(page).to have_content(new_user_name)
            expect(page).to have_current_path(admin_user_path(user), ignore_query: true)
          end
        end
      end
    end

    describe 'editing custom attributes' do
      let!(:custom_attribute) do
        create(:user_custom_attribute,
          key: attribute,
          value: Arkose::VerifyResponse::RISK_BAND_MEDIUM,
          user: user
        )
      end

      context 'when user has a non-editable custom attribute' do
        let(:attribute) { 'bread_provider' }

        it 'does not allow the admin to update the custom attribute' do
          visit path_to_visit

          expect(page).to have_selector('#user_custom_attributes_attributes_0_value', count: 0)
        end
      end

      context 'when user has an editable custom attribute' do
        let(:attribute) { UserCustomAttribute::ARKOSE_RISK_BAND }

        it 'allows the admin to update the custom attribute' do
          visit path_to_visit
          select(Arkose::VerifyResponse::RISK_BAND_LOW, from: UserCustomAttribute::ARKOSE_RISK_BAND.humanize)
          click_button submit_button_selector

          expect(page).to have_content(_('User was successfully updated.'))
          expect(page).to have_content(Arkose::VerifyResponse::RISK_BAND_LOW)
        end
      end
    end

    describe 'admin role assignment' do
      let_it_be(:admin_role) { create(:member_role, :admin) }

      context 'when custom roles is not licensed' do
        it 'does not show admin roles dropdown' do
          visit path_to_visit

          expect(page).not_to have_content('Access summary for Regular user')
        end
      end

      context 'when custom roles is licensed' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        it 'allows the admin to assign and unassign an admin role', :js do
          visit path_to_visit

          expect(page).to have_content('Access summary for Regular user')

          within_testid('admin-role-dropdown') do
            find_by_testid('base-dropdown-toggle').click
            within_testid('base-dropdown-menu') do
              find('.gl-new-dropdown-item', text: admin_role.name).click
            end
          end

          click_button submit_button_selector

          expect(page).to have_content(_('User was successfully updated.'))

          # reload the page to make sure we have correct data
          visit path_to_visit

          within_testid('admin-role-dropdown') do
            expect(find_by_testid('base-dropdown-toggle')).to have_content(admin_role.name)

            find_by_testid('base-dropdown-toggle').click
            within_testid('base-dropdown-menu') do
              find('.gl-new-dropdown-item', text: 'No access').click
            end
          end

          click_button submit_button_selector

          expect(page).to have_content(_('User was successfully updated.'))
        end
      end
    end
  end

  describe 'GET /admin/users/new', :js do
    def fill_in_new_user_form
      fill_in 'user_name', with: 'Big Bang'
      fill_in 'user_username', with: 'bang'
      fill_in 'user_email', with: 'bigbang@mail.com'
    end

    def create_new_user(fails: false)
      visit new_admin_user_path
      fill_in_new_user_form
      perform_enqueued_jobs do
        click_button 'Create user'

        if fails # rubocop:disable RSpec/AvoidConditionalStatements -- this is a helper method
          expect(page).to have_current_path(admin_users_path)
        else
          expect(page).to have_current_path(admin_user_path('bang'))
        end
      end
    end

    context 'with a user cap set' do
      before do
        stub_application_setting(new_user_signups_cap: 2)
        stub_ee_application_setting(seat_control: ::ApplicationSetting::SEAT_CONTROL_USER_CAP)
      end

      context 'when the cap has not been reached' do
        it 'sends only a welcome email to the user', :sidekiq_inline do
          create_new_user

          welcome_email = ActionMailer::Base.deliveries.last
          expect(welcome_email.to).to eq(['bigbang@mail.com'])
          expect(welcome_email.subject).to eq('Account was created for you')
          expect(welcome_email.text_part.body).to have_content('Click here to set your password')

          expect(ActionMailer::Base.deliveries.count).to eq(1)
        end
      end

      context 'when the cap has been reached' do
        before do
          user
        end

        it 'sends only a notification email to the admin', :sidekiq_inline do
          create_new_user

          email = ActionMailer::Base.deliveries.last
          expect(email.to).to eq([admin.email])
          expect(email.subject).to eq('Important information about usage on your GitLab instance')
          expect(email.text_part.body).to have_content('Your GitLab instance has reached the maximum allowed user cap')

          expect(ActionMailer::Base.deliveries.count).to eq(1)
        end
      end
    end

    context 'when generating overages' do
      before do
        create_current_license(plan: License::PREMIUM_PLAN, seats: 1)
      end

      it 'creates a new user' do
        create_new_user

        expect(page).to have_content('User was successfully created.')
      end

      context 'when block seat overages is active' do
        before do
          stub_ee_application_setting(seat_control: ::ApplicationSetting::SEAT_CONTROL_BLOCK_OVERAGES)
        end

        it 'shows an error' do
          create_new_user(fails: true)

          expect(page).to have_content('You have used all seats in your subscription, so you cannot add new users.')
        end
      end
    end
  end

  describe 'GET /admin/users/:id/projects' do
    before do
      visit projects_admin_user_path(minimal_user)
    end

    context "when user has minimal access role in a group" do
      let_it_be(:minimal_user) { create(:user) }
      let_it_be(:group) { create(:group) }
      let_it_be(:minimal_access) { create(:group_member, :minimal_access, user: minimal_user, group: group) }

      it 'lists minimal access groups' do
        within('#groups') do
          expect(page).to have_content('Groups 1')
          expect(page).to have_content 'Minimal Access'
          expect(page).to have_link group.name, href: admin_group_path(group)
        end
      end
    end
  end
end
