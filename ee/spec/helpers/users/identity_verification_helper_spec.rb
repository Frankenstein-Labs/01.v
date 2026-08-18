# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::IdentityVerificationHelper, feature_category: :instance_resiliency do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:user) { create(:user) }

  describe '#*identity_verification_data' do
    let(:request_double) { instance_double(ActionDispatch::Request) }
    let(:sign_up_data_exchange_payload) { 'sign_up_data_exchange_payload' }
    let(:iv_data_exchange_payload) { 'iv_data_exchange_payload' }

    let(:signup_identity_verification_data) do
      {
        successful_verification_path: success_signup_identity_verification_path,
        verification_state_path: verification_state_signup_identity_verification_path,
        phone_exemption_path: toggle_phone_exemption_signup_identity_verification_path,
        phone_send_code_path: send_phone_verification_code_signup_identity_verification_path,
        phone_verify_code_path: verify_phone_verification_code_signup_identity_verification_path,
        credit_card_verify_path: verify_credit_card_signup_identity_verification_path,
        email_verification_message: "Unverified accounts are deleted after 7 days.",
        credit_card_verify_captcha_path: verify_credit_card_captcha_signup_identity_verification_path
      }
    end

    let(:identity_verification_data) do
      {
        successful_verification_path: success_identity_verification_path,
        verification_state_path: verification_state_identity_verification_path,
        phone_exemption_path: toggle_phone_exemption_identity_verification_path,
        phone_send_code_path: send_phone_verification_code_identity_verification_path,
        phone_verify_code_path: verify_phone_verification_code_identity_verification_path,
        credit_card_verify_path: verify_credit_card_identity_verification_path,
        email_verification_message: "Unverified accounts are deleted after 7 days.",
        credit_card_verify_captcha_path: verify_credit_card_captcha_identity_verification_path
      }
    end

    let(:common_data) do
      {
        offer_phone_number_exemption: mock_offer_phone_number_exemption,
        phone_number: {},
        credit_card: {
          user_id: user.id,
          form_id: ::Gitlab::SubscriptionPortal::REGISTRATION_VALIDATION_FORM_ID
        },
        email: {
          obfuscated: helper.obfuscated_email(user.email),
          verify_path: verify_email_code_signup_identity_verification_path,
          resend_path: resend_email_code_signup_identity_verification_path
        },
        arkose: {
          api_key: 'api-key',
          domain: 'domain',
          data_exchange_payload: sign_up_data_exchange_payload,
          data_exchange_payload_path: data_exchange_payload_path
        },
        arkose_data_exchange_payload: iv_data_exchange_payload,
        unified_registration: false
      }
    end

    let(:signup_identity_verification_data_result) do
      common_data.merge(signup_identity_verification_data)
    end

    let(:identity_verification_data_result) { common_data.merge(identity_verification_data) }

    where(:method, :expected_data) do
      :signup_identity_verification_data | ref(:signup_identity_verification_data_result)
      :identity_verification_data        | ref(:identity_verification_data_result)
    end

    with_them do
      let(:mock_identity_verification_state) do
        { credit_card: false, email: true }
      end

      let(:mock_required_identity_verification_methods) { ['email'] }
      let(:mock_offer_phone_number_exemption) { true }

      before do
        allow(user).to receive(:required_identity_verification_methods).and_return(
          mock_required_identity_verification_methods
        )
        allow(user).to receive(:identity_verification_state).and_return(
          mock_identity_verification_state
        )
        allow(user).to receive(:offer_phone_number_exemption?).and_return(
          mock_offer_phone_number_exemption
        )

        allow(::AntiAbuse::IdentityVerification::Settings).to receive(:arkose_public_api_key).and_return('api-key')
        allow(::AntiAbuse::IdentityVerification::Settings).to receive(:arkose_labs_domain).and_return('domain')

        allow(helper).to receive(:request).and_return(request_double)
        allow_next_instance_of(Arkose::DataExchangePayload, request_double,
          a_hash_including({ use_case: Arkose::DataExchangePayload::USE_CASE_SIGN_UP })) do |builder|
          allow(builder).to receive(:build).and_return(sign_up_data_exchange_payload)
        end

        allow_next_instance_of(Arkose::DataExchangePayload, request_double,
          a_hash_including({ use_case: Arkose::DataExchangePayload::USE_CASE_IDENTITY_VERIFICATION })) do |builder|
          allow(builder).to receive(:build).and_return(iv_data_exchange_payload)
        end
      end

      subject(:data) { helper.send(method, user) }

      context 'when no phone number for user exists' do
        it 'returns the expected data' do
          expect(Gitlab::Json.parse(data[:data])).to eq(expected_data.deep_stringify_keys)
        end
      end

      context 'when phone number for user exists' do
        let_it_be(:record) { create(:phone_number_validation, user: user) }

        it 'returns the expected data' do
          phone_number_data = {
            country: record.country,
            international_dial_code: record.international_dial_code,
            number: record.phone_number,
            send_allowed_after: record.sms_send_allowed_after
          }

          json_result = Gitlab::Json.parse(data[:data])
          expect(json_result).to eq(expected_data.merge({ phone_number: phone_number_data }).deep_stringify_keys)
        end
      end
    end
  end

  describe 'unified_registration in #*identity_verification_data' do
    let(:request_double) { instance_double(ActionDispatch::Request) }

    before do
      allow(user).to receive_messages(
        required_identity_verification_methods: ['email'],
        identity_verification_state: { email: true },
        offer_phone_number_exemption?: true
      )
      allow(::AntiAbuse::IdentityVerification::Settings).to receive_messages(
        arkose_public_api_key: 'api-key',
        arkose_labs_domain: 'domain'
      )
      allow(helper).to receive(:request).and_return(request_double)
      allow_next_instance_of(Arkose::DataExchangePayload, request_double, anything) do |builder|
        allow(builder).to receive(:build).and_return('payload')
      end
    end

    it 'merges unified_registration: true into the JSON payload' do
      result = helper.signup_identity_verification_data(user, unified_registration: true)

      expect(Gitlab::Json.parse(result[:data])).to include('unified_registration' => true)
    end

    it 'defaults unified_registration to false' do
      result = helper.signup_identity_verification_data(user)

      expect(Gitlab::Json.parse(result[:data])).to include('unified_registration' => false)
    end

    it 'always includes unified_registration in identity_verification_data' do
      result = helper.identity_verification_data(user)

      expect(Gitlab::Json.parse(result[:data])).to include('unified_registration' => false)
    end
  end

  describe '#rate_limited_error_message' do
    subject(:message) { helper.rate_limited_error_message(limit) }

    let(:limit) { :credit_card_verification_check_for_reuse }

    it 'returns a generic error message' do
      expect(message).to eq(format(s_("IdentityVerification|You've reached the maximum amount of tries. " \
        'Wait %{interval} and try again.'), { interval: 'about 1 hour' }))
    end

    context 'when the limit is for email_verification_code_send' do
      let(:limit) { :email_verification_code_send }

      it 'returns a specific message' do
        expect(message).to eq(format(s_("IdentityVerification|You've reached the maximum amount of resends. " \
          'Wait %{interval} and try again.'), { interval: 'about 1 hour' }))
      end
    end
  end

  describe '#user_banned_error_message' do
    subject { helper.user_banned_error_message }

    it { is_expected.to eq "Your account has been blocked. Contact #{EE::CUSTOMER_SUPPORT_URL} for assistance." }
  end

  describe '#pipl_restricted_country?' do
    subject { helper.pipl_restricted_country?(country_code) }

    context 'on GitLab.com', :saas do
      context 'with a restricted country code' do
        let(:country_code) { 'CN' }

        it { is_expected.to be(true) }
      end

      context 'with an unrestricted country code' do
        let(:country_code) { 'US' }

        it { is_expected.to be(false) }
      end
    end

    context 'on self-managed' do
      context 'with a restricted country code' do
        let(:country_code) { 'CN' }

        it { is_expected.to be(false) }
      end
    end
  end
end
