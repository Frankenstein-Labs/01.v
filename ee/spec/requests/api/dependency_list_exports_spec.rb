# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::DependencyListExports, feature_category: :dependency_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let(:export_type) { nil }
  let(:send_email) { false }
  let(:params) { { export_type: export_type, send_email: send_email } }

  shared_examples_for 'creating dependency list export' do
    subject(:create_dependency_list_export) { post api(request_path, user), params: params }

    context 'with user without permission' do
      before do
        stub_licensed_features(dependency_scanning: true, security_dashboard: true)

        resource.add_guest(user)
      end

      it 'returns 403' do
        expect(::Dependencies::CreateExportService).not_to receive(:new)

        create_dependency_list_export

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'with user with enough permission' do
      before do
        resource.add_developer(user)
      end

      context 'with license feature disabled' do
        before do
          stub_licensed_features(dependency_scanning: false, security_dashboard: false)
        end

        it 'returns 403' do
          expect(::Dependencies::CreateExportService).not_to receive(:new)

          create_dependency_list_export

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with license feature enabled' do
        before do
          stub_licensed_features(dependency_scanning: true, security_dashboard: true)
        end

        it 'creates and returns a dependency_list_export' do
          create_dependency_list_export

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response).to have_key('id')
          expect(json_response).to have_key('has_finished')
          expect(json_response).to have_key('self')
          expect(json_response).to have_key('download')
          expect(json_response['export_type']).to eq(export_type)
          expect(json_response['send_email']).to eq(send_email)
        end

        context 'when send_email is true' do
          let(:send_email) { true }

          it 'sets value on created export' do
            create_dependency_list_export

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['send_email']).to eq(send_email)
          end
        end

        context 'when export creation fails' do
          before do
            allow_next_instance_of(Dependencies::CreateExportService) do |service|
              error = ServiceResponse.error(message: ['validation error'])
              allow(service).to receive(:execute).and_return(error)
            end
          end

          it 'returns and error message and status code from the service' do
            create_dependency_list_export

            expect(response).to have_gitlab_http_status(:unprocessable_entity)
            expect(json_response['message']).to eq(['validation error'])
          end
        end
      end
    end
  end

  shared_examples 'supports export type' do |type|
    let(:params) { { export_type: type } }

    subject(:create_dependency_list_export) { post api(request_path, user), params: params }

    it 'supports export type' do
      create_dependency_list_export

      expect(response).to have_gitlab_http_status(:created)
      expect(json_response['export_type']).to eq(type)
    end
  end

  shared_examples 'does not support export type' do |type|
    let(:params) { { export_type: type } }

    subject(:create_dependency_list_export) { post api(request_path, user), params: params }

    it 'does not support export type' do
      create_dependency_list_export

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['error']).to eq('export_type does not have a valid value')
    end
  end

  describe 'POST /projects/:id/dependency_list_exports' do
    let(:request_path) { "/projects/#{project.id}/dependency_list_exports" }
    let(:resource) { project }
    let(:exportable) { project }
    let(:export_type) { 'dependency_list' }

    it_behaves_like 'creating dependency list export'

    context 'with permissions to create exports' do
      before do
        stub_licensed_features(dependency_scanning: true, security_dashboard: true)
        resource.add_developer(user)
      end

      it_behaves_like 'supports export type', 'dependency_list'
      it_behaves_like 'supports export type', 'csv'
      it_behaves_like 'supports export type', 'cyclonedx_1_6_json'
      it_behaves_like 'does not support export type', 'json_array'
      it_behaves_like 'does not support export type', 'sbom'

      context 'with no export_type' do
        let(:export_type) { nil }

        it 'creates export with dependency_list type' do
          post api(request_path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['export_type']).to eq('dependency_list')
        end
      end

      it_behaves_like 'authorizing granular token permissions', :create_dependency_list_export do
        let(:boundary_object) { project }
        let(:request) { post api(request_path, personal_access_token: pat) }
      end
    end
  end

  describe 'POST /groups/:id/dependency_list_exports' do
    let(:request_path) { "/groups/#{group.id}/dependency_list_exports" }
    let(:resource) { group }
    let(:exportable) { group }
    let(:export_type) { 'json_array' }

    it_behaves_like 'creating dependency list export'

    context 'with permissions to create exports' do
      before do
        stub_licensed_features(dependency_scanning: true, security_dashboard: true)
        resource.add_developer(user)
      end

      it_behaves_like 'supports export type', 'json_array'
      it_behaves_like 'supports export type', 'csv'
      it_behaves_like 'does not support export type', 'cyclonedx_1_6_json'
      it_behaves_like 'does not support export type', 'dependency_list'
      it_behaves_like 'does not support export type', 'sbom'

      context 'with no export_type' do
        let(:export_type) { nil }

        it 'creates export with json_array type' do
          post api(request_path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['export_type']).to eq('json_array')
        end
      end

      it_behaves_like 'authorizing granular token permissions', :create_dependency_list_export do
        let(:boundary_object) { group }
        let(:request) { post api(request_path, personal_access_token: pat) }
      end
    end
  end

  describe 'POST /pipelines/:id/dependency_list_exports' do
    let(:request_path) { "/pipelines/#{pipeline.id}/dependency_list_exports" }
    let(:resource) { project }
    let(:exportable) { pipeline }
    let(:export_type) { 'sbom' }

    it_behaves_like 'creating dependency list export'

    context 'with permissions to create exports' do
      before do
        stub_licensed_features(dependency_scanning: true, security_dashboard: true)
        resource.add_developer(user)
      end

      it_behaves_like 'authorizing granular token permissions', :create_dependency_list_export do
        let(:boundary_object) { project }
        let(:request) { post api(request_path, personal_access_token: pat), params: params }
      end

      it_behaves_like 'supports export type', 'sbom'
      it_behaves_like 'does not support export type', 'csv'
      it_behaves_like 'does not support export type', 'cyclonedx_1_6_json'
      it_behaves_like 'does not support export type', 'dependency_list'
      it_behaves_like 'does not support export type', 'json_array'

      context 'with no export_type' do
        let(:export_type) { nil }

        it 'creates export with sbom type' do
          post api(request_path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['export_type']).to eq('sbom')
        end
      end

      describe 'export content', :sidekiq_inline do
        let_it_be(:pipeline) { create(:ee_ci_pipeline, :with_cyclonedx_report, project: project) }
        let(:raw_file) { ::Dependencies::DependencyListExport.find(json_response['id']).file.read }

        subject(:sbom) { Gitlab::Json.parse(raw_file) }

        before do
          post api(request_path, user), params: params
        end

        RSpec::Matchers.define :be_valid_cyclonedx_json do
          match do |actual|
            (@validator = Gitlab::Ci::Parsers::Sbom::Validators::CyclonedxSchemaValidator.new(actual)).valid?
          end

          failure_message do
            "expected to be a valid CycloneDX document but failed with errors: #{@validator.errors.join("\n")}"
          end
        end

        it 'passes schema validation' do
          expect(sbom).to be_valid_cyclonedx_json
        end

        it 'outputs a CyloneDX SBoM' do
          expect(sbom['bomFormat']).to eq('CycloneDX')
          expect(sbom['specVersion']).to eq('1.4')
          expect(sbom['serialNumber']).to match(/^urn:uuid:\h{8}-\h{4}-\h{4}-\h{4}-\h{12}$/)
          expect(sbom['version']).to eq(1)
        end

        describe 'metadata' do
          let(:metadata) { sbom['metadata'] }

          it 'has correct author data' do
            expect(metadata['authors']).to match_array([{ 'name' => 'GitLab', 'email' => 'support@gitlab.com' }])
          end

          describe 'properties' do
            let(:properties) { metadata['properties'] }

            it 'has correct property data' do
              expect(properties).to include({ 'name' => 'gitlab:meta:schema_version', 'value' => '1' })
              expect(properties).to include({ 'name' => 'gitlab:dependency_scanning:package_manager',
                'value' => 'bundler' })
              expect(properties).to include({ 'name' => 'gitlab:dependency_scanning:package_manager:name',
          'value' => 'go' })
              expect(properties).to include({ 'name' => 'gitlab:dependency_scanning:package_manager:name',
          'value' => 'npm' })
            end
          end

          describe 'tools' do
            let(:tools) { metadata['tools'] }

            it 'has correct tools data' do
              expect(tools).to include({ 'vendor' => 'GitLab', 'name' => 'Gemnasium', 'version' => '2.34.0' })
              expect(tools).to include({ 'vendor' => 'CycloneDX', 'name' => 'cyclonedx-gradle-plugin',
          'version' => '1.7.3' })
            end
          end
        end

        context 'with a container scanning sbom' do
          let_it_be(:pipeline) do
            create(:ee_ci_pipeline, :with_cyclonedx_container_scanning, project: project)
          end

          it 'passes schema validation' do
            expect(sbom).to be_valid_cyclonedx_json
          end

          it 'does not put license name in the id field' do
            component = sbom['components'].find do |component|
              component['name'] == 'component-with-license-name'
            end

            expect(component['licenses']).to eq([
              {
                'license' => {
                  'name' => 'not-an-spdx-license'
                }
              }
            ])
          end
        end

        context 'when pipeline contains invalid reports' do
          let_it_be(:pipeline) do
            create(:ee_ci_pipeline, :with_cyclonedx_report, :with_invalid_cyclonedx_report, project: project)
          end

          it 'filters out invalid reports' do
            expect(sbom['metadata']['tools'].size).to be > 1
            expect(sbom['components'].size).to be > 1
            expect(sbom['metadata']['tools']).not_to include(hash_including('name' => 'Invalid Tool'))
            expect(sbom['components']).not_to include(hash_including('name' => 'duplicate'))
          end
        end
      end
    end
  end

  describe 'GET /dependency_list_exports/:export_id' do
    let(:dependency_list_export) { create(:dependency_list_export, :finished, author: user, project: project) }
    let(:request_path) { "/dependency_list_exports/#{dependency_list_export.id}" }

    subject(:fetch_dependency_list_export) { get api(request_path, user) }

    shared_examples 'shows export data' do
      it 'fetches and returns a dependency_list_export' do
        fetch_dependency_list_export

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['id']).to eq(dependency_list_export.id)
        expect(json_response['status']).to eq(dependency_list_export.status_name.to_s)
        expect(json_response['has_finished']).to eq(dependency_list_export.finished?)
        expect(json_response['self']).to match("/api/v4/dependency_list_exports/#{dependency_list_export.id}")
        expect(json_response['download'])
          .to match("/api/v4/dependency_list_exports/#{dependency_list_export.id}/download")
      end
    end

    context 'with user without permission' do
      before do
        stub_licensed_features(dependency_scanning: true)
        project.add_guest(user)
      end

      it 'returns 403' do
        fetch_dependency_list_export

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'with user with enough permission' do
      before do
        project.add_developer(user)
      end

      context 'with license feature disabled' do
        before do
          stub_licensed_features(dependency_scanning: false)
        end

        it 'returns 403' do
          fetch_dependency_list_export

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with license feature enabled' do
        before do
          stub_licensed_features(dependency_scanning: true)
        end

        it_behaves_like 'authorizing granular token permissions', :read_dependency_list_export do
          let(:boundary_object) { project }
          let(:request) { get api(request_path, personal_access_token: pat) }
        end

        context 'when record does not exist' do
          let(:request_path) { "/dependency_list_exports/#{non_existing_record_id}" }

          it 'returns not found' do
            fetch_dependency_list_export

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        it_behaves_like 'shows export data'

        context 'when export is failed' do
          let(:dependency_list_export) { create(:dependency_list_export, :failed, author: user, project: project) }

          it_behaves_like 'shows export data'
        end

        context 'with dependency list export not completed' do
          let(:dependency_list_export) { create(:dependency_list_export, status, author: user, project: project) }

          where(:status) { [:created, :running] }

          with_them do
            it 'sets polling and returns accepted' do
              fetch_dependency_list_export

              expect(response).to have_gitlab_http_status(:accepted)
              expect(response.headers[Gitlab::PollingInterval::HEADER_NAME]).to match(/\d+/)
            end
          end
        end
      end
    end

    context 'when the export belongs to a group' do
      let(:dependency_list_export) do
        create(:dependency_list_export, :finished, author: user, group: group, project: nil)
      end

      before do
        stub_licensed_features(dependency_scanning: true, security_dashboard: true)
        group.add_developer(user)
      end

      it_behaves_like 'authorizing granular token permissions', :read_dependency_list_export do
        let(:boundary_object) { group }
        let(:request) { get api(request_path, personal_access_token: pat) }
      end
    end
  end

  describe 'GET /dependency_list_exports/:export_id/download' do
    let(:dependency_list_export) { create(:dependency_list_export, :finished, author: user, project: project) }
    let(:request_path) { "/dependency_list_exports/#{dependency_list_export.id}/download" }

    subject(:download_dependency_list_export) { get api(request_path, user) }

    context 'with user without permission' do
      before do
        stub_licensed_features(dependency_scanning: true)
        project.add_guest(user)
      end

      it 'returns 403' do
        download_dependency_list_export

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'with user with enough permission' do
      before do
        project.add_developer(user)
      end

      context 'with license feature disabled' do
        before do
          stub_licensed_features(dependency_scanning: false)
        end

        it 'returns 403' do
          download_dependency_list_export

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with license feature enabled' do
        before do
          stub_licensed_features(dependency_scanning: true)
        end

        it_behaves_like 'authorizing granular token permissions', :read_dependency_list_export do
          let(:boundary_object) { project }
          let(:request) { get api(request_path, personal_access_token: pat) }
        end

        context 'when record does not exist' do
          let(:request_path) { "/dependency_list_exports/#{non_existing_record_id}/download" }

          it 'returns not found' do
            download_dependency_list_export

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        it 'returns file content' do
          download_dependency_list_export

          expect(response).to have_gitlab_http_status(:ok)

          json = Gitlab::Json.parse(File.read(response.headers['X-Sendfile']))
          expect(json).to eq(Gitlab::Json.parse(dependency_list_export.file.read))
        end

        context 'with dependency list export not finished' do
          let(:dependency_list_export) { create(:dependency_list_export, author: user, project: project) }

          it 'returns 404' do
            download_dependency_list_export

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end
    end

    context 'when the export belongs to a group' do
      let(:dependency_list_export) do
        create(:dependency_list_export, :finished, author: user, group: group, project: nil)
      end

      before do
        stub_licensed_features(dependency_scanning: true, security_dashboard: true)
        group.add_developer(user)
      end

      it_behaves_like 'authorizing granular token permissions', :read_dependency_list_export do
        let(:boundary_object) { group }
        let(:request) { get api(request_path, personal_access_token: pat) }
      end
    end
  end
end
