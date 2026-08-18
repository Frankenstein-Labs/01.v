# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Rack Attack global throttles', feature_category: :system_access do
  include_context 'rack attack cache store'

  context 'when the request is to /api/v4/geo/proxy' do
    include WorkhorseHelpers

    let(:requests_per_period) { 1 }

    before do
      stub_application_setting(
        throttle_unauthenticated_api_requests_per_period: requests_per_period,
        throttle_unauthenticated_api_enabled: true
      )
    end

    context 'with a valid Workhorse JWT header' do
      it 'allows requests over the rate limit' do
        (1 + requests_per_period).times do
          post '/api/v4/geo/proxy', headers: workhorse_internal_api_request_header

          expect(response).not_to have_gitlab_http_status(:too_many_requests)
        end
      end
    end

    context 'without a Workhorse JWT header', :verify_workhorse_jwt do
      it 'rejects requests over the rate limit' do
        requests_per_period.times do
          post '/api/v4/geo/proxy'

          expect(response).not_to have_gitlab_http_status(:too_many_requests)
        end

        post '/api/v4/geo/proxy'

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end

    context 'with an invalid Workhorse JWT header', :verify_workhorse_jwt do
      it 'rejects requests over the rate limit' do
        requests_per_period.times do
          post '/api/v4/geo/proxy', headers: { 'HTTP_GITLAB_WORKHORSE_API_REQUEST' => 'invalid' }

          expect(response).not_to have_gitlab_http_status(:too_many_requests)
        end

        post '/api/v4/geo/proxy', headers: { 'HTTP_GITLAB_WORKHORSE_API_REQUEST' => 'invalid' }

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end

    context 'with a valid Workhorse JWT but a different path' do
      it 'rejects requests over the rate limit' do
        requests_per_period.times do
          get '/api/v4/projects', headers: workhorse_internal_api_request_header

          expect(response).not_to have_gitlab_http_status(:too_many_requests)
        end

        get '/api/v4/projects', headers: workhorse_internal_api_request_header

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end
  end

  context 'when the request is from Geo secondary' do
    include ::EE::GeoHelpers

    let_it_be(:primary) { create(:geo_node, :primary) }
    let_it_be(:secondary) { create(:geo_node) }

    let_it_be(:project) { create(:project) }
    let_it_be(:requests_per_period) { 1 }

    before do
      stub_current_geo_node(primary)
      stub_application_setting(
        throttle_unauthenticated_git_http_requests_per_period: requests_per_period,
        throttle_unauthenticated_git_http_period_in_seconds: 600,
        throttle_unauthenticated_git_http_enabled: true
      )
    end

    context 'with a valid Geo JWT token' do
      let(:geo_auth) { Gitlab::Geo::BaseRequest.new(scope: project.full_path).authorization }

      it 'allows requests over the rate limit' do
        (1 + requests_per_period).times do
          make_geo_git_request(authorization: geo_auth)
          expect(response).not_to have_gitlab_http_status(:too_many_requests)
        end
      end
    end

    context 'with an invalid Geo JWT token' do
      let(:invalid_auth) { "#{::Gitlab::Geo::BaseRequest::GITLAB_GEO_AUTH_TOKEN_TYPE} invalid-token" }

      it 'rejects requests over the rate limit' do
        requests_per_period.times do
          make_geo_git_request(authorization: invalid_auth)
          expect(response).not_to have_gitlab_http_status(:too_many_requests)
        end

        make_geo_git_request(authorization: invalid_auth)
        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end

    def make_geo_git_request(authorization:)
      get "/#{project.full_path}.git/info/refs", params: { service: 'git-upload-pack' },
        headers: { 'Authorization' => authorization }
    end
  end
end
