# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Evidences::EvidenceEntity do
  # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Necessary to create build.job_artifacts
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let(:release) { create(:release, project: project) }
  let(:evidence) { create(:evidence, release: release) }
  let(:schema_file) { 'evidences/evidence' }

  it 'matches the schema when evidence has report artifacts' do
    stub_licensed_features(release_evidence_test_artifacts: true)

    pipeline = create(:ci_empty_pipeline, sha: release.sha, project: project)
    build = create(:ci_build, :test_reports, :with_archive_artifact, pipeline: pipeline)
    evidence_hash = described_class.represent(evidence, report_artifacts: [build]).as_json

    expect(evidence_hash[:release][:report_artifacts]).not_to be_empty
    expect(evidence_hash.to_json).to match_schema(schema_file)
  end
  # rubocop:enable RSpec/FactoryBot/AvoidCreate
end
