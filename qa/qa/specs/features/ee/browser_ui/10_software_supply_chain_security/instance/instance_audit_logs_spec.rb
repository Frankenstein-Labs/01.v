# frozen_string_literal: true

module QA
  # Issue to enable this test in live environments: https://gitlab.com/gitlab-org/quality/team-tasks/-/issues/614
  RSpec.describe 'Software Supply Chain Security', :skip_live_env, feature_category: :compliance_management do
    describe 'Instance', :requires_admin do
      context 'for change password', :skip_signup_disabled do
        before do
          user = create(:user, username: "user_#{SecureRandom.hex(4)}", password: "pw_#{SecureRandom.hex(4)}")

          Runtime::Browser.visit(:gitlab, Page::Main::Login)

          Page::Main::Login.perform do |login_page|
            login_page.sign_in_using_credentials(user: user)
          end

          Page::Main::Menu.perform(&:click_edit_profile_link)
          Page::Profile::Menu.perform(&:click_password_and_authentication)
          Page::Profile::PasswordAndAuth.perform(&:click_change_password)
          Page::Profile::Password.perform do |password_page|
            password_page.update_password('new_password', user.password)
          end
          sign_in
        end

        it 'logs audit events for UI operations' do
          Page::Main::Menu.perform(&:go_to_admin_area)
          QA::Page::Admin::Menu.perform(&:go_to_monitoring_audit_events)
          EE::Page::Admin::Monitoring::AuditLog.perform do |audit_log_page|
            expect(audit_log_page).to have_audit_log_table_with_text("Changed password")
          end
        end
      end

      context 'for start and stop user impersonation' do
        let!(:user_for_impersonation) { create(:user) }

        before do
          sign_in
          Page::Main::Menu.perform(&:go_to_admin_area)
          Page::Admin::Menu.perform(&:go_to_users_overview)
          Page::Admin::Overview::Users::Index.perform do |index|
            index.choose_search_user(user_for_impersonation.username)
            index.click_search
            index.click_user(user_for_impersonation.name)
          end

          Page::Admin::Overview::Users::Show.perform(&:click_impersonate_user)

          Page::Main::Menu.perform(&:stop_impersonation)
        end

        it 'logs audit events for impersonation operations', quarantine: {
          issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/16384',
          type: :flaky
        } do
          Page::Main::Menu.perform(&:go_to_admin_area)
          QA::Page::Admin::Menu.perform(&:go_to_monitoring_audit_events)
          EE::Page::Admin::Monitoring::AuditLog.perform do |audit_log_page|
            ["Started Impersonation", "Stopped Impersonation"].each do |expected_event|
              expect(audit_log_page).to have_audit_log_table_with_text(expected_event)
            end
          end
        end
      end

      def sign_in
        Page::Main::Menu.perform(&:sign_out_if_signed_in)
        Runtime::Browser.visit(:gitlab, Page::Main::Login)
        Page::Main::Login.perform(&:sign_in_using_admin_credentials)
      end
    end
  end
end
