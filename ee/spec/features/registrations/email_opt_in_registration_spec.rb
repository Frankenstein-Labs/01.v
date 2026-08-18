# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Registration with the email opt in value', :js, :saas_registration, :with_current_organization,
  feature_category: :onboarding do
  it 'renders the trial registration form inside the unified two-panel layout' do
    visit new_trial_registration_path

    expect(page).to have_css('.registration-marketing-panel-illustration')
  end

  it 'completes a password based trial sign up through the two-panel layout' do
    expect_to_receive_trial_duration

    visit new_trial_registration_path

    expect(page).to have_css('.registration-marketing-panel-illustration')

    user_signs_up_through_registration

    created_user = User.find_by(email: user_email)
    expect(created_user).to be_present
    expect(created_user.onboarding_status_initial_registration_type).to eq('trial')
    expect(created_user.onboarding_status_email_opt_in).to be(true)
  end

  context 'for regular registration' do
    include IdentityVerificationHelpers

    let_it_be(:new_user) { build_stubbed(:user) }

    shared_examples 'toggles email opt-in checkbox', :with_trial_types do
      it 'toggles the omniauth form actions' do
        visit path

        expect_all_email_opt_in_to_be(true)

        within('body.page-initialised') do
          uncheck email_opt_in_text
        end

        expect_all_email_opt_in_to_be(false)

        check email_opt_in_text

        expect_all_email_opt_in_to_be(true)
      end

      context 'for password based sign up' do
        it 'creates the user with the default email opt in value' do
          sign_up_method.call

          expect(page).to have_title(welcome_title)
          expect(user.onboarding_status_email_opt_in).to be(true)
        end
      end

      context 'for omniauth registration' do
        it 'creates the user with email opt in as false' do
          with_omniauth_full_host do
            user_signs_up_with_sso do
              visit path

              within('body.page-initialised') do
                uncheck email_opt_in_text
              end
            end

            expect_to_see_identity_verification_page
          end

          expect(user.onboarding_status_email_opt_in).to be(false)
        end

        it 'creates the user with the default email opt in value' do
          with_omniauth_full_host do
            user_signs_up_with_sso do
              visit path
            end

            expect_to_see_identity_verification_page
          end

          expect(user.onboarding_status_email_opt_in).to be(true)
        end
      end

      context 'when submission fails on password based sign up' do
        it 'remembers the submitted email opt in value' do
          new_user = build_stubbed(:user)
          create(:user, email: new_user.email)
          visit path

          fill_in_sign_up_form(new_user) do
            within('body.page-initialised') do
              uncheck email_opt_in_text
            end
          end

          expect(page).to have_current_path create_path, ignore_query: true
          expect_all_email_opt_in_to_be(false)
        end
      end

      def email_opt_in_text
        _(
          'I agree that GitLab can contact me by email ' \
            'about its product, services, or events.'
        )
      end

      def expect_all_email_opt_in_to_be(value)
        expect(
          page.all('form.js-omniauth-form').any? do |item|
            item['action'].include?("onboarding_status_email_opt_in=#{value}")
          end
        ).to be true
      end
    end

    it_behaves_like 'toggles email opt-in checkbox' do
      let(:path) { new_user_registration_path }
      let(:sign_up_method) { -> { regular_sign_up } }
      let(:create_path) { user_registration_path }
      let(:welcome_title) { _('Welcome') }
    end
  end
end
