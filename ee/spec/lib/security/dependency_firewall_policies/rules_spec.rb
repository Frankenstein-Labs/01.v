# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Security::DependencyFirewallPolicies::Rules, feature_category: :dependency_firewall do
  let(:rules_data) do
    [
      { type: "license", denied: [{ name: 'MIT' }], allowed: [], exceptions: [] },
      { type: "license", denied: [], allowed: [{ name: 'Apache-2.0' }], exceptions: [] }
    ]
  end

  let(:rules) { described_class.new(rules_data) }

  describe '#initialize' do
    it 'wraps each rule hash in a Rule object' do
      expect(rules.rules).to all(be_a(Security::DependencyFirewallPolicies::Rule))
      expect(rules.rules.size).to eq(2)
    end

    context 'when rules is nil' do
      let(:rules) { described_class.new(nil) }

      it 'initializes with empty array' do
        expect(rules.rules).to eq([])
      end
    end

    context 'when rules is empty array' do
      let(:rules) { described_class.new([]) }

      it 'initializes with empty array' do
        expect(rules.rules).to eq([])
      end
    end
  end

  describe 'enumerable methods' do
    it 'responds to each' do
      expect(rules).to respond_to(:each)
    end

    it 'responds to []' do
      expect(rules).to respond_to(:[])
    end

    it 'responds to map' do
      expect(rules).to respond_to(:map)
    end

    it 'iterates over Rule objects' do
      types = rules.map(&:type)
      expect(types).to eq(%w[license license])
    end

    it 'allows array access to Rule objects' do
      expect(rules[0]).to be_a(Security::DependencyFirewallPolicies::Rule)
      expect(rules[0].type).to eq("license")
      expect(rules[1].type).to eq("license")
    end
  end
end
