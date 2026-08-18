# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Internal::Orbit, feature_category: :knowledge_graph do
  include WorkhorseHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
  let_it_be(:public_project) { create(:project, :public) }
  let_it_be(:private_project) { create(:project, :private) }

  let(:workhorse_headers) { workhorse_internal_api_request_header }
  let(:auth_headers) { { 'HTTP_PRIVATE_TOKEN' => personal_access_token.token } }

  before do
    stub_feature_flags(knowledge_graph_infra: true)
  end

  def redaction_params(resources:)
    { resources: resources }
  end

  def post_redaction(params:, headers: workhorse_headers.merge(auth_headers))
    post api('/internal/orbit/redaction'), params: params, headers: headers
  end

  describe 'POST /internal/orbit/redaction' do
    context 'when Workhorse token is missing', :verify_workhorse_jwt do
      it 'rejects the request' do
        post_redaction(
          params: redaction_params(
            resources: [{ resource_type: 'project', resource_ids: [1], ability: 'read_project' }]
          ),
          headers: auth_headers
        )

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when Workhorse token is invalid', :verify_workhorse_jwt do
      it 'rejects the request' do
        post_redaction(
          params: redaction_params(
            resources: [{ resource_type: 'project', resource_ids: [1], ability: 'read_project' }]
          ),
          headers: auth_headers.merge('HTTP_GITLAB_WORKHORSE_API_REQUEST' => 'invalid-token')
        )

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when user token is missing' do
      it 'returns 401' do
        post_redaction(
          params: redaction_params(
            resources: [
              { resource_type: 'project', resource_ids: [public_project.id], ability: 'read_project' }
            ]
          ),
          headers: workhorse_headers
        )

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when user is inactive' do
      it 'returns 403' do
        blocked_user = create(:user, :blocked)
        blocked_token = create(:personal_access_token, user: blocked_user)

        post_redaction(
          params: redaction_params(
            resources: [
              { resource_type: 'project', resource_ids: [public_project.id], ability: 'read_project' }
            ]
          ),
          headers: workhorse_headers.merge('HTTP_PRIVATE_TOKEN' => blocked_token.token)
        )

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'with valid resources' do
      let_it_be(:private_project_with_access) { create(:project, :private) }

      before_all do
        private_project_with_access.add_reporter(user)
      end

      it 'returns authorization map' do
        project_ids = [
          public_project.id,
          private_project.id,
          private_project_with_access.id
        ]

        post_redaction(
          params: redaction_params(
            resources: [
              { resource_type: 'project', resource_ids: project_ids, ability: 'read_project' }
            ]
          )
        )

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['authorizations']).to contain_exactly(
          a_hash_including(
            'resource_type' => 'project',
            'authorized' => {
              public_project.id.to_s => true,
              private_project.id.to_s => false,
              private_project_with_access.id.to_s => true
            }
          )
        )
      end

      it 'rejects duplicate resource types' do
        post_redaction(
          params: redaction_params(
            resources: [
              { resource_type: 'project', resource_ids: [public_project.id], ability: 'read_project' },
              { resource_type: 'project', resource_ids: [private_project_with_access.id], ability: 'read_project' }
            ]
          )
        )

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'handles multiple resource types' do
        issue = create(:issue, project: public_project)

        post_redaction(
          params: redaction_params(
            resources: [
              { resource_type: 'project', resource_ids: [public_project.id], ability: 'read_project' },
              { resource_type: 'issue', resource_ids: [issue.id], ability: 'read_issue' }
            ]
          )
        )

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['authorizations'].size).to eq(2)
      end
    end

    context 'when knowledge_graph_infra flag is disabled' do
      it 'returns 404' do
        stub_feature_flags(knowledge_graph_infra: false)

        post_redaction(
          params: redaction_params(
            resources: [
              { resource_type: 'project', resource_ids: [public_project.id], ability: 'read_project' }
            ]
          )
        )

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with OAuth token (mcp_orbit scope)' do
      let_it_be(:oauth_app) { create(:oauth_application, scopes: 'mcp_orbit') }
      let_it_be(:oauth_token) do
        create(:oauth_access_token, application: oauth_app, resource_owner: user, scopes: 'mcp_orbit')
      end

      it 'authenticates with mcp_orbit scope' do
        post_redaction(
          params: redaction_params(
            resources: [
              { resource_type: 'project', resource_ids: [public_project.id], ability: 'read_project' }
            ]
          ),
          headers: workhorse_headers.merge('HTTP_AUTHORIZATION' => "Bearer #{oauth_token.plaintext_token}")
        )

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    # Regression coverage for: POST /orbit/query with a :read_api PAT returns 502.
    # Workhorse processes the user-facing POST /orbit/query and, when GKG sends
    # back a redaction request mid-stream, calls this internal endpoint with the
    # original user's token. Because the public /orbit/query route accepts
    # :read_api PATs (ee/lib/api/orbit/data.rb), this internal POST callback
    # must also accept :read_api or the global default (lib/api/api.rb line 54)
    # rejects it with `insufficient_scope` and Workhorse surfaces a 502.
    context 'with read_api-scoped PAT' do
      let_it_be(:read_api_pat) { create(:personal_access_token, user: user, scopes: [:read_api]) }

      it 'authenticates with read_api scope' do
        post_redaction(
          params: redaction_params(
            resources: [
              { resource_type: 'project', resource_ids: [public_project.id], ability: 'read_project' }
            ]
          ),
          headers: workhorse_headers.merge('HTTP_PRIVATE_TOKEN' => read_api_pat.token)
        )

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    # Regression coverage for: tools/call query_graph from an :mcp-scoped OAuth
    # token returns 502 once results trigger redaction. POST /api/v4/orbit/mcp
    # accepts both :mcp and :mcp_orbit (ee/lib/api/orbit/mcp.rb), so the matching
    # internal callback must also accept :mcp or Workhorse fails the redaction
    # exchange with `insufficient_scope` and the caller sees Bad Gateway.
    context 'with OAuth token (mcp scope)' do
      let_it_be(:oauth_app) { create(:oauth_application, scopes: 'mcp') }
      let_it_be(:oauth_token) do
        create(:oauth_access_token, application: oauth_app, resource_owner: user, scopes: 'mcp')
      end

      it 'authenticates with mcp scope' do
        post_redaction(
          params: redaction_params(
            resources: [
              { resource_type: 'project', resource_ids: [public_project.id], ability: 'read_project' }
            ]
          ),
          headers: workhorse_headers.merge('HTTP_AUTHORIZATION' => "Bearer #{oauth_token.plaintext_token}")
        )

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when the group restricts access by IP address' do
      let_it_be(:restricted_group) do
        create(:group, :public).tap { |group| create(:ip_restriction, group: group, range: '10.0.0.0/24') }
      end

      let_it_be(:restricted_project) { create(:project, :public, group: restricted_group) }

      before do
        stub_licensed_features(group_ip_restriction: true)
      end

      def post_redaction_from(client_ip)
        headers = workhorse_headers.merge(auth_headers)
        headers['HTTP_X_GITLAB_ORBIT_CLIENT_IP'] = client_ip if client_ip

        post_redaction(
          params: redaction_params(
            resources: [
              { resource_type: 'project', resource_ids: [restricted_project.id], ability: 'read_project' }
            ]
          ),
          headers: headers
        )
      end

      def authorized_project
        json_response['authorizations'].first['authorized'][restricted_project.id.to_s]
      end

      it 'redacts the resource when the client IP is outside the allowed range', :aggregate_failures do
        post_redaction_from('192.168.1.1')

        expect(response).to have_gitlab_http_status(:ok)
        expect(authorized_project).to be(false)
      end

      it 'authorizes the resource when the client IP is within the allowed range', :aggregate_failures do
        post_redaction_from('10.0.0.5')

        expect(response).to have_gitlab_http_status(:ok)
        expect(authorized_project).to be(true)
      end

      it 'authorizes the resource when no client IP header is present', :aggregate_failures do
        post_redaction_from(nil)

        expect(response).to have_gitlab_http_status(:ok)
        expect(authorized_project).to be(true)
      end

      it 'logs a warning when the client IP header is absent' do
        logger = instance_spy(Gitlab::AuthLogger)
        allow(Gitlab::AuthLogger).to receive(:build).and_return(logger)

        post_redaction_from(nil)

        expect(logger).to have_received(:warn).with(a_hash_including(message: include('client IP')))
      end

      it 'does not log the missing client IP warning when the header is present' do
        logger = instance_spy(Gitlab::AuthLogger)
        allow(Gitlab::AuthLogger).to receive(:build).and_return(logger)

        post_redaction_from('10.0.0.5')

        expect(logger).not_to have_received(:warn)
      end

      it 'ignores a malformed client IP and authorizes with a warning', :aggregate_failures do
        logger = instance_spy(Gitlab::AuthLogger)
        allow(Gitlab::AuthLogger).to receive(:build).and_return(logger)

        post_redaction_from('not-an-ip')

        expect(response).to have_gitlab_http_status(:ok)
        expect(authorized_project).to be(true)
        expect(logger).to have_received(:warn).with(a_hash_including(message: include('client IP')))
      end

      it 'evaluates an IPv6 client address against the restriction' do
        post_redaction_from('2001:db8::1')

        expect(authorized_project).to be(false)
      end
    end
  end
end
