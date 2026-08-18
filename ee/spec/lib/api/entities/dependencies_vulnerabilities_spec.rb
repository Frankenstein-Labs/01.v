# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::DependenciesVulnerabilities, feature_category: :dependency_management do
  let(:options) { { occurrence_id: occurrence.id, project: project } }
  let(:finding) { create(:vulnerabilities_finding, :detected) }
  let(:vulnerability) { finding.vulnerability }
  let(:occurrence) { build(:sbom_occurrence, project: project) }
  let(:project) { build(:project) }

  let(:expected_result) do
    {
      occurrence_id: occurrence.id,
      id: vulnerability.id,
      name: finding.name,
      url: "#{project.web_url}/-/security/vulnerabilities/#{vulnerability.id}",
      severity: vulnerability.severity
    }
  end

  subject { described_class.new(vulnerability, options).as_json }

  it { is_expected.to match(expected_result) }
end
