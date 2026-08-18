# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::PypiPackages, feature_category: :package_registry do
  include WorkhorseHelpers
  include PackagesManagerApiSpecHelpers
  include HttpBasicAuthHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group, freeze: false) { create(:group, maintainers: user) }
  let_it_be(:project, freeze: false) { create(:project, group: group) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
  let_it_be(:package_name) { 'Dummy-Package' }
  let_it_be(:package) { create(:pypi_package, project: project, name: package_name, version: '1.0.0') }

  let(:file_sha256) { package.package_files.first.file_sha256 }
  let(:headers) { basic_auth_header(user.username, personal_access_token.token) }
  let(:firewall_service) { Security::DependencyFirewall::EnforcementService }
  let(:snowplow_gitlab_standard_context) do
    { project: project, namespace: group, property: 'i_package_pypi_user', user: user }
  end

  subject(:download) { get api(url), headers: headers }

  shared_examples 'allowing auditor to download' do
    context 'when group/project is private' do
      let(:headers) { user_basic_auth_header(create(:auditor)) }

      before do
        target.update_column(:visibility_level, ::Gitlab::VisibilityLevel.const_get(:PRIVATE, false))
      end

      it_behaves_like 'returning response status', :success
    end
  end

  shared_examples 'pypi dependency firewall enforcement on download' do
    before do
      allow(firewall_service).to receive(:firewall_check)
        .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))
    end

    context 'when the dependency_firewall_phase1 feature flag is disabled' do
      before do
        stub_feature_flags(dependency_firewall_phase1: false)
      end

      it 'does not call the firewall and allows the download', :aggregate_failures do
        expect(firewall_service).not_to receive(:firewall_check)

        download

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when the dependency_firewall_phase1 feature flag is enabled' do
      context 'when the firewall allows the package' do
        it 'calls the firewall with the PEP 503 normalized name, version, operation, and current_user',
          :aggregate_failures do
          expect(firewall_service).to receive(:firewall_check)
            .with(
              project: package.project,
              pkg_type: 'pypi',
              name: package.normalized_pypi_name,
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
        let(:warning_message) { "Package 'requests' violates 'License policy' policy" }

        before do
          allow(firewall_service).to receive(:firewall_check)
            .and_return(ServiceResponse.success(
              payload: { status: firewall_service::SUCCESS_WARNING, message: warning_message }
            ))
        end

        it 'allows the download and sets the warning header', :aggregate_failures do
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
          expect(::Gitlab::Tracking).not_to receive(:event).with(anything, 'pull_package', anything)

          download

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['error']).to eq('Dependency Firewall policy violation')
        end
      end

      context 'when firewall_check returns a non-blocking error response' do
        before do
          allow(firewall_service).to receive(:firewall_check)
            .and_return(ServiceResponse.error(message: 'upstream unavailable', reason: :service_unavailable))
        end

        it 'allows the download' do
          download

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when the firewall is not licensed' do
        before do
          allow(project).to receive(:licensed_feature_available?).with(:dependency_firewall).and_return(false)
        end

        it 'allows the download', :aggregate_failures do
          expect(firewall_service).to receive(:firewall_check).and_call_original

          download

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end
  end

  describe 'GET /api/v4/groups/:id/-/packages/pypi/files/:sha256/*file_identifier' do
    let(:url) { "/groups/#{group.id}/-/packages/pypi/files/#{file_sha256}/#{package_name}-1.0.0.tar.gz" }

    it_behaves_like 'applying ip restriction for group'
    it_behaves_like 'allowing auditor to download' do
      let(:target) { group }
    end
  end

  describe 'GET /api/v4/projects/:id/packages/pypi/files/:sha256/*file_identifier' do
    let(:url) { "/projects/#{project.id}/packages/pypi/files/#{file_sha256}/#{package_name}-1.0.0.tar.gz" }

    it_behaves_like 'applying ip restriction for group'
    it_behaves_like 'allowing auditor to download' do
      let(:target) { project }
    end

    it_behaves_like 'pypi dependency firewall enforcement on download'
  end

  describe 'Flow 1: forwarded simple index', feature_category: :package_registry do
    include_context 'dependency proxy helpers context'

    let(:unknown) { 'requests' }
    let(:url) { "/projects/#{project.id}/packages/pypi/simple/#{unknown}" }
    let(:upstream_simple_url) { 'https://pypi.org/simple/requests/' }
    let(:json_headers) { headers.merge('Accept' => 'application/vnd.pypi.simple.v1+json') }

    def decoded_send_url_params
      return unless response.headers[::Gitlab::Workhorse::SEND_DATA_HEADER]

      type, params = workhorse_send_data
      return unless type == 'send-url'

      params
    end

    before do
      stub_licensed_features(dependency_firewall: true)
      stub_feature_flags(dependency_firewall_phase1: true, pypi_pep_691_json: true)
      allow_fetch_cascade_application_setting(attribute: 'pypi_package_requests_forwarding', return_value: true)
    end

    context 'when the package is unknown locally' do
      it 'hands off to Workhorse with a JSON transform when JSON is requested', :aggregate_failures do
        expect(firewall_service).not_to receive(:firewall_check)
        get api(url), headers: json_headers

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to be_empty

        params = decoded_send_url_params
        expect(params['URL']).to eq(upstream_simple_url)
        expect(params['SSRFFilter']).to be(true)
        # Forced, not forwarded from the client: if this regressed to passing the
        # caller's Accept through, pypi.org could answer with JSON while Format
        # says html, and htmlstream would escape the whole body into one text node.
        expect(params.dig('Header', 'Accept')).to eq([::API::PypiPackages::PEP_691_JSON_CONTENT_TYPE])
        # Carried over from the Ruby client this replaces. Without them Workhorse
        # falls back to no dial timeout and 30s for response headers, so a slow
        # upstream would hold the connection far longer than it used to.
        expect(params['DialTimeout']).to eq('10s')
        expect(params['ResponseHeaderTimeout']).to eq('10s')
        # Transport-level failures only (Workhorse's http.Client.Do returning an
        # error). A completed upstream response keeps its own status, so a real
        # upstream 5xx reaches pip unchanged rather than as a 502 -- see
        # TestCompletedNonSuccessStatusIsNotReplacedByErrorResponseStatus.
        expect(params['ErrorResponseStatus']).to eq(502)
        expect(params['TimeoutResponseStatus']).to eq(502)
        expect(params.dig('TransformConfig', 'Format')).to eq('json')
        expect(params.dig('TransformConfig', 'Key')).to eq('url')
        # The scheme, not the CDN host: every entry is routed back through GitLab so
        # an off-CDN one is rejected at download time, not handed to pip. Workhorse
        # matches the http spelling of this prefix too.
        expect(params.dig('TransformConfig', 'From')).to eq('https://')
        expect(params.dig('TransformConfig', 'To'))
          .to end_with("/api/v4/projects/#{project.id}/packages/pypi/forward/requests/")
      end

      it 'hands off with an HTML transform when JSON is not requested', :aggregate_failures do
        get api(url), headers: headers

        params = decoded_send_url_params
        expect(params.dig('TransformConfig', 'Format')).to eq('html')
        expect(params.dig('TransformConfig', 'Key')).to eq('href')
        expect(params.dig('Header', 'Accept')).to eq(['text/html'])
      end

      # CE emits this from redirect_registry_request, which the Workhorse hand-off
      # replaces -- without it, forwarding volume reads zero once the flag is on.
      it 'tracks the pypi_request_forward event (preserving the forwarding metric)' do
        allow(::Gitlab::Tracking).to receive(:event)

        get api(url), headers: headers

        expect(::Gitlab::Tracking).to have_received(:event).with('API::PypiPackages', 'pypi_request_forward')
      end

      # The chosen format depends on Accept and the upstream ETag is forwarded, so
      # without this a shared cache could serve one format to a client that asked
      # for the other.
      it 'marks the response as varying on Accept for both formats', :aggregate_failures do
        get api(url), headers: json_headers
        expect(response.headers['Vary']).to include('Accept')

        get api(url), headers: headers
        expect(response.headers['Vary']).to include('Accept')
      end

      # The upstream Content-Type is forwarded, so without this a browser would
      # render the proxied pypi.org document as same-origin markup.
      it 'marks the proxied document as an attachment' do
        get api(url), headers: headers

        expect(response.headers['Content-Disposition']).to eq('attachment')
      end
    end

    # `simple/*package_name` is a glob, and PEP 503 normalization does not strip
    # URL metacharacters. Unescaped, a `?` would truncate both the upstream URL we
    # fetch and the prefix every rewritten href is built from, so pip would end up
    # requesting `/forward/evil` and 404ing on a route that does not exist.
    context 'when the package name carries URL metacharacters' do
      let(:url) { "/projects/#{project.id}/packages/pypi/simple/evil%3Fx" }

      it 'escapes the name in both the upstream URL and the rewrite prefix', :aggregate_failures do
        get api(url), headers: json_headers

        params = decoded_send_url_params
        expect(params['URL']).to eq('https://pypi.org/simple/evil%3Fx/')
        expect(params.dig('TransformConfig', 'To'))
          .to end_with("/api/v4/projects/#{project.id}/packages/pypi/forward/evil%3Fx/")
      end
    end

    context 'when a known local package exists' do
      let(:url) { "/projects/#{project.id}/packages/pypi/simple/#{package_name}" }

      it 'serves the local presenter without handing off to Workhorse', :aggregate_failures do
        get api(url), headers: headers
        expect(response).to have_gitlab_http_status(:ok)
        expect(decoded_send_url_params).to be_nil
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(dependency_firewall_phase1: false)
      end

      it 'redirects to pypi.org (existing behaviour)', :aggregate_failures do
        get api(url), headers: headers
        expect(response).to have_gitlab_http_status(:found)
        expect(response.headers['Location']).to eq('https://pypi.org/simple/requests/')
        expect(decoded_send_url_params).to be_nil
      end
    end

    context 'when the firewall is not licensed' do
      before do
        stub_licensed_features(dependency_firewall: false)
      end

      it 'redirects to pypi.org without handing off to Workhorse', :aggregate_failures do
        get api(url), headers: json_headers
        expect(response).to have_gitlab_http_status(:found)
        expect(response.headers['Location']).to eq('https://pypi.org/simple/requests/')
        expect(decoded_send_url_params).to be_nil
      end
    end

    context 'when forwarding is disabled' do
      before do
        allow_fetch_cascade_application_setting(attribute: 'pypi_package_requests_forwarding', return_value: false)
      end

      it 'returns 404 (existing behaviour)', :aggregate_failures do
        get api(url), headers: headers
        expect(response).to have_gitlab_http_status(:not_found)
        expect(decoded_send_url_params).to be_nil
      end
    end
  end

  describe 'Flow 2: forwarded file download', feature_category: :package_registry do
    include_context 'dependency proxy helpers context'

    # The metadata rewrite encodes the upstream host as the first path segment, so a
    # forward path arrives here as "<host>/<artifact path>".
    let(:upstream_path) { 'files.pythonhosted.org/packages/aa/requests-2.31.0.tar.gz' }
    let(:base_path) { "/projects/#{project.id}/packages/pypi/forward/requests/#{upstream_path}" }
    let(:upstream_url) { "https://#{upstream_path}" }
    let(:url) { base_path }

    before do
      stub_licensed_features(dependency_firewall: true)
      stub_feature_flags(dependency_firewall_phase1: true)
      allow_fetch_cascade_application_setting(attribute: 'pypi_package_requests_forwarding', return_value: true)
      allow(firewall_service).to receive(:firewall_check)
        .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))
    end

    it 'redirects to the reconstructed pythonhosted URL when the firewall allows', :aggregate_failures do
      get api(url), headers: headers
      expect(response).to have_gitlab_http_status(:found)
      expect(response.headers['Location']).to eq(upstream_url)
    end

    it 'derives the version and normalizes the name at the firewall boundary' do
      expect(firewall_service).to receive(:firewall_check)
        .with(hash_including(name: 'requests', version: '2.31.0'))
        .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))
      get api("/projects/#{project.id}/packages/pypi/forward/Requests/#{upstream_path}"), headers: headers
    end

    it 'issues a 302 (not 404) when firewall warns and sets the warning header', :aggregate_failures do
      warning_message = "Package 'requests' violates 'License policy' policy"
      allow(firewall_service).to receive(:firewall_check)
        .and_return(ServiceResponse.success(
          payload: { status: firewall_service::SUCCESS_WARNING, message: warning_message }
        ))
      get api(url), headers: headers
      expect(response).to have_gitlab_http_status(:found)
      expect(response.headers['Location']).to eq(upstream_url)
      expect(response.headers['X-Gitlab-Dependency-Firewall-Warning']).to eq(warning_message)
    end

    it 'returns 403 when the firewall blocks', :aggregate_failures do
      allow(firewall_service).to receive(:firewall_check)
        .and_return(ServiceResponse.error(message: "Package 'requests' violates 'X' policy",
          reason: firewall_service::SUCCESS_BLOCKED))
      get api(url), headers: headers
      expect(response).to have_gitlab_http_status(:forbidden)
      expect(::Gitlab::Json.safe_parse(response.body)['message']).to eq("Package 'requests' violates 'X' policy")
    end

    it 'strips a .metadata suffix (PEP 658) before deriving the version and redirects to it', :aggregate_failures do
      expect(firewall_service).to receive(:firewall_check)
        .with(hash_including(version: '2.31.0'))
        .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))
      get api("#{base_path}.metadata"), headers: headers
      expect(response).to have_gitlab_http_status(:found)
      expect(response.headers['Location']).to eq("#{upstream_url}.metadata")
    end

    # PEP 658 makes pip fetch the metadata and then the artifact, so counting both
    # would inflate forwarded pulls against locally hosted ones -- and a resolve
    # that never downloads the wheel would still record a pull.
    describe 'pull_package tracking across the PEP 658 request pair' do
      it 'counts the artifact request but not the metadata one', :aggregate_failures do
        expect(::Gitlab::Tracking).to receive(:event)
          .with(anything, 'pull_package', hash_including(property: 'i_package_pypi_user')).once

        get api("#{base_path}.metadata"), headers: headers
        expect(response).to have_gitlab_http_status(:found)

        get api(base_path), headers: headers
        expect(response).to have_gitlab_http_status(:found)
      end
    end

    it 'returns 404 and never calls the firewall when the version cannot be derived', :aggregate_failures do
      expect(firewall_service).not_to receive(:firewall_check)
      get api("/projects/#{project.id}/packages/pypi/forward/requests/" \
        'files.pythonhosted.org/packages/aa/requests-2.31.0.txt'), headers: headers
      expect(response).to have_gitlab_http_status(:not_found)
    end

    # The metadata rewrite deliberately captures every https URL, not just PyPI CDN
    # ones, so an index entry pointing elsewhere lands here rather than going to pip
    # unrewritten. It has to be refused: nothing vouches for that host.
    it 'returns 404 and never calls the firewall when the host is not allowed', :aggregate_failures do
      expect(firewall_service).not_to receive(:firewall_check)

      get api("/projects/#{project.id}/packages/pypi/forward/requests/" \
        'cdn.example.net/packages/aa/requests-2.31.0.tar.gz'), headers: headers

      expect(response).to have_gitlab_http_status(:not_found)
      expect(response.headers['Location']).to be_nil
    end

    # `package_name` is a free-form route segment. If it chose where the version
    # started, claiming "requests-2" would turn requests 2.31.0 into version
    # "31.0" -- matching no advisory -- while the 302 still handed over the real
    # 2.31.0 artifact. Coordinates now come from the filename, and a claimed name
    # that disagrees with it fails closed.
    describe 'a package_name crafted to move the version split' do
      # A claimed name only moves the split when it is a longer prefix of the
      # filename, so both cases swallow leading version segments -- "requests-2"
      # would have been enforced as version "31.0" and "requests-2-31" as "0". The
      # dotted spelling ("requests.2") never gets here: Grape's :package_name
      # segment does not match a dot, so the router 404s it first.
      where(:description, :claimed_name) do
        [
          ['one segment swallowed', 'requests-2'],
          ['two segments swallowed', 'requests-2-31']
        ]
      end

      with_them do
        it 'returns 404 without calling the firewall or redirecting', :aggregate_failures do
          expect(firewall_service).not_to receive(:firewall_check)

          get api("/projects/#{project.id}/packages/pypi/forward/#{claimed_name}/#{upstream_path}"),
            headers: headers

          expect(response).to have_gitlab_http_status(:not_found)
          expect(response.headers['Location']).to be_nil
        end
      end
    end

    # Grape decodes route params, so `%23`/`%3F` arrive here as a literal `#`/`?`.
    # Left unchecked they truncate the Location the client actually follows, so the
    # firewall would evaluate a junk version ("2.31.0.tar.gz#x") while the client
    # fetched the real requests-2.31.0.tar.gz behind it.
    describe 'a path crafted to truncate the redirect the client follows' do
      where(:description, :encoded_suffix) do
        [
          ['a fragment', '%23x-9.9.9.tar.gz'],
          ['a query string', '%3Fx-9.9.9.tar.gz']
        ]
      end

      with_them do
        it 'returns 404 without calling the firewall or emitting a redirect', :aggregate_failures do
          expect(firewall_service).not_to receive(:firewall_check)

          get api("#{base_path}#{encoded_suffix}"), headers: headers

          expect(response).to have_gitlab_http_status(:not_found)
          expect(response.headers['Location']).to be_nil
        end
      end
    end

    context 'when the Dependency Firewall flag is disabled (a lapse after URLs were baked into a lockfile)' do
      before do
        stub_feature_flags(dependency_firewall_phase1: false)
      end

      it 'forwards to the upstream artifact without calling the firewall', :aggregate_failures do
        expect(firewall_service).not_to receive(:firewall_check)
        get api(url), headers: headers
        expect(response).to have_gitlab_http_status(:found)
        expect(response.headers['Location']).to eq(upstream_url)
      end
    end

    context 'when the Dependency Firewall is not licensed (a lapse after URLs were baked into a lockfile)' do
      before do
        stub_licensed_features(dependency_firewall: false)
      end

      it 'forwards to the upstream artifact without calling the firewall', :aggregate_failures do
        expect(firewall_service).not_to receive(:firewall_check)
        get api(url), headers: headers
        expect(response).to have_gitlab_http_status(:found)
        expect(response.headers['Location']).to eq(upstream_url)
      end
    end

    context 'when forwarding is disabled' do
      before do
        allow_fetch_cascade_application_setting(attribute: 'pypi_package_requests_forwarding', return_value: false)
      end

      it 'returns 404 without calling the firewall', :aggregate_failures do
        expect(firewall_service).not_to receive(:firewall_check)
        get api(url), headers: headers
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    # Lives here rather than in the CE spec: the route is CE but a granted request
    # only reaches the 302 once EE's `handle_pypi_forwarded_download!` is loaded.
    it_behaves_like 'authorizing granular token permissions', :download_pypi_package,
      expected_success_status: :redirect do
      let(:boundary_object) { project }
      let(:request) { get api(url), headers: basic_auth_header(user.username, pat.token) }
    end
  end

  describe 'POST /api/v4/projects/:id/packages/pypi (dependency firewall)' do
    include_context 'workhorse headers'

    let(:url) { "/projects/#{project.id}/packages/pypi" }
    let(:file_name) { 'package.whl' }
    # Consecutive runs of [-_.] must collapse to a single '-' (PEP 503),
    # matching Packages::Pypi::Package#normalized_pypi_name.
    let(:upload_name) { 'Upload__Test..Pkg' }
    let(:upload_version) { '1.2.3' }
    let(:params) do
      {
        content: temp_file(file_name),
        name: upload_name,
        version: upload_version,
        sha256_digest: '1' * 64,
        md5_digest: '1' * 32,
        requires_python: '>=3.7'
      }
    end

    let(:headers) { basic_auth_header(user.username, personal_access_token.token).merge(workhorse_headers) }

    subject(:upload) do
      workhorse_finalize(
        api(url),
        method: :post,
        file_key: :content,
        params: params,
        headers: headers,
        send_rewritten_field: true
      )
    end

    before do
      stub_feature_flags(dependency_firewall_phase1: project.root_ancestor)
      allow(firewall_service).to receive(:firewall_check)
        .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))
    end

    context 'when the dependency_firewall_phase1 feature flag is disabled' do
      before do
        stub_feature_flags(dependency_firewall_phase1: false)
      end

      it 'does not call the firewall and creates the package', :aggregate_failures do
        expect(firewall_service).not_to receive(:firewall_check)

        expect { upload }.to change { project.packages.pypi.count }.by(1)
        expect(response).to have_gitlab_http_status(:created)
      end
    end

    context 'when the firewall allows the package' do
      it 'creates the package', :aggregate_failures do
        expect { upload }.to change { project.packages.pypi.count }.by(1)
        expect(response).to have_gitlab_http_status(:created)
      end

      it 'calls the firewall with the PEP 503 normalized name, version, operation, and current_user',
        :aggregate_failures do
        expect(firewall_service).to receive(:firewall_check)
          .with(
            project: project,
            pkg_type: 'pypi',
            name: 'upload-test-pkg',
            version: upload_version,
            operation: firewall_service::PACKAGE_UPLOAD,
            current_user: user
          )
          .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))

        upload

        expect(response).to have_gitlab_http_status(:created)
      end
    end

    context 'when the firewall warns on the package' do
      let(:warning_message) { "Package 'requests' violates 'License policy' policy" }

      before do
        allow(firewall_service).to receive(:firewall_check)
          .and_return(ServiceResponse.success(
            payload: { status: firewall_service::SUCCESS_WARNING, message: warning_message }
          ))
      end

      it 'creates the package and sets the warning header', :aggregate_failures do
        expect { upload }.to change { project.packages.pypi.count }.by(1)
        expect(response).to have_gitlab_http_status(:created)
        expect(response.headers['X-Gitlab-Dependency-Firewall-Warning']).to eq(warning_message)
      end
    end

    context 'when firewall_check returns a non-blocking error response' do
      before do
        allow(firewall_service).to receive(:firewall_check)
          .and_return(ServiceResponse.error(message: 'upstream unavailable', reason: :service_unavailable))
      end

      it 'creates the package', :aggregate_failures do
        expect { upload }.to change { project.packages.pypi.count }.by(1)
        expect(response).to have_gitlab_http_status(:created)
      end
    end

    context 'when the firewall is not licensed' do
      before do
        allow(project).to receive(:licensed_feature_available?).with(:dependency_firewall).and_return(false)
      end

      it 'creates the package', :aggregate_failures do
        expect(firewall_service).to receive(:firewall_check).and_call_original

        expect { upload }.to change { project.packages.pypi.count }.by(1)
        expect(response).to have_gitlab_http_status(:created)
      end
    end

    context 'when the firewall blocks the package' do
      before do
        allow(firewall_service).to receive(:firewall_check)
          .and_return(ServiceResponse.error(message: nil, reason: firewall_service::SUCCESS_BLOCKED))
      end

      it 'returns 403 and does not create the package', :aggregate_failures do
        expect { upload }.not_to change { project.packages.pypi.count }
        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['error']).to eq('Dependency Firewall policy violation')
      end

      it 'does not track a push_package event', :aggregate_failures do
        expect(::Gitlab::Tracking).not_to receive(:event).with(anything, 'push_package', anything)

        upload

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
