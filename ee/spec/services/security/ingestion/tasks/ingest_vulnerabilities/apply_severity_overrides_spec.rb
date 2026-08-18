# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Tasks::IngestVulnerabilities::ApplySeverityOverrides, feature_category: :vulnerability_management do
  describe '#execute' do
    let(:pipeline) { create(:ci_pipeline) }
    let(:report_finding) { create(:ci_reports_security_finding, name: 'changed', severity: :critical, uuid: uuid) }
    let(:finding_map) { create(:finding_map, report_finding: report_finding, uuid: uuid) }
    let(:service_object) { described_class.new(pipeline, [finding_map]) }
    let(:uuid) { vulnerability_with_override.finding.uuid }
    let(:vulnerability_with_override) do
      create(:vulnerability,
        :with_finding,
        :with_severity_override,
        :high_severity,
        present_on_default_branch: true,
        resolved_on_default_branch: true)
    end

    subject(:execute) { service_object.execute }

    before do
      finding_map.vulnerability_id = vulnerability_with_override.id
    end

    describe 'with an existing severity override' do
      it 'applies the overridden severity' do
        expect do
          execute

          vulnerability_with_override.reload
        end.to change { vulnerability_with_override.severity }
      end
    end
  end
end
