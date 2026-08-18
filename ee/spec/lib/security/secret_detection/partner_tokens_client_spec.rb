# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::PartnerTokensClient, feature_category: :secret_detection do
  let(:finding) { create(:security_finding, :with_finding_data) }
  let(:token_type) { 'AWS' }
  let(:token_value) { 'AKIAIOSFODNN7EXAMPLE' }

  subject(:client) { described_class.new(finding) }

  before do
    allow(finding).to receive_messages(token_type: token_type, token_value: token_value)
  end

  shared_examples 'handles partner configuration' do |partner_type, expected_rate_limit_key|
    let(:token_type) { partner_type }
    let(:expected_config) do
      {
        client_class: ::Security::SecretDetection::PartnerTokens::AwsClient,
        rate_limit_key: expected_rate_limit_key,
        enabled: true
      }
    end

    before do
      allow(Security::SecretDetection::PartnerTokens::Registry)
        .to receive(:partner_for).with(partner_type).and_return(expected_config)
      allow(finding).to receive(:token_type).and_return(partner_type)
    end

    it "returns correct configuration for #{partner_type}" do
      expect(client.partner_config).to eq(expected_config)
    end

    it "checks rate limiting with #{expected_rate_limit_key}" do
      expect(::Gitlab::ApplicationRateLimiter).to receive(:throttled?)
        .with(expected_rate_limit_key, scope: [finding.project])
        .and_return(false)

      expect(client.rate_limited?).to be false
    end
  end

  describe '#valid_config?' do
    context 'when all requirements are met' do
      before do
        allow(client).to receive(:partner_config).and_return({ rate_limit_key: :partner_aws_api })
      end

      it 'returns true' do
        expect(client.valid_config?).to be true
      end
    end

    context 'when partner config is nil' do
      before do
        allow(client).to receive(:partner_config).and_return(nil)
      end

      it 'returns false' do
        expect(client.valid_config?).to be false
      end
    end

    context 'when token_type is nil' do
      before do
        allow(finding).to receive(:token_type).and_return(nil)
      end

      it 'returns false' do
        expect(client.valid_config?).to be false
      end
    end

    context 'when token_value is nil' do
      before do
        allow(finding).to receive(:token_value).and_return(nil)
      end

      it 'returns false' do
        expect(client.valid_config?).to be false
      end
    end
  end

  describe '#rate_limited?' do
    let(:expected_rate_limit_key) { :partner_aws_api }

    before do
      allow(client).to receive(:partner_config).and_return({
        rate_limit_key: expected_rate_limit_key
      })
    end

    it 'checks application rate limiter with correct key and scope' do
      expect(::Gitlab::ApplicationRateLimiter).to receive(:throttled?)
        .with(expected_rate_limit_key, scope: [finding.project])
        .and_return(false)

      expect(client.rate_limited?).to be false
    end

    it 'returns true when rate limited' do
      allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?)
        .with(expected_rate_limit_key, scope: [finding.project])
        .and_return(true)

      expect(Gitlab::Metrics::SecretDetection::PartnerTokens)
        .to receive(:increment_rate_limit_hits)
        .with(limit_type: expected_rate_limit_key.to_s)

      expect(Gitlab::AppLogger).to receive(:warn).with(
        message: 'Rate limit exceeded for partner token verification',
        finding_id: finding.id,
        project_id: finding.project.id,
        project_path: finding.project.full_path,
        token_type: token_type,
        rate_limit_key: expected_rate_limit_key
      )

      expect(client.rate_limited?).to be true
    end
  end

  describe '#partner_config' do
    context 'with valid token type' do
      let(:expected_config) do
        {
          client_class: ::Security::SecretDetection::PartnerTokens::AwsClient,
          rate_limit_key: :partner_aws_api,
          enabled: true
        }
      end

      before do
        allow(::Security::SecretDetection::PartnerTokens::Registry)
          .to receive(:partner_for).with('AWS').and_return(expected_config)
      end

      it 'returns partner configuration from registry' do
        expect(client.partner_config).to eq(expected_config)
      end
    end

    context 'with invalid token type' do
      before do
        allow(finding).to receive(:token_type).and_return('INVALID')
        allow(::Security::SecretDetection::PartnerTokens::Registry)
          .to receive(:partner_for).with('INVALID').and_return(nil)
      end

      it 'returns nil for unsupported token type' do
        expect(client.partner_config).to be_nil
      end
    end

    where(:partner_type, :rate_limit_key) do
      [
        ['AWS', :partner_aws_api],
        ['GCP API key', :partner_gcp_api],
        ['Postman API token', :partner_postman_api]
      ]
    end

    with_them do
      it_behaves_like 'handles partner configuration', params[:partner_type], params[:rate_limit_key]
    end
  end

  describe '#verify_token' do
    let(:verification_result) do
      Security::SecretDetection::PartnerTokens::BaseClient::TokenStatus.new(
        status: :active,
        metadata: { verified_at: Time.zone.now }
      )
    end

    let(:mock_client) { instance_double(Security::SecretDetection::PartnerTokens::AwsClient) }

    before do
      allow(::Security::SecretDetection::PartnerTokens::Registry)
        .to receive(:client_for).with('AWS').and_return(mock_client)
      allow(mock_client).to receive(:verify_token).with('AKIAIOSFODNN7EXAMPLE').and_return(verification_result)
    end

    it 'creates client from registry and verifies token' do
      expect(::Security::SecretDetection::PartnerTokens::Registry)
        .to receive(:client_for).with('AWS')
      expect(mock_client).to receive(:verify_token).with('AKIAIOSFODNN7EXAMPLE')

      result = client.verify_token
      expect(result).to eq(verification_result)
    end
  end
end
