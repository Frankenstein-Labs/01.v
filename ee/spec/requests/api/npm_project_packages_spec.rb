# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::NpmProjectPackages, feature_category: :package_registry do
  include HttpBasicAuthHelpers
  include WorkhorseHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, maintainers: user) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
  let_it_be(:package) { create(:npm_package, project: project) }

  let(:firewall_service) { Security::DependencyFirewall::EnforcementService }
  let(:headers) { basic_auth_header(user.username, personal_access_token.token) }

  describe 'GET /api/v4/projects/:id/packages/npm/*package_name/-/*file_name' do
    let(:package_file) { package.package_files.first }
    let(:url) { "/projects/#{project.id}/packages/npm/#{package.name}/-/#{package_file.file_name}" }

    subject { get api(url), headers: headers }

    it_behaves_like 'applying ip restriction for group'
  end

  describe 'GET /api/v4/projects/:id/packages/npm/*package_name/-/*file_name (dependency firewall)' do
    let(:package_file) { package.package_files.first }
    let(:url) { "/projects/#{project.id}/packages/npm/#{package.name}/-/#{package_file.file_name}" }
    # npm authenticates via a Bearer token (basic auth is ignored), so this resolves
    # current_user; without it the firewall would receive current_user: nil.
    let(:headers) { build_token_auth_header(personal_access_token.token) }

    subject(:download) { get api(url), headers: headers }

    shared_examples 'npm dependency firewall enforcement on download' do
      before do
        stub_feature_flags(dependency_firewall_phase1: project.root_ancestor)
        allow(firewall_service).to receive(:firewall_check)
          .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))
      end

      context 'when the dependency_firewall_phase1 feature flag is disabled' do
        before do
          stub_feature_flags(dependency_firewall_phase1: false)
        end

        it 'does not call the firewall and serves the file', :aggregate_failures do
          expect(firewall_service).not_to receive(:firewall_check)

          download

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when the firewall allows the package' do
        it 'serves the file' do
          download

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'calls the firewall with the normalized name, version, operation, and current_user', :aggregate_failures do
          expect(firewall_service).to receive(:firewall_check)
            .with(
              project: package.project,
              pkg_type: 'npm',
              name: package.name,
              version: package.version,
              operation: firewall_service::PACKAGE_DOWNLOAD,
              current_user: user
            )
            .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))

          download

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when the firewall warns on the package' do
        let(:warning_message) { "Package 'foo' violates 'License policy' policy" }

        before do
          allow(firewall_service).to receive(:firewall_check)
            .and_return(ServiceResponse.success(
              payload: { status: firewall_service::SUCCESS_WARNING, message: warning_message }
            ))
        end

        it 'serves the file and sets the warning header', :aggregate_failures do
          download

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.headers['X-Gitlab-Dependency-Firewall-Warning']).to eq(warning_message)
        end
      end

      context 'when the firewall blocks the package' do
        before do
          allow(firewall_service).to receive(:firewall_check)
            .and_return(ServiceResponse.error(message: nil, reason: firewall_service::SUCCESS_BLOCKED))
        end

        it 'returns 403 with a policy violation error', :aggregate_failures do
          download

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['error']).to eq('Dependency Firewall policy violation')
        end

        it 'does not track a pull_package event', :aggregate_failures do
          expect(::Gitlab::Tracking).not_to receive(:event).with(anything, 'pull_package', anything)

          download

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when firewall_check returns a non-blocking error response' do
        before do
          allow(firewall_service).to receive(:firewall_check)
            .and_return(ServiceResponse.error(message: 'upstream unavailable', reason: :service_unavailable))
        end

        it 'serves the file' do
          download

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when the firewall is not licensed' do
        before do
          allow(project).to receive(:licensed_feature_available?).and_call_original
          allow(project).to receive(:licensed_feature_available?).with(:dependency_firewall).and_return(false)
        end

        it 'serves the file', :aggregate_failures do
          expect(firewall_service).to receive(:firewall_check).and_call_original

          download

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    it_behaves_like 'npm dependency firewall enforcement on download'
  end

  describe 'GET .../packages/npm/*package_name/-/*file_name (forwarded firewall)' do
    let_it_be(:fw_project) { create(:project, :public, group: group) }

    let(:package_name) { 'lodash' }
    let(:file_name) { 'lodash-4.17.21.tgz' }
    let(:url) { "/projects/#{fw_project.id}/packages/npm/#{package_name}/-/#{file_name}" }
    let(:headers) { build_token_auth_header(personal_access_token.token) }
    let(:upstream_tarball) { 'https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz' }

    subject(:download) { get api(url), headers: headers }

    before do
      stub_licensed_features(dependency_firewall: true)
      stub_feature_flags(dependency_firewall_phase1: fw_project.root_ancestor)
      stub_application_setting(npm_package_requests_forwarding: true)
      allow(firewall_service).to receive(:firewall_check)
        .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))
    end

    context 'when the package is not hosted locally and forwarding + flag are on' do
      it 'firewall-checks the parsed version and 302-redirects to the upstream tarball', :aggregate_failures do
        expect(firewall_service).to receive(:firewall_check)
          .with(
            project: fw_project,
            pkg_type: 'npm',
            name: package_name,
            version: '4.17.21',
            operation: firewall_service::PACKAGE_DOWNLOAD,
            current_user: user
          )
          .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))

        download

        expect(response).to have_gitlab_http_status(:found)
        expect(response.headers['Location']).to eq(upstream_tarball)
      end

      context 'when the firewall blocks the package' do
        before do
          allow(firewall_service).to receive(:firewall_check)
            .and_return(ServiceResponse.error(message: nil, reason: firewall_service::SUCCESS_BLOCKED))
        end

        it 'returns 403 and does not redirect', :aggregate_failures do
          download

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['error']).to eq('Dependency Firewall policy violation')
        end
      end

      context 'with a scoped package' do
        let(:package_name) { '@scope/pkg' }
        let(:file_name) { 'pkg-4.17.21.tgz' }

        it 'firewall-checks the normalized name and parsed version, keeping the scope in the path',
          :aggregate_failures do
          expect(firewall_service).to receive(:firewall_check)
            .with(hash_including(name: '@scope/pkg', version: '4.17.21'))
            .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))

          download

          expect(response).to have_gitlab_http_status(:found)
          expect(response.headers['Location']).to eq('https://registry.npmjs.org/@scope/pkg/-/pkg-4.17.21.tgz')
        end
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(dependency_firewall_phase1: false)
      end

      it 'forwards to the upstream registry without calling the firewall', :aggregate_failures do
        expect(firewall_service).not_to receive(:firewall_check)

        download

        expect(response).to have_gitlab_http_status(:found)
        expect(response.headers['Location']).to eq(upstream_tarball)
      end
    end

    context 'when forwarding is disabled' do
      before do
        stub_application_setting(npm_package_requests_forwarding: false)
      end

      it 'does not call the firewall and returns 404', :aggregate_failures do
        expect(firewall_service).not_to receive(:firewall_check)

        download

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the firewall is not licensed' do
      before do
        stub_licensed_features(dependency_firewall: false)
      end

      it 'forwards to the upstream registry without calling the firewall', :aggregate_failures do
        expect(firewall_service).not_to receive(:firewall_check)

        download

        expect(response).to have_gitlab_http_status(:found)
        expect(response.headers['Location']).to eq(upstream_tarball)
      end
    end

    context 'when the requested filename does not match the package name' do
      let(:file_name) { 'evil-1.0.0.tgz' }

      it 'does not call the firewall and returns 404', :aggregate_failures do
        expect(firewall_service).not_to receive(:firewall_check)

        download

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET .../packages/npm/*package_name (forwarded metadata)' do
    let_it_be(:fw_project) { create(:project, :public, group: group) }

    let(:package_name) { 'lodash' }
    let(:url) { "/projects/#{fw_project.id}/packages/npm/#{package_name}" }
    let(:headers) { build_token_auth_header(personal_access_token.token) }
    let(:upstream_url) { 'https://registry.npmjs.org/lodash' }
    let(:send_data_header) { ::Gitlab::Workhorse::SEND_DATA_HEADER }

    subject(:metadata) { get api(url), headers: headers }

    def decoded_send_url_params
      type, params = workhorse_send_data
      return unless type == 'send-url'

      params
    end

    before do
      stub_licensed_features(dependency_firewall: true)
      stub_feature_flags(dependency_firewall_phase1: fw_project.root_ancestor)
      stub_application_setting(npm_package_requests_forwarding: true)
    end

    context 'when the package is not hosted locally and forwarding + flag are on' do
      it 'hands off to Workhorse with a send-url transform instruction', :aggregate_failures do
        metadata

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to be_empty

        params = decoded_send_url_params
        expect(params['URL']).to eq(upstream_url)
        expect(params['SSRFFilter']).to be(true)
        expect(params['AllowLocalhost']).to be(false)
        expect(params['RestrictForwardedResponseHeaders'])
          .to eq('Enabled' => true, 'AllowList' => %w[Content-Type ETag])
        expect(params['ErrorResponseStatus']).to eq(502)
        expect(params['TimeoutResponseStatus']).to eq(502)
        expect(params.dig('TransformConfig', 'Key')).to eq('tarball')
        expect(params.dig('TransformConfig', 'From')).to eq('https://registry.npmjs.org/')
        expect(params.dig('TransformConfig', 'To'))
          .to end_with("/api/v4/projects/#{fw_project.id}/packages/npm/")
      end

      it 'forwards the client Accept header to Workhorse' do
        get api(url), headers: headers.merge('Accept' => 'application/vnd.npm.install-v1+json')

        expect(decoded_send_url_params.dig('Header', 'Accept')).to eq(['application/vnd.npm.install-v1+json'])
      end

      it 'tracks the npm_request_forward event (preserving the forwarding metric)' do
        allow(::Gitlab::Tracking).to receive(:event)

        metadata

        expect(::Gitlab::Tracking).to have_received(:event).with('API::NpmProjectPackages', 'npm_request_forward')
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(dependency_firewall_phase1: false)
      end

      it 'does not hand off to Workhorse and 302-redirects to the upstream registry', :aggregate_failures do
        metadata

        expect(response).to have_gitlab_http_status(:found)
        expect(response.headers['Location']).to eq(upstream_url)
        expect(response.headers[send_data_header]).to be_nil
      end
    end

    context 'when forwarding is disabled' do
      before do
        stub_application_setting(npm_package_requests_forwarding: false)
      end

      it 'does not hand off to Workhorse', :aggregate_failures do
        metadata

        expect(response.headers[send_data_header]).to be_nil
      end
    end

    context 'when the firewall is not licensed' do
      before do
        stub_licensed_features(dependency_firewall: false)
      end

      it 'does not hand off to Workhorse and 302-redirects to the upstream registry', :aggregate_failures do
        metadata

        expect(response).to have_gitlab_http_status(:found)
        expect(response.headers['Location']).to eq(upstream_url)
        expect(response.headers[send_data_header]).to be_nil
      end
    end

    context 'with a scoped package' do
      let(:package_name) { '@scope/pkg' }

      it 'forwards the scoped package via registry_url (scope kept unencoded)' do
        metadata

        expect(decoded_send_url_params['URL']).to eq('https://registry.npmjs.org/@scope/pkg')
      end
    end

    context 'when the package is hosted locally on the forward-candidate project' do
      let_it_be(:local_package) { create(:npm_package, project: fw_project, name: 'lodash', version: '1.0.0') }

      it 'serves local metadata via CE without handing off to Workhorse', :aggregate_failures do
        metadata

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers[send_data_header]).to be_nil
      end
    end
  end
end
