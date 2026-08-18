# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Identity Verification', :with_trial_types, :js, :with_current_organization, feature_category: :instance_resiliency do
  include IdentityVerificationHelpers

  before do
    stub_saas_features(identity_verification: true)
    stub_application_setting_enum('email_confirmation_setting', 'hard')
    stub_application_setting(
      require_admin_approval_after_user_signup: false,
      arkose_labs_public_api_key: 'public_key',
      arkose_labs_private_api_key: 'private_key',
      telesign_customer_xid: 'customer_id',
      telesign_api_key: 'private_key'
    )
  end

  let(:user_email) { 'onboardinguser@example.com' }
  let(:new_user) { build(:user, email: user_email) }
  let(:user) { User.find_by_email(user_email) }

  describe 'Trial flow with unified registration', :saas do
    before do
      stub_saas_features(onboarding: true)

      visit new_trial_registration_path
    end

    it 'serves the trial identity verification page within the unified two-panel layout' do
      sign_up(flow: :trial, arkose: { risk: :low })

      expect_to_see_identity_verification_page

      expect(page).to have_css('.registration-marketing-panel-illustration')
    end
  end

  shared_examples 'does not allow unauthorized access to verification endpoints' do |protected_endpoints|
    # Normally, users cannot trigger requests to endpoints of verification
    # methods in later steps by only using the UI (e.g. if the current step is
    # email verification, phone and credit card steps cannot be interacted
    # with). However, there is nothing stopping users from manually or
    # programatically sending requests to these endpoints.
    #
    # This spec ensures that only the endpoints of the verification method in
    # the current step are accessible to the user regardless of the way the
    # request is sent.
    #
    # Note: SAML flow is skipped as the signin process is more involved which
    # makes the test unnecessarily complex.

    def send_request(session, method, path, headers:)
      session.public_send(method, path, headers: headers, xhr: true, as: :json)
    end

    it 'returns 400 for unauthorized verification endpoints',
      quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/449030' do
      session = ActionDispatch::Integration::Session.new(Rails.application)

      # sign in
      session.post user_session_path, params: { user: { login: new_user.username, password: new_user.password } }

      # visit identity verification page
      session.get signup_identity_verification_path

      # extract CSRF token
      body = session.response.body
      html = Nokogiri::HTML.parse(body)
      csrf_token = html.at("meta[name=csrf-token]")['content']

      headers = { 'X-CSRF-Token' => csrf_token }

      phone_send_code_path = send_phone_verification_code_signup_identity_verification_path
      phone_verify_code_path = verify_phone_verification_code_signup_identity_verification_path
      credit_card_verify_captcha_path = verify_credit_card_captcha_signup_identity_verification_path

      verification_endpoint_requests = {
        phone: [
          -> { send_request(session, :post, phone_send_code_path, headers: headers) },
          -> { send_request(session, :post, phone_verify_code_path, headers: headers) }
        ],
        credit_card: [
          -> { send_request(session, :post, credit_card_verify_captcha_path, headers: headers) }
        ]
      }

      protected_endpoints.each do |e|
        verification_endpoint_requests[e].each do |request_lambda|
          expect(request_lambda.call).to eq 400
        end
      end
    end
  end

  shared_examples 'registering a user with identity verification when risk is unavailable' do |flow: :standard|
    include_examples 'registering a low risk user with identity verification', flow: flow, risk: :unavailable
  end

  shared_examples 'registering a low risk user with identity verification' do |flow: :standard, risk: :low|
    before do
      sign_up(flow: flow, arkose: { risk: risk })
    end

    it 'verifies the user' do
      expect_to_see_identity_verification_page

      verify_email

      expect_verification_completed

      expect_to_see_dashboard_page
    end

    unless flow == :saml
      describe 'access to verification endpoints' do
        it_behaves_like 'does not allow unauthorized access to verification endpoints', [:phone, :credit_card]
      end
    end
  end

  # Flow/risk-agnostic, so exercised once. Empty and invalid-format codes are client-side
  # validations covered by ee/spec/frontend/users/identity_verification/components/email_verification_spec.js.
  shared_examples 'email verification code error handling' do
    before do
      sign_up(flow: :standard, arkose: { risk: :low })
    end

    context 'when the verification code has expired' do
      before do
        travel (Users::EmailVerification::ValidateTokenService::TOKEN_VALID_FOR_MINUTES + 1).minutes
      end

      it 'shows error message',
        quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/449030' do
        verify_code(email_verification_code)

        expect(page).to have_content(s_('IdentityVerification|The code has expired. Send a new code and try again.'))
      end
    end

    context 'when the verification code is incorrect' do
      it 'shows error message' do
        verify_code('000000')

        expect(page).to have_content(
          s_('IdentityVerification|The code is incorrect. Enter it again, or send a new code.')
        )
      end
    end

    context 'when user requests a new code' do
      it 'resends a new code' do
        click_link 'Send a new code'

        expect(page).to have_content(s_('IdentityVerification|A new code has been sent.'))
      end
    end
  end

  shared_examples 'registering a medium risk user with identity verification' do
    |flow: :standard, skip_email_validation: false|

    before do
      sign_up(flow: flow, arkose: { risk: :medium, challenge_shown: true })
    end

    it 'verifies the user' do
      expect_to_see_identity_verification_page

      verify_email unless skip_email_validation

      verify_phone_number(solve_arkose_challenge: true)

      expect_verification_completed

      expect_to_see_dashboard_page
    end

    context 'when the user requests a phone verification exemption' do
      it 'verifies the user' do
        expect_to_see_identity_verification_page

        verify_email unless skip_email_validation

        request_phone_exemption

        solve_arkose_verify_challenge

        verify_credit_card

        # verify_credit_card creates a credit_card verification record &
        # refreshes the page. This causes an automatic redirect to the welcome
        # page, skipping the verification successful badge, and preventing us
        # from calling expect_verification_completed

        expect_to_see_dashboard_page
      end
    end

    unless flow == :saml
      describe 'access to verification endpoints' do
        it_behaves_like 'does not allow unauthorized access to verification endpoints', [:credit_card]

        context 'when all prerequisite verification methods have not been completed' do
          unless skip_email_validation
            it_behaves_like 'does not allow unauthorized access to verification endpoints', [:phone]
          end
        end
      end
    end
  end

  shared_examples 'registering a high risk user with identity verification' do
    |flow: :standard, skip_email_validation: false|

    before do
      sign_up(flow: flow, arkose: { risk: :high })
    end

    it 'verifies the user' do
      expect_to_see_identity_verification_page

      verify_email unless skip_email_validation

      verify_phone_number(solve_arkose_challenge: true)

      verify_credit_card

      expect_to_see_dashboard_page
    end

    context 'and the user has a phone verification exemption' do
      it 'verifies the user',
        quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/449030' do
        user.add_phone_number_verification_exemption

        expect_to_see_identity_verification_page

        verify_email unless skip_email_validation

        solve_arkose_verify_challenge

        verify_credit_card

        # verify_credit_card creates a credit_card verification record &
        # refreshes the page. This causes an automatic redirect to the welcome
        # page, skipping the verification successful badge, and preventing us
        # from calling expect_verification_completed

        expect_to_see_dashboard_page
      end
    end

    unless flow == :saml
      describe 'access to verification endpoints' do
        context 'when all prerequisite verification methods have been completed' do
          before do
            verify_email unless skip_email_validation

            verify_phone_number(solve_arkose_challenge: true)
          end

          it_behaves_like 'does not allow unauthorized access to verification endpoints', [:phone]
        end

        context 'when some prerequisite verification methods have not been completed' do
          before do
            verify_email unless skip_email_validation
          end

          it_behaves_like 'does not allow unauthorized access to verification endpoints', [:credit_card]
        end

        context 'when all prerequisite verification methods have not been completed' do
          it_behaves_like 'does not allow unauthorized access to verification endpoints', [:credit_card]
        end
      end
    end
  end

  shared_examples 'allows the user to complete registration' do |flow:|
    if flow == :invite
      specify do
        expect(page).to have_current_path(group_path(invitation.group))
        expect(page).to have_content(
          "You have been granted access to the #{invitation.group.name} group with the following role: Developer."
        )
      end
    else
      specify 'completes identity verification and reaches dashboard',
        quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/449030' do
        expect_to_see_identity_verification_page

        verify_email

        expect_verification_completed

        expect_to_see_dashboard_page
      end
    end
  end

  shared_examples 'allows the user to complete registration when Arkose is unavailable' do |flow: :standard|
    context 'when Arkose is disabled via application setting' do
      before do
        stub_application_setting(arkose_labs_enabled: false)
        sign_up(flow: flow, arkose: { disable: true })
      end

      it_behaves_like 'allows the user to complete registration', flow: flow
    end

    context 'when Arkose is down' do
      before do
        sign_up(flow: flow, arkose: { token_verification_response: :failed, service_down: true })
      end

      it_behaves_like 'allows the user to complete registration', flow: flow
    end

    context 'when unable to connect to Arkose' do
      before do
        allow(Gitlab::HTTP).to receive(:perform_request).and_raise(Errno::ECONNREFUSED.new('bad connection'))
        sign_up(flow: flow, arkose: {})
      end

      it_behaves_like 'allows the user to complete registration', flow: flow
    end

    context 'when Arkose returns an unknown client error' do
      before do
        sign_up(flow: flow, arkose: { token_verification_response: :error })
      end

      it_behaves_like 'allows the user to complete registration', flow: flow
    end
  end

  describe 'Standard flow' do
    before do
      visit new_user_registration_path
    end

    context 'when Arkose is up' do
      it_behaves_like 'registering a user with identity verification when risk is unavailable'
      it_behaves_like 'registering a low risk user with identity verification'
      it_behaves_like 'registering a medium risk user with identity verification'
      it_behaves_like 'registering a high risk user with identity verification'

      it_behaves_like 'email verification code error handling'
    end

    it_behaves_like 'allows the user to complete registration when Arkose is unavailable'
  end

  describe 'Invite flow' do
    let(:invitation) { create(:group_member, :invited, :developer, invite_email: user_email) }

    before do
      visit invite_path(invitation.raw_invite_token, invite_type: ::Members::InviteMailer::INITIAL_INVITE)
    end

    context 'when Arkose is up' do
      %i[unavailable low].each do |risk|
        context "when the user is risk is #{risk}" do
          before do
            sign_up(flow: :invite, arkose: { risk: risk })
          end

          it 'does not verify the user and lands on group page' do
            expect(page).to have_current_path(group_path(invitation.group))
            expect(page).to have_content(
              "You have been granted access to the #{invitation.group.name} group with the following role: Developer."
            )
          end
        end
      end

      it_behaves_like 'registering a medium risk user with identity verification',
        flow: :invite, skip_email_validation: true

      context 'when user is high risk',
        quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24096' do
        it_behaves_like 'registering a high risk user with identity verification',
          flow: :invite, skip_email_validation: true
      end

      context 'when invite is from a paid namespace', :saas do
        let(:ultimate_group) { create(:group_with_plan, plan: :ultimate_plan) }

        let(:invitation) do
          create(:group_member, :invited, :developer, invite_email: user_email, group: ultimate_group)
        end

        it 'does not require identity verification' do
          sign_up(flow: :invite, arkose: { risk: :medium })

          expect_to_see_dashboard_page
        end

        context 'when paid group is under OSS license' do
          let(:ultimate_group) { create(:group_with_plan, plan: :opensource_plan) }

          it_behaves_like 'registering a medium risk user with identity verification',
            flow: :invite, skip_email_validation: true
        end
      end
    end

    it_behaves_like 'allows the user to complete registration when Arkose is unavailable', flow: :invite
  end

  describe 'Trial flow', :saas do
    before do
      visit new_trial_registration_path
    end

    context 'when Arkose is up' do
      it_behaves_like 'registering a user with identity verification when risk is unavailable', flow: :trial
      it_behaves_like 'registering a low risk user with identity verification', flow: :trial
      it_behaves_like 'registering a medium risk user with identity verification', flow: :trial
      it_behaves_like 'registering a high risk user with identity verification', flow: :trial
    end

    it_behaves_like 'allows the user to complete registration when Arkose is unavailable', flow: :trial
  end

  describe 'SAML flow' do
    around do |example|
      with_omniauth_full_host { example.run }
    end

    context 'when Arkose is up' do
      let(:arkose_token_verification_response) { { session_risk: { risk_band: risk.capitalize } } }

      it_behaves_like 'registering a user with identity verification when risk is unavailable', flow: :saml
      it_behaves_like 'registering a low risk user with identity verification', flow: :saml
      it_behaves_like 'registering a medium risk user with identity verification', flow: :saml
      it_behaves_like 'registering a high risk user with identity verification', flow: :saml
    end

    it_behaves_like 'allows the user to complete registration when Arkose is unavailable', flow: :saml
  end

  describe 'Subscription flow', :saas do
    before do
      stub_ee_application_setting(should_check_namespace_plan: true)

      visit new_subscriptions_path
    end

    context 'when Arkose is up' do
      it_behaves_like 'registering a user with identity verification when risk is unavailable'
      it_behaves_like 'registering a low risk user with identity verification'
      it_behaves_like 'registering a medium risk user with identity verification'
      it_behaves_like 'registering a high risk user with identity verification'
    end

    it_behaves_like 'allows the user to complete registration when Arkose is unavailable'
  end

  describe 'user that already went through identity verification' do
    context 'when the user is medium risk but phone verification application setting is turned off' do
      before do
        stub_application_setting(phone_verification_enabled: false)
        visit new_user_registration_path

        sign_up(arkose: { risk: :medium })
      end

      it 'verifies the user with email only' do
        expect_to_see_identity_verification_page

        verify_email

        expect_verification_completed

        expect_to_see_dashboard_page

        user_signs_out

        # even though the phone verification application setting is turned back on
        # when the user logs in next, they will not be asked to do identity verification again
        stub_application_setting(phone_verification_enabled: true)

        gitlab_sign_in(user, password: new_user.password)

        expect_to_see_dashboard_page
      end
    end
  end

  private

  def sign_up(flow: :standard, **opts)
    invite = flow == :invite
    saml = flow == :saml

    if saml
      provider = 'google_oauth2'

      stub_arkose_token_verification(**opts[:arkose]) unless opts[:arkose][:disable]

      mock_auth_hash(provider, 'external_uid', user_email)
      stub_omniauth_setting(block_auto_created_users: false)

      visit new_user_registration_path

      click_button Gitlab::Auth::OAuth::Provider.label_for(provider)
    else
      fill_in_sign_up_form(new_user, invite: invite) do
        solve_arkose_verify_challenge(**opts[:arkose]) unless opts[:arkose][:disable]
      end
    end
  end

  def user_signs_out
    find_by_testid('user-dropdown').click
    click_link 'Sign out'

    expect(page).to have_button(_('Sign in'))
  end
end
