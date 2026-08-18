# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::VirtualRegistries::Packages::Maven::Endpoints, :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax
  include_context 'for maven virtual registry api setup'

  before do
    stub_feature_flags(maven_problem_details_errors: false)
  end

  shared_examples 'maven virtual registry authenticated endpoint' do |success_shared_example_name:|
    %i[personal_access_token deploy_token job_token].each do |token_type|
      context "with a #{token_type}" do
        let_it_be(:user) { deploy_token } if token_type == :deploy_token

        context 'when sent by headers' do
          let(:headers) { super().merge(token_header(token_type)) }

          it_behaves_like success_shared_example_name
        end

        context 'when sent by basic auth' do
          let(:headers) { super().merge(token_basic_auth(token_type)) }

          it_behaves_like success_shared_example_name
        end
      end
    end

    context 'with an oauth_token' do
      context 'when sent by bearer header' do
        let(:headers) { super().merge(token_header(:oauth_token, sent_as: :bearer_header)) }

        it_behaves_like success_shared_example_name
      end

      context 'when sent as a query param' do
        let(:url) { "#{super()}?#{token_query_param(:oauth_token).to_query}" }

        it_behaves_like success_shared_example_name
      end

      it_behaves_like 'virtual registry invalid oauth token'
    end
  end

  describe 'GET /api/v4/virtual_registries/packages/maven/:id/*path' do
    let_it_be(:path) { 'com/test/package/1.2.3/package-1.2.3.pom' }

    let(:url) { "/virtual_registries/packages/maven/#{registry.id}/#{path}" }
    let(:service_response) do
      ServiceResponse.success(
        payload: {
          action: :workhorse_upload_url,
          action_params: { url: upstream.url_for(path), upstream: upstream }
        }
      )
    end

    let(:service_double) do
      instance_double(::VirtualRegistries::Packages::Maven::HandleFileRequestService, execute: service_response)
    end

    before do
      allow(::VirtualRegistries::Packages::Maven::HandleFileRequestService)
        .to receive(:new)
        .with(registry: registry, current_user: user, params: { path: path })
        .and_return(service_double)
    end

    subject(:request) do
      get api(url), headers: headers
    end

    shared_examples 'returning the workhorse send_url response' do
      it 'returns a workhorse send_url response' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers[Gitlab::Workhorse::SEND_DATA_HEADER]).to start_with('send-url:')
        expect(response.headers['Content-Type']).to eq('application/octet-stream')
        expect(response.headers['Content-Length'].to_i).to eq(0)
        expect(response.body).to eq('')

        send_data_type, send_data = workhorse_send_data

        expected_restrict_forwarded_response_headers = {
          'Enabled' => true,
          'AllowList' => described_class::ALLOWED_RESPONSE_HEADERS
        }
        expected_resp_headers = described_class::EXTRA_RESPONSE_HEADERS.deep_transform_values do |value|
          [value]
        end

        expect(send_data_type).to eq('send-url')
        expect(send_data['URL']).to be_present
        expect(send_data['Header']).to eq({})
        expect(send_data['ResponseHeaders']).to eq(expected_resp_headers)
        expect(send_data['AllowLocalhost']).to be_truthy
        expect(send_data['AllowRedirects']).to be_truthy
        expect(send_data['ResponseHeaderTimeout']).to eq('10s')
        expect(send_data['DialTimeout']).to eq('10s')
        expect(send_data['ErrorResponseStatus']).to eq(502)
        expect(send_data['TimeoutResponseStatus']).to eq(504)
        expect(send_data['RestrictForwardedResponseHeaders']).to eq(expected_restrict_forwarded_response_headers)
      end
    end

    shared_examples 'returning the workhorse send_dependency response' do
      let(:enabled_endpoint_uris) { [URI('192.168.1.1')] }
      let(:outbound_local_requests_allowlist) { ['127.0.0.1'] }
      let(:allowed_endpoints) { enabled_endpoint_uris + outbound_local_requests_allowlist }

      before do
        allow(ObjectStoreSettings).to receive(:enabled_endpoint_uris).and_return(enabled_endpoint_uris)
        stub_application_setting(outbound_local_requests_whitelist: outbound_local_requests_allowlist)
      end

      it 'returns a workhorse upload_url response' do
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

        request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers[Gitlab::Workhorse::SEND_DATA_HEADER]).to start_with('send-dependency:')
        expect(response.headers['Content-Type']).to eq('application/octet-stream')
        expect(response.headers['Content-Length'].to_i).to eq(0)
        expect(response.body).to eq('')

        send_data_type, send_data = workhorse_send_data

        expected_headers = upstream.headers.deep_stringify_keys.deep_transform_values do |value|
          [value]
        end

        expected_resp_headers = described_class::EXTRA_RESPONSE_HEADERS.deep_transform_values do |value|
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
        expect(send_data['RestrictForwardedResponseHeaders']).to include(expected_restrict_forwarded_response_headers)
      end
    end

    it_behaves_like 'maven virtual registry authenticated endpoint',
      success_shared_example_name: 'returning the workhorse send_dependency response' do
        let(:headers) { {} }
      end

    context 'with a valid user' do
      let(:headers) { { 'Private-Token' => personal_access_token.token } }

      context 'with successful handle request service responses' do
        let_it_be(:cache_entry) do
          create(
            :virtual_registries_packages_maven_cache_remote_entry,
            content_type: 'text/xml',
            upstream: upstream,
            group_id: upstream.group_id,
            relative_path: "/#{path}"
          )
        end

        before do
          # reset the test stub to use the actual service
          allow(::VirtualRegistries::Packages::Maven::HandleFileRequestService).to receive(:new).and_call_original
        end

        context 'when the handle request service returns download_file' do
          it 'returns the workhorse send_url response' do
            request

            expect(response).to have_gitlab_http_status(:ok)
            expect(response.media_type).to eq(cache_entry.content_type)
            # this is a direct download from the file system, workhorse is not involved
            expect(response.headers[Gitlab::Workhorse::SEND_DATA_HEADER]).to be_nil
          end
        end

        context 'when the handle request service returns download_digest' do
          let(:path) { "#{super()}.sha1" }

          it 'returns the requested digest' do
            request

            expect(response).to have_gitlab_http_status(:ok)
            expect(response.media_type).to eq('text/plain')
            expect(response.body).to eq(cache_entry.file_sha1)
          end

          context 'when cache is not found' do
            let(:service_response) do
              ServiceResponse.success(
                payload: {
                  action: :workhorse_send_url,
                  action_params: { url: upstream.url_for(path) }
                }
              )
            end

            before do
              allow(::VirtualRegistries::Packages::Maven::HandleFileRequestService)
                .to receive(:new)
                .with(registry: registry, current_user: user, params: { path: path })
                .and_return(service_double)
            end

            it_behaves_like 'returning the workhorse send_url response'
          end
        end
      end

      context 'with service response errors' do
        where(:reason, :expected_status) do
          :path_not_present                  | :bad_request
          :unauthorized                      | :unauthorized
          :no_upstreams                      | :bad_request
          :file_not_found_on_upstreams       | :not_found
          :upstream_not_available            | :bad_request
          :fips_unsupported_md5              | :bad_request
        end

        with_them do
          let(:service_response) do
            ServiceResponse.error(message: 'error', reason: reason)
          end

          it "returns a #{params[:expected_status]} response" do
            request

            expect(response).to have_gitlab_http_status(expected_status)
            expect(response.body).to include('error') unless expected_status == :unauthorized
          end
        end
      end

      context 'with a web browser' do
        before do
          allow_next_instance_of(::Browser) do |b|
            allow(b).to receive(:known?).and_return(true)
          end
        end

        it 'returns a bad request response' do
          request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(response.body).to include(described_class::WEB_BROWSER_ERROR_MESSAGE)
        end
      end

      it_behaves_like 'rate limited endpoint', rate_limit_key: :virtual_registries_endpoints_api_limit do
        let_it_be(:other_group) { create(:group, owners: user) }
        let_it_be(:other_registry) { create(:virtual_registries_packages_maven_registry, group: other_group) }

        let(:current_user) { user }

        before do
          allow(::VirtualRegistries::Packages::Maven::HandleFileRequestService)
            .to receive(:new)
            .with(registry: other_registry, current_user: user, params: { path: path })
            .and_return(service_double)
        end

        def request
          get api(url), headers: headers
        end

        def request_with_second_scope
          get api("/virtual_registries/packages/maven/#{other_registry.id}/#{path}"), headers: headers
        end
      end

      context 'for a invalid registry id' do
        let(:url) { "/virtual_registries/packages/maven/#{non_existing_record_id}/#{path}" }

        it_behaves_like 'returning response status', :not_found
      end

      context 'with a personal access token with only the read_virtual_registry scope' do
        let(:personal_access_token) { create(:personal_access_token, user: user, scopes: ['read_virtual_registry']) }

        let(:headers) { { 'Private-Token' => personal_access_token.token } }

        before do
          # read_virtual_registry is only available when the dependency proxy feature is enabled
          stub_config(dependency_proxy: { enabled: true })
        end

        it_behaves_like 'returning the workhorse send_dependency response'
      end

      it_behaves_like 'authorizing granular token permissions', :download_maven_package_file do
        let(:boundary_object) { registry.group }
        let(:request) do
          get api(url), headers: { 'Private-Token' => pat.token }
        end
      end

      context 'with a project member who is not a group member' do
        let(:user) { create(:user, maintainer_of: project) }

        it 'denies with 404 (no :read_group) or 403 (fails virtual registry authorization)' do
          request

          expect(response.status).to eq(403).or eq(404)
        end
      end
    end

    context 'with no user' do
      let(:headers) { {} }

      it 'returns unauthorized with the www-authenticate header' do
        request

        expect(response).to have_gitlab_http_status(:unauthorized)
        expect(response.headers[described_class::AUTHENTICATE_REALM_HEADER])
          .to eq(described_class::AUTHENTICATE_REALM_NAME)
      end
    end

    it_behaves_like 'virtual registry not available', :maven

    it_behaves_like 'virtual registry custom role read access' do
      before do
        allow(::VirtualRegistries::Packages::Maven::HandleFileRequestService)
          .to receive(:new)
          .and_return(service_double)
      end
    end

    context 'without Workhorse JWT', :verify_workhorse_jwt do
      let(:headers) { { 'Private-Token' => personal_access_token.token } }

      it 'returns 403 forbidden' do
        request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'POST /api/v4/virtual_registries/packages/maven/:id/*path/upload' do
    include_context 'workhorse headers'

    let(:file_upload) { fixture_file_upload('spec/fixtures/packages/maven/my-app-1.0-20180724.124855-1.pom') }
    let(:gid_header) { { described_class::UPSTREAM_GID_HEADER => upstream.to_global_id.to_s } }
    let(:additional_headers) do
      gid_header.merge(::Gitlab::Workhorse::SEND_DEPENDENCY_CONTENT_TYPE_HEADER => 'text/xml')
    end

    let(:headers) { workhorse_headers.merge(additional_headers) }

    let_it_be(:path) { 'com/test/package/1.2.3/package-1.2.3.pom' }
    let_it_be(:url) { "/virtual_registries/packages/maven/#{registry.id}/#{path}/upload" }
    let_it_be(:processing_cache_entries) do
      create(
        :virtual_registries_packages_maven_cache_remote_entry,
        :processing,
        upstream: upstream,
        group: upstream.group,
        relative_path: "/#{path}"
      )
    end

    subject(:request) do
      workhorse_finalize(
        api(url),
        file_key: :file,
        headers: headers,
        params: {
          file: file_upload,
          'file.md5' => 'd8e8fca2dc0f896fd7cb4cb0031ba249',
          'file.sha1' => '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83'
        },
        send_rewritten_field: true
      )
    end

    shared_examples 'returning successful response' do
      it 'accepts the upload', :freeze_time do
        expect { request }.to change { upstream.cache_entries.count }.by(1)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to eq('')
        expect(upstream.default_cache_entries.search_by_relative_path(path).last).to have_attributes(
          relative_path: "/#{path}",
          upstream_etag: nil,
          upstream_checked_at: Time.zone.now,
          file_sha1: kind_of(String),
          file_md5: kind_of(String)
        )
      end
    end

    it_behaves_like 'maven virtual registry authenticated endpoint',
      success_shared_example_name: 'returning successful response'

    context 'with a valid user' do
      let(:headers) { super().merge(token_header(:personal_access_token)) }

      context 'with no workhorse headers' do
        let(:headers) { token_header(:personal_access_token).merge(gid_header) }

        it_behaves_like 'returning response status', :forbidden
      end

      context 'with no permissions on registry' do
        let_it_be(:user) { create(:user) }

        it_behaves_like 'returning response status', :not_found
      end

      context 'with an invalid upstream gid' do
        let_it_be(:upstream) { build(:virtual_registries_packages_maven_upstream, id: non_existing_record_id) }

        it_behaves_like 'returning response status', :not_found
      end

      context 'with an incoherent upstream gid' do
        let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream) }

        it_behaves_like 'returning response status', :not_found
      end

      context 'with a persistence error' do
        before do
          allow(::VirtualRegistries::Packages::Maven::Cache::Remote::Entry)
            .to receive(:create_or_update_by!).and_raise(ActiveRecord::RecordInvalid)
        end

        it_behaves_like 'returning response status', :bad_request
      end

      it_behaves_like 'authorizing granular token permissions', :upload_maven_package_file do
        let(:boundary_object) { registry.group }
        let(:headers) { super().merge({ 'Private-Token' => pat.token }) }
        let(:request) do
          workhorse_finalize(
            api(url),
            file_key: :file,
            headers: headers,
            params: {
              file: file_upload,
              'file.md5' => 'd8e8fca2dc0f896fd7cb4cb0031ba249',
              'file.sha1' => '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83'
            },
            send_rewritten_field: true
          )
        end
      end

      context 'with a project member who is not a group member' do
        let(:user) { create(:user, maintainer_of: project) }

        it 'denies with 404 (no :read_group) or 403 (fails virtual registry authorization)' do
          request

          expect(response.status).to eq(403).or eq(404)
        end
      end
    end

    it_behaves_like 'virtual registry not available', :maven

    it_behaves_like 'virtual registry custom role read access' do
      let(:headers) { workhorse_headers.merge(additional_headers).merge('PRIVATE-TOKEN' => custom_role_token) }
    end
  end

  describe 'RFC 9457 problem details' do
    let(:path) { 'com/test/package/1.2.3/package-1.2.3.pom' }
    let(:url) { "/virtual_registries/packages/maven/#{registry.id}/#{path}" }

    subject(:request) do
      get api(url), headers: headers
    end

    context 'with a non-group member' do
      let_it_be(:user) { create(:user, maintainer_of: project) }

      before do
        stub_feature_flags(maven_problem_details_errors: true)
      end

      # 404 when SharedSetup denies :read_group; 403 when :read_group passes and authorize! fails
      it 'returns RFC 9457 problem details for 403 or 404' do
        request

        expect(response.content_type).to eq('application/problem+json')
        expect(json_response['status']).to eq(403).or eq(404)
        status_code = json_response['status']
        expect(json_response).to include(
          'type' => 'about:blank',
          'status' => status_code,
          'title' => Rack::Utils::HTTP_STATUS_CODES[status_code]
        )
        expect(json_response['detail'])
          .to eq("#{status_code} #{Rack::Utils::HTTP_STATUS_CODES[status_code]}")
      end

      context 'when maven_problem_details_errors is disabled' do
        before do
          stub_feature_flags(maven_problem_details_errors: false)
        end

        it 'returns a standard JSON error for 403 or 404' do
          request

          expect(response.status).to eq(403).or eq(404)
          expect(response.content_type).not_to eq('application/problem+json')
          expect(json_response).to have_key('message')
        end
      end
    end

    context 'when rate-limited with maven_problem_details_errors enabled' do
      before do
        stub_feature_flags(maven_problem_details_errors: true)
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?).and_return(true)
      end

      it 'returns 429 with RFC 9457 problem details and is not a 500' do
        get api(url), headers: headers

        expect(response).to have_gitlab_http_status(:too_many_requests)
        expect(response.content_type).to include('application/problem+json')
        expect(response.headers['Retry-After']).to be_present
      end
    end
  end
end
