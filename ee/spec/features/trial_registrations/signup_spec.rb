# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Trial Sign Up', :with_trial_types, :saas_registration, :with_current_organization, feature_category: :acquisition do
  let_it_be(:new_user) { build_stubbed(:user) }

  before do
    stub_saas_features(onboarding: true)
  end

  it 'serves the new trial registration page with the unified two-panel layout' do
    visit new_trial_registration_path

    expect(page).to have_css('.registration-marketing-panel-illustration')
  end

  context 'when email is passed in the path', :js do
    it 'prefills the email form field' do
      visit new_trial_registration_path(email: 'foobar@email.com')

      expect(page).to have_field('Company email', with: 'foobar@email.com')
    end
  end

  context 'with the unavailable username', :js do
    let(:existing_user) { create(:user, :with_namespace) }

    it 'shows the error about existing username' do
      visit new_trial_registration_path

      fill_in 'new_user_username', with: existing_user.username

      expect(page).to have_css('.username .validation-error:not(.hide)',
        text: 'Username is already taken.')
    end
  end

  it_behaves_like 'creates a user with ArkoseLabs risk band' do
    let(:signup_path) { new_trial_registration_path }
    let(:user_email) { new_user.email }
    let(:fill_and_submit_signup_form) do
      fill_in_sign_up_form(new_user)
    end
  end

  context 'when reCAPTCHA is enabled', :js do
    before do
      stub_application_setting(recaptcha_enabled: true)
    end

    context 'when reCAPTCHA verification fails' do
      before do
        allow_next_instance_of(TrialRegistrationsController) do |instance|
          allow(instance).to receive(:verify_recaptcha).and_return(false)
        end
      end

      it 'does not create the user' do
        visit new_trial_registration_path

        expect { fill_in_sign_up_form(new_user) }.not_to change { User.count }
        expect(page).to have_content(_('There was an error with the reCAPTCHA. Please solve the reCAPTCHA again.'))
      end
    end
  end
end
