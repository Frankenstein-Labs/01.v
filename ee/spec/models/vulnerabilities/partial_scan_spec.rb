# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::PartialScan, feature_category: :vulnerability_management do
  describe 'validations' do
    subject(:partial_scan) { build(:vulnerabilities_partial_scan) }

    it { is_expected.to validate_presence_of(:scan) }
    it { is_expected.to validate_presence_of(:mode) }
  end

  describe 'creation' do
    let_it_be(:scan) { create(:security_scan) }

    it 'sets attributes from scan' do
      partial_scan = described_class.create!(mode: :differential, scan: scan)

      expect(partial_scan.project).to eq(scan.project)
      expect(partial_scan.pipeline).to eq(scan.pipeline)
      expect(partial_scan.scan_type).to eq(scan.scan_type)
    end
  end

  describe '.by_pipeline_ids' do
    let_it_be(:pipeline_1) { create(:ee_ci_pipeline, :success) }
    let_it_be(:pipeline_2) { create(:ee_ci_pipeline, :success) }
    let_it_be(:scan_1) { create(:vulnerabilities_partial_scan, pipeline: pipeline_1) }
    let_it_be(:scan_2) { create(:vulnerabilities_partial_scan, pipeline: pipeline_2) }
    let_it_be(:unrelated_scan) { create(:vulnerabilities_partial_scan) }

    subject { described_class.by_pipeline_ids([pipeline_1.id, pipeline_2.id]) }

    it { is_expected.to contain_exactly(scan_1, scan_2) }
  end

  describe '.distinct_scan_types' do
    let_it_be(:sast_scan) { create(:vulnerabilities_partial_scan, scan_type: :sast) }
    let_it_be(:sast_scan2) { create(:vulnerabilities_partial_scan, scan_type: :sast) }
    let_it_be(:dast_scan) { create(:vulnerabilities_partial_scan, scan_type: :dast) }

    subject { described_class.distinct_scan_types }

    it { is_expected.to match_array(%w[sast dast]) }
  end

  describe '#pipeline' do
    it_behaves_like 'a partition-pruned pipeline association' do
      let(:related_resource) { create(:vulnerabilities_partial_scan, pipeline_id: pipeline.id) }
    end
  end
end
