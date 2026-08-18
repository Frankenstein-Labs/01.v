# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::DependencyProxy::Packages::Npm, :aggregate_failures, feature_category: :package_registry do
  using RSpec::Parameterized::TableSyntax
  include HttpBasicAuthHelpers
  include WorkhorseHelpers
  include_context 'for a dependency proxy for packages'

  let_it_be_with_refind(:dependency_proxy_setting) do
    create(:dependency_proxy_packages_setting, :npm, project: project)
  end

  before do
    stub_feature_flags(allow_guest_plus_roles_to_pull_packages: false)
  end

  describe 'GET /api/v4/projects/:project_id/dependency_proxy/packages/npm/*package_name/-/*file_name' do
    let(:package_name) { '@test/package' }
    let(:file_name) { '@test/package-1.0.0.tgz' }
    let(:url) { "/projects/#{project.id}/dependency_proxy/packages/npm/#{package_name}/-/#{file_name}" }

    subject { get(api(url), headers: headers) }

    context 'with granular token authorization' do
      before do
        project.add_guest(user)
      end

      it_behaves_like 'authorizing granular token permissions', :download_npm_package do
        let(:boundary_object) { project }
        let(:request) { get api(url), headers: build_token_auth_header(pat.token) }
      end
    end

    context 'with valid parameters' do
      shared_examples 'handling different token types' do |personal_access_token_cases:|
        let_it_be(:package) { create(:npm_package, project: project) }
        let(:package_file) { package.package_files.find { |f| f.file_name.end_with?('.tgz') } }
        let(:package_name) { package.name }
        let(:file_name) { package_file.file_name }
        let(:headers) { { 'Authorization' => "Bearer #{token}" } if token }

        before do
          allow_next_instance_of(::DependencyProxy::Packages::VerifyPackageFileEtagService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success)
          end
        end

        context 'and a personal access token' do
          where(:user_role, :valid_token, :expected_status) do
            personal_access_token_cases
          end

          with_them do
            let(:token) do
              break nil if user_role == :anonymous

              valid_token ? personal_access_token.token : 'invalid_token'
            end

            before do
              project.send(:"add_#{user_role}", user) unless user_role == :anonymous
            end

            it_behaves_like 'returning response status', params[:expected_status]
          end
        end

        context 'and a deploy token' do
          where(:valid_token, :expected_status) do
            true  | :ok
            false | :unauthorized
          end

          with_them do
            let(:token) { valid_token ? deploy_token.token : 'invalid_token' }

            it_behaves_like 'returning response status', params[:expected_status]
          end
        end

        context 'and a ci job token' do
          where(:valid_token, :expected_status) do
            true  | :ok
            false | :unauthorized
          end

          with_them do
            let(:token) { valid_token ? job.token : 'invalid_token' }

            before_all do
              project.add_developer(user)
            end

            it_behaves_like 'returning response status', params[:expected_status]
          end
        end
      end

      shared_examples 'a user pulling files' do
        let(:using_a_deploy_token) { false }
        let(:token) { personal_access_token.token }
        let(:headers) { { 'Authorization' => "Bearer #{token}" } }

        shared_examples 'returning a workhorse sendurl response' do
          it_behaves_like 'returning a workhorse sendurl response with', headers: {}

          context 'with an external token' do
            before do
              dependency_proxy_setting.update!(npm_external_registry_auth_token: 'token')
            end

            it_behaves_like 'returning a workhorse sendurl response with',
              headers: { 'Authorization' => ['Bearer token'] }
          end

          context 'with an external basic auth' do
            before do
              dependency_proxy_setting.update!(npm_external_registry_basic_auth: 'token')
            end

            it_behaves_like 'returning a workhorse sendurl response with',
              headers: { 'Authorization' => ['Basic token'] }
          end
        end

        shared_examples 'returning a workhorse senddependency response' do
          it_behaves_like 'returning a workhorse senddependency response with', headers: nil, upload_url_present: false

          context 'with an external token' do
            before do
              dependency_proxy_setting.update!(npm_external_registry_auth_token: 'token')
            end

            it_behaves_like 'returning a workhorse senddependency response with',
              headers: { 'Authorization' => ['Bearer token'] },
              upload_url_present: false
          end

          context 'with an external basic auth' do
            before do
              dependency_proxy_setting.update!(npm_external_registry_basic_auth: 'token')
            end

            it_behaves_like 'returning a workhorse senddependency response with',
              headers: { 'Authorization' => ['Basic token'] },
              upload_url_present: false
          end
        end

        shared_examples 'pulling existing files' do |can_destroy_package_files: false|
          let_it_be(:package) { create(:npm_package, project: project) }

          let(:package_file) { package.package_files.find { |f| f.file_name.end_with?('.tgz') } }
          let(:package_name) { package.name }

          context 'when pulling a file' do
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
              it_behaves_like params[:shared_example] if params[:shared_example]
            end
          end
        end

        shared_examples 'pulling non existing files' do |can_write_package_files: true|
          context 'with file test.tgz' do
            let(:file_name) { 'test.tgz' }

            if can_write_package_files
              it_behaves_like 'returning a workhorse senddependency response'
            else
              it_behaves_like 'returning a workhorse sendurl response'
            end
          end
        end

        context 'with a reporter pulling files' do
          before_all do
            project.add_reporter(user)
          end

          it_behaves_like 'pulling existing files'
          it_behaves_like 'pulling non existing files', can_write_package_files: false
        end

        context 'with a developer pulling files' do
          before_all do
            project.add_developer(user)
          end

          it_behaves_like 'pulling existing files'
          it_behaves_like 'pulling non existing files'
        end

        context 'with a maintainer pulling files' do
          before_all do
            project.add_maintainer(user)
          end

          it_behaves_like 'pulling existing files', can_destroy_package_files: true
          it_behaves_like 'pulling non existing files'

          context 'with a ci job token' do
            let(:token) { job.token }

            it_behaves_like 'pulling existing files', can_destroy_package_files: true
            it_behaves_like 'pulling non existing files'
          end
        end

        context 'with a deploy token' do
          let(:using_a_deploy_token) { true }

          let(:token) { deploy_token.token }

          it_behaves_like 'pulling existing files', can_destroy_package_files: true
          it_behaves_like 'pulling non existing files'
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
                [:anonymous, nil,   :forbidden],
                [:guest,     true,  :ok],
                [:guest,     false, :unauthorized]
              ]
            it_behaves_like 'a user pulling files'
          end

          context 'with an internal project' do
            before do
              project.update!(visibility_level: Gitlab::VisibilityLevel::INTERNAL)
            end

            it_behaves_like 'handling different token types',
              personal_access_token_cases: [
                [:anonymous, nil,   :not_found],
                [:guest,     true,  :ok],
                [:guest,     false, :unauthorized]
              ]
            it_behaves_like 'a user pulling files'
          end

          context 'with a private project' do
            before do
              project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
            end

            it_behaves_like 'handling different token types',
              personal_access_token_cases: [
                [:anonymous, nil,   :not_found],
                [:guest,     true,  :forbidden],
                [:guest,     false, :unauthorized],
                [:reporter,  true,  :ok],
                [:reporter,  false, :unauthorized]
              ]
            it_behaves_like 'a user pulling files'
          end
        end
      end

      it_behaves_like 'updating personal access token last used' do
        let_it_be(:package) { create(:npm_package, project: project) }
        let(:package_file) { package.package_files.with_format('tgz').take }
        let(:package_name) { package.name }
        let(:file_name) { package_file.file_name }
        let(:headers) { build_token_auth_header(personal_access_token.token) }
      end
    end

    context 'with invalid parameters' do
      context 'with invalid package name' do
        let(:package_name) { '@test/package/invalid' }

        it_behaves_like 'returning response status', :bad_request
      end

      context 'with invalid package file name' do
        let(:file_name) { '%2F..%2Ftest.tgz' }

        it_behaves_like 'returning response status', :bad_request
      end
    end

    context 'with a developer' do
      let(:headers) { { 'Authorization' => "Bearer #{personal_access_token.token}" } }

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
            maven_external_registry_url: 'http://sandbox.test',
            npm_external_registry_url: nil
          )
        end

        it_behaves_like 'returning response status', :not_found
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

      context 'with packages_dependency_proxy_npm disabled' do
        before do
          stub_feature_flags(packages_dependency_proxy_npm: false)
        end

        it_behaves_like 'returning response status', :not_found
      end
    end

    context 'without Workhorse JWT', :verify_workhorse_jwt do
      let(:headers) { { 'Authorization' => "Bearer #{personal_access_token.token}" } }

      it 'returns 403 forbidden' do
        get(api(url), headers: headers)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
