# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::MavenPackages, feature_category: :package_registry do
  include WorkhorseHelpers
  include HttpBasicAuthHelpers

  include_context 'workhorse headers'

  before do
    stub_feature_flags(maven_problem_details_errors: false)
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
  let_it_be(:group) { create(:group, maintainers: user) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:package) { create(:maven_package, project: project, name: project.full_path) }
  let_it_be(:maven_metadatum) { package.maven_metadatum }
  let_it_be(:package_file) { package.package_files.with_file_name_like('%.xml').first }
  let_it_be(:jar_file) { package.package_files.with_file_name_like('%.jar').first }
  let_it_be(:metadata_package) do
    create(:maven_package, project: project, name: "#{project.full_path}/my-app", version: nil)
  end

  let_it_be(:metadata_package_file) { metadata_package.package_files.with_file_name_like('%.xml').first }

  let(:metadata_maven_path) { "#{metadata_package.maven_metadatum.path}/#{metadata_package_file.file_name}" }

  let(:headers) { { 'Private-Token' => personal_access_token.token } }
  let(:firewall_service) { Security::DependencyFirewall::EnforcementService }

  shared_examples 'dependency firewall enforcement on download' do
    before do
      stub_feature_flags(dependency_firewall_phase1: project.root_ancestor)
      allow(firewall_service).to receive(:firewall_check)
        .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))
    end

    context 'when the dependency_firewall_phase1 feature flag is disabled' do
      before do
        stub_feature_flags(dependency_firewall_phase1: false)
      end

      it 'does not call the firewall and allows the download' do
        expect(firewall_service).not_to receive(:firewall_check)

        subject

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when the firewall blocks the package' do
      before do
        allow(firewall_service).to receive(:firewall_check)
          .and_return(ServiceResponse.error(message: nil, reason: firewall_service::SUCCESS_BLOCKED))
      end

      it 'returns 403 with a policy violation message' do
        subject

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['error']).to eq('Dependency Firewall policy violation')
      end
    end

    context 'when the firewall warns on the package' do
      let(:warning_message) { "Package 'com.example/my-app' violates 'License policy' policy" }

      before do
        allow(firewall_service).to receive(:firewall_check)
          .and_return(ServiceResponse.success(
            payload: { status: firewall_service::SUCCESS_WARNING, message: warning_message }
          ))
      end

      it 'allows the download and sets the warning header', :aggregate_failures do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers['X-Gitlab-Dependency-Firewall-Warning']).to eq(warning_message)
      end
    end

    context 'when the firewall is not licensed' do
      before do
        allow(project).to receive(:licensed_feature_available?).with(:dependency_firewall).and_return(false)
      end

      it 'allows the download' do
        expect(firewall_service).to receive(:firewall_check).and_call_original

        subject

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'with a non-checksum file' do
      it 'calls the firewall with the correct fields, operation, and current_user' do
        expect(firewall_service).to receive(:firewall_check)
          .with(
            project: package.project,
            pkg_type: 'maven',
            name: package.name,
            version: package.version,
            operation: firewall_service::PACKAGE_DOWNLOAD,
            current_user: user
          )
          .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))

        subject

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'with a checksum file' do
      it 'does not call the firewall' do
        expect(firewall_service).not_to receive(:firewall_check)

        checksum_subject

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'does not track a pull_package event' do
        pom_file = package.package_files.with_file_name_like('%.pom').first
        expect(::Gitlab::Tracking).not_to receive(:event).with(anything, 'pull_package', anything)
        get api("/packages/maven/#{maven_metadatum.path}/#{pom_file.file_name}"), headers: headers
        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'with a metadata file (nil version)' do
      it 'allows the download' do
        metadata_subject

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when firewall_check returns an error response' do
      before do
        allow(firewall_service).to receive(:firewall_check)
          .and_return(ServiceResponse.error(message: 'upstream unavailable', reason: :service_unavailable))
      end

      it 'allows the download' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when the firewall raises an error (invalid parameters)' do
      before do
        allow(firewall_service).to receive(:firewall_check)
          .and_raise(ArgumentError, 'DependencyFirewall: name is blank')
      end

      it 'returns 500' do
        subject

        expect(response).to have_gitlab_http_status(:internal_server_error)
      end
    end
  end

  shared_examples 'dependency firewall enforcement on upload authorize' do
    before do
      stub_feature_flags(dependency_firewall_phase1: project.root_ancestor)
    end

    context 'when the dependency_firewall_phase1 feature flag is disabled' do
      before do
        stub_feature_flags(dependency_firewall_phase1: false)
      end

      it 'does not call the firewall and allows the upload' do
        expect(firewall_service).not_to receive(:firewall_check)

        subject

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when the firewall blocks the package' do
      before do
        allow(firewall_service).to receive(:firewall_check)
          .and_return(ServiceResponse.error(message: nil, reason: firewall_service::SUCCESS_BLOCKED))
      end

      it 'returns 403 with a policy violation message' do
        subject

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['error']).to eq('Dependency Firewall policy violation')
      end
    end

    context 'when the firewall warns on the package' do
      let(:warning_message) { "Package 'com.example/my-app' violates 'License policy' policy" }

      before do
        allow(firewall_service).to receive(:firewall_check)
          .and_return(ServiceResponse.success(
            payload: { status: firewall_service::SUCCESS_WARNING, message: warning_message }
          ))
      end

      it 'allows the upload and sets the warning header', :aggregate_failures do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers['X-Gitlab-Dependency-Firewall-Warning']).to eq(warning_message)
      end
    end

    context 'when the firewall is not licensed' do
      before do
        allow(project).to receive(:licensed_feature_available?).with(:dependency_firewall).and_return(false)
      end

      it 'allows the upload' do
        expect(firewall_service).to receive(:firewall_check).and_call_original

        subject

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'with a non-checksum file' do
      it 'calls the firewall with the correct fields and operation' do
        package_name = package_path.rpartition('/').first
        version = package_path.rpartition('/').last

        expect(firewall_service).to receive(:firewall_check)
          .with(
            project: project,
            pkg_type: 'maven',
            name: package_name,
            version: version,
            operation: firewall_service::PACKAGE_UPLOAD,
            current_user: user
          )
          .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))

        subject

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'with a checksum file' do
      it 'does not call the firewall' do
        expect(firewall_service).not_to receive(:firewall_check)

        checksum_subject

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when firewall_check returns an error response' do
      before do
        allow(firewall_service).to receive(:firewall_check)
          .and_return(ServiceResponse.error(message: 'upstream unavailable', reason: :service_unavailable))
      end

      it 'allows the upload' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when the firewall raises an error (invalid parameters)' do
      before do
        allow(firewall_service).to receive(:firewall_check)
          .and_raise(ArgumentError, 'DependencyFirewall: name is blank')
      end

      it 'returns 500' do
        subject

        expect(response).to have_gitlab_http_status(:internal_server_error)
      end
    end
  end

  describe 'GET /api/v4/packages/maven/*path/:file_name' do
    context 'with dependency firewall' do
      subject { get api("/packages/maven/#{maven_metadatum.path}/#{jar_file.file_name}"), headers: headers }

      let(:checksum_subject) do
        get api("/packages/maven/#{maven_metadatum.path}/#{jar_file.file_name}.sha1"), headers: headers
      end

      let(:metadata_subject) do
        get api("/packages/maven/#{metadata_package.maven_metadatum.path}/#{metadata_package_file.file_name}"),
          headers: headers
      end

      it_behaves_like 'dependency firewall enforcement on download'
    end
  end

  describe 'GET /api/v4/groups/:id/-/packages/maven/*path/:file_name' do
    let(:url) { "/groups/#{group.id}/-/packages/maven/#{maven_metadatum.path}/#{package_file.file_name}" }

    subject { get api(url), headers: headers }

    it_behaves_like 'applying ip restriction for group'

    context 'with dependency firewall' do
      subject do
        get api("/groups/#{group.id}/-/packages/maven/#{maven_metadatum.path}/#{jar_file.file_name}"),
          headers: headers
      end

      let(:checksum_subject) do
        get api("/groups/#{group.id}/-/packages/maven/#{maven_metadatum.path}/#{jar_file.file_name}.sha1"),
          headers: headers
      end

      let(:metadata_subject) do
        get api("/groups/#{group.id}/-/packages/maven/#{metadata_maven_path}"), headers: headers
      end

      it_behaves_like 'dependency firewall enforcement on download'
    end
  end

  describe 'GET /api/v4/projects/:id/packages/maven/*path/:file_name' do
    let(:url) { "/projects/#{project.id}/packages/maven/#{maven_metadatum.path}/#{package_file.file_name}" }

    subject { get api(url), headers: headers }

    it_behaves_like 'applying ip restriction for group'

    context 'with dependency firewall' do
      subject do
        get api("/projects/#{project.id}/packages/maven/#{maven_metadatum.path}/#{jar_file.file_name}"),
          headers: headers
      end

      let(:checksum_subject) do
        get api("/projects/#{project.id}/packages/maven/#{maven_metadatum.path}/#{jar_file.file_name}.sha1"),
          headers: headers
      end

      let(:metadata_subject) do
        get api("/projects/#{project.id}/packages/maven/#{metadata_maven_path}"), headers: headers
      end

      it_behaves_like 'dependency firewall enforcement on download'
    end
  end

  describe 'RFC 9457 problem details' do
    context 'with project-level download and non-existing path' do
      before do
        stub_feature_flags(maven_problem_details_errors: true)
        # Disable request forwarding so the API raises `not_found!('Project')`
        # instead of forwarding the request to Maven Central.
        stub_feature_flags(maven_central_request_forwarding: false)
      end

      subject do
        get api("/projects/#{project.id}/packages/maven/non/existent/path/foo.jar"), headers: headers
      end

      it_behaves_like 'returning RFC 9457 problem details', status: :not_found, detail: '404 Project Not Found'

      context 'when maven_problem_details_errors is disabled' do
        before do
          stub_feature_flags(maven_problem_details_errors: false)
        end

        it_behaves_like 'not returning RFC 9457 problem details', status: :not_found
      end
    end
  end

  describe 'PUT /api/v4/projects/:id/packages/maven/*path/:file_name/authorize' do
    let(:package_path) { 'com/example/my-app/1.0.0' }
    let(:file_name) { 'my-app-1.0.0.jar' }
    let(:checksum_subject) do
      put api("/projects/#{project.id}/packages/maven/#{package_path}/#{file_name}.sha1/authorize"),
        headers: headers.merge(workhorse_headers)
    end

    subject do
      put api("/projects/#{project.id}/packages/maven/#{package_path}/#{file_name}/authorize"),
        headers: headers.merge(workhorse_headers)
    end

    it_behaves_like 'dependency firewall enforcement on upload authorize'
  end
end
