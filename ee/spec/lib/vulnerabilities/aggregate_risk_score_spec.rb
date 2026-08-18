# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::AggregateRiskScore, feature_category: :vulnerability_management do
  describe ".score" do
    subject(:score) do
      described_class.score(
        risk_scores_sum: risk_scores_sum,
        created_at_sum: created_at_sum,
        active_vulnerabilities_count: active_vulnerabilities_count
      )
    end

    let(:risk_scores_sum) { 1.5 }
    let(:active_vulnerabilities_count) { 4 }
    let(:created_at_sum) { active_vulnerabilities_count * 30.days.ago.to_f * 1000 }

    context "when there are no active vulnerabilities" do
      let(:active_vulnerabilities_count) { 0 }

      it "returns 0.0" do
        expect(score).to eq(0.0)
      end
    end

    context "when there are active vulnerabilities" do
      it "calculates the aggregate risk score with age factor" do
        expect(score).to be > 0.0
        expect(score).to be <= 1.0

        expect(score).to be_within(0.005).of(0.304)
      end
    end

    context "with very high risk scores" do
      let(:risk_scores_sum) { 10.0 }

      it "caps the result at 1.0" do
        expect(score).to eq(1.0)
      end
    end
  end
end
