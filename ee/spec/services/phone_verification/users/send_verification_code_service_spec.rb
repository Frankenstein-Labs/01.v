# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PhoneVerification::Users::SendVerificationCodeService, feature_category: :instance_resiliency do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:low_risk_score) { 100 }
  let_it_be(:high_risk_score) { 750 }

  let_it_be_with_reload(:user) { create(:user) }
  let(:ip_address) { '1.2.3.4' }
  let(:phone_number_details) { { country: 'US', international_dial_code: 1, phone_number: '555' } }
  let(:risk_score) { low_risk_score }
  let(:risk_service_response) { ServiceResponse.success(payload: { risk_score: risk_score }) }

  subject(:service) { described_class.new(user, ip_address: ip_address, **phone_number_details) }

  describe '#execute' do
    before do
      allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?)
        .with(:phone_verification_send_code, scope: user).and_return(false)

      %i[soft hard].each do |prefix|
        rate_limit_name = :"#{prefix}_phone_verification_transactions_limit"
        allow(Gitlab::ApplicationRateLimiter)
          .to receive(:throttled?).with(rate_limit_name, scope: :global).and_return(false)
      end

      allow_next_instance_of(PhoneVerification::TelesignClient::RiskScoreService,
        phone_number: "#{phone_number_details[:international_dial_code]}#{phone_number_details[:phone_number]}",
        user: user,
        ip_address: ip_address
      ) do |instance|
        allow(instance).to receive(:execute).and_return(risk_service_response)
      end

      allow_next_instance_of(PhoneVerification::TelesignClient::SendVerificationCodeService) do |instance|
        allow(instance).to receive(:execute).and_return(send_verification_code_response)
      end
    end

    shared_examples 'it returns a success response' do
      it 'returns a success response', :aggregate_failures do
        response = service.execute

        expect(response).to be_a(ServiceResponse)
        expect(response).to be_success
      end
    end

    context 'when telesign_intelligence_enabled application setting is set to true' do
      before do
        stub_application_setting(telesign_intelligence_enabled: true)
      end

      context 'when phone number details are invalid' do
        let(:phone_number_details) { { country: 'US', international_dial_code: 1 } }

        it 'returns an error', :aggregate_failures do
          response = service.execute

          expect(response).to be_a(ServiceResponse)
          expect(response).to be_error
          expect(response.message).to eq('Phone number can\'t be blank')
          expect(response.reason).to eq(:bad_params)
        end
      end

      context 'when user has reached max verification attempts' do
        let_it_be(:record) do
          create(:phone_number_validation, sms_send_count: 1, sms_sent_at: Time.current, user: user)
        end

        before do
          allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?)
          .with(:phone_verification_send_code, scope: user).and_return(true)
        end

        it 'resets sms_send_count and sms_sent_at' do
          expect { service.execute }.to change {
            [record.reload.sms_send_count, record.reload.sms_sent_at]
          }.to([0, nil])
        end

        it 'returns an error', :aggregate_failures do
          response = service.execute

          expect(response).to be_a(ServiceResponse)
          expect(response).to be_error
          expect(response.message).to eq(
            'You\'ve reached the maximum number of tries. ' \
            'Wait 1 day and try again.'
          )
          expect(response.reason).to eq(:rate_limited)
        end
      end

      context 'when phone number is linked to an already banned user' do
        let(:banned_user) { create(:user, :banned) }
        let(:record) { create(:phone_number_validation, :validated, user: banned_user) }

        let(:phone_number_details) do
          {
            country: 'AU',
            international_dial_code: record.international_dial_code,
            phone_number: record.phone_number
          }
        end

        it 'bans the user' do
          expect_next_instance_of(::Users::AutoBanService, user: user, reason: :banned_phone_number) do |instance|
            expect(instance).to receive(:execute).and_call_original
          end

          service.execute

          expect(user).to be_banned
        end

        it 'saves the phone number validation record' do
          service.execute

          record = user.phone_number_validation

          expect(record.international_dial_code).to eq(phone_number_details[:international_dial_code])
          expect(record.phone_number).to eq(phone_number_details[:phone_number])
        end

        it 'returns an error', :aggregate_failures do
          response = service.execute

          expect(response).to be_a(ServiceResponse)
          expect(response).to be_error
          expect(response.message)
            .to eq("Your account has been blocked. Contact #{EE::CUSTOMER_SUPPORT_URL} for assistance.")
          expect(response.reason).to eq(:related_to_banned_user)
        end
      end

      context 'when intelligence score has already been determined' do
        let(:phone_number) { phone_number_details[:phone_number] }

        before do
          create(:phone_number_validation, phone_number: phone_number, risk_score: low_risk_score, user: user)
        end

        it 'does not execute the risk score service' do
          expect(::PhoneVerification::TelesignClient::RiskScoreService).not_to receive(:new)

          service.execute
        end

        context 'when the phone number has changed' do
          let(:phone_number) { '12345' }

          it 'executes the risk score service' do
            expect(::PhoneVerification::TelesignClient::RiskScoreService).to receive(:new)

            service.execute
          end
        end
      end

      context 'when intelligence API returns a score of 0' do
        let(:risk_score) { 0 }
        let_it_be(:send_verification_code_response) { ServiceResponse.success }

        it 'sets the risk score to 1' do
          service.execute
          record = user.phone_number_validation

          expect(record.risk_score).to eq 1
        end
      end

      context 'when phone number is high risk' do
        let(:risk_score) { high_risk_score }
        let_it_be(:send_verification_code_response) { ServiceResponse.success }

        it 'returns an error', :aggregate_failures do
          response = service.execute

          expect(response).to be_a(ServiceResponse)
          expect(response).to be_error
          expect(response.message).to eq('Phone verification high-risk user')
          expect(response.reason).to eq(:related_to_high_risk_user)
        end

        it 'saves the phone number validation' do
          service.execute
          record = user.phone_number_validation

          expect(record.risk_score).to eq risk_score
        end

        context 'when the user is already assumed high risk' do
          before do
            ::IdentityVerification::UserRiskProfile.new(user).assume_high_risk!(reason: 'High Risk')
          end

          it_behaves_like 'it returns a success response'
        end

        context 'when the user has already validated a credit card' do
          before do
            allow(user).to receive(:credit_card_verified?).and_return(true)
          end

          it_behaves_like 'it returns a success response'

          it 'does not mark the user as high risk' do
            service.execute

            expect(user.assumed_high_risk?).to be(false)
          end
        end
      end

      context 'with a duplicate phone number' do
        let_it_be(:send_verification_code_response) { ServiceResponse.success }

        context 'when a duplicate phone validation has been created within a week' do
          before do
            create(
              :phone_number_validation,
              international_dial_code: phone_number_details[:international_dial_code],
              phone_number: phone_number_details[:phone_number]
            )
          end

          it 'returns an error', :aggregate_failures do
            response = service.execute

            expect(response).to be_a(ServiceResponse)
            expect(response).to be_error
            expect(response.message).to eq('Phone verification high-risk user')
            expect(response.reason).to eq(:related_to_high_risk_user)
          end
        end

        context 'when a duplicate phone validation is older than 1 week' do
          before do
            create(
              :phone_number_validation,
              international_dial_code: phone_number_details[:international_dial_code],
              phone_number: phone_number_details[:phone_number],
              created_at: 8.days.ago
            )
          end

          it_behaves_like 'it returns a success response'
        end
      end

      context 'when phone number is invalid' do
        let_it_be(:risk_service_response) do
          ServiceResponse.error(message: 'Downstream error message', reason: :invalid_phone_number)
        end

        it 'returns an error', :aggregate_failures do
          response = service.execute

          expect(response).to be_a(ServiceResponse)
          expect(response).to be_error
          expect(response.message).to eq('Downstream error message')
          expect(response.reason).to eq(:invalid_phone_number)
        end
      end

      context 'when there is a client error in sending the verification code' do
        let_it_be(:send_verification_code_response) do
          ServiceResponse.error(message: 'Downstream error message', reason: :bad_request)
        end

        it 'returns an error', :aggregate_failures do
          response = service.execute

          expect(response).to be_a(ServiceResponse)
          expect(response).to be_error
          expect(response.message).to eq('Downstream error message')
          expect(response.reason).to eq(:bad_request)
        end
      end

      context 'when there is a TeleSign error in getting the risk score' do
        let_it_be(:risk_service_response) do
          ServiceResponse.error(message: 'Downstream error message', reason: :unknown_telesign_error)
        end

        it 'returns an error', :aggregate_failures do
          response = service.execute

          expect(response).to be_a(ServiceResponse)
          expect(response).to be_error
          expect(response.message).to eq('Downstream error message')
          expect(response.reason).to eq(:unknown_telesign_error)
        end

        it 'force verifies the user', :aggregate_failures, :freeze_time do
          service.execute
          record = user.phone_number_validation

          expect(record.validated_at).to eq(Time.now.utc)
          expect(record.risk_score).to eq(0)
          expect(record.telesign_reference_xid).to eq('unknown_telesign_error')
        end
      end

      context 'when there is a TeleSign error in sending the verification code' do
        let_it_be(:send_verification_code_response) do
          ServiceResponse.error(message: 'Downstream error message', reason: :unknown_telesign_error)
        end

        it 'returns an error', :aggregate_failures do
          response = service.execute

          expect(response).to be_a(ServiceResponse)
          expect(response).to be_error
          expect(response.message).to eq('Downstream error message')
          expect(response.reason).to eq(:unknown_telesign_error)
        end

        it 'force verifies the user', :aggregate_failures, :freeze_time do
          service.execute
          record = user.phone_number_validation

          expect(record.validated_at).to eq(Time.now.utc)
          expect(record.risk_score).to eq(0)
          expect(record.telesign_reference_xid).to eq('unknown_telesign_error')
        end
      end

      context 'when there is a server error in sending the verification code' do
        let_it_be(:send_verification_code_response) do
          ServiceResponse.error(message: 'Downstream error message', reason: :internal_server_error)
        end

        it 'returns an error', :aggregate_failures do
          response = service.execute

          expect(response).to be_a(ServiceResponse)
          expect(response).to be_error
          expect(response.message).to eq('Downstream error message')
          expect(response.reason).to eq(:internal_server_error)
        end
      end

      context 'when there is an unknown exception' do
        let(:exception) { StandardError.new }

        before do
          allow(Gitlab::ErrorTracking).to receive(:track_exception)
          allow_next_instance_of(PhoneVerification::TelesignClient::RiskScoreService) do |instance|
            allow(instance).to receive(:execute).and_raise(exception)
          end
        end

        it 'returns an error ServiceResponse', :aggregate_failures do
          response = service.execute

          expect(response).to be_a(ServiceResponse)
          expect(response).to be_error
          expect(response.message).to eq('Something went wrong. Please try again.')
          expect(response.reason).to be(:internal_server_error)
        end

        it 'tracks the exception' do
          service.execute

          expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(
            exception, user_id: user.id
          )
        end
      end

      context 'when verification code is sent successfully' do
        let_it_be(:telesign_reference_xid) { '123' }

        let_it_be(:send_verification_code_response) do
          ServiceResponse.success(payload: { telesign_reference_xid: telesign_reference_xid })
        end

        it 'increments phone verification transactions count' do
          expect(Gitlab::ApplicationRateLimiter).to receive(:throttled?)
            .with(:soft_phone_verification_transactions_limit, scope: :global).and_return(true)
          expect(Gitlab::ApplicationRateLimiter).to receive(:throttled?)
            .with(:hard_phone_verification_transactions_limit, scope: :global).and_return(true)
          service.execute
        end

        context 'when limit is hit' do
          where(:limit, :rate_limit_key) do
            'soft' | :soft_phone_verification_transactions_limit
            'hard' | :hard_phone_verification_transactions_limit
          end

          with_them do
            before do
              allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?).with(rate_limit_key,
                scope: :global).and_return(true)
            end

            it 'logs the event' do
              expect(Gitlab::AppLogger).to receive(:info).with({
                class: described_class.name,
                message: 'IdentityVerification::Phone',
                event: 'Phone verification daily transaction limit exceeded',
                exceeded_limit: rate_limit_key.to_s
              })

              service.execute
            end
          end
        end

        it_behaves_like 'it returns a success response'

        it 'saves the risk score and telesign_reference_xid', :aggregate_failures do
          service.execute
          record = user.phone_number_validation

          expect(record.risk_score).to eq(risk_score)
          expect(record.telesign_reference_xid).to eq(telesign_reference_xid)
        end

        it 'updates sms_send_count and sms_sent_at', :freeze_time do
          service.execute
          record = user.phone_number_validation
          expect(record.sms_send_count).to eq(1)
          expect(record.sms_sent_at).to eq(Time.current)
        end

        context 'when last SMS was sent before the current day' do
          before do
            create(:phone_number_validation, user: user, sms_sent_at: 1.day.ago, sms_send_count: 2)
          end

          it 'sets sms_send_count to 1' do
            record = user.phone_number_validation
            expect { service.execute }.to change { record.reload.sms_send_count }.from(2).to(1)
          end
        end

        context 'when send is allowed', :freeze_time do
          let_it_be(:record) do
            create(:phone_number_validation, user: user, sms_send_count: 1, sms_sent_at: Time.current)
          end

          let!(:old_sms_sent_at) { record.sms_sent_at }

          before do
            travel_to(5.minutes.from_now)
          end

          it_behaves_like 'it returns a success response'

          it 'increments sms_send_count and sets sms_sent_at', :aggregate_failures,
            quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/17090' do
            expect(record.sms_send_count).to eq 1
            expect(record.sms_sent_at).to be_within(1.second).of(old_sms_sent_at)

            service.execute
            record.reload

            expect(record.sms_send_count).to eq 2
            expect(record.sms_sent_at).to be_within(1.second).of(old_sms_sent_at + 5.minutes)
          end
        end

        context 'when send is not allowed', :freeze_time do
          let_it_be(:record) do
            create(:phone_number_validation, user: user, sms_send_count: 1, sms_sent_at: Time.current)
          end

          it 'returns an error', :aggregate_failures do
            response = service.execute

            expect(response).to be_a(ServiceResponse)
            expect(response).to be_error
            expect(response.message).to eq('Sending not allowed at this time')
            expect(response.reason).to eq(:send_not_allowed)
          end
        end
      end
    end

    context 'when telesign_intelligence_enabled application setting is set to false' do
      let_it_be(:send_verification_code_response) do
        ServiceResponse.success(payload: { telesign_reference_xid: '123' })
      end

      before do
        stub_application_setting(telesign_intelligence_enabled: false)
      end

      it_behaves_like 'it returns a success response'

      it 'does not save the risk_score' do
        service.execute
        record = user.phone_number_validation

        expect(record.risk_score).to eq 0
        expect(record.telesign_reference_xid).to eq '123'
      end
    end
  end
end
