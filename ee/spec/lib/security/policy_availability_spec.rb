# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PolicyAvailability, feature_category: :security_policy_management do
  let_it_be_with_reload(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:project) { create(:project, group: subgroup) }

  describe '.available?' do
    context 'with a policy type gated by the security_orchestration_policies license' do
      using RSpec::Parameterized::TableSyntax

      let(:policy_type) { :security_orchestration_policies }

      it 'is true when the feature is licensed' do
        stub_licensed_features(security_orchestration_policies: true)

        expect(described_class.available?(project, policy_type)).to be(true)
      end

      it 'is false when the feature is not licensed' do
        stub_licensed_features(security_orchestration_policies: false)

        expect(described_class.available?(project, policy_type)).to be(false)
      end

      it 'resolves the license against a group as well as a project' do
        stub_licensed_features(security_orchestration_policies: true)

        expect(described_class.available?(root_group, policy_type)).to be(true)
        expect(described_class.available?(subgroup, policy_type)).to be(true)
      end

      it 'is false when project is nil' do
        expect(described_class.available?(nil, policy_type)).to be(false)
      end
    end

    context 'with dependency_firewall_policy' do
      let(:policy_type) { :dependency_firewall }

      before do
        stub_saas_features(dependency_firewall: true)
        stub_licensed_features(dependency_firewall: true)
        root_group.namespace_settings.update!(dependency_firewall_enabled: true)
      end

      it 'is true with the flag, the license and the root namespace setting' do
        expect(described_class.available?(project, policy_type)).to be(true)
      end

      it 'is false when the root namespace setting is off' do
        root_group.namespace_settings.update!(dependency_firewall_enabled: false)

        expect(described_class.available?(project, policy_type)).to be(false)
      end

      it 'is false without the license' do
        stub_licensed_features(dependency_firewall: false)

        expect(described_class.available?(project, policy_type)).to be(false)
      end

      it 'is false without the feature flag' do
        stub_feature_flags(dependency_firewall_phase1: false)

        expect(described_class.available?(project, policy_type)).to be(false)
      end

      it 'is not gated by the security_orchestration_policies license' do
        stub_licensed_features(dependency_firewall: true, security_orchestration_policies: false)

        expect(described_class.available?(project, policy_type)).to be(true)
      end

      it 'delegates to the dependency firewall availability rules' do
        expect(::Security::DependencyFirewall::Availability).to receive(:enforced_for?).with(project).and_call_original

        described_class.available?(project, policy_type)
      end

      it 'is false when project is nil' do
        expect(described_class.available?(nil, policy_type)).to be(false)
      end
    end

    context 'with an unknown policy type' do
      before do
        stub_licensed_features(security_orchestration_policies: true, dependency_firewall: true)
      end

      it 'is false' do
        expect(described_class.available?(project, :unknown_policy)).to be(false)
      end

      it 'is false when project is nil' do
        expect(described_class.available?(nil, :unknown_policy)).to be(false)
      end
    end
  end

  describe '.any_available?' do
    it 'is true when the security orchestration policies license is present' do
      stub_licensed_features(security_orchestration_policies: true, dependency_firewall: false)

      expect(described_class.any_available?(project)).to be(true)
    end

    it 'is true when only the dependency firewall is enforced' do
      stub_saas_features(dependency_firewall: true)
      stub_licensed_features(security_orchestration_policies: false, dependency_firewall: true)
      root_group.namespace_settings.update!(dependency_firewall_enabled: true)

      expect(described_class.any_available?(project)).to be(true)
    end

    it 'is false when no policy type is available' do
      stub_licensed_features(security_orchestration_policies: false, dependency_firewall: false)

      expect(described_class.any_available?(project)).to be(false)
    end

    it 'is false when the dependency firewall is licensed but its setting is off' do
      stub_saas_features(dependency_firewall: true)
      stub_licensed_features(security_orchestration_policies: false, dependency_firewall: true)
      root_group.namespace_settings.update!(dependency_firewall_enabled: false)

      expect(described_class.any_available?(project)).to be(false)
    end

    it 'is false when subject is nil' do
      stub_licensed_features(security_orchestration_policies: true, dependency_firewall: true)

      expect(described_class.any_available?(nil)).to be(false)
    end
  end
end
