# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::OnDemandScanPipelineConfigurationService,
  feature_category: :security_policy_management do
  describe '#execute' do
    let_it_be(:project) { create(:project) }

    let_it_be(:website_site_profile) { create(:dast_site_profile, target_type: :website, project: project) }
    let_it_be(:api_site_profile) { create(:dast_site_profile, target_type: :api, project: project) }

    let(:site_profile) { website_site_profile }
    let_it_be(:scanner_profile) { create(:dast_scanner_profile, project: project) }

    let(:service) { described_class.new(project) }
    let(:actions) do
      [
        {
          scan: 'dast',
          site_profile: site_profile.name,
          scanner_profile: scanner_profile.name,
          tags: ['runner-tag']
        },
        {
          scan: 'dast',
          site_profile: 'Site Profile B'
        }
      ]
    end

    subject(:pipeline_configuration) { service.execute(actions).reduce({}, :merge) }

    before do
      allow(DastSiteProfilesFinder).to receive(:new).and_return(double(execute: []))
      allow(DastSiteProfilesFinder).to receive(:new).with(project_id: project.id, name: site_profile.name).and_return(double(execute: [site_profile]))
      allow(DastScannerProfilesFinder).to receive(:new).and_return(double(execute: []))
      allow(DastScannerProfilesFinder).to receive(:new).with(project_ids: [project.id], name: scanner_profile.name).and_return(double(execute: [scanner_profile]))
    end

    it 'uses DastSiteProfilesFinder and DastScannerProfilesFinder to find DAST profiles within the project' do
      expect(DastSiteProfilesFinder).to receive(:new).with(project_id: project.id, name: site_profile.name)
      expect(DastSiteProfilesFinder).to receive(:new).with(project_id: project.id, name: 'Site Profile B')
      expect(DastScannerProfilesFinder).to receive(:new).with(project_ids: [project.id], name: scanner_profile.name)

      pipeline_configuration
    end

    it 'delegates params creation to DastOnDemandScans::ParamsCreateService' do
      expect(AppSec::Dast::ScanConfigs::BuildService).to receive(:new).with(container: project, params: { dast_site_profile: site_profile, dast_scanner_profile: scanner_profile }).and_call_original
      expect(AppSec::Dast::ScanConfigs::BuildService).to receive(:new).with(container: project, params: { dast_site_profile: nil, dast_scanner_profile: nil }).and_call_original

      pipeline_configuration
    end

    context 'when site profile is configured with website type' do
      let(:site_profile) { website_site_profile }

      it 'fetches template content using ::TemplateFinder' do
        expect(::TemplateFinder).to receive(:build).with(:gitlab_ci_ymls, nil, name: 'DAST-On-Demand-Scan').and_call_original

        pipeline_configuration
      end

      it 'returns prepared CI configuration with DAST On-Demand scans defined' do
        expected_configuration = {
          'dast-on-demand-0': {
            stage: 'dast',
            tags: ['runner-tag'],
            image: { name: '$SECURE_ANALYZERS_PREFIX/dast:$DAST_VERSION$DAST_IMAGE_SUFFIX' },
            variables: {
              DAST_VERSION: 6,
              SECURE_ANALYZERS_PREFIX: '$CI_TEMPLATE_REGISTRY_HOST/security-products',
              DAST_IMAGE_SUFFIX: ''
            },
            allow_failure: true,
            script: ['/analyze'],
            artifacts: { access: 'developer', paths: ["gl-dast-*.*"], reports: { dast: 'gl-dast-report.json' }, when: 'always' },
            dast_configuration: { site_profile: site_profile.name, scanner_profile: scanner_profile.name },
            rules: [
              { if: '$CI_GITLAB_FIPS_MODE == "true"', variables: { DAST_IMAGE_SUFFIX: "-fips" } },
              { when: 'on_success' }
            ]
          },
          'dast-on-demand-1': {
            script: 'echo "Error during On-Demand Scan execution: Dast site profile was not provided" && false',
            allow_failure: true
          }
        }

        expect(pipeline_configuration).to eq(expected_configuration)
      end
    end

    context 'when site profile is configured with api type' do
      let(:site_profile) { api_site_profile }

      it 'fetches template content using ::TemplateFinder' do
        expect(::TemplateFinder).to receive(:build).with(:gitlab_ci_ymls, nil, name: 'DAST-On-Demand-API-Scan').and_call_original

        pipeline_configuration
      end

      it 'returns prepared CI configuration with DAST On-Demand API scans defined' do
        expected_configuration = {
          'dast-on-demand-0': {
            stage: 'dast',
            variables: {
              SECURE_ANALYZERS_PREFIX: '$CI_TEMPLATE_REGISTRY_HOST/security-products',
              DAST_API_VERSION: '6',
              DAST_API_IMAGE_SUFFIX: '',
              DAST_API_IMAGE: 'api-security'
            },
            tags: ['runner-tag'],
            image: '$SECURE_ANALYZERS_PREFIX/$DAST_API_IMAGE:$DAST_API_VERSION$DAST_API_IMAGE_SUFFIX',
            allow_failure: true,
            script: ['/peach/analyzer-dast-api'],
            dast_configuration: { site_profile: site_profile.name, scanner_profile: scanner_profile.name },
            artifacts: {
              access: 'developer',
              when: 'always',
              paths: ['gl-assets', 'gl-dast-api-report.json', 'gl-*.log'],
              reports: {
                dast: 'gl-dast-api-report.json'
              }
            }
          },
          'dast-on-demand-1': {
            script: 'echo "Error during On-Demand Scan execution: Dast site profile was not provided" && false',
            allow_failure: true
          }
        }

        expect(pipeline_configuration).to eq(expected_configuration)
      end
    end

    context 'when scan_settings.ignore_default_before_after_script is set' do
      let(:scan_settings) { { ignore_default_before_after_script: ignore_default_before_after_script } }

      let(:actions) do
        [
          {
            scan: 'dast',
            site_profile: site_profile.name,
            scanner_profile: scanner_profile.name,
            tags: ['runner-tag'],
            scan_settings: scan_settings
          }
        ]
      end

      context 'when setting is set to true' do
        let_it_be(:ignore_default_before_after_script) { true }

        it 'overrides before_script and after_script with empty array' do
          expect(pipeline_configuration[:'dast-on-demand-0']).to include(before_script: [], after_script: [])
        end
      end

      context 'when setting is set to false' do
        let_it_be(:ignore_default_before_after_script) { false }

        it 'does not override before_script and after_script with empty array' do
          expect(pipeline_configuration[:'dast-on-demand-0']).not_to include(before_script: [], after_script: [])
        end
      end
    end

    context 'when metadata is added to action' do
      let(:action_metadata) do
        {
          name: 'My policy',
          sha: '8dc6668b57dbeec74feb7c68119cf0c28cbe2a29',
          project_id: 123
        }
      end

      let(:actions) do
        [
          {
            scan: 'dast',
            site_profile: site_profile.name,
            scanner_profile: scanner_profile.name,
            tags: ['runner-tag'],
            metadata: action_metadata
          },
          {
            scan: 'dast',
            site_profile: 'Site Profile B',
            metadata: action_metadata
          }
        ]
      end

      it 'adds _security_metadata_context section to job configuration' do
        metadata_key = Security::SecurityOrchestrationPolicies::CiConfigurationMetadata::METADATA_KEY
        expect(pipeline_configuration[:'dast-on-demand-0']).to include(metadata_key => action_metadata)
        expect(pipeline_configuration[:'dast-on-demand-1']).to include(metadata_key => action_metadata)
      end
    end

    describe "variable injection and precedence" do
      let(:actions) do
        [
          {
            scan: 'dast',
            site_profile: site_profile.name,
            scanner_profile: scanner_profile.name,
            variables: { "DAST_VERSION" => "42" }
          }
        ]
      end

      subject(:variables) { pipeline_configuration.dig(:"dast-on-demand-0", :variables) }

      it "overrides template variables with action variables" do
        expect(variables).to include(DAST_VERSION: "42")
      end
    end
  end
end
