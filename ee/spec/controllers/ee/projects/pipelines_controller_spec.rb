# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::PipelinesController, feature_category: :continuous_integration do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :small_repo, developers: user) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project, ref: 'master', sha: project.commit.id) }
  let_it_be(:mit_spdx_identifier) { 'MIT' }

  before do
    sign_in(user)
  end

  describe 'frontend abilities', feature_category: :vulnerability_management do
    context 'when accessing show action' do
      subject(:request) do
        get :show, params: { namespace_id: project.namespace, project_id: project, id: pipeline }
      end

      it 'pushes the resolve_vulnerability_with_ai ability to the frontend' do
        expect(controller).to receive(:push_frontend_ability).with(
          ability: :resolve_vulnerability_with_ai,
          resource: project,
          user: user
        )

        request
      end

      context 'when pipeline_security_ai_vr feature flag is disabled' do
        before do
          stub_feature_flags(pipeline_security_ai_vr: false)
        end

        it 'does not push the resolve_vulnerability_with_ai ability to the frontend' do
          expect(controller).not_to receive(:push_frontend_ability)

          request
        end
      end
    end

    context 'when accessing security action' do
      subject(:request) do
        get :security, params: { namespace_id: project.namespace, project_id: project, id: pipeline }
      end

      before do
        create(:ee_ci_build, :sast, pipeline: pipeline)
        stub_licensed_features(sast: true, security_dashboard: true)
      end

      it 'pushes the resolve_vulnerability_with_ai ability to the frontend' do
        expect(controller).to receive(:push_frontend_ability).with(
          ability: :resolve_vulnerability_with_ai,
          resource: project,
          user: user
        )

        request
      end

      context 'when pipeline_security_ai_vr feature flag is disabled' do
        before do
          stub_feature_flags(pipeline_security_ai_vr: false)
        end

        it 'does not push the resolve_vulnerability_with_ai ability to the frontend' do
          expect(controller).not_to receive(:push_frontend_ability)

          request
        end
      end
    end
  end

  describe 'GET security', feature_category: :vulnerability_management do
    context 'with a sast artifact' do
      let(:request) { get :security, params: { namespace_id: project.namespace, project_id: project, id: pipeline } }

      before do
        create(:ee_ci_build, :sast, pipeline: pipeline)
      end

      context 'with feature enabled' do
        before do
          stub_licensed_features(sast: true, security_dashboard: true)
        end

        it 'responds with a 200 and show the template' do
          request

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to render_template :show
        end

        it_behaves_like 'tracks govern usage event', 'pipeline_security'
      end

      context 'with feature disabled' do
        it 'redirects to the pipeline page' do
          request

          expect(response).to redirect_to(pipeline_path(pipeline))
        end

        it_behaves_like "doesn't track govern usage event", 'pipeline_security'
      end
    end

    context 'without sast artifact' do
      context 'with feature enabled' do
        before do
          stub_licensed_features(sast: true)

          get :security, params: { namespace_id: project.namespace, project_id: project, id: pipeline }
        end

        it 'redirects to the pipeline page' do
          expect(response).to redirect_to(pipeline_path(pipeline))
        end
      end

      context 'with feature disabled' do
        before do
          get :security, params: { namespace_id: project.namespace, project_id: project, id: pipeline }
        end

        it 'redirects to the pipeline page' do
          expect(response).to redirect_to(pipeline_path(pipeline))
        end
      end
    end
  end

  describe 'GET codequality_report', feature_category: :code_quality do
    let(:pipeline) { create(:ci_pipeline, project: project) }

    it 'renders the show template' do
      get :codequality_report, params: { namespace_id: project.namespace, project_id: project, id: pipeline }

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template :show
    end
  end

  describe 'GET licenses', feature_category: :software_composition_analysis do
    let(:licenses_with_html) { get :licenses, format: :html, params: { namespace_id: project.namespace, project_id: project, id: pipeline } }
    let(:licenses_with_json) { get :licenses, format: :json, params: { namespace_id: project.namespace, project_id: project, id: pipeline } }
    let_it_be(:software_license_policy) { create(:software_license_policy, :with_mit_license, project: project) }

    let(:payload) { Gitlab::Json.parse(licenses_with_json.body) }

    context 'with a cyclonedx report' do
      let_it_be(:build) { create(:ci_build, pipeline: pipeline) }
      let_it_be(:report) { create(:ee_ci_job_artifact, :cyclonedx, job: build) }

      context 'with feature enabled' do
        before_all do
          create(:pm_package, name: "esutils", purl_type: "npm", default_license_names: ['OLDAP-1.1'],
            other_licenses: [{ license_names: ["BSD-2-Clause"], versions: ["2.0.3"] }])
          create(:pm_package, name: "github.com/astaxie/beego", purl_type: "golang",
            other_licenses: [{ license_names: ["Apache-2.0"], versions: ["v1.10.0"] }])
          create(:pm_package, name: "nokogiri", purl_type: "gem",
            other_licenses: [{ license_names: ["MIT"], versions: ["1.8.0"] }])
        end

        before do
          stub_licensed_features(license_scanning: true)
        end

        context 'with html' do
          before do
            licenses_with_html
          end

          it 'responds with a 200 and show the template' do
            expect(response).to have_gitlab_http_status(:ok)
            expect(response).to render_template :show
          end
        end

        context 'with json' do
          let(:scanner) { ::Gitlab::LicenseScanning.scanner_for_pipeline(project, pipeline) }

          it 'returns license scanning report in json format' do
            expect(payload.size).to eq(scanner.report.licenses.size)
            expect(payload.first.keys).to match_array(%w[name classification dependencies count url])
          end

          it 'returns MIT license allowed status' do
            payload_mit = payload.find { |l| l['name'] == 'MIT License' }
            expect(payload_mit['count']).to eq(scanner.report.licenses.find { |x| x.name == 'MIT License' }.count)
            expect(payload_mit['url']).to eq("https://spdx.org/licenses/MIT.html")
            expect(payload_mit['classification']['approval_status']).to eq('allowed')
          end

          context 'approval_status' do
            subject(:status) { payload.find { |l| l['name'] == 'MIT License' }.dig('classification', 'approval_status') }

            it { is_expected.to eq('allowed') }
          end

          it 'returns the JSON license data sorted by license name' do
            expect(payload.pluck('name')).to match_array([
              'Apache License 2.0',
              'BSD 2-Clause "Simplified" License',
              'Open LDAP Public License v1.1',
              'MIT License',
              'unknown'
            ])
          end

          it 'returns a JSON representation of the license data' do
            expect(payload).to be_present

            payload.each do |item|
              expect(item['name']).to be_present
              expect(item['classification']).to have_key('id')
              expect(item.dig('classification', 'approval_status')).to be_present
              expect(item.dig('classification', 'name')).to be_present
              expect(item).to have_key('dependencies')
              item['dependencies'].each do |dependency|
                expect(dependency['name']).to be_present
              end
              expect(item['count']).to be_present
              expect(item).to have_key('url')
            end
          end
        end
      end
    end

    context 'without a cyclonedx report' do
      context 'with feature enabled' do
        before do
          stub_licensed_features(license_scanning: true)
          licenses_with_html
        end

        it 'redirects to the pipeline page' do
          expect(response).to redirect_to(pipeline_path(pipeline))
        end
      end

      context 'with feature enabled json' do
        before do
          stub_licensed_features(license_scanning: true)
          licenses_with_json
        end

        it 'returns 404' do
          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'with feature disabled' do
        before do
          licenses_with_html
        end

        it 'redirects to the pipeline page' do
          expect(response).to redirect_to(pipeline_path(pipeline))
        end
      end

      context 'with feature disabled json' do
        before do
          licenses_with_json
        end

        it 'returns 404' do
          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end

  describe 'GET license_count', :use_clean_rails_memory_store_caching, feature_category: :software_composition_analysis do
    let(:license_count_request) { get :license_count, format: :json, params: { namespace_id: project.namespace, project_id: project, id: pipeline } }
    let_it_be(:software_license_policy) { create(:software_license_policy, :with_mit_license, project: project) }
    let(:cache_key) { ['license_count', project.cache_key_with_version, pipeline.cache_key_with_version] }

    context 'with a cyclonedx report' do
      let_it_be(:build) { create(:ci_build, pipeline: pipeline) }
      let_it_be(:report) { create(:ee_ci_job_artifact, :cyclonedx, job: build) }

      context 'with feature enabled' do
        before_all do
          create(:pm_package, name: "esutils", purl_type: "npm",
            other_licenses: [{ license_names: ["BSD-2-Clause"], versions: ["2.0.3"] }])
          create(:pm_package, name: "github.com/astaxie/beego", purl_type: "golang",
            other_licenses: [{ license_names: ["Apache-2.0"], versions: ["v1.10.0"] }])
          create(:pm_package, name: "nokogiri", purl_type: "gem",
            other_licenses: [{ license_names: ["MIT"], versions: ["1.8.0"] }])
        end

        before do
          stub_licensed_features(license_scanning: true)
        end

        it 'populates and returns the license count from the cache' do
          # Perform the request to populate the cache
          license_count_request
          expect(response).to have_gitlab_http_status(:ok)

          # Check that the cache has been populated
          scanner = ::Gitlab::LicenseScanning.scanner_for_pipeline(project, pipeline)
          expect(Rails.cache.read(cache_key)).to eq(scanner.report.licenses.count)

          # Perform the request again to test cache hit
          license_count_request

          expect(response).to have_gitlab_http_status(:ok)
          payload = Gitlab::Json.parse(response.body)
          expect(payload['license_count']).to eq(scanner.report.licenses.count)
        end
      end

      context 'with feature disabled' do
        before do
          license_count_request
        end

        it 'returns a 404 status' do
          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'without a cyclonedx report' do
      before do
        stub_licensed_features(license_scanning: true)
        license_count_request
      end

      it 'returns a 404 status when no license data is present' do
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
