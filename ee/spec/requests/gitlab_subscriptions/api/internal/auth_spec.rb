# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::API::Internal::Auth, :aggregate_failures, :api, feature_category: :plan_provisioning do
  let(:subscriptions_host) { Gitlab::Routing.url_helpers.subscription_portal_url }

  describe '.verify_api_request' do
    let_it_be(:internal_api_jwk) { ::JWT::JWK.new(OpenSSL::PKey.generate_key('RSA')) }
    let_it_be(:unrelated_jwk) { ::JWT::JWK.new(OpenSSL::PKey.generate_key('RSA')) }

    context 'when the request does not have the internal token header' do
      it 'returns nil' do
        headers = { 'Other-Header' => 'test-token' }

        expect(described_class.verify_api_request(headers)).to be_nil
      end
    end

    context 'when the open ID configuration cannot be fetched', :use_clean_rails_redis_caching do
      let(:token) { generate_token(jwk: internal_api_jwk, payload: jwt_payload) }

      before do
        stub_open_id_configuration(success: false, json: { error: 'test-error' })
      end

      it 'returns nil' do
        expect(described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })).to be_nil
      end

      it 'does not cache the open ID configuration' do
        described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })

        expect(Rails.cache.read('customers-dot-internal-api-oidc')).to be_nil
      end
    end

    context 'when the JWKS cannot be fetched', :use_clean_rails_redis_caching do
      let(:token) { generate_token(jwk: internal_api_jwk, payload: jwt_payload) }

      before do
        stub_open_id_configuration
        stub_keys_discovery(success: false)
      end

      it 'returns nil' do
        expect(described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })).to be_nil
      end

      it 'does not cache the JWK response' do
        described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })

        expect(Rails.cache.read('customers-dot-internal-api-jwks')).to be_nil
      end
    end

    context 'when the JWKs data is already cached', :use_clean_rails_redis_caching do
      it 'does not need to call the CustomersDot API' do
        Rails.cache.write('customers-dot-internal-api-oidc', valid_open_id_configuration)
        Rails.cache.write('customers-dot-internal-api-jwks', export_jwks([unrelated_jwk, internal_api_jwk]))

        token = generate_token(jwk: internal_api_jwk, payload: jwt_payload)

        expect(described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })).to be_present
      end
    end

    context 'when the JWKs can be fetched from the subscription portal', :freeze_time do
      before do
        stub_open_id_configuration
        stub_keys_discovery(jwks: [unrelated_jwk, internal_api_jwk])
      end

      it 'caches the JWK data', :use_clean_rails_redis_caching do
        token = generate_token(jwk: internal_api_jwk, payload: jwt_payload)

        described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })

        expect(Rails.cache.read('customers-dot-internal-api-oidc')).to eq valid_open_id_configuration
        expect(Rails.cache.read('customers-dot-internal-api-jwks')).to eq export_jwks([unrelated_jwk, internal_api_jwk])
      end

      context 'when the token has the wrong issuer' do
        it 'returns nil' do
          token = generate_token(jwk: internal_api_jwk, payload: jwt_payload(iss: 'some-other-issuer'))

          expect(described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })).to be_nil
        end
      end

      context 'when the token has the wrong subject' do
        it 'returns nil' do
          token = generate_token(jwk: internal_api_jwk, payload: jwt_payload(sub: 'some-other-subject'))

          expect(described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })).to be_nil
        end
      end

      context 'when the token has the wrong audience' do
        it 'returns nil' do
          token = generate_token(jwk: internal_api_jwk, payload: jwt_payload(aud: 'some-other-audience'))

          expect(described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })).to be_nil
        end
      end

      context 'when the token has expired' do
        it 'returns nil' do
          token = generate_token(
            jwk: internal_api_jwk,
            payload: jwt_payload(iat: 10.minutes.ago.to_i, exp: 5.minutes.ago.to_i)
          )

          expect(described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })).to be_nil
        end
      end

      context 'when the token cannot be decoded using the CustomersDot JWKs' do
        it 'returns nil' do
          token = generate_token(jwk: ::JWT::JWK.new(OpenSSL::PKey.generate_key('RSA')), payload: jwt_payload)

          expect(described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })).to be_nil
        end
      end

      context 'when the token can be decoded using CustomersDot JWKs' do
        it 'returns the decoded JWT' do
          token = generate_token(jwk: internal_api_jwk, payload: jwt_payload)

          expect(described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })).to match_array(
            [jwt_payload.stringify_keys, { 'typ' => 'JWT', 'kid' => internal_api_jwk.kid, 'alg' => 'RS256' }]
          )
        end
      end
    end

    def generate_token(jwk:, payload:)
      JWT.encode(payload, jwk.keypair, 'RS256', { typ: 'JWT', kid: jwk.kid })
    end

    def jwt_payload(**options)
      {
        aud: 'gitlab-subscriptions',
        sub: 'customers-dot-internal-api',
        iss: "#{subscriptions_host}/",
        exp: (Time.current.to_i + 5.minutes.to_i)
      }.merge(options)
    end

    def valid_open_id_configuration
      {
        'issuer' => "#{subscriptions_host}/",
        'jwks_uri' => "#{subscriptions_host}/oauth/discovery/keys",
        'id_token_signing_alg_values_supported' => ['RS256']
      }
    end

    def stub_open_id_configuration(success: true, json: valid_open_id_configuration)
      allow(Gitlab::HTTP)
        .to receive(:get)
        .with("#{subscriptions_host}/.well-known/openid-configuration")
        .and_return(instance_double(HTTParty::Response, ok?: success, parsed_response: json))
    end

    def export_jwks(jwks)
      {
        'keys' => jwks.map { |jwk| jwk.export.merge('use' => 'sig', 'alg' => 'RS256') }
      }
    end

    def stub_keys_discovery(success: true, jwks: [])
      allow(Gitlab::HTTP)
        .to receive(:get)
        .with("#{subscriptions_host}/oauth/discovery/keys")
        .and_return(instance_double(HTTParty::Response, ok?: success, parsed_response: export_jwks(jwks)))
    end
  end
end
