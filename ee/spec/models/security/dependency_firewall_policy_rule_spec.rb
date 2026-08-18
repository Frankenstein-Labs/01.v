# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DependencyFirewallPolicyRule, feature_category: :security_policy_management do
  it_behaves_like 'policy rule' do
    let(:rule_hash) { build(:dependency_firewall_policy)[:rules].first }
    let(:policy_type) { :dependency_firewall_policy }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:security_policy).inverse_of(:dependency_firewall_policy_rules).required }
  end

  describe 'enum type' do
    it 'defines license, vulnerability, and malicious types' do
      expect(described_class.types).to eq('license' => 0, 'vulnerability' => 1, 'malicious' => 2)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:type) }
    it { is_expected.to validate_presence_of(:rule_index) }

    describe 'content' do
      subject(:rule) { build(:dependency_firewall_policy_rule, content: content) }

      context 'with denied licenses' do
        let(:content) { { denied: [{ name: 'MIT License' }] } }

        it { is_expected.to be_valid }
      end

      context 'with allowed licenses' do
        let(:content) { { allowed: [{ name: 'Apache-2.0' }] } }

        it { is_expected.to be_valid }
      end

      context 'with exceptions' do
        context 'with denied' do
          let(:content) do
            { denied: [{ name: 'MIT License' }], exceptions: [{ purl: 'pkg:npm/myinternallib' }] }
          end

          it { is_expected.to be_valid }
        end

        context 'with allowed' do
          let(:content) do
            { allowed: [{ name: 'MIT License' }], exceptions: [{ purl: 'pkg:npm/myinternallib' }] }
          end

          it { is_expected.to be_valid }
        end
      end

      context 'with both denied and allowed (mutually exclusive)' do
        let(:content) do
          { denied: [{ name: 'MIT License' }], allowed: [{ name: 'Apache License 2.0' }] }
        end

        it { is_expected.to be_invalid }
      end

      context 'with neither denied nor allowed' do
        let(:content) { {} }

        it { is_expected.to be_invalid }
      end

      context 'with empty denied list' do
        let(:content) { { denied: [] } }

        it { is_expected.to be_invalid }
      end

      context 'with denied license missing name' do
        let(:content) { { denied: [{}] } }

        it { is_expected.to be_invalid }
      end

      context 'with exception missing pkg: prefix' do
        let(:content) do
          { denied: [{ name: 'MIT License' }], exceptions: [{ purl: 'npm/myinternallib' }] }
        end

        it { is_expected.to be_invalid }
      end

      context 'with additional unknown property' do
        let(:content) { { denied: [{ name: 'MIT License' }], unknown: 'value' } }

        it { is_expected.to be_invalid }
      end
    end

    describe 'vulnerability rule content' do
      subject(:rule) do
        build(:dependency_firewall_policy_rule,
          type: described_class.types[:vulnerability],
          content: content)
      end

      context 'with denied severity' do
        let(:content) { { denied: [{ severity: 'high' }] } }

        it { is_expected.to be_valid }
      end

      context 'with allowed severity' do
        let(:content) { { allowed: [{ severity: 'low' }] } }

        it { is_expected.to be_valid }
      end

      context 'with exceptions by vulnerability id' do
        let(:content) do
          { denied: [{ severity: 'high' }], exceptions: [{ id: 'CVE-2024-1234' }] }
        end

        it { is_expected.to be_valid }
      end

      context 'with exceptions by PURL' do
        let(:content) do
          { denied: [{ severity: 'high' }], exceptions: [{ purl: 'pkg:npm/myinternallib' }] }
        end

        it { is_expected.to be_valid }
      end

      context 'with severity not in the allowed enum' do
        let(:content) { { denied: [{ severity: 'galactic' }] } }

        it { is_expected.to be_invalid }
      end

      context 'with more than one denied severity entry' do
        let(:content) { { denied: [{ severity: 'high' }, { severity: 'medium' }] } }

        it { is_expected.to be_invalid }
      end

      context 'with both denied and allowed (mutually exclusive)' do
        let(:content) do
          { denied: [{ severity: 'high' }], allowed: [{ severity: 'low' }] }
        end

        it { is_expected.to be_invalid }
      end

      context 'with neither denied nor allowed' do
        let(:content) { {} }

        it { is_expected.to be_invalid }
      end

      context 'with denied item shaped as license (missing severity)' do
        let(:content) { { denied: [{ name: 'MIT License' }] } }

        it { is_expected.to be_invalid }
      end
    end

    describe 'malicious rule content' do
      subject(:rule) do
        build(:dependency_firewall_policy_rule,
          type: described_class.types[:malicious],
          content: content)
      end

      context 'with denied is_malicious flag' do
        let(:content) { { denied: [{ is_malicious: true }] } }

        it { is_expected.to be_valid }
      end

      context 'with allowed (not permitted for malicious rules)' do
        let(:content) { { allowed: [{ is_malicious: true }] } }

        it { is_expected.to be_invalid }
      end

      context 'with is_malicious set to false' do
        let(:content) { { denied: [{ is_malicious: false }] } }

        it { is_expected.to be_invalid }
      end

      context 'with denied item shaped as license (missing is_malicious)' do
        let(:content) { { denied: [{ name: 'MIT License' }] } }

        it { is_expected.to be_invalid }
      end

      context 'with neither denied nor allowed' do
        let(:content) { {} }

        it { is_expected.to be_invalid }
      end
    end
  end
end
