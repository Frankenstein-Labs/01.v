# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::TokenExchange::TokenIssuer, feature_category: :system_access do
  let_it_be(:cloud_connector_key) { create(:cloud_connector_keys) }
  let_it_be(:user) { create(:user) }

  let(:audience) { ['gitlab-artifact-registry'] }
  let(:ttl) { 300 }

  before do
    # CachingKeyLoader memoizes Keys.current at the class level, which leaks
    # across specs when other specs also create keys. Pin it to ours.
    allow(::CloudConnector::CachingKeyLoader).to receive(:private_jwk)
      .and_return(cloud_connector_key.to_jwk)
    allow(Doorkeeper::OpenidConnect.configuration).to receive(:issuer)
      .and_return('http://test.host/oauth-issuer')
  end

  subject(:issuer) do
    described_class.new(audience: audience, user: user, ttl: ttl)
  end

  describe '#token' do
    it 'returns a signed JWT with the expected claim shape', :aggregate_failures do
      token = issuer.token

      payload, header = JWT.decode(token, cloud_connector_key.public_key, true, algorithm: 'RS256')

      expect(header).to include('typ' => 'JWT', 'alg' => 'RS256')
      expect(header['kid']).to eq(cloud_connector_key.to_jwk.kid)

      expect(payload).to include(
        'iss' => 'http://test.host/oauth-issuer',
        'aud' => %w[gitlab-artifact-registry gitlab-iam-data-access],
        'sub' => user.to_global_id.to_s,
        'ver' => 1
      )
      expect(payload['gitlab']).to include(
        'origin' => 'organization',
        'origin_id' => user.organization.uuid,
        'local_id' => user.id,
        'identity_kind' => 'user',
        'organization_role' => 'member'
      )
      expect(payload['jti']).to match(/\A[0-9a-f-]{36}\z/)

      %w[gitlab_realm gitlab_organization_id gitlab_organization_role].each do |removed|
        expect(payload).not_to have_key(removed)
      end
    end

    it 'always scopes the token to iam-data-access without duplicating it' do
      token = described_class.new(audience: [described_class::DATA_ACCESS_AUDIENCE], user: user).token
      payload, = JWT.decode(token, cloud_connector_key.public_key, true, algorithm: 'RS256')

      expect(payload['aud']).to match_array([described_class::DATA_ACCESS_AUDIENCE])
    end

    it 'coerces a String audience to an array' do
      token = described_class.new(audience: 'gitlab-artifact-registry', user: user).token
      payload, = JWT.decode(token, cloud_connector_key.public_key, true, algorithm: 'RS256')

      expect(payload['aud']).to match_array(['gitlab-artifact-registry', described_class::DATA_ACCESS_AUDIENCE])
    end

    it 'sets iat, nbf, and exp', :freeze_time, :aggregate_failures do
      token = issuer.token
      payload, = JWT.decode(token, cloud_connector_key.public_key, true, algorithm: 'RS256')

      expect(payload['iat']).to eq(Time.current.to_i)
      expect(payload['nbf']).to eq(Time.current.to_i)
      expect(payload['exp']).to eq(Time.current.to_i + ttl)
    end

    it 'defaults exp to DEFAULT_TTL_SECONDS when ttl is omitted', :freeze_time do
      token = described_class.new(audience: audience, user: user).token
      payload, = JWT.decode(token, cloud_connector_key.public_key, true, algorithm: 'RS256')

      expect(payload['exp']).to eq(Time.current.to_i + described_class::DEFAULT_TTL_SECONDS)
    end

    it 'generates a fresh jti per mint' do
      jti1 = JWT.decode(issuer.token, nil, false).first['jti']
      jti2 = JWT.decode(issuer.token, nil, false).first['jti']

      expect(jti1).not_to eq(jti2)
    end

    describe 'organization_role claim' do
      def decoded_role(for_user)
        token = described_class.new(audience: audience, user: for_user, ttl: ttl).token
        decoded = JWT.decode(token, cloud_connector_key.public_key, true, algorithm: 'RS256').first
        decoded.dig('gitlab', 'organization_role')
      end

      it "emits 'member' when the user does not own the organization" do
        expect(decoded_role(user)).to eq('member')
      end

      it "emits 'owner' when the user owns the organization" do
        owner = create(:user)
        owner.organization_users.find_by(organization: owner.organization).update!(access_level: :owner)

        expect(decoded_role(owner)).to eq('owner')
      end
    end
  end
end
