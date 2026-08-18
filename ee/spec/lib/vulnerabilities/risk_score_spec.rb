# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::RiskScore, feature_category: :vulnerability_management do
  describe "#from_finding" do
    let_it_be(:identifier) do
      create(:vulnerabilities_identifier, external_type: 'cve', external_id: 'CVE-2023-12345', name: 'CVE-2023-12345')
    end

    let(:finding) { create(:vulnerabilities_finding, identifiers: [identifier], severity: :critical) }

    let_it_be(:cve_enrichment) do
      create(:pm_cve_enrichment, cve: identifier.name, epss_score: 0.9, is_known_exploit: true)
    end

    it "initializes the required params" do
      risk_score_instance = described_class.from_finding(finding)

      expect(risk_score_instance.severity).to eq('critical')
      expect(risk_score_instance.epss_score).to eq(0.9)
      expect(risk_score_instance.is_known_exploit).to be(true)
    end
  end

  describe "#score" do
    subject(:risk_score) do
      described_class.new(
        severity: severity,
        epss_score: epss_score,
        is_known_exploit: is_known_exploit
      ).score
    end

    let_it_be(:severity) { 'critical' }
    let_it_be(:epss_score) { 0 }
    let_it_be(:is_known_exploit) { false }

    context "with just the base score without epss and kev values" do
      using RSpec::Parameterized::TableSyntax

      where(:severity, :expected_risk_score) do
        'critical' | 0.6
        'high' | 0.4
        'medium' | 0.2
        'unknown' | 0.2
        'low' | 0.05
        'info' | 0
      end

      with_them do
        it { is_expected.to eq(expected_risk_score) }
      end
    end

    context "with cve_enrichment" do
      context "with epss score" do
        context "when its greater than or equal to 0.5" do
          let_it_be(:epss_score) { 0.6 }

          it "adds appropriate epss_modifier" do
            expected_score = 0.6 + 0.38 # base_score + epss_modifier
            expect(risk_score).to eq expected_score
          end
        end

        context "when its greater than or equal to 0.01 and less than 0.5" do
          let_it_be(:epss_score) { 0.4 }

          it "adds appropriate epss_modifier" do
            expected_score = 0.6 + 0.22 # base_score + epss_modifier
            expect(risk_score).to eq expected_score
          end
        end

        context "when its less than 0.1" do
          let_it_be(:epss_score) { 0.09 }

          it "adds appropriate epss_modifier" do
            expected_score = 0.6 + 0.027 # base_score + epss_modifier
            expect(risk_score).to eq expected_score
          end
        end
      end

      context "with a known exploit" do
        let_it_be(:is_known_exploit) { true }

        it "adds appropriate kev_modifier" do
          expected_score = 0.6 + 0.3 # base_score + kev_modifier
          expect(risk_score).to eq expected_score
        end
      end

      context "when all the modifiers are added" do
        let_it_be(:epss_score) { 0.9 }
        let_it_be(:is_known_exploit) { true }

        it "does not exceed a maximum value of 1" do
          expect(risk_score).to eq 1.0
        end
      end
    end
  end
end
