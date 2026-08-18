# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::Security::PartnerTokenService, feature_category: :secret_detection do
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:scan) { create(:security_scan, pipeline: pipeline, scan_type: :secret_detection, project: project) }

  # Helpers for shared examples
  let_it_be(:findings) { create_list(:security_finding, 3, scan: scan) }
  let_it_be(:finding) { create(:security_finding, scan: scan) }
  let(:expected_finding_type) { :security }
  let(:expected_token_status_model) { ::Security::FindingTokenStatus }
  let(:expected_unique_by_column) { :security_finding_id }

  it_behaves_like 'partner token service'

  describe '.save_result' do
    let(:uuid) { SecureRandom.uuid }
    let(:security_finding) { create(:security_finding, scan: scan, uuid: uuid) }
    let(:result) do
      Security::SecretDetection::PartnerTokens::BaseClient::TokenStatus.new(
        status: 'active',
        metadata: { verified_at: Time.current }
      )
    end

    context 'with associated vulnerability findings' do
      let(:vulnerability) { create(:vulnerability, project: project) }
      let(:vuln_finding) do
        create(:vulnerabilities_finding,
          project: project,
          vulnerability: vulnerability,
          uuid: security_finding.uuid
        )
      end

      before do
        security_finding.update!(vulnerability_finding: vuln_finding)
      end

      it 'creates token status for both security and vulnerability findings' do
        expect { described_class.save_result(security_finding, result) }
          .to change { Security::FindingTokenStatus.count }.by(1)
          .and change { Vulnerabilities::FindingTokenStatus.count }.by(1)

        expect(security_finding.reload.token_status).to have_attributes(
          status: 'active',
          project_id: project.id
        )

        expect(vuln_finding.reload.finding_token_status).to have_attributes(
          status: 'active',
          project_id: project.id
        )
      end
    end

    context 'with multiple related findings and vulnerability findings' do
      let(:another_scan) { create(:security_scan, pipeline: pipeline, scan_type: :secret_detection, project: project) }
      let!(:related_finding) { create(:security_finding, scan: another_scan, uuid: uuid) }
      let(:vulnerability) { create(:vulnerability, project: project) }
      let(:vuln_finding) do
        create(:vulnerabilities_finding,
          project: project,
          vulnerability: vulnerability,
          uuid: uuid
        )
      end

      before do
        security_finding.update!(vulnerability_finding: vuln_finding)
      end

      it 'creates token status for all security and vulnerability findings' do
        expect { described_class.save_result(security_finding, result) }
          .to change { Security::FindingTokenStatus.count }.by(2)
          .and change { Vulnerabilities::FindingTokenStatus.count }.by(1)

        [security_finding, related_finding].each do |finding|
          expect(finding.reload.token_status).to have_attributes(
            status: 'active',
            project_id: project.id
          )
        end

        expect(vuln_finding.reload.finding_token_status).to have_attributes(
          status: 'active',
          project_id: project.id
        )
      end
    end

    context 'with tracking' do
      let(:finding_with_token) do
        create(:security_finding,
          scan: scan,
          finding_data: {
            'identifiers' => [
              {
                'external_type' => 'gitleaks_rule_id',
                'external_id' => 'AWS'
              }
            ]
          }
        )
      end

      it 'tracks secret_detection_token_verified event' do
        expect { described_class.save_result(finding_with_token, result) }
          .to trigger_internal_events('secret_detection_token_verified')
          .with(
            project: finding_with_token.project,
            namespace: finding_with_token.project.namespace,
            additional_properties: {
              label: 'AWS',
              property: 'active'
            }
          )
      end
    end
  end
end
