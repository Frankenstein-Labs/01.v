# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DependencyFirewall::Availability, feature_category: :dependency_firewall do
  let_it_be_with_reload(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be_with_reload(:project) { create(:project, group: subgroup) }

  describe '.feature_flag_enabled?' do
    context 'when the flag is disabled' do
      before do
        stub_feature_flags(dependency_firewall_phase1: false)
      end

      it 'is false for every container', :aggregate_failures do
        expect(described_class.feature_flag_enabled?(root_group)).to be(false)
        expect(described_class.feature_flag_enabled?(subgroup)).to be(false)
        expect(described_class.feature_flag_enabled?(project)).to be(false)
      end
    end

    context 'when the flag is enabled for the root group' do
      before do
        stub_feature_flags(dependency_firewall_phase1: root_group)
      end

      it 'covers the group, its subgroups and its projects', :aggregate_failures do
        expect(described_class.feature_flag_enabled?(root_group)).to be(true)
        expect(described_class.feature_flag_enabled?(subgroup)).to be(true)
        expect(described_class.feature_flag_enabled?(project)).to be(true)
      end
    end

    context 'when the flag is enabled for a subgroup instead of the top-level group' do
      before do
        stub_feature_flags(dependency_firewall_phase1: subgroup)
      end

      it 'is false, so only one enablement on the top-level group is needed', :aggregate_failures do
        expect(described_class.feature_flag_enabled?(subgroup)).to be(false)
        expect(described_class.feature_flag_enabled?(project)).to be(false)
      end
    end

    context 'when the flag is enabled for the project instead of the top-level group' do
      before do
        stub_feature_flags(dependency_firewall_phase1: project)
      end

      it 'is false, so only one enablement on the top-level group is needed' do
        expect(described_class.feature_flag_enabled?(project)).to be(false)
      end
    end

    context 'with a nil container' do
      it 'falls back to the global gate', :aggregate_failures do
        expect(described_class.feature_flag_enabled?(nil)).to be(true)

        stub_feature_flags(dependency_firewall_phase1: false)

        expect(described_class.feature_flag_enabled?(nil)).to be(false)
      end
    end
  end

  describe '.available?' do
    before do
      stub_feature_flags(dependency_firewall_phase1: root_group)
    end

    it 'is true when the flag and the license are both present' do
      stub_licensed_features(dependency_firewall: true)

      expect(described_class.available?(project)).to be(true)
    end

    it 'is false without the license' do
      stub_licensed_features(dependency_firewall: false)

      expect(described_class.available?(project)).to be(false)
    end

    it 'is false without the flag' do
      stub_feature_flags(dependency_firewall_phase1: false)
      stub_licensed_features(dependency_firewall: true)

      expect(described_class.available?(project)).to be(false)
    end

    it 'is false for a nil container, whatever the global flag state' do
      stub_licensed_features(dependency_firewall: true)

      expect(described_class.available?(nil)).to be(false)
    end
  end

  describe '.namespace_configurable?' do
    before do
      stub_feature_flags(dependency_firewall_phase1: root_group)
      stub_licensed_features(dependency_firewall: true)
      stub_saas_features(dependency_firewall: true)
    end

    it 'is true for a root group' do
      expect(described_class.namespace_configurable?(root_group)).to be(true)
    end

    it 'is false for a subgroup' do
      expect(described_class.namespace_configurable?(subgroup)).to be(false)
    end

    it 'is false when the SaaS feature is unavailable' do
      stub_saas_features(dependency_firewall: false)

      expect(described_class.namespace_configurable?(root_group)).to be(false)
    end

    it 'is false without the license' do
      stub_licensed_features(dependency_firewall: false)

      expect(described_class.namespace_configurable?(root_group)).to be(false)
    end

    it 'is false without the flag' do
      stub_feature_flags(dependency_firewall_phase1: false)

      expect(described_class.namespace_configurable?(root_group)).to be(false)
    end

    it 'is false for a nil group' do
      expect(described_class.namespace_configurable?(nil)).to be(false)
    end

    # The toggle would be impossible to switch on if its own surface depended on it.
    it 'does not depend on the namespace setting' do
      root_group.namespace_settings.update!(dependency_firewall_enabled: false)

      expect(described_class.namespace_configurable?(root_group)).to be(true)
    end
  end

  describe '.instance_configurable?' do
    before do
      stub_licensed_features(dependency_firewall: true)
      stub_saas_features(dependency_firewall: false)
    end

    it 'is true with the license and the flag' do
      expect(described_class.instance_configurable?).to be(true)
    end

    it 'is false on .com, which enables per namespace instead' do
      stub_saas_features(dependency_firewall: true)

      expect(described_class.instance_configurable?).to be(false)
    end

    it 'is false without the license' do
      stub_licensed_features(dependency_firewall: false)

      expect(described_class.instance_configurable?).to be(false)
    end

    it 'is false without the flag' do
      stub_feature_flags(dependency_firewall_phase1: false)

      expect(described_class.instance_configurable?).to be(false)
    end
  end

  describe '.enforced_for?' do
    before do
      stub_feature_flags(dependency_firewall_phase1: root_group)
      stub_licensed_features(dependency_firewall: true)
    end

    context 'on .com, reading the namespace toggle' do
      before do
        stub_saas_features(dependency_firewall: true)
        root_group.namespace_settings.update!(dependency_firewall_enabled: true)
      end

      it 'is true with the flag, the license and the setting' do
        expect(described_class.enforced_for?(project)).to be(true)
      end

      it 'is false when the root group setting is off' do
        root_group.namespace_settings.update!(dependency_firewall_enabled: false)

        expect(described_class.enforced_for?(project)).to be(false)
      end

      it 'ignores the instance toggle' do
        root_group.namespace_settings.update!(dependency_firewall_enabled: false)
        stub_ee_application_setting(dependency_firewall_enabled: true)

        expect(described_class.enforced_for?(project)).to be(false)
      end

      it 'is false without the license' do
        stub_licensed_features(dependency_firewall: false)

        expect(described_class.enforced_for?(project)).to be(false)
      end

      it 'is false without the flag' do
        stub_feature_flags(dependency_firewall_phase1: false)

        expect(described_class.enforced_for?(project)).to be(false)
      end
    end

    context 'on self-managed, reading the instance toggle' do
      before do
        stub_saas_features(dependency_firewall: false)
        stub_ee_application_setting(dependency_firewall_enabled: true)
      end

      it 'is true with the flag, the license and the setting' do
        expect(described_class.enforced_for?(project)).to be(true)
      end

      it 'is false when the instance setting is off' do
        stub_ee_application_setting(dependency_firewall_enabled: false)

        expect(described_class.enforced_for?(project)).to be(false)
      end

      it 'ignores a stray namespace toggle' do
        stub_ee_application_setting(dependency_firewall_enabled: false)
        root_group.namespace_settings.update!(dependency_firewall_enabled: true)

        expect(described_class.enforced_for?(project)).to be(false)
      end
    end

    context 'with a nil container' do
      it 'is false even when the flag is enabled globally' do
        expect(described_class.enforced_for?(nil)).to be(false)
      end
    end
  end
end
