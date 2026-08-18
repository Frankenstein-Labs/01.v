# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::Eligibility, feature_category: :dependency_management do
  describe '.remediable?' do
    subject(:remediable) { described_class.remediable?(vulnerability) }

    let(:vulnerability) { instance_double(Vulnerability, solution: solution) }

    context 'when the solution is present and describes a fix' do
      let(:solution) { 'Upgrade rails to 6.1.7.10 or above.' }

      it { is_expected.to be(true) }
    end

    context 'when the solution is nil' do
      let(:solution) { nil }

      it { is_expected.to be(false) }
    end

    context 'when the solution is blank' do
      let(:solution) { '   ' }

      it { is_expected.to be(false) }
    end

    context 'when the solution is the templated "no solution" message' do
      let(:solution) { 'Unfortunately, there is no solution available yet.' }

      it { is_expected.to be(false) }
    end

    context 'when the "no solution" message has no comma' do
      let(:solution) { 'Unfortunately there is no solution available.' }

      it { is_expected.to be(false) }
    end
  end

  describe '.remediation_profile' do
    subject(:remediation_profile) { described_class.remediation_profile(project) }

    let_it_be(:project) { create(:project) }
    let(:profile) { instance_double(Security::ScanProfile) }

    context 'when the project is nil' do
      let(:project) { nil }

      it { is_expected.to be_nil }
    end

    context 'when the security_remediation_profiles flag is disabled' do
      before do
        stub_feature_flags(security_remediation_profiles: false)
      end

      it 'does not query the project and returns nil' do
        expect(project).not_to receive(:security_scan_profile_for)

        expect(remediation_profile).to be_nil
      end
    end

    context 'when the security_remediation_profiles flag is enabled' do
      before do
        stub_feature_flags(security_remediation_profiles: true)

        allow(project).to receive(:security_scan_profile_for)
          .with(:dependency_scanning_post_processing, :sbom_ingested)
          .and_return(profiles)
      end

      context 'when a matching profile exists' do
        let(:profiles) { [profile] }

        it { is_expected.to eq(profile) }
      end

      context 'when no matching profile exists' do
        let(:profiles) { [] }

        it { is_expected.to be_nil }
      end

      context 'when the lookup returns nil' do
        let(:profiles) { nil }

        it { is_expected.to be_nil }
      end
    end
  end

  describe '.remediation_configuration' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:profile) { create(:security_scan_profile, :dependency_scanning_post_processing, namespace: group) }
    let_it_be(:scan_profile_project) { create(:security_scan_profile_project, scan_profile: profile, project: project) }
    let_it_be(:trigger) do
      create(:security_scan_profile_trigger, :sbom_ingested, scan_profile: profile,
        configuration_values: { auto_remediation: { cooldown: 3 } })
    end

    subject(:remediation_configuration) { described_class.remediation_configuration(project) }

    before do
      stub_licensed_features(security_scan_profiles: true)
    end

    it 'returns the configuration resolved from the sbom-ingested trigger' do
      expect(remediation_configuration.dig(:auto_remediation, :cooldown)).to eq(3)
    end
  end
end
