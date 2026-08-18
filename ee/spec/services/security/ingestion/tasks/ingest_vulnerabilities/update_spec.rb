# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Tasks::IngestVulnerabilities::Update, feature_category: :vulnerability_management do
  describe '#execute' do
    let(:pipeline) { create(:ci_pipeline) }
    let(:cvss) { [{ 'vector' => 'new_vector', 'vendor' => 'GitLab' }] }
    let(:report_finding_1) do
      create(:ci_reports_security_finding, name: 'changed', solution: 'solution', severity: :critical, cvss: cvss)
    end

    let(:report_finding_2) do
      create(:ci_reports_security_finding, name: 'changed', solution: 'solution', severity: :critical, cvss: cvss)
    end

    let(:finding_map_1) { create(:finding_map, report_finding: report_finding_1) }
    let(:finding_map_2) { create(:finding_map, report_finding: report_finding_2) }
    let(:service_object) { described_class.new(pipeline, [finding_map_1, finding_map_2]) }
    let(:new_finding_1) { create(:vulnerabilities_finding) }
    let(:new_finding_2) { create(:vulnerabilities_finding) }
    let(:vulnerability_1) do
      create(:vulnerability,
        :with_finding,
        :high_severity,
        present_on_default_branch: true,
        resolved_on_default_branch: true,
        cvss: [{ 'vector' => 'vector_text', 'vendor' => 'GitLab' }],
        detected_at: Time.zone.now,
        updated_at: 1.day.ago)
    end

    let(:vulnerability_2) do
      create(:vulnerability,
        :with_finding,
        :high_severity,
        present_on_default_branch: false,
        resolved_on_default_branch: true,
        cvss: [{ 'vector' => 'vector_text', 'vendor' => 'GitLab' }],
        detected_at: Time.zone.now,
        updated_at: 1.day.ago)
    end

    subject(:set_present_on_default_branch) { service_object.execute }

    before do
      finding_map_1.finding_id = new_finding_1.id
      finding_map_1.vulnerability_id = vulnerability_1.id

      finding_map_2.finding_id = new_finding_2.id
      finding_map_2.vulnerability_id = vulnerability_2.id
    end

    it 'updates only the vulnerabilities do not exist on default branch', :freeze_time do
      expect do
        set_present_on_default_branch

        vulnerability_1.reload
        vulnerability_2.reload
      end.to change { vulnerability_1.title }.to('changed')
         .and change { vulnerability_1.severity }.to('critical')
         .and change { vulnerability_1[:solution] }.to('solution')
         .and change { vulnerability_1.resolved_on_default_branch }.to(false)
         .and change { vulnerability_1.cvss }.to(cvss)
         .and change { vulnerability_1.updated_at }.to(Time.zone.now)
         .and change { vulnerability_1.finding_id }.to(new_finding_1.id)
         .and not_change { vulnerability_2.attributes }
    end

    it 'orders the update values by vulnerability_id to keep a consistent row lock order' do
      finding_map_1.vulnerability_id = 200
      finding_map_2.vulnerability_id = 100

      ordered_ids = service_object.send(:attributes).map { |attrs| attrs[:id] }

      expect(ordered_ids).to eq([100, 200])
    end
  end
end
