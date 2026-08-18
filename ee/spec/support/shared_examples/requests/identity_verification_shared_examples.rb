# frozen_string_literal: true

def mock_send_phone_number_verification_code(success:, service_params: [], response_opts: {})
  response = success ? ServiceResponse.success(**response_opts) : ServiceResponse.error(**response_opts)

  allow_next_instance_of(::PhoneVerification::Users::SendVerificationCodeService, *service_params) do |service|
    allow(service).to receive(:execute).and_return(response)
  end
end

def mock_verify_phone_number_verification_code(success:, response_opts: {})
  response = success ? ServiceResponse.success(**response_opts) : ServiceResponse.error(**response_opts)
  allow_next_instance_of(::PhoneVerification::Users::VerifyCodeService) do |service|
    allow(service).to receive(:execute).and_return(response)
  end
end

def mock_rate_limit(limit_name, method, result, scope: nil)
  allow(::Gitlab::ApplicationRateLimiter).to receive(method).with(limit_name, scope: scope).and_return(result)
end

RSpec.shared_examples 'logs and tracks the event' do |category, event, reason = nil|
  it 'logs and tracks the event' do
    message = "IdentityVerification::#{category.to_s.classify}"

    logger_args = {
      message: message,
      event: event.to_s.titlecase,
      username: user.username
    }
    logger_args[:reason] = reason.to_s if reason

    allow(Gitlab::AppLogger).to receive(:info).and_call_original

    do_request

    expect(Gitlab::AppLogger).to have_received(:info).with(hash_including(logger_args))

    tracking_args = {
      category: message,
      action: event.to_s,
      property: '',
      user: user
    }
    tracking_args[:property] = reason.to_s if reason

    expect_snowplow_event(**tracking_args)
  end
end

RSpec.shared_examples 'it requires a signed-in verified user' do
  let_it_be(:confirmed_user, freeze: false) { create(:user, :identity_verification_eligible) }

  before do
    stub_session(session_data: { verification_user_id: nil })
    sign_in confirmed_user

    do_request
  end

  context 'when the user was created after the release day' do
    it 'sets the user instance variable' do
      expect(assigns(:user)).to eq(confirmed_user)
    end

    it 'does not redirect to root path' do
      expect(response).not_to redirect_to(root_path)
    end
  end

  context 'when the user was created before the release day' do
    let_it_be(:confirmed_user, freeze: false) do
      create(:user, created_at: IdentityVerifiable::IDENTITY_VERIFICATION_RELEASE_DATE - 1.day)

      it 'redirects to root path' do
        expect(response).to redirect_to(root_path)
      end
    end
  end
end

RSpec.shared_examples 'it ensures verification attempt is allowed' do |method|
  let(:target_user) { nil }

  subject { response }

  before do
    if target_user
      allow(target_user).to receive(:verification_method_allowed?).with(method: method).and_return(allowed)
    else
      allow_next_found_instance_of(User) do |instance|
        allow(instance).to receive(:verification_method_allowed?)
          .with(method: method).and_return(allowed)
      end
    end

    do_request
  end

  context 'when verification is allowed' do
    let(:allowed) { true }

    it { is_expected.to have_gitlab_http_status(:ok) }
  end

  context 'when verification is not allowed' do
    let(:allowed) { false }

    it { is_expected.to have_gitlab_http_status(:bad_request) }
  end
end

RSpec.shared_examples 'logs challenge solved event' do
  using RSpec::Parameterized::TableSyntax

  where(:challenge_shown, :challenge_type) do
    false | 'transparent'
    true  | 'interactive'
  end

  with_them do
    before do
      stub_arkose_token_verification(challenge_shown: challenge_shown)
    end

    it "logs the event" do
      allow(Gitlab::AppLogger).to receive(:info).with(an_instance_of(Hash))

      expect(Gitlab::AppLogger).to receive(:info).with(
        hash_including(
          message: "Arkose challenge solved"
        )
      )

      do_request
    end
  end
end

RSpec.shared_examples 'it verifies arkose token' do |method|
  let(:target_user) { nil }

  before do
    # This shared example tests ensure_phone_challenge_completed! and
    # ensure_credit_card_challenge_completed! before action hooks depending on
    # the passed `method` param. The following stubs ensure that these before
    # action hooks don't return early by returning [method] from
    # user.required_identity_verification_methods to make
    # `arkose_challenge_required?(method: method)` return true.
    if target_user
      allow(target_user).to receive(:required_identity_verification_methods).and_return([method])
    else
      allow_next_found_instance_of(User) do |instance|
        allow(instance).to receive(:required_identity_verification_methods).and_return([method])
      end
    end
  end

  context 'when verification fails' do
    it 'returns a 400 with an error message', :aggregate_failures do
      stub_arkose_token_verification(token_verification_response: :failed)

      do_request

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(response.body).to eq(
        { message: s_('IdentityVerification|Complete verification to proceed.') }.to_json)
    end
  end

  context 'when verification succeeds' do
    it 'returns a 200' do
      stub_arkose_token_verification(token_verification_response: :success)

      do_request

      expect(response).to have_gitlab_http_status(:ok)
    end

    it_behaves_like 'logs challenge solved event'
  end

  context 'when Arkose is down' do
    it 'returns a 200' do
      stub_arkose_token_verification(token_verification_response: :error, service_down: true)

      do_request

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  context 'when Arkose is disabled' do
    it 'does not send a token verification request and returns a 200', :aggregate_failures do
      # Stub ::AntiAbuse::IdentityVerification::Settings.arkose_enabled? to
      # return false (`arkose_enabled` param) and Arkose token verification
      # request to fail if sent.
      stub_arkose_token_verification(arkose_enabled: false, token_verification_response: :failed)

      do_request

      expect(WebMock).not_to have_requested(:post, 'https://verify-api.arkoselabs.com/api/v4/verify/')

      # Since Arkose is disabled, `method` (i.e. phone or credit card) will no
      # longer require the user to solve an Arkose challenge and will proceed
      # with the request without token verification.
      expect(response).to have_gitlab_http_status(:ok)
    end
  end
end

# GET verification_state
RSpec.shared_examples 'it sets poll interval header' do
  it 'sets poll interval header' do
    do_request

    expect(response.headers.to_h).to include(Gitlab::PollingInterval::HEADER_NAME => '10000')
  end
end

# POST send_phone_verification_code
RSpec.shared_examples 'it successfully sends phone number verification code' do
  let(:response_opts) { { payload: { container: 'contents' } } }
  let(:service_params) { [user, { ip_address: an_instance_of(String), **phone_number_details.stringify_keys }] }

  before do
    mock_send_phone_number_verification_code(
      success: true, service_params: service_params, response_opts: response_opts
    )
  end

  it 'responds with status 200 OK' do
    do_request

    expected_json = { status: :success }.merge(response_opts[:payload]).to_json
    expect(response.body).to eq(expected_json)
  end

  it_behaves_like 'logs and tracks the event', :phone, :sent_phone_verification_code
end

# POST send_phone_verification_code
RSpec.shared_examples 'it handles failed phone number verification code send' do
  let(:response_opts) { { message: 'message', reason: :related_to_banned_user } }

  before do
    mock_send_phone_number_verification_code(success: false, response_opts: response_opts)
  end

  it_behaves_like 'logs and tracks the event', :phone, :failed_attempt, :related_to_banned_user

  it 'responds with error message', :aggregate_failures do
    do_request

    expect(response).to have_gitlab_http_status(:bad_request)
    expect(response.body).to eq({ message: response_opts[:message], reason: response_opts[:reason] }.to_json)
  end

  context 'when the error is related to a high risk user' do
    let(:response_opts) { { message: 'message', reason: :related_to_high_risk_user } }

    it 'does not log an error' do
      expect(Gitlab::AppLogger).not_to receive(:info).with(reason: 'related_to_high_risk_user')

      do_request
    end
  end
end

# POST verify_phone_verification_code
RSpec.shared_examples 'it successfully verifies a phone number verification code' do
  before do
    mock_verify_phone_number_verification_code(success: true)
  end

  it 'responds with status 200 OK' do
    do_request

    expect(response.body).to eq({ status: :success }.to_json)
  end

  it_behaves_like 'logs and tracks the event', :phone, :success
end

# POST verify_phone_verification_code
RSpec.shared_examples 'it handles failed phone number code verification' do
  let(:response_opts) { { message: 'message', reason: 'reason' } }

  before do
    mock_verify_phone_number_verification_code(success: false, response_opts: response_opts)
  end

  it_behaves_like 'logs and tracks the event', :phone, :failed_attempt, :reason

  it 'responds with error message' do
    do_request

    expect(response).to have_gitlab_http_status(:bad_request)
    expect(response.body).to eq({ message: response_opts[:message], reason: response_opts[:reason] }.to_json)
  end

  context 'when multiple codes are attempted' do
    let_it_be(:param_wrapper, freeze: false) { described_class.name.demodulize.underscore.gsub('_controller', '') }
    let_it_be(:params, freeze: false) do
      { param_wrapper => { verification_code: %w[998 999] } }
    end

    it 'passes no params to VerifyCodeService' do
      do_request

      expect(::PhoneVerification::Users::VerifyCodeService).to have_received(:new).with(user, {})
    end
  end
end

# GET verify_credit_card
RSpec.shared_examples 'it verifies presence of credit_card_validation record for the user' do
  using RSpec::Parameterized::TableSyntax

  context 'when request format is html' do
    let(:params) { { format: :html } }

    it 'returns 404' do
      do_request

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  context 'when no credit_card_validation record exist for the user' do
    it 'returns 404' do
      do_request

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  context 'when a credit_card_validation record exists for the user' do
    let(:rate_limited) { false }
    let(:ip) { '1.2.3.4' }

    let_it_be(:cc_attrs, freeze: false) { attributes_for(:credit_card_validation) }
    let_it_be(:credit_card_validation, freeze: false) { create(:credit_card_validation, user: user, **cc_attrs) }

    before do
      allow_next_instance_of(ActionDispatch::Request) do |request|
        allow(request).to receive(:ip).and_return(ip)
      end

      allow_next_instance_of(described_class) do |controller|
        allow(controller).to receive(:check_rate_limit!)
          .with(:credit_card_verification_check_for_reuse, scope: ip)
          .and_return(rate_limited)
      end
    end

    it 'returns HTTP status 200 and an empty json', :aggregate_failures do
      do_request

      expect(json_response).to be_empty
      expect(response).to have_gitlab_http_status(:ok)
    end

    it_behaves_like 'logs and tracks the event', :credit_card, :success

    context 'when the user\'s credit card has been used by a banned user' do
      before do
        create(:credit_card_validation, user: create(:user, :banned), **cc_attrs)
      end

      it_behaves_like 'logs and tracks the event', :credit_card, :failed_attempt, :related_to_banned_user

      it 'bans the user' do
        expect_next_instance_of(::Users::AutoBanService, user: user, reason: :banned_credit_card) do |instance|
          expect(instance).to receive(:execute).and_call_original
        end

        expect { do_request }.to change { user.reload.banned? }.from(false).to(true)
      end

      it 'returns HTTP status 400 and a message', :aggregate_failures do
        do_request

        expect(json_response).to include({
          'message' => "Your account has been blocked. Contact #{EE::CUSTOMER_SUPPORT_URL} for assistance.",
          'reason' => 'related_to_banned_user'
        })
        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when rate limited' do
      let(:rate_limited) { true }

      it 'returns HTTP status 400 and a message', :aggregate_failures do
        do_request

        expect(json_response).to include({
          'message' => format(s_("IdentityVerification|You've reached the maximum amount of tries. " \
                                 "Wait %{interval} and try again."), { interval: 'about 1 hour' })
        })
        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it_behaves_like 'logs and tracks the event', :credit_card, :failed_attempt, :rate_limited
    end
  end
end

# PATCH toggle_phone_exemption
RSpec.shared_examples 'toggles phone number verification exemption for the user' do
  let(:target_user) { nil }

  let(:exemption_offered) { true }

  before do
    if target_user
      allow(target_user).to receive(:offer_phone_number_exemption?).and_return(exemption_offered)
    else
      allow_next_found_instance_of(User) do |instance|
        allow(instance).to receive(:offer_phone_number_exemption?).and_return(exemption_offered)
      end
    end
  end

  it 'toggles phone exemption' do
    expect { do_request }.to change { User.find(user.id).phone_number_verification_exempt? }.to(true)
  end

  it 'returns verification methods and state', :aggregate_failures do
    do_request

    expect(json_response.keys).to include('verification_methods', 'verification_state')
    expect(json_response["verification_methods"]).not_to include('phone')
  end

  it_behaves_like 'logs and tracks the event', :toggle_phone_exemption, :success

  context 'when phone exemption is not offered for the user' do
    let(:exemption_offered) { false }

    it_behaves_like 'logs and tracks the event', :toggle_phone_exemption, :failed

    it 'returns an empty response with a bad request status', :aggregate_failures do
      do_request

      expect(json_response).to be_empty

      expect(response).to have_gitlab_http_status(:bad_request)
    end
  end
end
