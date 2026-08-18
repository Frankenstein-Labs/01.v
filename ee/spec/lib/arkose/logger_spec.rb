# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Arkose::Logger, feature_category: :instance_resiliency do
  let_it_be(:user) { build_stubbed(:user, email: 'test@example.com') }
  let_it_be(:session_token) { '22612c147bb418c8.2570749403' }

  let_it_be(:mock_correlation_id) { 'be025cf83013ac4f52ffd2bf712b11a2' }
  let_it_be(:json_verify_response) do
    Gitlab::Json.parse(File.read(Rails.root.join('ee/spec/fixtures/arkose/successfully_solved_ec_response.json')))
  end

  let(:verify_response) { Arkose::VerifyResponse.new(json_verify_response) }
  let(:logger) { described_class.new(session_token: session_token, user: user, verify_response: verify_response) }

  let(:expected_payload) do
    {
      correlation_id: mock_correlation_id,
      message: log_message,
      response: json_verify_response,
      username: user&.username,
      email_domain: 'example.com',
      'arkose.session_id': '22612c147bb418c8.2570749403',
      'arkose.session_is_legit': false,
      'arkose.global_score': '0',
      'arkose.global_telltale_list': [],
      'arkose.custom_score': '0',
      'arkose.custom_telltale_list': [],
      'arkose.risk_band': 'Low',
      'arkose.risk_category': 'NO-THREAT',
      'arkose.challenge_type': 'visual',
      'arkose.country': 'AU',
      'arkose.is_bot': true,
      'arkose.is_vpn': true,
      'arkose.data_exchange_blob_received': false,
      'arkose.data_exchange_blob_decrypted': false
    }.compact
  end

  before do
    allow(Gitlab::AppLogger).to receive(:info)
    allow(Gitlab::ApplicationContext).to receive(:current).and_return(
      { correlation_id: mock_correlation_id }
    )
  end

  shared_examples 'logs the event with the correct payload' do
    it 'logs the event with the correct info' do
      expect(expected_payload).to include(:username)
      expect(Gitlab::AppLogger).to receive(:info).with(expected_payload)

      subject
    end
  end

  shared_examples 'logs the event without user info' do
    context 'when user is nil' do
      let(:user) { nil }

      it 'logs the event without user info' do
        user_info = [:username, :email_domain]
        expect(Gitlab::AppLogger).to receive(:info).with(expected_payload.except(*user_info))

        subject
      end
    end
  end

  describe '#log_successful_token_verification' do
    let(:log_message) { 'Arkose challenge solved' }

    subject { logger.log_successful_token_verification }

    it_behaves_like 'logs the event with the correct payload'
    it_behaves_like 'logs the event without user info'
  end

  describe '#log_invalid_token' do
    let(:log_message) { 'Arkose was unable to verify the token' }

    subject { logger.log_invalid_token }

    it_behaves_like 'logs the event with the correct payload'
    it_behaves_like 'logs the event without user info'
  end

  describe '#log_unsolved_challenge' do
    let(:log_message) { 'Arkose challenge not solved' }

    subject { logger.log_unsolved_challenge }

    it_behaves_like 'logs the event with the correct payload'
    it_behaves_like 'logs the event without user info'
  end

  describe '#log_risk_band_assignment' do
    let(:log_message) { 'Arkose risk band assigned to user' }

    subject { logger.log_risk_band_assignment }

    it_behaves_like 'logs the event with the correct payload'

    context 'when user is nil' do
      let(:user) { nil }

      it 'does nothing' do
        expect(Gitlab::AppLogger).not_to receive(:info)
      end
    end
  end

  describe '#log_failed_token_verification' do
    subject(:logger) { described_class.new(session_token: session_token, user: user, verify_response: nil) }

    it 'logs the event with the correct info' do
      payload = { session_token: session_token, log_data: user.id }

      expect(Gitlab::AppLogger).to receive(:error).with(a_string_including(
        "Arkose returned an error while verifying token: #{payload}"
      ))

      logger.log_failed_token_verification
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'logs the event with the correct info' do
        payload = { session_token: session_token, log_data: nil }

        expect(Gitlab::AppLogger).to receive(:error).with(a_string_including(
          "Arkose returned an error while verifying token: #{payload}"
        ))

        logger.log_failed_token_verification
      end
    end
  end
end
