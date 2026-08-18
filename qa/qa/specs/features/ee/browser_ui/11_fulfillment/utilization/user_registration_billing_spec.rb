# frozen_string_literal: true

module QA
  RSpec.describe 'Fulfillment',
    :requires_admin,
    :skip_live_env,
    feature_category: :consumables_cost_management,
    quarantine: {
      issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/work_items/19015',
      type: :flaky
    } do
    describe 'Utilization' do
      describe 'User Registration' do
        let!(:group) { create(:group) }

        let(:user) do
          build(:user,
            :hard_delete,
            first_name: 'QA',
            last_name: 'Test',
            username: "qa-test-#{SecureRandom.hex(3)}")
        end

        before do
          # Enable sign-ups
          Runtime::ApplicationSettings.set_application_settings(signup_enabled: true)
          Runtime::ApplicationSettings.set_application_settings(require_admin_approval_after_user_signup: true)

          # Wait for the setting to propagate.
          # The user's blocked_pending_approval state is set at registration time based on
          # this setting, so it must be active before the user registers.
          # See https://gitlab.com/gitlab-org/gitlab/-/issues/603412
          #
          Support::Waiter.wait_until(
            max_duration: 15,
            sleep_interval: 1,
            message: 'Waiting for require_admin_approval_after_user_signup setting to propagate'
          ) do
            Runtime::ApplicationSettings.get_application_setting(:require_admin_approval_after_user_signup) == true
          end

          Runtime::Browser.visit(:gitlab, Page::Registration::SignUp)

          # Register the new user through the registration page
          Page::Registration::SignUp.perform do |sign_up|
            sign_up.register_user(user)
          end

          Flow::UserOnboarding.onboard_user
        end

        after do
          # Restore what the signup_enabled setting was before this test was run
          Runtime::ApplicationSettings.restore_application_settings(:signup_enabled)
        end

        context 'when adding and removing a group member' do
          it 'consumes a seat on the license' do
            Flow::Login.sign_in_as_admin

            Runtime::Browser.visit(:gitlab, EE::Page::Admin::Subscription)

            # Save the number of users as stated by the license
            # and sanitize the value when returned as 10,000
            users_in_subscription = EE::Page::Admin::Subscription.perform(&:users_in_subscription).tr(',', '')

            Runtime::Browser.visit(:gitlab, EE::Page::Admin::Dashboard)

            # Save the number of users active on the instance as reported by GitLab
            # and sanitize the value when returned as 10,000
            users_in_license = EE::Page::Admin::Dashboard.perform(&:users_in_license).tr(',', '')

            expect(users_in_subscription).to eq(users_in_license)

            billable_users = EE::Page::Admin::Dashboard.perform(&:billable_users)

            # Activate the new user
            user.reload! && user.approve! # first reload the API resource to fetch the ID, then approve

            EE::Page::Admin::Dashboard.perform do |dashboard|
              dashboard.refresh

              # Validate billable users has not changed after approval
              expect(dashboard.billable_users).to eq(billable_users)

              group.add_member(user) # add the user to the group

              dashboard.refresh

              # Validate billable users incremented by 1
              expect(dashboard.billable_users.to_i).to eq(billable_users.to_i + 1)

              group.remove_member(user) # remove the user from the group

              dashboard.refresh

              # Validate billable users equals the original amount
              expect(dashboard.billable_users).to eq(billable_users)
            end
          end
        end
      end
    end
  end
end
