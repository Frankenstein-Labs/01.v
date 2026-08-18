# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::Vulnerabilities::PartnerTokenService, feature_category: :secret_detection do
  let_it_be(:project) { create(:project) }

  # Helpers for shared examples
  let(:expected_finding_type) { :vulnerability }
  let(:expected_token_status_model) { ::Vulnerabilities::FindingTokenStatus }
  let(:expected_unique_by_column) { :vulnerability_occurrence_id }

  let_it_be(:findings) { create_list(:vulnerabilities_finding, 3) }
  let_it_be(:finding) { create(:vulnerabilities_finding) }

  it_behaves_like 'partner token service'

  describe '.save_result' do
    let(:result) do
      Security::SecretDetection::PartnerTokens::BaseClient::TokenStatus.new(
        status: :active,
        metadata: { verified_at: Time.current }
      )
    end

    context 'with tracking' do
      let(:finding_with_token) do
        create(:vulnerabilities_finding, :with_secret_detection, project: project)
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
