# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Security::Parsers::Sarif::ReportTypeInference, feature_category: :vulnerability_management do
  describe '.infer' do
    it 'infers dependency_scanning from a CVE in ruleId' do
      expect(described_class.infer(result: { 'ruleId' => 'CVE-2021-44228' }, rule: {})).to eq(:dependency_scanning)
    end

    described_class::SECRET_CWES.each do |cwe|
      it "infers secret_detection for CWE-#{cwe}" do
        rule = { 'properties' => { 'tags' => ["CWE-#{cwe}"] } }
        expect(described_class.infer(result: {}, rule: rule)).to eq(:secret_detection)
      end
    end

    it 'infers sast for a non-secret CWE' do
      rule = { 'properties' => { 'tags' => ['CWE-89'] } }
      expect(described_class.infer(result: {}, rule: rule)).to eq(:sast)
    end

    it 'defaults to sast when no identifiers are present' do
      expect(described_class.infer(result: { 'ruleId' => 'R1' }, rule: {})).to eq(:sast)
    end
  end
end
