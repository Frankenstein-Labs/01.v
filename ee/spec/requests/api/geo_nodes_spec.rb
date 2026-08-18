# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::GeoNodes, :aggregate_failures, :request_store, :geo, :prometheus, :api, feature_category: :geo_replication do
  include ApiHelpers
  include ::EE::GeoHelpers

  include_context 'custom session'

  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:primary) { create(:geo_node, :primary) }
  let_it_be_with_reload(:secondary) { create(:geo_node) }
  let_it_be_with_refind(:secondary_status) { create(:geo_node_status, :healthy, geo_node: secondary) }
  let(:unexisting_node_id) { non_existing_record_id }
  let_it_be(:group_to_sync) { create(:group) }
  let_it_be(:organization1) { create(:organization) }
  let_it_be(:organization2) { create(:organization) }

  describe 'POST /geo_nodes' do
    it 'denies access if not admin' do
      post api('/geo_nodes', user), params: {}
      expect(response).to have_gitlab_http_status(:forbidden)
    end

    it 'returns rendering error if params are missing' do
      post api('/geo_nodes', admin, admin_mode: true), params: {}
      expect(response).to have_gitlab_http_status(:bad_request)
    end

    context 'when the params are valid' do
      let(:geo_node_params) do
        {
          name: 'Test Node 1',
          url: 'http://example.com',
          selective_sync_type: "shards",
          selective_sync_shards: %w[shard1 shard2],
          selective_sync_namespace_ids: group_to_sync.id,
          minimum_reverification_interval: 10
        }
      end

      it 'delegates the creation of the Geo node to Geo::NodeCreateService' do
        post api('/geo_nodes', admin, admin_mode: true), params: geo_node_params
        expect(response).to have_gitlab_http_status(:created)
      end

      it_behaves_like 'authorizing granular token permissions', :create_geo_node do
        let(:boundary_object) { :instance }
        let(:user) { admin }
        let(:request) do
          post api('/geo_nodes', personal_access_token: pat), params: geo_node_params
        end
      end
    end

    context 'with organization_ids parameter' do
      context 'when geo_selective_sync_by_organizations feature flag is enabled' do
        it 'accepts organization_ids parameter' do
          geo_node_params = {
            name: 'Test Node with Organizations',
            url: 'http://example.com',
            selective_sync_type: "organizations",
            selective_sync_organization_ids: [organization1.id, organization2.id]
          }

          post api('/geo_nodes', admin, admin_mode: true), params: geo_node_params

          expect(response).to have_gitlab_http_status(:created)
        end

        it 'includes organization_ids in the response' do
          geo_node_params = {
            name: 'Test Node with Organizations',
            url: 'http://example.com',
            selective_sync_type: "organizations",
            selective_sync_organization_ids: [organization1.id, organization2.id]
          }

          post api('/geo_nodes', admin, admin_mode: true), params: geo_node_params

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response).to include('selective_sync_type' => 'organizations')
          expect(json_response).to include('selective_sync_organization_ids' => [organization1.id, organization2.id])
        end
      end

      context 'when geo_selective_sync_by_organizations feature flag is disabled' do
        before do
          stub_feature_flags(geo_selective_sync_by_organizations: false)
        end

        it 'ignores organization_ids parameter when feature flag is disabled' do
          geo_node_params = {
            name: 'Test Node without Organizations',
            url: 'http://example.com',
            selective_sync_type: "organizations",
            selective_sync_organization_ids: [organization1.id, organization2.id]
          }

          post api('/geo_nodes', admin, admin_mode: true), params: geo_node_params

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response).not_to include('organization_ids')
        end
      end
    end
  end

  describe 'GET /geo_nodes' do
    it 'retrieves the Geo nodes if admin is logged in' do
      get api("/geo_nodes", admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('public_api/v4/geo_nodes', dir: 'ee')
    end

    it_behaves_like 'authorizing granular token permissions', :read_geo_node do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) do
        get api('/geo_nodes', personal_access_token: pat)
      end
    end

    it 'denies access if not admin' do
      get api('/geo_nodes', user)

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  describe 'GET /geo_nodes/:id' do
    it 'retrieves the Geo nodes if admin is logged in' do
      get api("/geo_nodes/#{primary.id}", admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('public_api/v4/geo_node', dir: 'ee')
      expect(json_response['web_edit_url']).to end_with("/admin/geo/sites/#{primary.id}/edit")

      links = json_response['_links']
      expect(links['self']).to end_with("/api/v4/geo_nodes/#{primary.id}")
      expect(links['status']).to end_with("/api/v4/geo_nodes/#{primary.id}/status")
      expect(links['repair']).to end_with("/api/v4/geo_nodes/#{primary.id}/repair")
    end

    it_behaves_like 'authorizing granular token permissions', :read_geo_node do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) do
        get api("/geo_nodes/#{primary.id}", personal_access_token: pat)
      end
    end

    it_behaves_like '404 response' do
      let(:request) { get api("/geo_nodes/#{unexisting_node_id}", admin, admin_mode: true) }
    end

    it 'denies access if not admin' do
      get api('/geo_nodes', user)

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  describe 'GET /geo_nodes/status' do
    it 'retrieves all Geo nodes statuses if admin is logged in' do
      create(:geo_node_status, :healthy, geo_node: primary)

      get api("/geo_nodes/status", admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('public_api/v4/geo_node_statuses', dir: 'ee')
      expect(json_response.size).to eq(2)
    end

    it 'returns only one record if only one record exists' do
      get api("/geo_nodes/status", admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('public_api/v4/geo_node_statuses', dir: 'ee')
      expect(json_response.size).to eq(1)
    end

    it_behaves_like 'authorizing granular token permissions', :read_geo_node do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) do
        get api("/geo_nodes/status", personal_access_token: pat)
      end
    end

    it 'denies access if not admin' do
      get api('/geo_nodes', user)

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  describe 'GET /geo_nodes/:id/status' do
    it 'retrieves the Geo nodes status if admin is logged in' do
      stub_current_geo_node(primary)
      secondary_status.update!(version: 'secondary-version', revision: 'secondary-revision')

      expect(GeoNodeStatus).not_to receive(:current_node_status)

      get api("/geo_nodes/#{secondary.id}/status", admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('public_api/v4/geo_node_status', dir: 'ee')

      expect(json_response['version']).to eq('secondary-version')
      expect(json_response['revision']).to eq('secondary-revision')

      links = json_response['_links']

      expect(links['self']).to end_with("/api/v4/geo_nodes/#{secondary.id}/status")
      expect(links['node']).to end_with("/api/v4/geo_nodes/#{secondary.id}")
    end

    it 'fetches the current node status from redis' do
      stub_current_geo_node(secondary)

      expect(GeoNodeStatus).to receive(:fast_current_node_status).and_return(secondary_status)
      expect(GeoNode).to receive(:find).and_return(secondary)

      get api("/geo_nodes/#{secondary.id}/status", admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('public_api/v4/geo_node_status', dir: 'ee')
    end

    it_behaves_like 'authorizing granular token permissions', :read_geo_node do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) do
        get api("/geo_nodes/#{secondary.id}/status", personal_access_token: pat)
      end
    end

    it 'shows the database-held response if current node status exists in the database, but not redis' do
      stub_current_geo_node(secondary)

      expect(GeoNodeStatus).to receive(:fast_current_node_status).and_return(nil)
      expect(GeoNode).to receive(:find).and_return(secondary)

      get api("/geo_nodes/#{secondary.id}/status", admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('public_api/v4/geo_node_status', dir: 'ee')
    end

    it 'the secondary shows 404 response if current node status does not exist in database or redis yet' do
      stub_current_geo_node(secondary)
      secondary_status.destroy!

      expect(GeoNodeStatus).to receive(:fast_current_node_status).and_return(nil)
      expect(GeoNode).to receive(:find).and_return(secondary)

      get api("/geo_nodes/#{secondary.id}/status", admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'the primary shows 404 response if secondary node status does not exist in database yet' do
      stub_current_geo_node(primary)
      secondary_status.destroy!

      expect(GeoNode).to receive(:find).and_return(secondary)

      get api("/geo_nodes/#{secondary.id}/status", admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it_behaves_like '404 response' do
      let(:request) { get api("/geo_nodes/#{unexisting_node_id}/status", admin, admin_mode: true) }
    end

    it 'denies access if not admin' do
      get api("/geo_nodes/#{secondary.id}/status", user)

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  describe 'POST /geo_nodes/:id/repair' do
    it_behaves_like '404 response' do
      let(:request) { post api("/geo_nodes/#{unexisting_node_id}/status", admin, admin_mode: true) }
    end

    it 'denies access if not admin' do
      post api("/geo_nodes/#{secondary.id}/repair", user)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    it 'returns 200 for the primary node' do
      stub_current_geo_node(primary)
      create(:geo_node_status, :healthy, geo_node: primary)

      post api("/geo_nodes/#{primary.id}/repair", admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('public_api/v4/geo_node_status', dir: 'ee')
    end

    it_behaves_like 'authorizing granular token permissions', :repair_geo_node do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) do
        post api("/geo_nodes/#{primary.id}/repair", personal_access_token: pat)
      end
    end

    it 'returns 200 when node does not need repairing' do
      allow_any_instance_of(GeoNode).to receive(:missing_oauth_application?).and_return(false)

      post api("/geo_nodes/#{secondary.id}/repair", admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('public_api/v4/geo_node_status', dir: 'ee')
    end

    it 'repairs a secondary with oauth application missing' do
      allow_any_instance_of(GeoNode).to receive(:missing_oauth_application?).and_return(true)

      post api("/geo_nodes/#{secondary.id}/repair", admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('public_api/v4/geo_node_status', dir: 'ee')
    end
  end

  describe 'PUT /geo_nodes/:id' do
    it_behaves_like '404 response' do
      let(:request) { put api("/geo_nodes/#{unexisting_node_id}", admin, admin_mode: true), params: {} }
    end

    it 'denies access if not admin' do
      put api("/geo_nodes/#{secondary.id}", user), params: {}

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    context 'when the params are valid' do
      let(:params) do
        {
          enabled: false,
          url: 'https://updated.example.com/',
          internal_url: 'https://internal-com.com/',
          files_max_capacity: 33,
          repos_max_capacity: 44,
          verification_max_capacity: 55,
          selective_sync_type: "shards",
          selective_sync_shards: %w[shard1 shard2],
          selective_sync_namespace_ids: [group_to_sync.id],
          minimum_reverification_interval: 10
        }.stringify_keys
      end

      it 'updates the parameters' do
        put api("/geo_nodes/#{secondary.id}", admin, admin_mode: true), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/geo_node', dir: 'ee')
        expect(json_response).to include(params)
      end

      it_behaves_like 'authorizing granular token permissions', :update_geo_node do
        let(:boundary_object) { :instance }
        let(:user) { admin }
        let(:request) do
          put api("/geo_nodes/#{secondary.id}", personal_access_token: pat), params: params
        end
      end
    end

    context 'with organization_ids parameter' do
      context 'when geo_selective_sync_by_organizations feature flag is enabled' do
        it 'updates organization_ids parameter' do
          params = {
            selective_sync_type: "organizations",
            selective_sync_organization_ids: [organization1.id, organization2.id]
          }

          put api("/geo_nodes/#{secondary.id}", admin, admin_mode: true), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('public_api/v4/geo_node', dir: 'ee')
          expect(json_response).to include('selective_sync_type' => 'organizations')
          expect(json_response).to include('selective_sync_organization_ids' => [organization1.id, organization2.id])
        end

        it 'can clear organization_ids by setting to empty array' do
          # First set organizations
          secondary.update!(selective_sync_type: 'organizations', organization_ids: [organization1.id])

          params = {
            selective_sync_type: "organizations",
            selective_sync_organization_ids: []
          }

          put api("/geo_nodes/#{secondary.id}", admin, admin_mode: true), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to include('selective_sync_type' => 'organizations')
          expect(json_response).to include('selective_sync_organization_ids' => [])
        end
      end

      context 'when geo_selective_sync_by_organizations feature flag is disabled' do
        before do
          stub_feature_flags(geo_selective_sync_by_organizations: false)
        end

        it 'ignores organization_ids parameter' do
          # Set some existing organizations
          secondary.update!(selective_sync_type: 'organizations', organization_ids: [organization1.id])

          params = {
            selective_sync_type: "namespaces",
            selective_sync_organization_ids: [organization2.id]
          }

          put api("/geo_nodes/#{secondary.id}", admin, admin_mode: true), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to include('selective_sync_type' => 'namespaces')
          expect(json_response).not_to include('organization_ids')
          # Should preserve existing organization_ids since parameter was ignored
          expect(secondary.reload.organization_ids).to eq([organization1.id])
        end
      end
    end

    it 'can update primary' do
      params = {
        url: 'https://updated.example.com/'
      }.stringify_keys

      put api("/geo_nodes/#{primary.id}", admin, admin_mode: true), params: params

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('public_api/v4/geo_node', dir: 'ee')
      expect(json_response).to include(params)
    end

    it 'cannot disable a primary' do
      params = {
        enabled: false
      }.stringify_keys

      put api("/geo_nodes/#{primary.id}", admin, admin_mode: true), params: params

      expect(response).to have_gitlab_http_status(:bad_request)
    end

    context 'auth with geo node token' do
      let(:geo_base_request) { Gitlab::Geo::BaseRequest.new(scope: ::Gitlab::Geo::API_SCOPE) }

      before do
        stub_current_geo_node(primary)
        allow(geo_base_request).to receive(:requesting_node) { secondary }
      end

      it 'enables the secondary node' do
        secondary.update!(enabled: false)

        put api("/geo_nodes/#{secondary.id}"), params: { enabled: true }, headers: geo_base_request.headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(secondary.reload).to be_enabled
      end

      it 'disables the secondary node' do
        secondary.update!(enabled: true)

        put api("/geo_nodes/#{secondary.id}"), params: { enabled: false }, headers: geo_base_request.headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(secondary.reload).not_to be_enabled
      end

      it 'returns bad request if you try to update the primary' do
        put api("/geo_nodes/#{primary.id}"), params: { enabled: false }, headers: geo_base_request.headers

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(primary.reload).to be_enabled
      end

      it 'responds with 401 when IP is not allowed' do
        stub_application_setting(geo_node_allowed_ips: '192.34.34.34')

        put api("/geo_nodes/#{secondary.id}"), params: {}, headers: geo_base_request.headers

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it 'responds 401 if auth header is bad' do
        allow_next_instance_of(Gitlab::Geo::JwtRequestDecoder) do |instance|
          allow(instance).to receive(:decode).and_raise(Gitlab::Geo::InvalidDecryptionKeyError)
        end

        put api("/geo_nodes/#{secondary.id}"), params: {}, headers: geo_base_request.headers

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /geo_nodes/:id' do
    it_behaves_like '404 response' do
      let(:request) { delete api("/geo_nodes/#{unexisting_node_id}", admin, admin_mode: true) }
    end

    it 'denies access if not admin' do
      delete api("/geo_nodes/#{secondary.id}", user)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    it 'deletes the node' do
      delete api("/geo_nodes/#{secondary.id}", admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:no_content)
    end

    it_behaves_like 'authorizing granular token permissions', :delete_geo_node do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) do
        delete api("/geo_nodes/#{secondary.id}", personal_access_token: pat)
      end
    end

    it 'returns 500 if Geo Node could not be deleted' do
      allow_any_instance_of(GeoNode).to receive(:destroy!).and_raise(StandardError, 'Something wrong')

      delete api("/geo_nodes/#{secondary.id}", admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:internal_server_error)
    end
  end
end
