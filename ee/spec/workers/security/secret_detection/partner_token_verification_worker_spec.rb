# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::PartnerTokenVerificationWorker, :clean_gitlab_redis_rate_limiting, feature_category: :secret_detection do
  subject(:worker) { described_class.new }

  let_it_be(:project) { create(:project) }
  let(:finding_type) { 'security' }
  let(:rate_limit_retry_count) { '0' }
  let(:client_instance) { instance_double(Security::SecretDetection::PartnerTokensClient) }
  let(:token_type) { 'AWS' }
  let(:token_value) { 'AKIAIOSFODNN7EXAMPLE' }

  shared_examples 'verifies token and saves status' do |_status_model, service_class|
    it 'verifies token and saves result', :freeze_time do
      expect(client_instance).to receive(:verify_token).and_return(verification_result)
      expect(service_class).to receive(:save_result).with(finding, verification_result)

      worker.perform(finding_id, finding_type, rate_limit_retry_count)
    end
  end

  shared_examples 'handles rate limiting' do
    it 'reschedules when rate limited' do
      expect(described_class).to receive(:perform_in)
        .with(described_class::BASE_DELAY, finding_id, anything, 1)

      worker.perform(finding_id, finding_type, rate_limit_retry_count)
    end
  end

  describe '#perform' do
    before do
      allow(Security::SecretDetection::PartnerTokensClient)
        .to receive(:new).and_return(client_instance)
      allow(client_instance).to receive_messages(verify_token: verification_result, valid_config?: true)
    end

    let(:verification_result) do
      Security::SecretDetection::PartnerTokens::BaseClient::TokenStatus.new(
        status: :active,
        metadata: { verified_at: Time.zone.now }
      )
    end

    context 'with security finding' do
      let_it_be(:security_finding) { create(:security_finding, :with_finding_data) }
      let(:finding_id) { security_finding.id }
      let(:finding) { security_finding }

      before do
        allow(client_instance).to receive(:rate_limited?).and_return(false)
      end

      it_behaves_like 'verifies token and saves status', ::Security::FindingTokenStatus,
        Security::SecretDetection::Security::PartnerTokenService
    end

    context 'with vulnerability finding' do
      let(:finding_type) { 'vulnerability' }
      let_it_be(:vulnerability_finding) { create(:vulnerabilities_finding, :with_secret_detection) }
      let(:finding_id) { vulnerability_finding.id }
      let(:finding) { vulnerability_finding }

      before do
        allow(client_instance).to receive(:rate_limited?).and_return(false)
      end

      it_behaves_like 'verifies token and saves status', ::Vulnerabilities::FindingTokenStatus,
        Security::SecretDetection::Vulnerabilities::PartnerTokenService
    end

    context 'when finding does not exist' do
      it 'returns early without API calls' do
        expect(Security::SecretDetection::PartnerTokensClient).not_to receive(:new)
        worker.perform(non_existing_record_id, finding_type, rate_limit_retry_count)
      end
    end

    context 'when partner config invalid' do
      let_it_be(:security_finding) { create(:security_finding) }
      let(:finding_id) { security_finding.id }

      before do
        allow(security_finding).to receive_messages(token_type: 'INVALID', token_value: 'invalid_token')
        allow(client_instance).to receive(:valid_config?).and_return(false)
      end

      it 'returns early without API calls' do
        expect(client_instance).not_to receive(:verify_token)
        worker.perform(finding_id, finding_type, rate_limit_retry_count)
      end
    end

    context 'with rate limiting' do
      let_it_be(:security_finding) { create(:security_finding, :with_finding_data) }
      let(:finding_id) { security_finding.id }

      before do
        allow(security_finding).to receive_messages(token_type: token_type, token_value: token_value)
        allow(client_instance).to receive(:valid_config?).and_return(true)
      end

      context 'when client rate limited' do
        before do
          allow(client_instance).to receive(:rate_limited?).and_return(true)
        end

        it_behaves_like 'handles rate limiting'
      end

      context 'when max retries exceeded' do
        let(:rate_limit_retry_count) { described_class::MAX_RATE_LIMIT_RETRIES.to_s }

        it 'returns without processing' do
          expect(described_class).not_to receive(:perform_in)
          worker.perform(finding_id, finding_type, rate_limit_retry_count)
        end
      end
    end

    context 'with error handling' do
      let_it_be(:security_finding) { create(:security_finding, :with_finding_data) }
      let(:finding_id) { security_finding.id }

      before do
        allow(security_finding).to receive_messages(token_type: token_type, token_value: token_value)
        allow(client_instance).to receive_messages(valid_config?: true, rate_limited?: false)
      end

      context 'with RateLimitError' do
        before do
          allow(client_instance).to receive(:verify_token)
            .and_raise(::Security::SecretDetection::PartnerTokens::BaseClient::RateLimitError)
        end

        it_behaves_like 'handles rate limiting'
      end

      it 'propagates NetworkError for Sidekiq retry' do
        allow(client_instance).to receive(:verify_token)
          .and_raise(::Security::SecretDetection::PartnerTokens::BaseClient::NetworkError, 'Network failed')

        expect { worker.perform(finding_id, finding_type, rate_limit_retry_count) }
          .to raise_error(::Security::SecretDetection::PartnerTokens::BaseClient::NetworkError)
      end
    end
  end

  describe 'worker configuration' do
    it { expect(described_class.idempotent?).to be true }
    it { expect(described_class.get_feature_category).to eq(:secret_detection) }
  end
end
