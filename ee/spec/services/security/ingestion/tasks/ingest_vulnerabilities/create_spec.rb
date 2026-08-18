# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Tasks::IngestVulnerabilities::Create, feature_category: :vulnerability_management do
  def create_finding_map
    user = create(:user)
    pipeline = create(:ci_pipeline, user: user)
    report_finding = create(:ci_reports_security_finding, solution: 'solution')
    create(:finding_map, :with_finding, report_finding: report_finding, pipeline: pipeline)
  end

  # `freeze: false` is required in this spec: one or more `let_it_be` subjects
  # cannot be frozen by default (deep_freeze traversal failure, a non-AR
  # subject, or an in-memory mutation that survives reload/refind). Do not
  # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
  # (see gitlab-org/gitlab#602925).
  let_it_be(:finding_maps, freeze: false) { [create_finding_map] }

  let(:vulnerability) { Vulnerability.last }

  subject { described_class.new(nil, finding_maps).execute }

  context 'with multiple pipelines' do
    let_it_be(:finding_maps, freeze: false) { Array.new(2).map { create_finding_map } }

    it 'uses user_id and project from pipeline' do
      subject

      created_vulnerabilities = Vulnerability.id_in(finding_maps.map(&:vulnerability_id))

      expect(created_vulnerabilities.size).to eq(2)
      expect(created_vulnerabilities.map(&:author_id)).to match_array(
        finding_maps.map { |finding_map| finding_map.pipeline.user_id })
      expect(created_vulnerabilities.map(&:project)).to match_array(finding_maps.map(&:project))
    end
  end

  it 'sets the expected fields', :aggregate_failures do
    subject

    expect(vulnerability.detected_at).not_to be_nil
    expect(vulnerability.cvss).to eq([{
      "vector" => "CVSS:3.1/AV:N/AC:L/PR:H/UI:N/S:U/C:L/I:L/A:N", "vendor" => "GitLab"
    }])
    expect(vulnerability.state).to eq('detected')
    expect(vulnerability[:solution]).to eq('solution')
  end
end
