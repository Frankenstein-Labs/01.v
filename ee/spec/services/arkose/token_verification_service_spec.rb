# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Arkose::TokenVerificationService, feature_category: :instance_resiliency do
  let(:user) { create(:user) }
  let(:email) { nil }
  let(:session_token) { '22612c147bb418c8.2570749403' }
  let(:service) { described_class.new(session_token: session_token, user: user, email: email) }
  let(:verify_api_url) { "https://verify-api.arkoselabs.com/api/v4/verify/" }
  let(:arkose_labs_private_api_key) { 'foo' }

  let(:arkose_ec_response) { {} }
  let(:mock_verify_response) { Arkose::VerifyResponse.new(arkose_ec_response) }
  let(:log_args) { { session_token: session_token, user: user, verify_response: mock_verify_response } }

  subject { service.execute }

  def verify_request_body
    # Match a request only when all expected values in the payload have the correct types
    body = {
      private_key: an_instance_of(String),
      session_token: an_instance_of(String)
    }

    body[:log_data] = an_instance_of(String) if user
    body[:email_address] = an_instance_of(String) if user || email

    body
  end

  before do
    allow_next_instance_of(Arkose::RecordUserDataService) do |service|
      allow(service).to receive(:execute)
    end

    stub_request(:post, verify_api_url)
      .with(
        body: verify_request_body,
        headers: {
          'Accept' => '*/*',
          'Content-Type' => 'application/json'
        }
      ).to_return(
        status: 200,
        body: arkose_ec_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    if mock_verify_response
      allow(Arkose::VerifyResponse)
      .to receive(:new).with(arkose_ec_response)
      .and_return(mock_verify_response)
    end
  end

  describe '#execute' do
    shared_examples_for 'interacting with Arkose verify API' do |url|
      let(:verify_api_url) { url }

      context 'when the user did not solve the challenge' do
        let(:arkose_ec_response) do
          Gitlab::Json.parse(File.read(Rails.root.join('ee/spec/fixtures/arkose/failed_ec_response.json')))
        end

        it 'returns an error response' do
          expect(subject).to be_error
        end

        it 'returns an error message' do
          expect(subject.message).to eq 'Captcha was not solved'
        end
      end

      context 'when the token is invalid' do
        let(:arkose_ec_response) do
          Gitlab::Json.parse(File.read(Rails.root.join('ee/spec/fixtures/arkose/invalid_token.json')))
        end

        it 'returns an error response' do
          expect(subject).to be_error
        end

        it 'logs the event' do
          expect_next_instance_of(::Arkose::Logger, log_args) do |logger|
            expect(logger).to receive(:log_invalid_token)
          end

          subject
        end

        it 'returns an error message' do
          expect(subject.message).to eq 'Captcha was not solved'
        end

        it 'tracks failure via fail-open' do
          expect(AntiAbuse::IdentityVerification::ArkoseFailOpen).to receive(:track_token_verification_result)
            .with(success: false).once
          subject
        end
      end

      shared_examples 'returns success response with the correct payload' do
        let(:expected_response_json) { arkose_ec_response }

        it 'returns a success response' do
          expect(subject).to be_success
        end

        it 'includes the json response in the payload' do
          expect(subject.payload[:response].response).to eq expected_response_json
        end
      end

      context 'when arkose is enabled' do
        context 'when the user solved the challenge' do
          context 'when the risk score is low' do
            let(:arkose_ec_response) do
              Gitlab::Json.parse(
                File.read(Rails.root.join('ee/spec/fixtures/arkose/successfully_solved_ec_response.json'))
              )
            end

            it 'makes a request to the Verify API' do
              subject

              expect(WebMock).to have_requested(:post, verify_api_url)
            end

            it_behaves_like 'returns success response with the correct payload'

            it 'logs the event' do
              expect_next_instance_of(::Arkose::Logger, log_args) do |logger|
                expect(logger).to receive(:log_successful_token_verification)
              end

              subject
            end

            it "records user's Arkose data" do
              init_args = { response: mock_verify_response, user: user }
              expect_next_instance_of(Arkose::RecordUserDataService, init_args) do |service|
                expect(service).to receive(:execute)
              end

              subject
            end

            it 'tracks successful token verification result' do
              expect(AntiAbuse::IdentityVerification::ArkoseFailOpen).to receive(:track_token_verification_result)
                .with(success: true).once
              subject
            end

            it 'passes the user email as email_address' do
              subject

              expect(WebMock).to have_requested(:post, verify_api_url)
                .with { |req| Gitlab::Json.parse(req.body)["email_address"] == user.email }
            end

            context 'when the email is present' do
              let(:email) { 'emailanduser@example.com' }

              it 'passes the user email as email_address' do
                subject

                expect(WebMock).to have_requested(:post, verify_api_url)
                  .with { |req| Gitlab::Json.parse(req.body)["email_address"] == user.email }
              end
            end

            context 'when the user is nil' do
              let(:user) { nil }

              it 'does not record Arkose data' do
                expect(Arkose::RecordUserDataService).not_to receive(:new)

                subject
              end

              context 'when the email is present' do
                let(:email) { 'emailnouser@example.com' }

                it 'passes the email as email_address' do
                  subject

                  expect(WebMock).to have_requested(:post, verify_api_url)
                    .with { |req| Gitlab::Json.parse(req.body)["email_address"] == email }
                end
              end
            end

            context 'when the session is allowlisted' do
              let(:arkose_ec_response) do
                json = Gitlab::Json.parse(
                  File.read(Rails.root.join('ee/spec/fixtures/arkose/successfully_solved_ec_response_high_risk.json'))
                )
                json['session_details']['telltale_list'].push(Arkose::VerifyResponse::ALLOWLIST_TELLTALE)
                json
              end

              it_behaves_like 'returns success response with the correct payload'

              it 'tracks successful token verification result' do
                expect(AntiAbuse::IdentityVerification::ArkoseFailOpen).to receive(:track_token_verification_result)
                  .with(success: true).once
                subject
              end
            end

            context 'when the risk score is high' do
              let(:arkose_ec_response) do
                Gitlab::Json.parse(
                  File.read(Rails.root.join('ee/spec/fixtures/arkose/successfully_solved_ec_response_high_risk.json'))
                )
              end

              it_behaves_like 'returns success response with the correct payload'
            end
          end
        end

        context 'when the response does not include the risk session' do
          context 'when the user solved the challenge' do
            let(:arkose_ec_response) do
              Gitlab::Json.parse(
                File.read(
                  Rails.root.join('ee/spec/fixtures/arkose/successfully_solved_ec_response_without_session_risk.json')
                )
              )
            end

            it_behaves_like 'returns success response with the correct payload'
          end

          context 'when the user did not solve the challenge' do
            let(:arkose_ec_response) do
              Gitlab::Json.parse(
                File.read(Rails.root.join('ee/spec/fixtures/arkose/failed_ec_response_without_risk_session.json'))
              )
            end

            it 'returns an error response' do
              expect(subject).to be_error
            end

            it 'returns an error message' do
              expect(subject.message).to eq 'Captcha was not solved'
            end

            it 'logs the event' do
              expect_next_instance_of(::Arkose::Logger, log_args) do |logger|
                expect(logger).to receive(:log_unsolved_challenge)
              end

              subject
            end

            it 'tracks successful token verification result' do
              expect(AntiAbuse::IdentityVerification::ArkoseFailOpen).to receive(:track_token_verification_result)
                .with(success: true).once
              subject
            end
          end
        end
      end

      shared_examples 'an unexpected token verification failure' do
        let(:mock_verify_response) { nil }

        it 'logs the event' do
          expect_next_instance_of(::Arkose::Logger, log_args) do |logger|
            expect(logger).to receive(:log_failed_token_verification)
          end

          subject
        end

        it 'does not record Arkose data' do
          expect(Arkose::RecordUserDataService).not_to receive(:new)

          subject
        end

        it 'assumes low risk for the user' do
          expect { subject }.to change {
            user.custom_attributes.by_key(IdentityVerification::UserRiskProfile::ASSUMED_LOW_RISK_ATTR_KEY).count
          }.from(0).to(1)
        end
      end

      context 'when response from Arkose is not what we expect' do
        # For example: https://gitlab.com/gitlab-org/modelops/anti-abuse/team-tasks/-/issues/54

        let(:arkose_ec_response) { 'unexpected_from_arkose' }
        let(:mock_verify_response) { nil }

        it_behaves_like 'returns success response with the correct payload' do
          let(:expected_response_json) { {} }
        end

        it_behaves_like 'an unexpected token verification failure'
      end

      context 'when an error occurs during the Arkose request' do
        let(:arkose_ec_response) { {} }

        before do
          allow(Gitlab::HTTP).to receive(:perform_request).and_raise(Errno::ECONNREFUSED.new('bad connection'))
        end

        it_behaves_like 'returns success response with the correct payload'
        it_behaves_like 'an unexpected token verification failure'
      end
    end

    context 'when calling the Arkose::TokenVerificationService' do
      before do
        stub_application_setting(arkose_labs_private_api_key: arkose_labs_private_api_key)
        stub_application_setting(arkose_labs_namespace: "gitlab")
      end

      it_behaves_like 'interacting with Arkose verify API', "https://gitlab-verify.arkoselabs.com/api/v4/verify/"
    end
  end
end
