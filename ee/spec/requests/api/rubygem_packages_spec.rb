# frozen_string_literal: true

require 'spec_helper'
require 'rubygems/package'

RSpec.describe API::RubygemPackages, feature_category: :package_registry do
  include PackagesManagerApiSpecHelpers
  include WorkhorseHelpers
  include HttpBasicAuthHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, maintainers: user) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:package_name) { 'package' }
  let_it_be(:version) { '0.0.1' }
  let_it_be(:package) { create(:rubygems_package, project: project, name: package_name, version: version) }
  let_it_be(:file_name) { "#{package_name}-#{version}.gem" }

  let(:headers) { build_auth_headers(personal_access_token.token) }
  let(:firewall_service) { Security::DependencyFirewall::EnforcementService }

  describe 'GET /api/v4/projects/:project_id/packages/rubygems/gems/:file_name' do
    let(:url) { api("/projects/#{project.id}/packages/rubygems/gems/#{file_name}") }

    subject(:download) { get(url, headers: headers) }

    it_behaves_like 'applying ip restriction for group'

    describe 'dependency firewall enforcement on download' do
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

      context 'when the firewall blocks the package' do
        before do
          allow(firewall_service).to receive(:firewall_check)
            .and_return(ServiceResponse.error(message: nil, reason: firewall_service::SUCCESS_BLOCKED))
        end

        it 'returns 403 with a policy violation message', :aggregate_failures do
          download

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['error']).to eq('Dependency Firewall policy violation')
          expect(json_response['message']).to eq('Dependency Firewall policy violation')
        end
      end

      context 'when the firewall warns on the package' do
        let(:warning_message) { "Package 'rubygems-example' violates 'License policy' policy" }

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

      context 'when the firewall is not licensed' do
        before do
          stub_licensed_features(dependency_firewall: false)
        end

        it 'allows the download', :aggregate_failures do
          expect(firewall_service).to receive(:firewall_check).and_call_original

          download

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      it 'calls the firewall with the package name, version, operation, and current_user', :aggregate_failures do
        expect(firewall_service).to receive(:firewall_check)
          .with(
            project: project,
            pkg_type: 'gem',
            name: package_name,
            version: version,
            operation: firewall_service::PACKAGE_DOWNLOAD,
            current_user: user
          )
          .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))

        download

        expect(response).to have_gitlab_http_status(:ok)
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
    end
  end

  describe 'POST /api/v4/projects/:project_id/packages/rubygems/api/v1/gems' do
    include_context 'workhorse headers'

    let(:url) { api("/projects/#{project.id}/packages/rubygems/api/v1/gems") }
    let(:upload_headers) { headers.merge(workhorse_headers) }
    let(:gem_fixture) { expand_fixture_path('packages/rubygems/package-0.0.1.gem') }

    # Strict matcher: proves gem_spec_from_metadata produced the right name/version end-to-end.
    # firewall_check receives pkg_type (the helper renames purl_type -> pkg_type one frame down).
    let(:firewall_check_args) do
      {
        project: project,
        pkg_type: 'gem',
        name: package_name,
        version: version,
        operation: firewall_service::PACKAGE_UPLOAD,
        current_user: user
      }
    end

    # Declarative fixture: by default we upload the real fixture gem. Edge-case contexts override
    # `metadata_yaml` (to craft just the metadata.gz contents) or `gem_path` (to craft the whole
    # archive); `params` is derived from `gem_path` so each example only states what differs.
    let(:metadata_yaml) { nil }
    let(:gem_path) { metadata_yaml ? gem_with_metadata(metadata_yaml) : gem_fixture }
    let(:params) { { file: workhorse_gem_upload(gem_path) } }
    let(:crafted_gems) { [] }

    subject(:upload_gem) do
      workhorse_finalize(
        url,
        method: :post,
        file_key: :file,
        params: params,
        headers: upload_headers,
        send_rewritten_field: true
      )
    end

    # temp_file writes via File.write, which can't handle binary gem bytes, so copy the staged file.
    def workhorse_gem_upload(source_path)
      upload_path = ::Packages::PackageFileUploader.workhorse_local_upload_path
      FileUtils.mkdir_p(upload_path)
      dest = File.join(upload_path, File.basename(source_path))
      FileUtils.cp(source_path, dest)
      UploadedFile.new(dest, filename: File.basename(dest))
    end

    # Builds a .gem (tar) on disk for the given TarWriter block and returns its path.
    def crafted_gem
      file = Tempfile.new(['crafted', '.gem'])
      crafted_gems << file
      file.binmode
      Gem::Package::TarWriter.new(file) { |tar| yield tar }
      file.flush
      file.path
    end

    # Builds a .gem whose single metadata.gz entry holds the given raw YAML string.
    def gem_with_metadata(yaml)
      crafted_gem do |tar|
        gz = StringIO.new
        Zlib::GzipWriter.wrap(gz) { |io| io.write(yaml) }
        tar.add_file('metadata.gz', 0o444) { |entry| entry.write(gz.string) }
      end
    end

    # Serialized Gem::Specification YAML, the shape Gem::Specification.from_yaml expects.
    def gem_metadata_yaml(name: package_name, gem_version: version)
      Gem::Specification.new do |spec|
        spec.name = name
        spec.version = gem_version
        spec.summary = 'summary'
        spec.authors = ['author']
      end.to_yaml
    end

    after do
      crafted_gems.each(&:close!)
    end

    before do
      stub_feature_flags(dependency_firewall_phase1: project.root_ancestor)
      stub_licensed_features(dependency_firewall: true)

      allow(firewall_service).to receive(:firewall_check)
        .with(firewall_check_args)
        .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))
    end

    context 'when the firewall allows the upload' do
      it 'returns 201' do
        upload_gem

        expect(response).to have_gitlab_http_status(:created)
      end
    end

    context 'when the firewall blocks the upload' do
      before do
        allow(firewall_service).to receive(:firewall_check)
          .with(firewall_check_args)
          .and_return(ServiceResponse.error(
            message: 'Package blocked by policy',
            reason: firewall_service::SUCCESS_BLOCKED
          ))
      end

      it 'returns 403 and creates no package record', :aggregate_failures do
        expect { upload_gem }.not_to change { ::Packages::Package.count }

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['message']).to eq('Package blocked by policy')
      end
    end

    context 'when the firewall warns (advisory mode)' do
      let(:warning_message) { "Package 'rubygems-example' violates 'License policy' policy" }

      before do
        allow(firewall_service).to receive(:firewall_check)
          .with(firewall_check_args)
          .and_return(ServiceResponse.success(
            payload: { status: firewall_service::SUCCESS_WARNING, message: warning_message }
          ))
      end

      it 'returns 201 and proceeds with the upload and sets the warning header', :aggregate_failures do
        upload_gem

        expect(response).to have_gitlab_http_status(:created)
        expect(response.headers['X-Gitlab-Dependency-Firewall-Warning']).to eq(warning_message)
      end
    end

    context 'when the firewall returns a non-block error (e.g. infrastructure failure)' do
      before do
        allow(firewall_service).to receive(:firewall_check)
          .with(firewall_check_args)
          .and_return(ServiceResponse.error(message: 'Internal failure', reason: :unknown))
      end

      it 'proceeds with the upload (only SUCCESS_BLOCKED is enforced) and returns 201' do
        upload_gem

        expect(response).to have_gitlab_http_status(:created)
      end
    end

    context 'when the dependency_firewall_phase1 feature flag is disabled' do
      before do
        stub_feature_flags(dependency_firewall_phase1: false)
      end

      it 'does not call the firewall and returns 201', :aggregate_failures do
        expect(firewall_service).not_to receive(:firewall_check)

        upload_gem

        expect(response).to have_gitlab_http_status(:created)
      end
    end

    context 'when the gem file cannot be parsed' do
      # Not a gem archive at all, so metadata parsing fails and enforcement is skipped.
      let(:params) { { file: temp_file(file_name, content: 'not a valid gem') } }

      it 'skips the firewall check and returns 201', :aggregate_failures do
        expect(firewall_service).not_to receive(:firewall_check)

        upload_gem

        expect(response).to have_gitlab_http_status(:created)
      end
    end

    context 'when the gem metadata.gz is a symlink entry' do
      # A non-file metadata entry is skipped (entry.file?), so parsing yields nil.
      let(:gem_path) { crafted_gem { |tar| tar.add_symlink('metadata.gz', '../outside', 0o644) } }

      it 'skips the firewall check and returns 201', :aggregate_failures do
        expect(firewall_service).not_to receive(:firewall_check)

        upload_gem

        expect(response).to have_gitlab_http_status(:created)
      end
    end

    context 'when metadata.gz appears after the scanned-entry budget' do
      # metadata.gz placed past the first few entries is not found by the bounded scan, so
      # enforcement is skipped rather than walking the whole archive on the request thread.
      let(:gem_path) do
        crafted_gem do |tar|
          6.times { |i| tar.add_file("padding-#{i}", 0o444) { |entry| entry.write('x') } }
          gz = StringIO.new
          Zlib::GzipWriter.wrap(gz) { |io| io.write(gem_metadata_yaml) }
          tar.add_file('metadata.gz', 0o444) { |entry| entry.write(gz.string) }
        end
      end

      it 'skips the firewall check and returns 201', :aggregate_failures do
        expect(firewall_service).not_to receive(:firewall_check)

        upload_gem

        expect(response).to have_gitlab_http_status(:created)
      end
    end

    context 'when metadata.gz exceeds the size limit' do
      # An oversized metadata.gz (decompresses beyond the cap) is treated as unparseable, so
      # enforcement is skipped and the upload proceeds.
      let(:metadata_yaml) { "a: #{'x' * (10.megabytes + 1)}" }

      it 'skips the firewall check and returns 201', :aggregate_failures do
        expect(firewall_service).not_to receive(:firewall_check)

        upload_gem

        expect(response).to have_gitlab_http_status(:created)
      end
    end

    context 'when metadata.gz contains a disallowed YAML class' do
      # Gem::Specification.from_yaml uses Gem::SafeYAML, which rejects arbitrary object tags;
      # the upload still proceeds (firewall skipped) rather than 500.
      let(:metadata_yaml) { "--- !ruby/object:Kernel\nfoo: bar\n" }

      it 'skips the firewall check and returns 201', :aggregate_failures do
        expect(firewall_service).not_to receive(:firewall_check)

        upload_gem

        expect(response).to have_gitlab_http_status(:created)
      end

      it 'logs the parse failure' do
        allow(::Gitlab::ErrorTracking).to receive(:log_exception)

        upload_gem

        expect(::Gitlab::ErrorTracking).to have_received(:log_exception)
          .with(kind_of(StandardError), hash_including(package_file_path: anything))
      end
    end

    context 'when the gem name is blank' do
      # A blank name is invalid firewall input, not a parse failure: it is not pre-filtered, so
      # the firewall runs and its ArgumentError propagates as a 500 that blocks the upload (no
      # package created) rather than silently skipping enforcement.
      let(:metadata_yaml) { gem_metadata_yaml(name: '') }

      before do
        allow(firewall_service).to receive(:firewall_check)
          .with(hash_including(name: '', version: version, pkg_type: 'gem', current_user: user))
          .and_raise(ArgumentError, 'DependencyFirewall: name is blank')
      end

      it 'fails the upload and creates no package', :aggregate_failures do
        expect { upload_gem }.not_to change { ::Packages::Package.count }

        expect(response).to have_gitlab_http_status(:internal_server_error)
      end
    end
  end
end
