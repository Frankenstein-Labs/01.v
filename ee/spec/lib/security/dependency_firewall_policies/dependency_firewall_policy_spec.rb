# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DependencyFirewallPolicies::DependencyFirewallPolicy, feature_category: :dependency_firewall do
  let_it_be(:policy_content) do
    {
      name: 'Test Dependency Firewall Policy',
      enabled: true,
      enforcement_type: 'enforced',
      rules: [
        {
          type: 'license',
          denied: [{ name: 'NIST Software License' }, { name: 'NTP License' }],
          exceptions: [{ purl: 'pkg:npm/myinternallib' }]
        },
        {
          type: 'license',
          allowed: [{ name: 'MIT License' }, { name: 'Nokia Open Source License' }],
          exceptions: [{ purl: 'pkg:npm/myexternallib' }]
        }
      ],
      bypass_settings: { users: [{ id: 1222 }], access_tokens: [{ id: 222 }] }
    }
  end

  let_it_be(:policy_record) do
    policy = create(:security_policy, :dependency_firewall_policy,
      name: 'Test Dependency Firewall Policy',
      description: 'Test Description',
      enabled: true,
      content: policy_content)

    Array.wrap(policy_content&.deep_symbolize_keys&.dig(:rules)).each_with_index do |rule_hash, index|
      create(:dependency_firewall_policy_rule,
        security_policy: policy,
        rule_index: index,
        type: Security::DependencyFirewallPolicyRule.types[rule_hash[:type]],
        content: rule_hash.except(:type))
    end

    policy
  end

  describe 'initialization with policy record' do
    let(:dependency_firewall_policy) { described_class.new(policy_record) }

    describe '#rules' do
      subject(:rules) { dependency_firewall_policy.rules }

      it 'returns a Rules instance' do
        expect(rules).to be_a(Security::DependencyFirewallPolicies::Rules)
      end

      it 'contains Rule objects' do
        expect(rules.rules).to all(be_a(Security::DependencyFirewallPolicies::Rule))
        expect(rules.count).to eq(2)
      end

      it 'contains the correct rule data' do
        expect(rules[0].type).to eq('license')

        expect(rules[1].type).to eq('license')
      end
    end

    describe '#bypass_settings' do
      subject(:bypass_settings) { dependency_firewall_policy.bypass_settings }

      it 'returns a BypassSettings instance' do
        expect(bypass_settings).to be_a(Security::DependencyFirewallPolicies::BypassSettings)
      end

      it 'contains the correct user IDs' do
        expect(bypass_settings.user_ids).to eq([1222])
      end

      it 'contains the correct access token IDs' do
        expect(bypass_settings.access_token_ids).to eq([222])
      end
    end

    describe '#enforcement_type' do
      it 'returns the enforcement_type from policy content' do
        expect(dependency_firewall_policy.enforcement_type).to eq('enforced')
      end
    end

    describe 'inherited methods from BaseSecurityPolicy' do
      it 'delegates name to policy_record' do
        expect(dependency_firewall_policy.name).to eq('Test Dependency Firewall Policy')
      end

      it 'delegates description to policy_record' do
        expect(dependency_firewall_policy.description).to eq('Test Description')
      end

      it 'delegates enabled to policy_record' do
        expect(dependency_firewall_policy.enabled).to be true
      end
    end
  end
end
