# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::ContainerController, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax
  include DependencyProxyHelpers
  include WorkhorseHelpers

  let_it_be_with_reload(:group) { create(:group, :private) }
  let_it_be_with_reload(:user) { create(:user, guest_of: group) }
  let_it_be_with_reload(:virtual_registry_setting) { create(:virtual_registries_setting, group: group) }
  let_it_be_with_reload(:registry) { create(:virtual_registries_container_registry, :with_upstreams, group: group) }
  let_it_be_with_reload(:upstream) { registry.upstreams.first }
  let_it_be_with_reload(:cache_entry) do
    create(
      :virtual_registries_container_cache_remote_entry,
      group: group,
      upstream: upstream,
      relative_path: '/alpine/manifests/latest'
    )
  end

  let(:jwt) do
    build_jwt(
      user,
      service_type: ::Auth::ContainerProxyAuthenticationService::SERVICE_TYPE_VIRTUAL_REGISTRY
    )
  end

  let(:headers) { jwt_token_authorization_headers(jwt) }
  let(:image) { 'alpine' }
  let(:action) { :download_file }
  let(:upstream_etag) { 'sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08' }
  let(:service_response) do
    ServiceResponse.success(
      payload: {
        action: action,
        action_params: {
          file: cache_entry.file,
          content_type: 'application/vnd.docker.distribution.manifest.v2+json',
          upstream_etag: upstream_etag
        }
      }
    )
  end

  let(:service_double) do
    instance_double(::VirtualRegistries::Container::HandleFileRequestService, execute: service_response)
  end

  before do
    stub_licensed_features(container_virtual_registry: true)
    stub_config(dependency_proxy: { enabled: true })
    stub_feature_flags(container_virtual_registries: true)

    allow(::VirtualRegistries::Container::HandleFileRequestService)
      .to receive(:new)
      .and_return(service_double)
  end

  shared_examples 'returns unauthorized without a token' do
    it 'returns unauthorized status' do
      get path

      expect(response).to have_gitlab_http_status(:unauthorized)
      expect(response.headers['WWW-Authenticate']).to eq(::DependencyProxy::Registry.authenticate_header)
    end
  end

  shared_examples 'validates service_type claim' do
    context 'with a token missing service_type claim' do
      let(:jwt) { build_jwt(user) }

      it 'returns unauthorized' do
        send_request

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'with a token with wrong service_type claim' do
      let(:jwt) do
        build_jwt(
          user,
          service_type: ::Auth::ContainerProxyAuthenticationService::SERVICE_TYPE_DEPENDENCY_PROXY
        )
      end

      it 'returns unauthorized' do
        send_request

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  shared_examples 'returns successful response' do
    context 'when the handle request service returns download_file' do
      it 'returns a successful response' do
        send_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers['Docker-Distribution-Api-Version']).to eq('registry/2.0')
        expect(response.headers['Content-Type']).to eq('application/vnd.docker.distribution.manifest.v2+json')
        expect(response.headers['Docker-Content-Digest']).to eq(upstream_etag) if expect_digest_header
      end
    end

    context 'when the handle request service returns workhorse_upload_url' do
      let(:service_response) do
        ServiceResponse.success(
          payload: {
            action: :workhorse_upload_url,
            action_params: {
              url: 'https://registry-1.docker.io/v2/library/alpine/manifests/latest',
              upstream: upstream
            }
          }
        )
      end

      let(:enabled_endpoint_uris) { [URI('192.168.1.1')] }
      let(:outbound_local_requests_allowlist) { ['127.0.0.1'] }
      let(:allowed_endpoints) { enabled_endpoint_uris + outbound_local_requests_allowlist }

      before do
        allow(upstream).to receive(:headers).and_return({ 'Authorization' => 'Bearer token123' })
        allow(ObjectStoreSettings).to receive(:enabled_endpoint_uris).and_return(enabled_endpoint_uris)
        stub_application_setting(outbound_local_requests_whitelist: outbound_local_requests_allowlist)
      end

      it 'returns a workhorse send_dependency response' do
        expect(::VirtualRegistries::Cache::EntryUploader).to receive(:workhorse_authorize).with(
          a_hash_including(
            use_final_store_path: true,
            final_store_path_config: { override_path: be_instance_of(String) }
          )
        ).and_call_original

        expect(Gitlab::Workhorse).to receive(:send_dependency).with(
          an_instance_of(Hash),
          an_instance_of(String),
          a_hash_including(
            allow_localhost: true,
            ssrf_filter: true,
            allowed_endpoints: allowed_endpoints
          )
        ).and_call_original

        send_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers[Gitlab::Workhorse::SEND_DATA_HEADER]).to start_with('send-dependency:')
        expect(response.headers['Content-Type']).to eq('application/octet-stream')
        expect(response.headers['Docker-Distribution-Api-Version']).to eq('registry/2.0')
        expect(response.headers['Content-Length'].to_i).to eq(0)
        expect(response.body).to eq('')

        send_data_type, send_data = workhorse_send_data

        expected_headers = { 'Authorization' => ['Bearer token123'] }

        expected_resp_headers = described_class::EXTRA_RESPONSE_HEADERS.transform_values do |value|
          [value]
        end

        expected_upload_config = {
          'Headers' => { described_class::UPSTREAM_GID_HEADER => [upstream.to_global_id.to_s] },
          'AuthorizedUploadResponse' => a_kind_of(Hash)
        }

        expected_restrict_forwarded_response_headers = {
          'Enabled' => true,
          'AllowList' => described_class::ALLOWED_RESPONSE_HEADERS
        }

        expect(send_data_type).to eq('send-dependency')
        expect(send_data['Url']).to be_present
        expect(send_data['Headers']).to eq(expected_headers)
        expect(send_data['ResponseHeaders']).to eq(expected_resp_headers)
        expect(send_data['UploadConfig']).to include(expected_upload_config)
        expect(send_data['SSRFFilter']).to be(true)
        expect(send_data['RestrictForwardedResponseHeaders']).to include(expected_restrict_forwarded_response_headers)
      end
    end
  end

  shared_examples 'validates feature flags and licensing' do
    context 'when container_virtual_registries feature flag is disabled' do
      before do
        stub_feature_flags(container_virtual_registries: false)
      end

      it 'returns not found' do
        send_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when container virtual registry is not licensed' do
      before do
        stub_licensed_features(container_virtual_registry: false)
      end

      it 'returns not found' do
        send_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when dependency proxy is disabled' do
      before do
        stub_config(dependency_proxy: { enabled: false })
      end

      it 'returns not found' do
        send_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  shared_examples 'when file is in object storage' do
    let(:proxy_download_enabled) { true }

    before do
      allow(VirtualRegistries::Cache::EntryUploader)
        .to receive(:proxy_download_enabled?).and_return(proxy_download_enabled)
      allow(cache_entry.file).to receive_messages(
        file_storage?: false,
        url: 'https://storage.example.com/blob'
      )
    end

    context 'with proxy_download enabled' do
      it_behaves_like 'proxies via Workhorse send-url'
    end

    context 'with proxy_download disabled' do
      let(:proxy_download_enabled) { false }

      it_behaves_like 'redirects to object storage'

      it 'sets Docker headers' do
        send_request

        expect(response.headers['Docker-Distribution-Api-Version']).to eq('registry/2.0')
        expect(response.headers['Docker-Content-Digest']).to eq(expect_digest_header ? upstream_etag : nil)
      end
    end
  end

  shared_examples 'proxies via Workhorse send-url' do
    it 'proxies via Workhorse send-url' do
      send_request

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.headers[Gitlab::Workhorse::SEND_DATA_HEADER]).to start_with('send-url:')
    end
  end

  shared_examples 'redirects to object storage' do
    it 'redirects to object storage' do
      send_request

      expect(response).to have_gitlab_http_status(:found)
      expect(response.headers['Location']).to eq('https://storage.example.com/blob')
    end
  end

  shared_examples 'validates permissions' do
    shared_examples 'returns forbidden' do
      let(:headers) do
        jwt = build_jwt(
          unauthorized_user,
          service_type: ::Auth::ContainerProxyAuthenticationService::SERVICE_TYPE_VIRTUAL_REGISTRY
        )
        jwt_token_authorization_headers(jwt)
      end

      specify do
        send_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user does not have read_virtual_registry permission' do
      let_it_be(:unauthorized_user) { create(:user) }

      it_behaves_like 'returns forbidden'
    end

    context 'when personal access token does not have read_virtual_registry permission' do
      let_it_be(:unauthorized_user) { create(:personal_access_token) }

      it_behaves_like 'returns forbidden'
    end

    context 'when deploy token does not have read_virtual_registry permission' do
      let_it_be(:unauthorized_user) { create(:deploy_token) }

      it_behaves_like 'returns forbidden'
    end
  end

  shared_examples 'a valid user' do
    it_behaves_like 'returns successful response'
  end

  shared_examples 'a valid personal access token' do
    let(:pat) { create(:personal_access_token, user: user, scopes: [:read_virtual_registry]) }
    let(:jwt) do
      build_jwt(
        pat,
        service_type: ::Auth::ContainerProxyAuthenticationService::SERVICE_TYPE_VIRTUAL_REGISTRY
      )
    end

    it_behaves_like 'returns successful response'
  end

  shared_examples 'a valid deploy token' do
    let(:user) { create(:deploy_token, :group, read_virtual_registry: true, groups: [group]) }

    it_behaves_like 'returns successful response'
  end

  shared_examples 'handles service response errors' do
    where(:reason, :expected_status) do
      :unauthorized                      | :forbidden
      :no_upstreams                      | :not_found
      :file_not_found_on_upstreams       | :not_found
      :upstream_not_available            | :service_unavailable
      :default_error                     | :bad_request
    end

    with_them do
      let(:service_response) do
        ServiceResponse.error(message: 'error', reason: reason)
      end

      it "returns a #{params[:expected_status]} response" do
        send_request

        expect(response).to have_gitlab_http_status(expected_status)
      end
    end
  end

  # GET /v2/virtual_registries/container/:id/*path
  describe 'GET show' do
    let(:tag) { 'latest' }
    let(:path) { "/v2/virtual_registries/container/#{registry.id}/#{image}/manifests/#{tag}" }

    subject(:send_request) { get path, headers: headers }

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'rate limited endpoint',
      rate_limit_key: :virtual_registries_endpoints_api_limit,
      use_second_scope: false do
      let(:current_user) { user }

      def request
        get path, headers: headers
      end
    end

    context 'with manifest requests' do
      let(:expect_digest_header) { true }
      let(:tag) { 'latest' }
      let(:path) { "/v2/virtual_registries/container/#{registry.id}/#{image}/manifests/#{tag}" }

      it_behaves_like 'returns unauthorized without a token'
      it_behaves_like 'returns successful response'
      it_behaves_like 'validates feature flags and licensing'
      it_behaves_like 'validates permissions'
      it_behaves_like 'validates service_type claim'
      it_behaves_like 'handles service response errors'

      context 'with tag' do
        it_behaves_like 'a valid user'
        it_behaves_like 'a valid personal access token'
        it_behaves_like 'a valid deploy token'
      end

      context 'with digest' do
        let(:digest) { "sha256:#{'a' * 64}" }
        let(:path) { "/v2/virtual_registries/container/#{registry.id}/#{image}/manifests/#{digest}" }

        it_behaves_like 'a valid user'
        it_behaves_like 'a valid personal access token'
        it_behaves_like 'a valid deploy token'
      end

      context 'with invalid registry id' do
        let(:path) { "/v2/virtual_registries/container/#{non_existing_record_id}/#{image}/manifests/#{tag}" }

        it 'returns not found' do
          send_request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      it_behaves_like 'when file is in object storage'
    end

    context 'with blob requests' do
      let(:expect_digest_header) { false }
      let(:sha) { 'sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08' }
      let(:path) { "/v2/virtual_registries/container/#{registry.id}/#{image}/blobs/#{sha}" }

      it_behaves_like 'returns successful response'

      context 'with full sha256 digest' do
        let(:sha) { "sha256:#{'a' * 64}" }

        it_behaves_like 'a valid user'
        it_behaves_like 'a valid personal access token'
        it_behaves_like 'a valid deploy token'
      end

      it_behaves_like 'when file is in object storage'
    end
  end

  # GET /v2/virtual_registries/container/:id/*path/referrers/:digest
  describe 'GET referrers' do
    let(:digest) { "sha256:#{'a' * 64}" }
    let(:path) { "/v2/virtual_registries/container/#{registry.id}/#{image}/referrers/#{digest}" }
    let(:referrers_body) do
      {
        schemaVersion: 2,
        mediaType: 'application/vnd.oci.image.index.v1+json',
        manifests: [{ mediaType: 'application/vnd.oci.image.manifest.v1+json', digest: digest, size: 1234 }]
      }.to_json
    end

    let(:base_referrers_payload) { { raw_body: referrers_body, filters_applied: nil } }

    let(:referrers_service_response) do
      ServiceResponse.success(payload: base_referrers_payload)
    end

    let(:referrers_service_double) do
      instance_double(
        ::VirtualRegistries::Container::HandleReferrersRequestService,
        execute: referrers_service_response
      )
    end

    subject(:send_request) { get path, headers: headers }

    before do
      allow(::VirtualRegistries::Container::HandleReferrersRequestService)
        .to receive(:new)
        .and_return(referrers_service_double)
    end

    it_behaves_like 'returns unauthorized without a token'
    it_behaves_like 'rate limited endpoint',
      rate_limit_key: :virtual_registries_endpoints_api_limit,
      use_second_scope: false do
      let(:current_user) { user }

      def request
        get path, headers: headers
      end
    end

    it_behaves_like 'validates feature flags and licensing'
    it_behaves_like 'validates permissions'
    it_behaves_like 'validates service_type claim'

    context 'with valid digest and upstream returns referrers list' do
      it 'returns 200 with correct Content-Type and upstream body' do
        send_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers['Content-Type']).to include(described_class::OCI_REFERRERS_CONTENT_TYPE)
        expect(response.body).to eq(referrers_body)
      end
    end

    context 'with valid digest and upstream returns 404 (empty index)' do
      let(:referrers_service_response) do
        ServiceResponse.success(
          payload: base_referrers_payload.merge(
            raw_body: ::VirtualRegistries::Container::HandleReferrersRequestService::EMPTY_INDEX.to_json
          )
        )
      end

      it 'returns 200 with empty OCI image index' do
        send_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers['Content-Type']).to include(described_class::OCI_REFERRERS_CONTENT_TYPE)
        parsed = Gitlab::Json.safe_parse(response.body)
        expect(parsed['manifests']).to be_empty
      end
    end

    context 'with artifactType filter applied' do
      let(:referrers_service_response) do
        ServiceResponse.success(payload: base_referrers_payload.merge(filters_applied: 'artifactType'))
      end

      it 'forwards OCI-Filters-Applied header' do
        send_request

        expect(response.headers['OCI-Filters-Applied']).to eq('artifactType')
      end
    end

    context 'with paginated upstream response' do
      it 'does not forward the Link header' do
        send_request

        expect(response.headers['Link']).to be_nil
      end
    end

    context 'with invalid registry id' do
      let(:path) { "/v2/virtual_registries/container/#{non_existing_record_id}/#{image}/referrers/#{digest}" }

      before do
        allow(::VirtualRegistries::Container::HandleReferrersRequestService).to receive(:new).and_call_original
      end

      it 'returns not found' do
        send_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with service error responses' do
      where(:reason, :expected_status) do
        :upstream_not_available | :service_unavailable
        :no_upstreams           | :not_found
        :upstream_auth_error    | :bad_gateway
      end

      with_them do
        let(:referrers_service_response) do
          ServiceResponse.error(message: 'error', reason: reason)
        end

        it "returns the expected status" do
          send_request

          expect(response).to have_gitlab_http_status(expected_status)
        end
      end
    end

    context 'when service returns invalid_artifact_type error' do
      let(:referrers_service_response) do
        ServiceResponse.error(message: 'Invalid artifactType parameter', reason: :invalid_artifact_type)
      end

      it 'returns 400 with an OCI-compliant error body' do
        send_request

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(response.parsed_body['errors']).to contain_exactly(
          { 'code' => 'UNSUPPORTED', 'message' => 'Invalid artifactType parameter' }
        )
      end
    end
  end

  # GET /v2/virtual_registries/container/:id/*image/referrers/*tag (catch-all for malformed paths)
  describe 'GET referrers_not_found' do
    let(:path) { "/v2/virtual_registries/container/#{registry.id}/#{image}/referrers/not-a-valid-digest" }

    subject(:send_request) { get path, headers: headers }

    it_behaves_like 'rate limited endpoint',
      rate_limit_key: :virtual_registries_endpoints_api_limit,
      use_second_scope: false do
      def request
        get path, headers: headers
      end
    end

    it 'sets the Docker-Distribution-Api-Version header' do
      send_request

      expect(response.headers['Docker-Distribution-Api-Version']).to eq('registry/2.0')
    end

    context 'with a valid image name and malformed digest' do
      it 'returns 400 DIGEST_INVALID' do
        send_request

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(response.parsed_body['errors']).to contain_exactly(
          { 'code' => 'DIGEST_INVALID', 'message' => 'Invalid digest format' }
        )
      end
    end

    context 'with an invalid image name' do
      let(:path) { "/v2/virtual_registries/container/#{registry.id}/invalid*/referrers/not-a-digest" }

      it 'returns 400 NAME_INVALID' do
        send_request

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(response.parsed_body['errors']).to contain_exactly(
          { 'code' => 'NAME_INVALID', 'message' => 'Invalid repository name' }
        )
      end
    end

    context 'without a JWT token' do
      let(:headers) { {} }

      it 'still returns 400 without requiring authentication' do
        send_request

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end
  end

  # POST /v2/virtual_registries/container/:id/*path/upload
  describe 'POST upload' do
    include_context 'workhorse headers'

    let(:sha) { 'sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08' }
    let(:upload_path) { "#{image}/blobs/#{sha}" }
    let(:path) { "/v2/virtual_registries/container/#{registry.id}/#{upload_path}/upload" }
    let(:file_upload) { fixture_file_upload('spec/fixtures/dk.png') }
    let(:gid_header) { { described_class::UPSTREAM_GID_HEADER => upstream.to_global_id.to_s } }
    let(:additional_headers) do
      gid_header.merge(Gitlab::Workhorse::SEND_DEPENDENCY_CONTENT_TYPE_HEADER => 'application/octet-stream')
    end

    let(:request_headers) { headers.merge(workhorse_headers).merge(additional_headers) }

    subject(:send_request) do
      workhorse_finalize(
        path,
        file_key: :file,
        headers: request_headers,
        params: {
          file: file_upload,
          'file.sha1' => '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83'
        },
        send_rewritten_field: true
      )
    end

    it { is_expected.to have_request_urgency(:low) }

    it_behaves_like 'rate limited endpoint',
      rate_limit_key: :virtual_registries_endpoints_api_limit,
      use_second_scope: false do
      let(:current_user) { user }

      def request
        workhorse_finalize(
          path,
          file_key: :file,
          headers: request_headers,
          params: {
            file: fixture_file_upload('spec/fixtures/dk.png'),
            'file.sha1' => '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83'
          },
          send_rewritten_field: true
        )
      end
    end

    it_behaves_like 'validates feature flags and licensing'

    context 'with valid request' do
      it 'accepts the upload and creates a cache entry' do
        expect { send_request }.to change { upstream.cache_remote_entries.count }.by(1)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to eq('')
      end

      it 'creates a cache entry with correct attributes' do
        send_request

        cache_entry = upstream.cache_remote_entries.find_by(relative_path: "/#{upload_path}")
        expect(cache_entry).to have_attributes(
          relative_path: "/#{image}/blobs/#{sha}",
          upstream_id: upstream.id,
          group_id: group.id,
          content_type: 'application/octet-stream',
          file_sha1: '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83'
        )
        expect(cache_entry.file).to be_present
        expect(cache_entry.size).to be > 0
      end

      context 'with quoted etag header' do
        let(:additional_headers) do
          gid_header.merge(
            Gitlab::Workhorse::SEND_DEPENDENCY_CONTENT_TYPE_HEADER => 'application/octet-stream',
            'Etag' => '"7901283c50d90d8a5a1fef11773b59d2"'
          )
        end

        it 'sanitizes the etag by removing quotes' do
          send_request

          cache_entry = upstream.cache_remote_entries.find_by(relative_path: "/#{image}/blobs/#{sha}")
          expect(cache_entry.upstream_etag).to eq('7901283c50d90d8a5a1fef11773b59d2')
        end
      end
    end

    context 'without authentication' do
      let(:request_headers) { workhorse_headers.merge(additional_headers) }

      it 'returns unauthorized' do
        send_request

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'with invalid upstream gid' do
      let_it_be(:upstream) { build(:virtual_registries_container_upstream, id: non_existing_record_id) }

      it 'returns not found' do
        send_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with upstream not belonging to registry' do
      let_it_be(:upstream) { create(:virtual_registries_container_upstream) }

      it 'returns not found' do
        send_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with missing upstream gid header' do
      let(:gid_header) { {} }

      it 'returns not found' do
        send_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when service returns an error' do
      before do
        allow_next_instance_of(VirtualRegistries::Container::Cache::Entries::CreateOrUpdateService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.error(message: 'Persistence error', reason: :persistence_error)
          )
        end
      end

      it 'returns bad request' do
        send_request

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end
  end
end
