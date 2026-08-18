# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Dependency Proxy for npm packages', :js, :aggregate_failures, feature_category: :package_registry do
  include_context 'file upload requests helpers'
  include_context 'with a server running the dependency proxy'

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :private) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
  let_it_be_with_reload(:dependency_proxy_setting) do
    create(:dependency_proxy_packages_setting, :npm, project: project)
  end

  let_it_be(:remote_file_path) { '/@test/package/-/@test/package-1.0.0.tgz' }
  let_it_be(:remote_file_content) { 'this is a package json file content' }

  let_it_be(:remote_server) do
    handler = ->(env) do
      if env['REQUEST_PATH'] == remote_file_path # rubocop: disable RSpec/AvoidConditionalStatements -- disabling rubocop warning as this is inside a lambda function
        [200, {}, [remote_file_content]]
      else
        [400, {}, []]
      end
    end

    run_server(handler)
  end

  let(:url) { capybara_url("/api/v4/projects/#{project.id}/dependency_proxy/packages/npm/#{remote_file_path}") }
  let(:headers) { { 'Authorization' => "Bearer #{personal_access_token.token}" } }
  let(:last_package) { ::Packages::Package.last }
  let(:last_package_file) { ::Packages::PackageFile.last }

  subject(:response) do
    HTTParty.get(url, headers: headers)
  end

  before do
    stub_licensed_features(dependency_proxy_for_packages: true)
    stub_config(dependency_proxy: { enabled: true })

    # avoid restriction on localhost url
    dependency_proxy_setting.update_column(:npm_external_registry_url, remote_server.base_url)
  end

  shared_examples 'pulling and caching the remote file' do
    it 'pulls and caches the remote file' do
      expect { response }
        .to change { ::Packages::Npm::Package.for_projects(project).count }.from(0).to(1)
        .and change { ::Packages::PackageFile.count }.from(0).to(1)
      expect(last_package.name).to eq('@test/package')
      expect(last_package.version).to eq('1.0.0')
      expect(last_package_file.file_name).to eq('@test/package-1.0.0.tgz')
      expect(response.code).to eq(200)
      expect(response.body).to eq(remote_file_content)
    end
  end

  shared_examples 'returning the cached file' do
    it 'returns the cached file' do
      expect_next_instance_of(::DependencyProxy::Packages::VerifyPackageFileEtagService) do |service|
        expect(service).to receive(:execute).and_return(ServiceResponse.success)
      end
      expect(Gitlab::Workhorse).not_to receive(:send_url)
      expect(Gitlab::Workhorse).not_to receive(:send_dependency)
      expect { response }
        .to not_change { ::Packages::Npm::Package.for_projects(project).count }
        .and not_change { ::Packages::PackageFile.count }
      expect(response.code).to eq(200)
      expect(response.body).to eq(remote_file_content)
    end
  end

  shared_examples 'proxying the remote file if the wrong etag is returned' do
    include_context 'with a wrong etag returned' do
      it 'proxies the remote file' do
        expect(Gitlab::Workhorse).to receive(:send_url).and_call_original
        expect(Gitlab::Workhorse).not_to receive(:send_dependency).and_call_original
        expect { response }
          .to not_change { ::Packages::Npm::Package.for_projects(project).count }
          .and not_change { ::Packages::PackageFile.pending_destruction.count }
        expect(response.code).to eq(200)
        expect(response.body).to eq(remote_file_content)
      end
    end
  end

  shared_context 'with an existing cached file' do
    let_it_be(:package) { create(:npm_package, name: '@test/package', version: '1.0.0', project: project) }
    let_it_be_with_reload(:package_file) { package.package_files.find { |f| f.file_name.end_with?('.tgz') } }

    before do
      file = CarrierWaveStringFile.new_file(
        file_content: remote_file_content,
        filename: '@test/package-1.0.0.tgz',
        content_type: 'text/plain'
      )
      package_file.update!(file_name: '@test/package-1.0.0.tgz', file: file)
    end
  end

  context 'with a reporter user' do
    before_all do
      project.add_reporter(user)
    end

    context 'with no existing file' do
      it 'pulls the remote file without caching' do
        expect { response }
          .to not_change { ::Packages::Npm::Package.for_projects(project).count }
          .and not_change { ::Packages::PackageFile.count }
        expect(response.code).to eq(200)
        expect(response.body).to eq(remote_file_content)
      end

      context 'with a timeout while getting the remote file' do
        let_it_be(:remote_server) do
          handler = ->(_) do
            sleep 0.1 # sleep for 100ms
            [200, {}, []]
          end

          run_server(handler)
        end

        before do
          allow(::Gitlab::Workhorse)
            .to receive(:send_url).and_wrap_original do |original_method, *args, **kwargs, &block|
            # we use `10m` that the function will add an `s` = `10ms`
            # Workhorse will parse that as a timeout of 10 milliseconds which is what we want here.
            kwargs[:timeouts] = { read: '10m' }
            original_method.call(*args, **kwargs, &block)
          end
        end

        it 'times out and return service unavailable' do
          expect { response }
            .to not_change { ::Packages::Npm::Package.for_projects(project).count }
            .and not_change { ::Packages::PackageFile.count }
          expect(response.code).to eq(504)
        end
      end

      it_behaves_like 'returning forbidden error when local requests are not allowed', :npm

      context 'when local requests are allowed in settings' do
        before do
          allow(Gitlab).to receive(:dev_or_test_env?).and_return(false)
          stub_application_setting(allow_local_requests_from_web_hooks_and_services: true)
        end

        it 'pulls the remote file without caching' do
          expect { response }
            .to not_change { ::Packages::Npm::Package.for_projects(project).count }
            .and not_change { ::Packages::PackageFile.count }
          expect(response.code).to eq(200)
          expect(response.body).to eq(remote_file_content)
        end
      end
    end

    context 'with existing file' do
      include_context 'with an existing cached file'

      it_behaves_like 'returning the cached file'
      it_behaves_like 'proxying the remote file if the wrong etag is returned'

      context 'with no etag returned' do
        include_context 'with no etag returned' do
          it_behaves_like 'returning the cached file'
        end
      end

      context 'with a wrong etag returned' do
        include_context 'with a wrong etag returned' do
          it_behaves_like 'returning forbidden error when local requests are not allowed', :npm
        end

        context 'when local requests are allowed in settings' do
          before do
            allow(Gitlab).to receive(:dev_or_test_env?).and_return(false)
            stub_application_setting(allow_local_requests_from_web_hooks_and_services: true)
          end

          it_behaves_like 'proxying the remote file if the wrong etag is returned'
        end
      end
    end
  end

  context 'with a developer user' do
    before_all do
      project.add_developer(user)
    end

    context 'with existing file' do
      include_context 'with an existing cached file'

      it_behaves_like 'returning the cached file'
      it_behaves_like 'proxying the remote file if the wrong etag is returned'

      context 'with no etag returned' do
        include_context 'with no etag returned' do
          it_behaves_like 'returning the cached file'
        end
      end
    end
  end
end
