# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GlobalSecretsManagerJwt, feature_category: :secrets_management do
  let_it_be(:user) { create(:user) }
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(3072) }

  before do
    stub_application_setting(ci_jwt_signing_key: rsa_key.to_s)
  end

  describe 'constants' do
    it 'defines DEFAULT_TTL' do
      expect(described_class::DEFAULT_TTL).to eq(30.seconds)
    end

    it 'defines SYSTEM_UID' do
      expect(described_class::SYSTEM_UID).to eq('gitlab_secrets_manager')
    end
  end

  describe '#payload', :freeze_time do
    let(:payload) { jwt.payload }
    let(:now) { Time.now.to_i }

    before do
      allow(SecureRandom).to receive(:uuid).and_return('test-uuid')
      allow(Labkit::Correlation::CorrelationId).to receive(:current_id).and_return('test-correlation-id')
    end

    context 'without current_user' do
      subject(:jwt) { described_class.new }

      it 'includes the standard JWT claims' do
        expect(payload).to include(
          iss: Gitlab.config.gitlab.url,
          iat: now,
          nbf: now,
          exp: now + described_class::DEFAULT_TTL.to_i,
          jti: 'test-uuid',
          aud: 'http://127.0.0.1:9800',
          sub: 'gitlab_secrets_manager',
          secrets_manager_scope: 'privileged',
          correlation_id: 'test-correlation-id'
        )
      end

      it 'includes system-level resource claims' do
        expect(payload).to include(
          user_id: described_class::SYSTEM_UID
        )
      end
    end

    context 'with a custom ttl' do
      subject(:jwt) { described_class.new(ttl: 5.minutes) }

      it 'sets exp using the given ttl' do
        expect(payload[:exp]).to eq(now + 5.minutes.to_i)
      end
    end

    context 'without a ttl' do
      subject(:jwt) { described_class.new }

      it 'falls back to DEFAULT_TTL' do
        expect(payload[:exp]).to eq(now + described_class::DEFAULT_TTL.to_i)
      end
    end

    context 'with current_user' do
      subject(:jwt) { described_class.new(current_user: user) }

      it 'includes the standard JWT claims' do
        expect(payload).to include(
          iss: Gitlab.config.gitlab.url,
          iat: now,
          nbf: now,
          exp: now + described_class::DEFAULT_TTL.to_i,
          jti: 'test-uuid',
          aud: 'http://127.0.0.1:9800',
          sub: 'gitlab_secrets_manager',
          secrets_manager_scope: 'privileged',
          correlation_id: 'test-correlation-id'
        )
      end

      it 'includes system-level resource claims' do
        expect(payload).to include(
          user_id: described_class::SYSTEM_UID
        )
      end
    end
  end

  describe '#encoded' do
    subject(:jwt) { described_class.new }

    it 'returns an encoded JWT string' do
      encoded_token = jwt.encoded

      expect(encoded_token.split('.').size).to eq(3)
    end

    it 'can be decoded with the correct key' do
      encoded_token = jwt.encoded

      decoded_token = JWT.decode(encoded_token, rsa_key.public_key, true, { algorithm: 'RS256' })

      expect(decoded_token.first).to include('iss', 'iat', 'nbf', 'exp', 'jti', 'aud', 'sub')
    end
  end
end
