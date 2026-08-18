# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JwksController, feature_category: :system_access do
  describe '/oauth/discovery/keys' do
    include_context 'when doing OIDC key discovery'

    it 'includes Cloud Connector keys' do
      expect(Rails.application.credentials).to receive(:openid_connect_signing_key).and_return(nil)
      expect(Gitlab::CurrentSettings).to receive(:ci_jwt_signing_key).and_return(nil)
      expect(CloudConnector::Keys).to receive(:all_as_pem).and_return([rsa_key_1.to_pem, rsa_key_2.to_pem])

      expect(jwks.size).to eq(2)
      expect(jwks).to match_array([
        satisfy { |jwk| key_match?(jwk, rsa_key_1) },
        satisfy { |jwk| key_match?(jwk, rsa_key_2) }
      ])
    end
  end
end
