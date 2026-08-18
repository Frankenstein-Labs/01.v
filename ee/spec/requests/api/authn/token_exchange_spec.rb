# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Authn::TokenExchange, feature_category: :system_access do
  let_it_be(:user) { create(:user) }
  let_it_be(:pat) { create(:personal_access_token, user: user) }
  let_it_be(:second_user) { create(:user) }
  let_it_be(:second_pat) { create(:personal_access_token, user: second_user) }
  let_it_be(:cloud_connector_keys) { create(:cloud_connector_keys) }

  let(:url) { '/token_exchange' }
  let(:params) { { audience: 'gitlab-artifact-registry' } }

  describe 'POST /token_exchange' do
    # Verify with the loader's current key -- the exact key the issuer signed with.
    def token_claims
      public_key = ::CloudConnector::CachingKeyLoader.private_jwk.verify_key
      JWT.decode(json_response['token'], public_key, true, algorithm: 'RS256').first
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(gate_token_exchange_endpoint: false)
      end

      it 'returns 404' do
        post(api(url, personal_access_token: pat), params: params)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the feature flag is enabled only for a different user' do
      let_it_be(:other_user) { create(:user) }

      before do
        stub_feature_flags(gate_token_exchange_endpoint: other_user)
      end

      it 'returns 404 for the calling user' do
        post(api(url, personal_access_token: pat), params: params)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with a valid audience' do
      it 'returns a token for the authenticated user', :aggregate_failures do
        post(api(url, personal_access_token: pat), params: params)

        expect(response).to have_gitlab_http_status(:created)

        claims = token_claims
        expect(claims['aud']).to match_array(%w[gitlab-artifact-registry gitlab-iam-data-access])
        expect(claims['sub']).to eq(user.to_global_id.to_s)
        expect(claims['ver']).to eq(1)
        expect(claims['gitlab']).to include(
          'origin' => 'organization',
          'origin_id' => user.organization.uuid,
          'local_id' => user.id,
          'identity_kind' => 'user',
          'organization_role' => 'member'
        )

        %w[gitlab_realm gitlab_organization_id gitlab_organization_role].each do |removed|
          expect(claims).not_to have_key(removed)
        end
      end

      context 'with a granular personal access token' do
        let_it_be(:granular_pat) { create(:granular_pat, user: user) }

        it 'issues a token (skip_granular_token_authorization is honoured)' do
          post(api(url, personal_access_token: granular_pat), params: params)

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['token']).to be_present
        end
      end

      context 'with an OAuth access token' do
        let_it_be(:oauth_token) { create(:oauth_access_token, resource_owner: user, scopes: [:api]) }

        it 'issues a token' do
          post(api(url, oauth_access_token: oauth_token), params: params)

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['token']).to be_present
        end
      end

      context 'with a project access token' do
        let_it_be(:project) { create(:project) }
        let_it_be(:project_access_token) { create(:resource_access_token, resource: project) }

        it 'issues a token' do
          post(api(url, personal_access_token: project_access_token), params: params)

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['token']).to be_present
          expect(token_claims['sub']).to eq(project_access_token.user.to_global_id.to_s)
        end
      end

      context 'with a CI job token' do
        let_it_be(:project) { create(:project) }
        let_it_be(:ci_build) { create(:ci_build, :running, project: project, user: user) }

        it 'issues a token (job_token_allowed route_setting is honoured)' do
          post(api(url), params: params.merge(job_token: ci_build.token))

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['token']).to be_present
        end
      end

      context 'with no expires_in' do
        it 'defaults to a 300 second ttl' do
          post(api(url, personal_access_token: pat), params: params)

          claims = token_claims
          expect(claims['exp'] - claims['iat']).to eq(300)
        end
      end

      context 'with expires_in within range' do
        it 'applies the requested expires_in' do
          post(api(url, personal_access_token: pat), params: params.merge(expires_in: 600))

          claims = token_claims
          expect(claims['exp'] - claims['iat']).to eq(600)
        end
      end

      context 'with expires_in above the upper bound' do
        it 'returns 400' do
          post(api(url, personal_access_token: pat), params: params.merge(expires_in: 13.hours.to_i))

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    it_behaves_like 'rate limited endpoint', rate_limit_key: :token_exchange do
      let(:current_user) { user }

      def request
        post(api(url, personal_access_token: pat), params: params)
      end

      def request_with_second_scope
        post(api(url, personal_access_token: second_pat), params: params)
      end
    end

    context 'with an unknown audience' do
      it 'returns 400' do
        post(api(url, personal_access_token: pat), params: { audience: 'unknown' })

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'without authentication' do
      it 'returns 401' do
        post(api(url), params: params)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'with a deploy token' do
      let_it_be(:deploy_token) { create(:deploy_token) }

      it 'returns 401 (deploy_token_allowed is intentionally not set)' do
        post(
          api(url),
          params: params,
          headers: { Gitlab::Auth::AuthFinders::DEPLOY_TOKEN_HEADER => deploy_token.token }
        )

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end
end
