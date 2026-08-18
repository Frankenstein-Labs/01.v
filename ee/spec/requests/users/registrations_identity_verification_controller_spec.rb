# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::RegistrationsIdentityVerificationController, :clean_gitlab_redis_sessions,
  :clean_gitlab_redis_rate_limiting, feature_category: :instance_resiliency do
  include SessionHelpers
  include IdentityVerificationHelpers

  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:unconfirmed_user) { create(:user, :unconfirmed, :low_risk) }
  let_it_be_with_reload(:confirmed_user) { create(:user, :low_risk) }
  let_it_be(:invalid_verification_user_id) { non_existing_record_id }
  let(:request_headers) { { "HTTP_USER_AGENT" => "test-ua" } }

  before do
    stub_saas_features(identity_verification: true)
    stub_application_setting_enum('email_confirmation_setting', 'hard')
    stub_application_setting(require_admin_approval_after_user_signup: false)

    allow(::Gitlab::ApplicationRateLimiter).to receive(:peek).and_call_original
    allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_call_original

    allow_next_found_instance_of(User) do |instance|
      allow(instance).to receive(:verification_method_allowed?).and_return(true)
    end
  end

  shared_examples 'it requires a signed-in user' do |expected_response_code|
    let(:response_code) { expected_response_code || :ok }

    context 'with a signed-in IdentityVerificationUser' do
      let(:verification_user_id) { unconfirmed_user.id }

      include_context 'with a signed-in IdentityVerificationUser'

      it 'sets the user instance variable and returns the expected response', :aggregate_failures do
        do_request

        expect(assigns(:user)).to eq(unconfirmed_user)
        expect(response).to have_gitlab_http_status(response_code)
      end
    end

    it_behaves_like 'it handles absence of a signed-in IdentityVerificationUser' do
      it 'redirects to root_path' do
        do_request

        expect(response).to redirect_to(root_path)
      end
    end

    it_behaves_like 'it requires a signed-in verified user'
  end

  shared_examples 'it requires an unconfirmed user' do |expected_response_code|
    subject { response }

    let(:response_code) { expected_response_code || :ok }

    before do
      stub_session(session_data: { verification_user_id: user.id })

      do_request
    end

    context 'when session contains a `verification_user_id` from a confirmed user' do
      let_it_be(:user) { confirmed_user }

      it 'handles the request as expected' do
        if request.format.html?
          expect(response).to redirect_to(success_signup_identity_verification_path)
        else
          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'when session contains a `verification_user_id` from an unconfirmed user' do
      let_it_be(:user) { unconfirmed_user }

      it { is_expected.to have_gitlab_http_status(response_code) }
    end
  end

  shared_examples 'it requires oauth users to go through ArkoseLabs challenge' do
    let(:user) { create(:omniauth_user, :unconfirmed) }
    let(:arkose_enabled) { true }

    before do
      allow(::AntiAbuse::IdentityVerification::Settings).to receive(:arkose_enabled?)
        .with(user: user, user_agent: 'test-ua').and_return(arkose_enabled)

      stub_session(session_data: { verification_user_id: user.id })

      do_request
    end

    subject { response }

    it { is_expected.to redirect_to(arkose_labs_challenge_signup_identity_verification_path) }

    context 'when user has an arkose_risk_band' do
      let(:user) { create(:omniauth_user, :unconfirmed, :low_risk) }

      it { is_expected.not_to redirect_to(arkose_labs_challenge_signup_identity_verification_path) }
    end

    context 'when arkose is disabled' do
      let(:arkose_enabled) { false }

      it { is_expected.not_to redirect_to(arkose_labs_challenge_signup_identity_verification_path) }
    end
  end

  describe 'GET show' do
    subject(:do_request) { get signup_identity_verification_path, headers: request_headers }

    before do
      stub_session(session_data: { verification_user_id: unconfirmed_user.id })
    end

    it_behaves_like 'it requires a signed-in user'
    it_behaves_like 'it requires an unconfirmed user'
    it_behaves_like 'it requires oauth users to go through ArkoseLabs challenge'

    it 'renders template show with layout minimal' do
      do_request

      expect(response).to render_template('show', layout: 'minimal')
    end

    context 'when in the unified self-managed subscription flow', :saas_onboarding do
      let(:sm_return_to) do
        ::Gitlab::Routing.url_helpers.new_subscriptions_path(
          plan_id: 'abc123', deployment_type: 'self_managed'
        )
      end

      before do
        stub_session(session_data: { verification_user_id: unconfirmed_user.id, user_return_to: sm_return_to })
      end

      it 'renders template show with layout registration_two_panel' do
        do_request

        expect(response).to render_template('show', layout: 'registration_two_panel')
      end
    end

    context 'with a banned user' do
      let_it_be(:user) { unconfirmed_user }

      before do
        stub_session(session_data: { verification_user_id: user.id })
        user.ban

        do_request
      end

      it 'redirects to the sign-in page with an error message', :aggregate_failures do
        expect(response).to have_gitlab_http_status(:redirect)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert])
          .to eq("Your account has been blocked. Contact #{EE::CUSTOMER_SUPPORT_URL} for assistance.")
      end

      it 'deletes the verification_user_id from the session' do
        expect(request.session.has_key?(:verification_user_id)).to be(false)
      end
    end
  end

  describe 'GET restricted' do
    subject(:get_restricted) { get restricted_signup_identity_verification_path }

    it 'returns the template with a redirect', :aggregate_failures do
      get_restricted

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe 'GET verification_state' do
    subject(:do_request) { get verification_state_signup_identity_verification_path }

    it_behaves_like 'it requires a signed-in user'

    context 'with an unverified user' do
      let_it_be(:user) { unconfirmed_user }

      before do
        stub_session(session_data: { verification_user_id: user.id })
        allow(::AntiAbuse::IdentityVerification::Settings).to receive(:arkose_enabled?).and_return(true)
      end

      it 'returns verification methods and state', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/463198' do
        do_request

        expect(json_response).to eq({
          'verification_methods' => user.required_identity_verification_methods,
          'verification_state' => user.identity_verification_state,
          'methods_requiring_arkose_challenge' => []
        })
      end

      it_behaves_like 'it sets poll interval header'

      describe 'methods_requiring_arkose_challenge' do
        subject do
          do_request

          json_response['methods_requiring_arkose_challenge']
        end

        where(:required_methods, :methods_requiring_challenge) do
          %w[email]                   | []
          %w[email phone]             | %w[phone]
          %w[email phone credit_card] | %w[phone]
          %w[email credit_card phone] | %w[credit_card]
          %w[email credit_card]       | %w[credit_card]
          %w[phone]                   | %w[phone]
          %w[phone credit_card]       | %w[phone]
          %w[credit_card phone]       | %w[credit_card]
          %w[credit_card]             | %w[credit_card]
        end

        with_them do
          before do
            allow_next_found_instance_of(User) do |instance|
              allow(instance).to receive(:required_identity_verification_methods).and_return(required_methods)
            end
          end

          it { is_expected.to match_array(methods_requiring_challenge) }

          context 'when Arkose is disabled' do
            before do
              allow(::AntiAbuse::IdentityVerification::Settings).to receive(:arkose_enabled?).and_return(false)
            end

            it { is_expected.to be_empty }
          end
        end
      end
    end
  end

  describe 'POST verify_email_code' do
    let_it_be(:user) { unconfirmed_user }
    let_it_be(:params) { { registrations_identity_verification: { code: '123456' } } }
    let_it_be(:service_response) { { status: :success } }

    subject(:do_request) do
      post verify_email_code_signup_identity_verification_path(params), headers: request_headers
    end

    before do
      allow_next_instance_of(::Users::EmailVerification::ValidateTokenService) do |service|
        allow(service).to receive(:execute).and_return(service_response)
      end

      stub_session(session_data: { verification_user_id: user.id })
    end

    it_behaves_like 'it requires a signed-in user'
    it_behaves_like 'it requires an unconfirmed user'
    it_behaves_like 'it requires oauth users to go through ArkoseLabs challenge'

    context 'when validation was successful' do
      it 'confirms the user', :freeze_time do
        expect { do_request }.to change { user.reload.confirmed_at }.from(nil).to(Time.current)
      end

      it_behaves_like 'logs and tracks the event', :email, :success

      it 'renders the result as json' do
        do_request

        expect(response.body).to eq(service_response.to_json)
      end

      context 'when the user has an unconfirmed email' do
        before do
          user.update!(unconfirmed_email: 'user+unconfired@example.com')
        end

        it 'confirms the user with the current email', :freeze_time, :aggregate_failures do
          current_email = user.email

          expect { do_request }.to change { user.reload.confirmed_at }.from(nil).to(Time.current)
          expect(user.email).to eq(current_email)
          expect(user.unconfirmed_email).to be_nil
        end
      end
    end

    context 'when failing to validate' do
      let_it_be(:service_response) { { status: :failure, reason: 'reason', message: 'message' } }

      it_behaves_like 'logs and tracks the event', :email, :failed_attempt, :reason

      it 'renders the result as json' do
        do_request

        expect(response.body).to eq(service_response.to_json)
      end
    end
  end

  describe 'POST resend_email_code' do
    let_it_be(:user) { unconfirmed_user }

    subject(:do_request) { post resend_email_code_signup_identity_verification_path, headers: request_headers }

    it_behaves_like 'it requires a signed-in user'
    it_behaves_like 'it requires an unconfirmed user'
    it_behaves_like 'it requires oauth users to go through ArkoseLabs challenge'

    context 'when rate limited' do
      before do
        mock_rate_limit(:soft_phone_verification_transactions_limit, :peek, false)
        mock_rate_limit(:email_verification_code_send, :throttled?, true, scope: user)

        stub_session(session_data: { verification_user_id: user.id })

        do_request
      end

      it 'renders the result as json' do
        expect(response.body).to eq({
          status: :failure,
          message: format(s_("IdentityVerification|You've reached the maximum amount of resends. Wait %{interval} " \
                             "and try again."), interval: 'about 1 hour')
        }.to_json)
      end
    end

    context 'when successful' do
      let_it_be(:new_token) { '123456' }
      let_it_be(:encrypted_token) { Devise.token_generator.digest(User, unconfirmed_user.email, new_token) }

      before do
        allow_next_instance_of(::Users::EmailVerification::GenerateTokenService) do |service|
          allow(service).to receive(:generate_token).and_return(new_token)
        end
        stub_session(session_data: { verification_user_id: user.id })
      end

      it 'sets the confirmation_sent_at time', :freeze_time do
        expect { do_request }.to change { user.reload.confirmation_sent_at }.to(Time.current)
      end

      it 'sets the confirmation_token to the encrypted custom token' do
        expect { do_request }.to change { user.reload.confirmation_token }.to(encrypted_token)
      end

      it 'sends the confirmation instructions email' do
        expect(::Notify).to receive(:confirmation_instructions_email)
          .with(user.email, token: new_token).once.and_call_original

        do_request
      end

      it_behaves_like 'logs and tracks the event', :email, :sent_instructions

      it 'renders the result as json' do
        do_request

        expect(response.body).to eq({ status: :success }.to_json)
      end
    end
  end

  describe 'POST send_phone_verification_code' do
    let_it_be(:unconfirmed_user) { create(:user, :medium_risk) }
    let_it_be(:user) { unconfirmed_user }
    let_it_be(:params) do
      { registrations_identity_verification: { country: 'US', international_dial_code: '1', phone_number: '555' } }
    end

    subject(:do_request) do
      post send_phone_verification_code_signup_identity_verification_path(params), headers: request_headers
    end

    before do
      stub_session(session_data: { verification_user_id: user.id })
      stub_arkose_token_verification(token_verification_response: :success)
    end

    it { is_expected.to have_request_urgency(:low) }

    describe 'before action hooks' do
      before do
        mock_send_phone_number_verification_code(success: true)
      end

      it_behaves_like 'it requires a signed-in user'
      it_behaves_like 'it requires an unconfirmed user'
      it_behaves_like 'it requires oauth users to go through ArkoseLabs challenge'
      it_behaves_like 'it ensures verification attempt is allowed', 'phone'
      it_behaves_like 'it verifies arkose token', 'phone'
    end

    it_behaves_like 'it successfully sends phone number verification code' do
      let(:phone_number_details) { params[:registrations_identity_verification] }
    end

    it_behaves_like 'it handles failed phone number verification code send'
  end

  describe 'POST verify_phone_verification_code' do
    let_it_be(:unconfirmed_user) { create(:user, :medium_risk) }
    let_it_be(:user) { unconfirmed_user }
    let_it_be(:params) do
      { registrations_identity_verification: { verification_code: '999' } }
    end

    subject(:do_request) do
      post verify_phone_verification_code_signup_identity_verification_path(params), headers: request_headers
    end

    before do
      stub_session(session_data: { verification_user_id: user.id })
    end

    describe 'before action hooks' do
      before do
        mock_verify_phone_number_verification_code(success: true)
      end

      it_behaves_like 'it requires a signed-in user'
      it_behaves_like 'it requires an unconfirmed user'
      it_behaves_like 'it requires oauth users to go through ArkoseLabs challenge'
      it_behaves_like 'it ensures verification attempt is allowed', 'phone'
    end

    it_behaves_like 'it successfully verifies a phone number verification code'
    it_behaves_like 'it handles failed phone number code verification'
  end

  shared_examples 'it requires a user without an arkose risk_band' do
    let_it_be(:user_without_risk_band) { create(:user) }
    let_it_be(:user_with_risk_band) { create(:user) }

    before do
      stub_session(session_data: { verification_user_id: user&.id })
      request
    end

    subject { response }

    context 'when session contains no `verification_user_id`' do
      let(:user) { nil }

      it { is_expected.to have_gitlab_http_status(:not_found) }
    end

    context 'when session contains a `verification_user_id` from a user with an arkose risk_band' do
      let(:user) { user_with_risk_band }

      it { is_expected.to have_gitlab_http_status(:not_found) }
    end

    context 'when session contains a `verification_user_id` from a user without an arkose risk_band' do
      let(:user) { user_without_risk_band }

      it { is_expected.to have_gitlab_http_status(:ok) }
    end
  end

  describe 'POST verify_arkose_labs_session' do
    let_it_be(:user) { create(:user, :unconfirmed) }

    let(:params) { { arkose_labs_token: 'fake-token' } }
    let(:do_request) { post verify_arkose_labs_session_signup_identity_verification_path, params: params }

    before do
      stub_session(session_data: { verification_user_id: user.id })
    end

    it_behaves_like 'it requires a signed-in user', :redirect
    it_behaves_like 'it requires an unconfirmed user', :redirect

    describe 'token verification' do
      context 'when it fails' do
        it 'renders arkose_labs_challenge with the correct alert flash' do
          stub_arkose_token_verification(token_verification_response: :failed)

          do_request

          expect(flash[:alert]).to include(s_('IdentityVerification|Complete verification to sign up.'))
          expect(response).to render_template('arkose_labs_challenge')
        end

        context 'with tracking' do
          before do
            stub_arkose_token_verification(token_verification_response: :failed)
          end

          it_behaves_like 'internal event tracking' do
            let(:event) { 'fail_arkose_challenge_during_registration' }
            let(:category) { described_class.name }

            subject { do_request }
          end
        end

        context 'when Arkose is down' do
          before do
            stub_arkose_token_verification(token_verification_response: :failed, service_down: true)
          end

          it 'marks the user as Arkose-verified', :aggregate_failures do
            expect { do_request }.to change { User.find(user.id).arkose_verified? }.from(false).to(true)

            expect(response).to redirect_to(signup_identity_verification_path)
          end
        end
      end

      context 'when it succeeds' do
        before do
          stub_arkose_token_verification(token_verification_response: :success)
        end

        it 'redirects to show action' do
          do_request

          expect(response).to redirect_to(signup_identity_verification_path)
        end

        it_behaves_like 'logs challenge solved event'

        it 'executes the phone verification limit check' do
          expect_next_found_instance_of(User) do |user|
            expect(user).to receive(:assume_high_risk_if_phone_verification_limit_exceeded!)
          end

          do_request
        end
      end
    end
  end

  describe 'GET arkose_labs_challenge' do
    let_it_be(:user) { create(:user, :unconfirmed) }

    let(:do_request) { get arkose_labs_challenge_signup_identity_verification_path }

    it_behaves_like 'it requires a signed-in user'
    it_behaves_like 'it requires an unconfirmed user'

    it 'renders arkose_labs_challenge template' do
      stub_session(session_data: { verification_user_id: user.id })
      do_request

      expect(response).to render_template('arkose_labs_challenge', layout: 'minimal')
    end

    context 'when in the unified self-managed subscription flow', :saas_onboarding do
      let(:sm_return_to) do
        ::Gitlab::Routing.url_helpers.new_subscriptions_path(
          plan_id: 'abc123', deployment_type: 'self_managed'
        )
      end

      it 'renders arkose_labs_challenge template with layout registration_two_panel' do
        stub_session(session_data: { verification_user_id: user.id, user_return_to: sm_return_to })
        do_request

        expect(response).to render_template('arkose_labs_challenge', layout: 'registration_two_panel')
      end
    end
  end

  describe 'GET success' do
    let(:stored_user_return_to_path) { '/user/return/to/path' }
    let(:return_to_entries) { { user_return_to: stored_user_return_to_path } }
    let(:user) { confirmed_user }

    before do
      stub_session(session_data: { verification_user_id: user.id }.merge(return_to_entries))
    end

    it 'renders template success with layout minimal' do
      get success_signup_identity_verification_path

      expect(response).to render_template('success', layout: 'minimal')
    end

    context 'when in the unified self-managed subscription flow', :saas_onboarding do
      let(:sm_return_to) do
        ::Gitlab::Routing.url_helpers.new_subscriptions_path(
          plan_id: 'abc123', deployment_type: 'self_managed'
        )
      end

      let(:return_to_entries) { { user_return_to: sm_return_to } }

      it 'renders template success with layout registration_two_panel' do
        get success_signup_identity_verification_path

        expect(response).to render_template('success', layout: 'registration_two_panel')
      end

      context 'with the account created iterable event' do
        before do
          stub_saas_features(onboarding: true)
          user.update!(onboarding_status_registration_type: 'subscription_sm')
        end

        it 'triggers the account created iterable event' do
          allow(::Onboarding::CreateIterableTriggerWorker).to receive(:perform_async)

          get success_signup_identity_verification_path

          expect(::Onboarding::CreateIterableTriggerWorker).to have_received(:perform_async).with(
            hash_including(
              'provider' => 'gitlab',
              'work_email' => user.email,
              'uid' => user.id,
              'product_interaction' => 'Direct Purchase Account Creation Premium SM',
              'preferred_language' => 'English'
            )
          )
        end

        context 'when there is no stored :redirect location' do
          it 'resolves the customers portal interstitial path directly via after_sign_up_path' do
            get success_signup_identity_verification_path

            expect(assigns(:redirect_url)).to eq(users_sign_up_customers_portal_redirect_path)
          end
        end

        context 'when a stale :redirect location is stored' do
          let(:return_to_entries) do
            {
              user_return_to: sm_return_to,
              redirect_return_to: users_sign_up_welcome_path
            }
          end

          it 'resolves the customers portal interstitial directly, ignoring the stored :redirect' do
            get success_signup_identity_verification_path

            expect(assigns(:redirect_url)).to eq(users_sign_up_customers_portal_redirect_path)
          end
        end
      end
    end

    context 'when not in a unified subscription flow' do
      it 'does not trigger the account created iterable event' do
        expect(::Onboarding::CreateIterableTriggerWorker).not_to receive(:perform_async)

        get success_signup_identity_verification_path
      end
    end

    context 'for an invite' do
      let!(:member_invite) { create(:project_member, :invited, invite_email: user.email) }

      context 'when onboarding is not available' do
        before do
          get success_signup_identity_verification_path
        end

        context 'when not yet verified' do
          let(:user) { unconfirmed_user }

          it 'redirects back to signup_identity_verification_path' do
            expect(response).to redirect_to(signup_identity_verification_path)
          end
        end

        context 'when verified' do
          it 'accepts pending invitations' do
            expect(member_invite.reload).not_to be_invite
          end

          it 'signs in the user' do
            expect(request.env['warden']).to be_authenticated
          end

          it 'deletes the verification_user_id from the session' do
            expect(request.session.has_key?(:verification_user_id)).to be(false)
          end

          it 'does not update onboarding_status' do
            expect(user.onboarding_status).to eq({})
          end
        end

        it 'renders the template with the after_sign_in_path_for variable', :aggregate_failures do
          expect(response).to have_gitlab_http_status(:ok)
          expect(assigns(:redirect_url)).to eq(stored_user_return_to_path)
        end
      end

      context 'when onboarding is available' do
        before do
          stub_saas_features(onboarding: true)
          user.update!(onboarding_in_progress: true)
        end

        it 'updates the registration types' do
          get success_signup_identity_verification_path

          expect(user.onboarding_status_registration_type).to eq('invite')
          expect(user.onboarding_status_initial_registration_type).to eq('invite')
        end

        it 'sets the tracking_label to invite registration' do
          get success_signup_identity_verification_path

          expect(assigns(:tracking_label)).to eq(::Onboarding::InviteRegistration.tracking_label)
        end
      end
    end

    context 'for trial registration' do
      before do
        stub_saas_features(onboarding: true)
        user.update!(onboarding_in_progress: true)
      end

      it 'detects a trial' do
        user.update!(onboarding_status_registration_type: 'trial')

        get success_signup_identity_verification_path

        expect(assigns(:tracking_label)).to eq(::Onboarding::TrialRegistration.tracking_label)
      end
    end
  end

  describe 'GET verify_credit_card' do
    let_it_be(:user) { unconfirmed_user }

    let(:params) { { format: :json } }

    subject(:do_request) { get verify_credit_card_signup_identity_verification_path(params) }

    before do
      stub_session(session_data: { verification_user_id: user.id })
    end

    it_behaves_like 'it verifies presence of credit_card_validation record for the user'
  end

  describe 'POST verify_credit_card_captcha' do
    let_it_be(:user) { unconfirmed_user }

    before do
      stub_session(session_data: { verification_user_id: user.id })
    end

    subject(:do_request) { post verify_credit_card_captcha_signup_identity_verification_path }

    it_behaves_like 'it ensures verification attempt is allowed', 'credit_card' do
      let_it_be(:cc) { create(:credit_card_validation, user: user) }
    end

    it_behaves_like 'it verifies arkose token', 'credit_card'
  end

  describe 'PATCH toggle_phone_exemption' do
    let_it_be(:unconfirmed_user) { create(:user, :unconfirmed, :medium_risk) }
    let_it_be(:user) { unconfirmed_user }

    subject(:do_request) { patch toggle_phone_exemption_signup_identity_verification_path(format: :json) }

    before do
      stub_session(session_data: { verification_user_id: user.id })
    end

    it_behaves_like 'it requires an unconfirmed user'
    it_behaves_like 'it requires a signed-in user'
    it_behaves_like 'toggles phone number verification exemption for the user'
  end
end
