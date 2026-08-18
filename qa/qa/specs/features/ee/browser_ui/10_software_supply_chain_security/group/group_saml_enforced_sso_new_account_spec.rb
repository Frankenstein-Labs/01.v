# frozen_string_literal: true

module QA
  RSpec.describe 'Software Supply Chain Security', :group_saml, :orchestrated, feature_category: :compliance_management,
    requires_admin: 'for various user admin functions' do
    describe 'Group SAML SSO - Enforced SSO' do
      include Support::API

      let!(:group) { create(:sandbox, :private, path: "saml_sso_group_#{SecureRandom.hex(8)}") }
      let!(:saml_idp_service) { Flow::Saml.run_saml_idp_service(group.path, [idp_user]) }
      let!(:group_sso_url) { Flow::Saml.enable_saml_sso(group, saml_idp_service, enforce_sso: true) }

      let(:idp_user) { build(:user, username: "saml_user_#{Faker::Number.number(digits: 8)}") }

      before do
        Page::Main::Menu.perform(&:sign_out_if_signed_in)

        Flow::Saml.logout_from_idp(saml_idp_service)
      end

      shared_examples 'group membership actions' do
        it 'creates a new account automatically and allows to leave group and join again' do
          # When the user signs in via IDP for the first time

          group.visit!

          EE::Page::Group::SamlSSOSignIn.perform(&:click_sign_in)

          Flow::Saml.login_to_idp_if_required(idp_user.username, idp_user.password)

          expect(page).to have_text("Signed in with SAML")

          Page::Group::Show.perform(&:leave_group)

          expect(page).to have_text("You left")

          Page::Main::Menu.perform(&:sign_out)

          Flow::Saml.logout_from_idp(saml_idp_service)

          # When the user exists with a linked identity

          visit_group_sso_url

          EE::Page::Group::SamlSSOSignIn.perform(&:click_sign_in)

          Flow::Saml.login_to_idp_if_required(idp_user.username, idp_user.password)

          expect(page).to have_text(
            "Sign in with your existing credentials to connect your organization's account"
          )

          Flow::Saml.logout_from_idp(saml_idp_service)

          # When the user is removed and so their linked identity is also removed

          remove_user(idp_user)

          visit_group_sso_url

          EE::Page::Group::SamlSSOSignIn.perform(&:click_sign_in)

          Flow::Saml.login_to_idp_if_required(idp_user.username, idp_user.password)

          expect(page).to have_text("Signed in with SAML")
        end
      end

      after do
        Flow::Saml.remove_saml_idp_service(saml_idp_service)
      end

      context 'with Snowplow tracking enabled' do
        before do
          Flow::Settings.enable_snowplow
        end

        after do
          Flow::Settings.disable_snowplow
        end

        it_behaves_like 'group membership actions'
      end

      context 'with Snowplow tracking disabled' do
        before do
          Flow::Settings.disable_snowplow
        end

        it_behaves_like 'group membership actions'
      end
    end

    private

    def remove_user(user)
      user.reload!
      user.remove_via_api!
      Support::Waiter.wait_until(max_duration: 180, retry_on_exception: true, sleep_interval: 3) { !user.exists? }
    end

    def visit_group_sso_url
      Runtime::Logger.info(%(Visiting managed_group_url at "#{group_sso_url}"))

      page.visit group_sso_url
      Support::Waiter.wait_until { current_url == group_sso_url }
    end
  end
end
