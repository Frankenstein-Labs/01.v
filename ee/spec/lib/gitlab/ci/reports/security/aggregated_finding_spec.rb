# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Reports::Security::AggregatedFinding, feature_category: :vulnerability_management do
  subject(:aggregated_finding) { described_class.new(pipeline, findings) }

  let(:pipeline) { build(:ci_pipeline) }
  let(:findings) { build_list(:security_finding, 1) }

  describe '#created_at' do
    it "returns the pipeline's created_at" do
      expect(aggregated_finding.created_at).to eq(pipeline.created_at)
    end

    context 'when pipeline is nil' do
      let(:pipeline) { nil }

      it 'returns nil' do
        expect(aggregated_finding.created_at).to be_nil
      end
    end
  end
end
