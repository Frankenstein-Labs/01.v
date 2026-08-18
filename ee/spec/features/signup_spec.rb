# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Signup on EE', :with_current_organization, :js, feature_category: :instance_resiliency do
  include IdentityVerificationHelpers

  # Make sure duo_code_review_bot is seeded before tests run to avoid
  # flaky tests when testing signups.
  seed_internal_bot(:duo_code_review_bot)

  let(:new_user) { build_stubbed(:user) }

  before do
    stub_application_setting(require_admin_approval_after_user_signup: false)
    allow(::AntiAbuse::IdentityVerification::Settings).to receive(:arkose_enabled?).and_return(false)
  end

  context 'for SaaS', :saas do
    before do
      stub_ee_application_setting(should_check_namespace_plan: true)
      visit new_user_registration_path
    end

    it 'allows visiting of a page after initial registration',
      quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/7295' do
      fill_in_sign_up_form(new_user)

      visit new_project_path

      expect(page).to have_current_path(users_sign_up_welcome_path)

      select 'Software Developer', from: 'user_onboarding_status_role'
      choose 'user_onboarding_status_setup_for_company_true'
      choose 'Join an existing project'
      click_button 'Continue'
      user = User.find_by_username(new_user[:username])

      expect(user.onboarding_status_role_name).to eq('software_developer')
      expect(user.onboarding_status_setup_for_company).to be_truthy
    end
  end

  describe 'password complexity', :js do
    let(:path_to_visit) { new_user_registration_path }
    let(:password_input_selector) { :new_user_password }

    it_behaves_like 'password complexity validations' do
      let(:submit_button_selector) { _('Continue') }
      let(:basic_rules) { [:length, :common, :user_info] }
    end

    context 'when all password complexity rules are enabled' do
      include_context 'with all password complexity rules enabled'

      context 'when all rules are matched' do
        let(:password) { '12345aA.' }

        it 'creates the user' do
          visit path_to_visit

          expect do
            fill_in_sign_up_form(new_user) do
              fill_in password_input_selector, with: password

              expect_password_to_be_validated
            end

            wait_for_user_to_be_created(new_user.email)
          end.to change { User.count }.by(1)
        end
      end
    end
  end

  context 'when reCAPTCHA is enabled' do
    before do
      stub_application_setting(recaptcha_enabled: true)
    end

    it 'creates the user' do
      visit new_user_registration_path

      expect do
        fill_in_sign_up_form(new_user)
        wait_for_user_to_be_created(new_user.email)
      end.to change { User.count }
    end

    context 'when reCAPTCHA verification fails' do
      before do
        allow_next_instance_of(RegistrationsController) do |instance|
          allow(instance).to receive(:verify_recaptcha).and_return(false)
        end
      end

      it 'does not create the user' do
        visit new_user_registration_path

        expect { fill_in_sign_up_form(new_user) }.not_to change { User.count }
        expect(page).to have_content(_('There was an error with the reCAPTCHA. Please solve the reCAPTCHA again.'))
      end
    end
  end

  it_behaves_like 'creates a user with ArkoseLabs risk band' do
    let(:signup_path) { new_user_registration_path }
    let(:user_email) { new_user[:email] }

    subject(:fill_and_submit_signup_form) do
      fill_in_sign_up_form(new_user)
    end
  end
end
