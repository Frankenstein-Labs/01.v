# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::KeysController, feature_category: :system_access do
  let(:served_jwks) { Gitlab::Json.safe_parse(response.body)['keys'] }
  let(:served_kids) { served_jwks.map { |jwk| jwk['kid'] } }

  describe 'GET /-/cloud_connector/keys' do
    context 'with Cloud Connector keys present' do
      let_it_be(:cc_key_1) { create(:cloud_connector_keys) }
      let_it_be(:cc_key_2) { create(:cloud_connector_keys) }

      it 'serves the valid Cloud Connector keys as a public JWKS', :aggregate_failures do
        get '/-/cloud_connector/keys'

        expect(response).to have_gitlab_http_status(:ok)
        expect(served_kids).to match_array([cc_key_1.to_jwk.kid, cc_key_2.to_jwk.kid])
        expect(served_kids).to include(::CloudConnector::Keys.current.to_jwk.kid)
        expect(served_jwks).to all(
          match('kty' => 'RSA', 'n' => be_present, 'e' => be_present, 'kid' => be_present,
            'use' => 'sig', 'alg' => 'RS256')
        )
      end

      it 'sets a public, one-hour cache policy', :aggregate_failures do
        get '/-/cloud_connector/keys'

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers['Cache-Control'])
          .to include('max-age=3600', 'public', 'must-revalidate', 'no-transform')
      end
    end

    context 'without Cloud Connector keys' do
      it 'responds with an empty key set', :aggregate_failures do
        get '/-/cloud_connector/keys'

        expect(response).to have_gitlab_http_status(:ok)
        expect(served_jwks).to be_empty
      end
    end

    context 'when a key export would include private material' do
      it 'serves only public JWK members, never private RSA params' do
        leaky_export = {
          kty: 'RSA', n: 'public-n', e: 'AQAB', kid: 'some-kid', d: 'PRIVATE', p: 'PRIVATE', q: 'PRIVATE'
        }
        public_key = instance_double(OpenSSL::PKey::RSA, to_jwk: leaky_export)
        key = instance_double(::CloudConnector::Keys, public_key: public_key)
        allow(::CloudConnector::Keys).to receive(:valid).and_return([key])

        get '/-/cloud_connector/keys'

        expect(served_jwks.flat_map(&:keys)).to contain_exactly('kty', 'n', 'e', 'kid', 'use', 'alg')
      end
    end

    context 'when compared with the shared /oauth/discovery/keys endpoint' do
      let_it_be(:cc_key_1) { create(:cloud_connector_keys) }
      let_it_be(:cc_key_2) { create(:cloud_connector_keys) }

      before do
        # Give the shared endpoint OIDC + CI keys too, so it is a strict superset.
        allow(Rails.application.credentials)
          .to receive(:openid_connect_signing_key).and_return(OpenSSL::PKey::RSA.new(2048).to_pem)
        allow(Gitlab::CurrentSettings)
          .to receive(:ci_jwt_signing_key).and_return(OpenSSL::PKey::RSA.new(2048).to_pem)
      end

      it 'serves a strict subset of the shared set, presenting Cloud Connector keys identically',
        :aggregate_failures do
        get '/oauth/discovery/keys'
        shared_by_kid = Gitlab::Json.safe_parse(response.body)['keys'].index_by { |jwk| jwk['kid'] }

        get '/-/cloud_connector/keys'
        cc_by_kid = Gitlab::Json.safe_parse(response.body)['keys'].index_by { |jwk| jwk['kid'] }

        # The dedicated endpoint serves exactly the Cloud Connector keys...
        expect(cc_by_kid.keys).to match_array([cc_key_1.to_jwk.kid, cc_key_2.to_jwk.kid])
        # ...which are a strict subset of the shared set (it also carries OIDC + CI keys)...
        expect(shared_by_kid.keys).to include(*cc_by_kid.keys)
        expect(shared_by_kid.size).to be > cc_by_kid.size
        # ...and each Cloud Connector key is presented identically by both controllers.
        cc_by_kid.each { |kid, jwk| expect(jwk).to eq(shared_by_kid[kid]) }
      end
    end
  end
end
