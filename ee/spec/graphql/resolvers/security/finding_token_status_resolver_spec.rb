# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::FindingTokenStatusResolver, feature_category: :secret_detection do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, developers: user) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:build) { create(:ci_build, pipeline: pipeline) }
  let_it_be(:security_scan) { create(:security_scan, project: project, build: build, scan_type: :secret_detection) }
  let_it_be(:security_finding) do
    create(:security_finding,
      scan: security_scan,
      finding_data: {
        'name' => 'GitLab personal access token',
        'identifiers' => [
          {
            'external_type' => 'gitleaks_rule_id',
            'external_id' => 'gitlab_personal_access_token',
            'name' => 'Gitleaks rule ID gitlab_personal_access_token'
          }
        ],
        'raw_source_code_extract' => 'glpat-test-token'
      }
    )
  end

  specify do
    expect(described_class)
      .to have_nullable_graphql_type(Types::Vulnerabilities::FindingTokenStatusType)
  end

  describe '#resolve' do
    before do
      stub_licensed_features(security_dashboard: true, secret_detection_validity_checks: true)
      project.security_setting.update!(validity_checks_enabled: true)
    end

    subject(:result) { resolve_status }

    shared_examples 'does not expose token status' do
      it { is_expected.to be_nil }
    end

    context 'when security_finding object is nil' do
      let(:security_finding) { nil }

      it_behaves_like 'does not expose token status'
    end

    context 'when scan_type is not secret_detection' do
      let_it_be(:sast_scan) { create(:security_scan, project: project, build: build, scan_type: :sast) }
      let_it_be(:sast_finding) { create(:security_finding, scan: sast_scan) }

      subject(:result) { resolve_status(sast_finding) }

      it_behaves_like 'does not expose token status'
    end

    context 'when project is not licensed for secret_detection_validity_checks' do
      before do
        stub_licensed_features(secret_detection_validity_checks: false)
      end

      it_behaves_like 'does not expose token status'
    end

    context 'when project setting validity_checks_enabled is false' do
      before do
        project.security_setting.update!(validity_checks_enabled: false)
      end

      it_behaves_like 'does not expose token status'
    end

    context 'when there is no token status record' do
      it 'returns nil for .value' do
        expect(result.value).to be_nil
      end
    end

    context 'when a token status exists' do
      let_it_be(:token_status) do
        create(:security_finding_token_status,
          security_finding: security_finding,
          status: :active
        )
      end

      it 'returns the active status' do
        status = result.value
        expect(status).to be_a(Security::FindingTokenStatus)
        expect(status.status).to eq('active')
      end
    end

    context 'when multiple token status records exist for different findings' do
      let_it_be(:security_finding_1) do
        create(:security_finding,
          scan: security_scan,
          finding_data: {
            'name' => 'GitLab personal access token',
            'identifiers' => [
              {
                'external_type' => 'gitleaks_rule_id',
                'external_id' => 'gitlab_personal_access_token',
                'name' => 'Gitleaks rule ID gitlab_personal_access_token'
              }
            ],
            'raw_source_code_extract' => 'glpat-token-1'
          }
        )
      end

      let_it_be(:security_finding_2) do
        create(:security_finding,
          scan: security_scan,
          finding_data: {
            'name' => 'GitLab personal access token',
            'identifiers' => [
              {
                'external_type' => 'gitleaks_rule_id',
                'external_id' => 'gitlab_personal_access_token',
                'name' => 'Gitleaks rule ID gitlab_personal_access_token'
              }
            ],
            'raw_source_code_extract' => 'glpat-token-2'
          }
        )
      end

      let_it_be(:token_status_1) do
        create(:security_finding_token_status,
          security_finding: security_finding_1,
          status: :active
        )
      end

      let_it_be(:token_status_2) do
        create(:security_finding_token_status,
          security_finding: security_finding_2,
          status: :inactive
        )
      end

      it 'returns the correct token status for each security finding' do
        result1 = resolve_status(security_finding_1)
        result2 = resolve_status(security_finding_2)

        expect(result1.value.status).to eq('active')
        expect(result2.value.status).to eq('inactive')
      end
    end

    context 'when batch loading multiple findings' do
      let_it_be(:findings) do
        Array.new(5) do |i|
          finding = create(:security_finding,
            scan: security_scan,
            finding_data: {
              'name' => 'GitLab personal access token',
              'identifiers' => [
                {
                  'external_type' => 'gitleaks_rule_id',
                  'external_id' => 'gitlab_personal_access_token',
                  'name' => 'Gitleaks rule ID gitlab_personal_access_token'
                }
              ],
              'raw_source_code_extract' => "glpat-token-#{i}"
            }
          )
          create(:security_finding_token_status,
            security_finding: finding,
            status: i.even? ? :active : :inactive
          )
          finding
        end
      end

      it 'batch loads all token statuses efficiently' do
        results = findings.map { |finding| resolve_status(finding).value }

        expect(results.map(&:status)).to eq(%w[active inactive active inactive active])
      end
    end
  end

  def resolve_status(obj = security_finding)
    resolve(
      described_class,
      obj: obj,
      ctx: { current_user: user },
      arg_style: :internal
    )
  end
end
