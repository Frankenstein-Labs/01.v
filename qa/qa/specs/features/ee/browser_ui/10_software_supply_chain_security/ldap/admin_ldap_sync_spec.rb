# frozen_string_literal: true

module QA
  RSpec.describe 'Software Supply Chain Security', :orchestrated, :ldap_no_server, feature_category: :system_access do
    describe 'LDAP admin sync' do
      before do
        run_ldap_service_with_user_as('admin')

        Runtime::Browser.visit(:gitlab, Page::Main::Login)

        login_with_ldap_admin_user
      end

      after do
        remove_ldap_service_with_user_as('non_admin')
      end

      it 'sets and removes user\'s admin status',
        quarantine: {
          issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24039',
          type: :investigating
        } do
        Page::Main::Menu.perform do |menu|
          admin_synchronised = menu.wait_until(max_duration: 80, sleep_interval: 1, reload: true) do
            menu.has_admin_area_link?(wait: 0)
          end

          expect(admin_synchronised).to be_truthy
        end

        remove_ldap_service_with_user_as('admin')

        run_ldap_service_with_user_as('non_admin')

        login_with_ldap_admin_user

        Page::Main::Menu.perform do |menu|
          admin_removed = menu.wait_until(max_duration: 160, sleep_interval: 1, reload: true) do
            !menu.has_admin_area_link?(wait: 0)
          end

          expect(admin_removed).to be_truthy
        end
      end

      def run_ldap_service_with_user_as(user_status)
        Service::DockerRun::LDAP.new(user_status).tap do |runner|
          runner.pull
          runner.register!
        end
      end

      def remove_ldap_service_with_user_as(user_status)
        Service::DockerRun::LDAP.new(user_status).remove!
      end

      def login_with_ldap_admin_user
        Page::Main::Login.perform do |login_page|
          user = Struct.new(:username, :password).new('adminuser1', 'password')

          QA::Support::Retrier.retry_until(raise_on_failure: true, sleep_interval: 3, max_attempts: 5) do
            login_page.sign_in_using_ldap_credentials(user: user)
          end
        end
      end
    end
  end
end
