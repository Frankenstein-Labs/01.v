# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::ScanProfiles::ConfigurationType, feature_category: :security_testing_configuration do
  it { expect(described_class.graphql_name).to eq('ScanProfileConfiguration') }

  it 'is a union of the per-scan-type configuration types' do
    expect(described_class.possible_types).to contain_exactly(
      Types::Security::ScanProfiles::AutoRemediationConfigurationType,
      Types::Security::ScanProfiles::SecretDetectionConfigurationType
    )
  end

  describe '.resolve_type' do
    let_it_be(:group) { create(:group) }

    context 'for a dependency scanning post-processing trigger' do
      let_it_be(:profile) do
        create(:security_scan_profile, :dependency_scanning_post_processing, namespace: group)
      end

      let_it_be(:trigger) do
        create(:security_scan_profile_trigger, scan_profile: profile, trigger_type: :sbom_ingested,
          configuration_values: { 'auto_remediation' => { 'severity_level' => 'critical' } })
      end

      it 'resolves to the auto-remediation type with the effective auto-remediation config' do
        type, value = described_class.resolve_type(trigger, {})

        expect(type).to eq(Types::Security::ScanProfiles::AutoRemediationConfigurationType)
        expect(value).to include(severity_level: 'critical', cooldown: 7, upgrade_policy: 'minor')
      end

      it 'applies project-specific overrides when a project is supplied via scoped context' do
        project = instance_double(Project, duo_dependency_bump_breaking_changes_available?: true)

        _type, value = described_class.resolve_type(trigger, { scan_profile_project: project })

        expect(value).to include(upgrade_policy: 'major')
      end
    end

    context 'for a secret detection trigger' do
      let_it_be(:profile) do
        create(:security_scan_profile, namespace: group, scan_type: :secret_detection)
      end

      let_it_be(:trigger) do
        create(:security_scan_profile_trigger, scan_profile: profile, trigger_type: :default_branch_pipeline,
          configuration_values: { 'historic_scan' => true })
      end

      it 'resolves to the secret detection type with the effective config' do
        type, value = described_class.resolve_type(trigger, {})

        expect(type).to eq(Types::Security::ScanProfiles::SecretDetectionConfigurationType)
        expect(value).to include(historic_scan: true)
      end
    end

    context 'for a scan type without a typed configuration' do
      let_it_be(:profile) { create(:security_scan_profile, namespace: group, scan_type: :sast) }

      let_it_be(:trigger) do
        create(:security_scan_profile_trigger, scan_profile: profile, trigger_type: :default_branch_pipeline)
      end

      it 'resolves to nil' do
        expect(described_class.resolve_type(trigger, {})).to be_nil
      end
    end
  end
end
