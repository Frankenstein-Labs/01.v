# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::DependencyProxy::Packages::Maven, :aggregate_failures, feature_category: :package_registry do
  using RSpec::Parameterized::TableSyntax
  include HttpBasicAuthHelpers
  include WorkhorseHelpers
  include_context 'for a dependency proxy for packages'

  let_it_be_with_refind(:dependency_proxy_setting) do
    create(:dependency_proxy_packages_setting, :maven, project: project)
  end

  let(:sha1_checksum_header) { ::API::Helpers::Packages::Maven::SHA1_CHECKSUM_HEADER }
  let(:md5_checksum_header) { ::API::Helpers::Packages::Maven::MD5_CHECKSUM_HEADER }

  before do
    stub_feature_flags(
      maven_problem_details_errors: false,
      allow_guest_plus_roles_to_pull_packages: false
    )
  end

  describe 'GET /api/v4/projects/:project_id/dependency_proxy/packages/maven/*path/:file_name' do
    let(:path) { 'foo/bar/1.2.3' }
    let(:file_name) { 'foo.bar-1.2.3.pom' }
    let(:url) { "/projects/#{project.id}/dependency_proxy/packages/maven/#{path}/#{file_name}" }

    subject(:api_request) { get(api(url), headers: headers) }

    context 'with granular token authorization' do
      before do
        project.add_guest(user)
      end

      it_behaves_like 'authorizing granular token permissions', :download_maven_package_file do
        let(:boundary_object) { project }
        let(:request) { get api(url), headers: { 'Private-Token' => pat.token } }
      end
    end

    context 'with valid parameters' do
      shared_examples 'handling different token types' do |personal_access_token_cases:|
        let_it_be(:package) { create(:maven_package, project: project) }
        let(:package_file) { package.package_files.find { |f| f.file_name.end_with?('.pom') } }
        let(:path) { package.maven_metadatum.path }
        let(:file_name) { package_file.file_name }

        before do
          allow_next_instance_of(::DependencyProxy::Packages::VerifyPackageFileEtagService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success)
          end
        end

        context 'and a personal access token' do
          where(:user_role, :valid_token, :sent_using, :expected_status) do
            personal_access_token_cases
          end

          with_them do
            let(:token) { valid_token ? personal_access_token.token : 'invalid_token' }
            let(:headers) do
              case sent_using
              when :custom_header
                { 'Private-Token' => token }
              when :basic_auth
                basic_auth_header(user.username, token)
              else
                {}
              end
            end

            before do
              project.send("add_#{user_role}", user) unless user_role == :anonymous
            end

            it_behaves_like 'returning response status', params[:expected_status]
          end
        end

        context 'and a deploy token' do
          where(:valid_token, :sent_using, :expected_status) do
            true  | :custom_header | :ok
            false | :custom_header | :unauthorized
            true  | :basic_auth    | :ok
            false | :basic_auth    | :unauthorized
          end

          with_them do
            let(:token) { valid_token ? deploy_token.token : 'invalid_token' }
            let(:headers) do
              case sent_using
              when :custom_header
                { 'Deploy-Token' => token }
              when :basic_auth
                basic_auth_header(deploy_token.username, token)
              else
                {}
              end
            end

            it_behaves_like 'returning response status', params[:expected_status]
          end
        end

        context 'and a ci job token' do
          where(:valid_token, :sent_using, :expected_status) do
            true  | :custom_header | :ok
            false | :custom_header | :unauthorized
            true  | :basic_auth    | :ok
            false | :basic_auth    | :unauthorized
          end

          with_them do
            let(:token) { valid_token ? job.token : 'invalid_token' }
            let(:headers) do
              case sent_using
              when :custom_header
                { 'Job-Token' => token }
              when :basic_auth
                basic_auth_header(::Gitlab::Auth::CI_JOB_USER, token)
              else
                {}
              end
            end

            before_all do
              project.add_developer(user)
            end

            it_behaves_like 'returning response status', params[:expected_status]
          end
        end
      end

      shared_examples 'a user pulling files' do
        let(:using_a_deploy_token) { false }

        authorization_header = {
          'Authorization' => [
            ActionController::HttpAuthentication::Basic.encode_credentials('user', 'password')
          ]
        }

        shared_examples 'tracking an internal event' do |from_cache: false|
          before do
            allow(::Gitlab::InternalEvents).to receive(:track_event)
          end

          it 'tracks an internal event' do
            event_name = if from_cache
                           'dependency_proxy_packages_maven_file_pulled_from_cache'
                         else
                           'dependency_proxy_packages_maven_file_pulled_from_external'
                         end

            u = user unless using_a_deploy_token

            expect(::Gitlab::InternalEvents).to receive(:track_event)
              .with(event_name, user: u, project: project)

            subject
          end
        end

        shared_examples 'returning a workhorse sendurl response' do
          it_behaves_like 'returning a workhorse sendurl response with', headers: authorization_header do
            before do
              dependency_proxy_setting.update!(
                maven_external_registry_username: 'user',
                maven_external_registry_password: 'password'
              )
            end
          end

          it_behaves_like 'tracking an internal event', from_cache: false
        end

        shared_examples 'returning a workhorse senddependency response' do
          it_behaves_like 'returning a workhorse senddependency response with',
            headers: authorization_header,
            upload_method: 'PUT' do
            before do
              dependency_proxy_setting.update!(
                maven_external_registry_username: 'user',
                maven_external_registry_password: 'password'
              )
            end
          end

          it_behaves_like 'tracking an internal event', from_cache: false
        end

        shared_examples 'pulling existing files' do |can_destroy_package_files: false|
          let_it_be(:package) { create(:maven_package, project: project) }

          let(:package_file) { package.package_files.find { |f| f.file_name.end_with?('.pom') } }
          let(:path) { package.maven_metadatum.path }

          context 'when pulling a pom file' do
            let(:file_name) { package_file.file_name }

            wrong_etag_shared_example = if can_destroy_package_files
                                          'returning a workhorse senddependency response'
                                        else
                                          'returning a workhorse sendurl response'
                                        end

            where(:etag_service_response, :expected_status, :shared_example) do
              ServiceResponse.success                                          | :ok | nil
              ServiceResponse.error(message: '', reason: :response_error_code) | :ok | nil
              ServiceResponse.error(message: '', reason: :no_etag)             | :ok | nil
              ServiceResponse.error(message: '', reason: :wrong_etag)          | nil | wrong_etag_shared_example
            end

            with_them do
              before do
                allow_next_instance_of(::DependencyProxy::Packages::VerifyPackageFileEtagService) do |service|
                  allow(service).to receive(:execute).and_return(etag_service_response)
                end
              end

              it_behaves_like 'returning response status', params[:expected_status] if params[:expected_status]
              it_behaves_like 'tracking an internal event', from_cache: true if params[:expected_status] == :ok
              it_behaves_like params[:shared_example] if params[:shared_example]

              if params[:expected_status] == :ok
                it 'returns the correct checksums' do
                  subject

                  expect(response).to have_gitlab_http_status(:ok)
                  expect(response.headers[sha1_checksum_header]).to be_an_instance_of(String)
                  expect(response.headers[md5_checksum_header]).to be_an_instance_of(String)
                end

                context 'with FIPS mode', :fips_mode do
                  it 'returns the correct checksums' do
                    subject

                    expect(response).to have_gitlab_http_status(:ok)
                    expect(response.headers[sha1_checksum_header]).to be_an_instance_of(String)
                    expect(response.headers[md5_checksum_header]).to be_nil
                  end
                end
              end
            end
          end

          [:md5, :sha1].each do |format|
            context "when pulling a #{format} file" do
              let(:file_name) { "#{package_file.file_name}.#{format}" }

              it 'returns it' do
                subject

                expect(response).to have_gitlab_http_status(:successful)
                expect(response.body).to eq(package_file["file_#{format}"])
              end
            end
          end
        end

        shared_examples 'pulling non existing files' do |can_write_package_files: true|
          context 'with file test.pom' do
            let(:file_name) { 'test.pom' }

            if can_write_package_files
              it_behaves_like 'returning a workhorse senddependency response'
            else
              it_behaves_like 'returning a workhorse sendurl response'
            end
          end

          context 'with file test.md5' do
            let(:file_name) { 'test.md5' }

            it_behaves_like 'returning a workhorse sendurl response'
          end

          context 'with file test.sha1' do
            let(:file_name) { 'test.sha1' }

            it_behaves_like 'returning a workhorse sendurl response'
          end
        end

        shared_context 'with custom headers' do
          let(:headers) { { 'Private-Token' => personal_access_token.token } }
        end

        shared_context 'with basic auth' do
          let(:headers) { basic_auth_header(user.username, personal_access_token.token) }
        end

        context 'with a reporter pulling files' do
          before_all do
            project.add_reporter(user)
          end

          include_context 'with custom headers' do
            it_behaves_like 'pulling existing files'
            it_behaves_like 'pulling non existing files', can_write_package_files: false

            context 'when doing a request to an external registry' do
              let(:enabled_endpoint_uris) { [URI('192.168.1.1')] }
              let(:outbound_local_requests_allowlist) { ['127.0.0.1'] }
              let(:allowed_endpoints) { enabled_endpoint_uris + outbound_local_requests_allowlist }

              before do
                allow(ObjectStoreSettings).to receive(:enabled_endpoint_uris).and_return(enabled_endpoint_uris)
                stub_application_setting(outbound_local_requests_whitelist: outbound_local_requests_allowlist)
              end

              it 'uses SSRF filter' do
                allow(Gitlab::Workhorse).to receive(:send_url)

                subject

                expect(Gitlab::Workhorse).to have_received(:send_url).with(
                  an_instance_of(String),
                  a_hash_including(allow_localhost: true, ssrf_filter: true, allowed_endpoints: allowed_endpoints)
                )
              end
            end
          end

          include_context 'with basic auth' do
            it_behaves_like 'pulling existing files'
            it_behaves_like 'pulling non existing files', can_write_package_files: false
          end
        end

        context 'with a developer pulling files' do
          before_all do
            project.add_developer(user)
          end

          include_context 'with custom headers' do
            it_behaves_like 'pulling existing files'
            it_behaves_like 'pulling non existing files'
          end

          include_context 'with basic auth' do
            it_behaves_like 'pulling existing files'
            it_behaves_like 'pulling non existing files'
          end
        end

        context 'with a maintainer pulling files' do
          before_all do
            project.add_maintainer(user)
          end

          include_context 'with custom headers' do
            it_behaves_like 'pulling existing files', can_destroy_package_files: true
            it_behaves_like 'pulling non existing files'
          end

          include_context 'with basic auth' do
            it_behaves_like 'pulling existing files', can_destroy_package_files: true
            it_behaves_like 'pulling non existing files'
          end

          context 'with a ci job token' do
            context 'with custom headers' do
              let(:headers) { { 'Job-Token' => job.token } }

              it_behaves_like 'pulling existing files', can_destroy_package_files: true
              it_behaves_like 'pulling non existing files'
            end

            context 'with basic auth' do
              let(:headers) { basic_auth_header(::Gitlab::Auth::CI_JOB_USER, job.token) }

              it_behaves_like 'pulling existing files', can_destroy_package_files: true
              it_behaves_like 'pulling non existing files'
            end
          end
        end

        context 'with a deploy token' do
          let(:using_a_deploy_token) { true }

          context 'with custom headers' do
            let(:headers) { { 'Deploy-Token' => deploy_token.token } }

            it_behaves_like 'pulling existing files', can_destroy_package_files: true
            it_behaves_like 'pulling non existing files'
          end

          context 'with basic auth' do
            let(:headers) { basic_auth_header(deploy_token.username, deploy_token.token) }

            it_behaves_like 'pulling existing files', can_destroy_package_files: true
            it_behaves_like 'pulling non existing files'
          end
        end
      end

      [true, false].each do |package_registry_public_access|
        context "with package registry public access set to #{package_registry_public_access}" do
          before do
            if package_registry_public_access
              project.project_feature.update!(package_registry_access_level: ProjectFeature::PUBLIC)
            end
          end

          context 'with a public project' do
            it_behaves_like 'handling different token types',
              personal_access_token_cases: [
                [:anonymous,     nil,   nil,            :unauthorized],
                [:guest,         true,  :custom_header, :ok],
                [:guest,         true,  :basic_auth,    :ok],
                [:guest,         false, :custom_header, :unauthorized],
                [:guest,         false, :basic_auth,    :unauthorized]
              ]
            it_behaves_like 'a user pulling files'
          end

          context 'with an internal project' do
            before do
              project.update!(visibility_level: Gitlab::VisibilityLevel::INTERNAL)
            end

            it_behaves_like 'handling different token types',
              personal_access_token_cases: [
                [:anonymous,     nil,   nil,            :unauthorized],
                [:guest,         true,  :custom_header, :ok],
                [:guest,         true,  :basic_auth,    :ok],
                [:guest,         false, :custom_header, :unauthorized],
                [:guest,         false, :basic_auth,    :unauthorized]
              ]
            it_behaves_like 'a user pulling files'
          end

          context 'with a private project' do
            before do
              project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
            end

            it_behaves_like 'handling different token types',
              personal_access_token_cases: [
                [:anonymous, nil,   nil,            :unauthorized],
                [:guest,     true,  :custom_header, :forbidden],
                [:guest,     true,  :basic_auth,    :forbidden],
                [:guest,     false, :custom_header, :unauthorized],
                [:guest,     false, :basic_auth,    :unauthorized],
                [:reporter,  true,  :custom_header, :ok],
                [:reporter,  true,  :basic_auth,    :ok],
                [:reporter,  false, :custom_header, :unauthorized],
                [:reporter,  false, :basic_auth,    :unauthorized]
              ]
            it_behaves_like 'a user pulling files'
          end
        end
      end

      it_behaves_like 'updating personal access token last used' do
        let_it_be(:package) { create(:maven_package, project: project) }
        let(:package_file) { package.package_files.with_format('pom').take }
        let(:path) { package.maven_metadatum.path }
        let(:file_name) { package_file.file_name }
        let(:headers) { basic_auth_header(user.username, personal_access_token.token) }
      end
    end

    context 'with invalid parameters' do
      context 'with an invalid path' do
        let(:path) { 'foo/bar/%0d%0ahttp:/%2fexample.com' }

        it_behaves_like 'returning response status with error', status: :bad_request,
          error: 'path should be a valid file path'
      end

      context 'with an invalid file name' do
        let(:file_name) { '%0d%0ahttp:/%2fexample.com' }

        it_behaves_like 'returning response status with error', status: :bad_request,
          error: 'file_name should be a valid file path'
      end
    end

    context 'with RFC 9457 problem details' do
      let(:headers) { { 'Private-Token' => personal_access_token.token } }

      before_all do
        project.add_developer(user)
      end

      before do
        stub_feature_flags(maven_problem_details_errors: true)
        dependency_proxy_setting.update!(enabled: false)
      end

      it_behaves_like 'returning RFC 9457 problem details', status: :not_found, detail: '404 Not Found'

      context 'when maven_problem_details_errors is disabled' do
        before do
          stub_feature_flags(maven_problem_details_errors: false)
        end

        it_behaves_like 'not returning RFC 9457 problem details', status: :not_found
      end
    end

    context 'with a developer' do
      let(:headers) { { 'Private-Token' => personal_access_token.token } }

      before_all do
        project.add_developer(user)
      end

      context 'with non existing dependency proxy setting' do
        before do
          dependency_proxy_setting.destroy!
        end

        it_behaves_like 'returning response status', :not_found
      end

      context 'with disabled dependency proxy setting' do
        before do
          dependency_proxy_setting.update!(enabled: false)
        end

        it_behaves_like 'returning response status', :not_found
      end

      context 'with url not set in the dependency proxy setting' do
        before do
          dependency_proxy_setting.update!(
            maven_external_registry_url: nil,
            npm_external_registry_url: 'http://sandbox.test'
          )
        end

        it_behaves_like 'returning response status', :not_found
      end

      context 'when external registry url has extra trailing slash' do
        before do
          dependency_proxy_setting.update_column(:maven_external_registry_url, 'http://sandbox.test/')
          allow(Gitlab::Workhorse).to receive(:send_dependency)
        end

        it 'strips the trailing slash' do
          api_request

          expect(Gitlab::Workhorse).to have_received(:send_dependency).with(
            an_instance_of(Hash),
            a_string_matching(%r{sandbox.test/#{path}/#{file_name}}),
            a_hash_including(:upload_config, :restrict_forwarded_response_headers)
          )
        end
      end

      context 'with a username and password set and pulling existing file' do
        let_it_be(:package) { create(:maven_package, project: project) }

        let(:package_file) { package.package_files.find { |f| f.file_name.end_with?('.pom') } }
        let(:path) { package.maven_metadatum.path }
        let(:file_name) { package_file.file_name }

        it 'sets the correct headers in the verify package file etag service' do
          service_double = instance_double(
            ::DependencyProxy::Packages::VerifyPackageFileEtagService,
            execute: ServiceResponse.success
          )
          expect(::DependencyProxy::Packages::VerifyPackageFileEtagService).to receive(:new)
            .with(
              remote_url: dependency_proxy_setting.url_from_maven_upstream(path: path, file_name: file_name),
              package_file: an_instance_of(Packages::PackageFile),
              headers: dependency_proxy_setting.headers_from_maven_upstream
            ).and_return(service_double)

          api_request

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      %i[packages dependency_proxy].each do |configuration_field|
        context "with #{configuration_field} disabled" do
          before do
            stub_config(configuration_field => { enabled: false })
          end

          it_behaves_like 'returning response status', :not_found
        end
      end

      context 'with licensed feature dependency_proxy_for_packages disabled' do
        before do
          stub_licensed_features(dependency_proxy_for_packages: false)
        end

        it_behaves_like 'returning response status', :forbidden
      end

      context "when accessing with a browser" do
        before do
          allow_next_instance_of(::Browser) do |b|
            allow(b).to receive(:known?).and_return(true)
          end
        end

        it 'returns a bad request response' do
          api_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(response.body).to include(described_class::WEB_BROWSER_ERROR_MESSAGE)
        end
      end

      context 'when doing a request to an external registry' do
        let(:enabled_endpoint_uris) { [URI('192.168.1.1')] }
        let(:outbound_local_requests_allowlist) { ['127.0.0.1'] }
        let(:allowed_endpoints) { enabled_endpoint_uris + outbound_local_requests_allowlist }

        before do
          allow(ObjectStoreSettings).to receive(:enabled_endpoint_uris).and_return(enabled_endpoint_uris)
          stub_application_setting(outbound_local_requests_whitelist: outbound_local_requests_allowlist)
        end

        it 'uses SSRF filter' do
          allow(Gitlab::Workhorse).to receive(:send_dependency)

          api_request

          expect(Gitlab::Workhorse).to have_received(:send_dependency).with(
            an_instance_of(Hash),
            an_instance_of(String),
            a_hash_including(allow_localhost: true, ssrf_filter: true, allowed_endpoints: allowed_endpoints)
          )
        end
      end
    end

    context 'without Workhorse JWT', :verify_workhorse_jwt do
      let(:headers) { basic_auth_header(user.username, personal_access_token.token) }

      it 'returns 403 forbidden' do
        api_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
