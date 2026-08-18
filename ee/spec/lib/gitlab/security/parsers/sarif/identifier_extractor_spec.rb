# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Security::Parsers::Sarif::IdentifierExtractor, feature_category: :vulnerability_management do
  describe '.semantic_identifiers' do
    it 'extracts CVE from ruleId' do
      ids = described_class.semantic_identifiers(result: { 'ruleId' => 'CVE-2021-44228' }, rule: {})
      expect(ids).to contain_exactly(hash_including(type: :cve, value: 'CVE-2021-44228'))
    end

    it 'extracts CWE from rule property tags' do
      rule = { 'properties' => { 'tags' => ['security', 'CWE-798: Hardcoded Credentials'] } }
      ids = described_class.semantic_identifiers(result: {}, rule: rule)
      expect(ids).to include(hash_including(type: :cwe, value: 'CWE-798', number: '798'))
    end

    it 'handles lowercase cwe tags' do
      ids = described_class.semantic_identifiers(result: {}, rule: { 'properties' => { 'tags' => ['cwe-89'] } })
      expect(ids).to include(hash_including(type: :cwe, value: 'CWE-89', number: '89'))
    end

    it 'extracts CVE from a descriptive tag without trailing punctuation in external_id' do
      rule = { 'properties' => { 'tags' => ['CVE-2021-44228: Log4Shell'] } }
      ids = described_class.semantic_identifiers(result: {}, rule: rule)
      expect(ids).to include(hash_including(type: :cve, value: 'CVE-2021-44228', external_id: '2021-44228'))
    end

    it 'rejects malformed CVE tags' do
      rule = { 'properties' => { 'tags' => ['cve-CVE123'] } }
      expect(described_class.semantic_identifiers(result: {}, rule: rule)).to be_empty
    end

    it 'extracts CWE from rule relationships' do
      rule = { 'relationships' => [{ 'target' => { 'id' => 'CWE-119', 'toolComponent' => { 'name' => 'CWE' } } }] }
      ids = described_class.semantic_identifiers(result: {}, rule: rule)
      expect(ids).to include(hash_including(type: :cwe, value: 'CWE-119', number: '119'))
    end

    it 'extracts CWE from rule relationships when target id is a number' do
      rule = { 'relationships' => [{ 'target' => { 'id' => '79', 'toolComponent' => { 'name' => 'CWE' } } }] }
      ids = described_class.semantic_identifiers(result: {}, rule: rule)
      expect(ids).to include(hash_including(type: :cwe, value: 'CWE-79', number: '79', external_id: '79'))
    end

    it 'ignores non-CWE toolComponent relationships' do
      rule = { 'relationships' => [{ 'target' => { 'id' => 'X-1', 'toolComponent' => { 'name' => 'OWASP' } } }] }
      expect(described_class.semantic_identifiers(result: {}, rule: rule)).to be_empty
    end

    it 'deduplicates identical identifiers across patterns' do
      result = { 'ruleId' => 'CVE-2021-44228' }
      rule = { 'properties' => { 'tags' => ['CVE-2021-44228'] } }
      ids = described_class.semantic_identifiers(result: result, rule: rule)
      expect(ids.count).to eq(1)
    end

    it 'deduplicates identifiers across sources even when raw values differ' do
      result = { 'ruleId' => 'CVE-2021-44228' }
      rule = { 'properties' => { 'tags' => ['CVE-2021-44228: Log4Shell'] } }
      ids = described_class.semantic_identifiers(result: result, rule: rule)
      expect(ids.count).to eq(1)
    end

    it 'returns empty when ruleId is not a CVE/CWE and no tags or relationships match' do
      ids = described_class.semantic_identifiers(result: { 'ruleId' => 'B001' }, rule: {})
      expect(ids).to be_empty
    end

    it 'falls back to result.rule.id when result.ruleId is absent' do
      ids = described_class.semantic_identifiers(result: { 'rule' => { 'id' => 'CVE-2024-9999' } }, rule: {})
      expect(ids).to include(hash_including(type: :cve, value: 'CVE-2024-9999'))
    end
  end
end
