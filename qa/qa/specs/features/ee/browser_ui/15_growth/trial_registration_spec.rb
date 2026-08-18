# frozen_string_literal: true

module QA
  RSpec.describe "Growth", :requires_admin, feature_category: :acquisition, only: { subdomain: :staging } do
    describe "Trial registration" do
      # Resource::User derives first/last name from `name`; setting them directly is silently ignored.
      # Username/name must match the delete_test_users cleanup criteria (qa-user-* / "QA User") as a
      # fallback in case the example fails before the after hook can delete the user.
      # Staging restricts sign-ups to gitlab.com addresses, so the default example.com domain won't do.
      let(:user) do
        build(:user, :hard_delete,
          name: "QA User Trial",
          username: "qa-user-trial-#{SecureRandom.hex(4)}",
          email_domain: "gitlab.com")
      end

      after do
        user.remove_via_api!
      end

      it "completes the trial registration happy path" do
        Runtime::Browser.visit(:gitlab, EE::Page::Registration::TrialRegistration)

        Page::Registration::SignUp.perform do |sign_up|
          sign_up.register_user(user)
        end

        # Email verification is skipped for the QA user agent on staging
        # (EE::RegistrationsController#bypass_email_confirmation_for_qa?)
        EE::Page::Registration::TrialWelcome.perform do |welcome|
          expect(welcome).to have_continue_button(wait: 30),
            "Expected the trial welcome form, but was on #{welcome.current_url}"
        end
      end
    end
  end
end
