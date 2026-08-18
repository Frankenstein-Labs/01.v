# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Configuration::SetLicenseConfigurationSourceService, feature_category: :dependency_management do
  describe '#execute' do
    let_it_be_with_reload(:security_setting) do
      create(:project_security_setting, license_configuration_source: :sbom)
    end

    let_it_be(:project) { security_setting.project }

    it 'returns attribute value' do
      expect(described_class.execute(project: project,
        source: 'sbom').payload).to include(license_configuration_source: 'sbom')
      expect(described_class.execute(project: project,
        source: 'pmdb').payload).to include(license_configuration_source: 'pmdb')
    end

    it 'changes the attribute' do
      expect { described_class.execute(project: project, source: 'sbom') }
        .not_to change { security_setting.reload.sbom_license_configuration_source? }
      expect { described_class.execute(project: project, source: 'pmdb') }
        .to change { security_setting.reload.sbom_license_configuration_source? }
        .from(true).to(false)
    end

    context 'with invalid source type' do
      it 'returns the error message' do
        expect(described_class.execute(project: project,
          source: 'invalid').message).to eq("'invalid' is not a valid license_configuration_source")
      end
    end

    context 'when security setting is not present' do
      let_it_be_with_reload(:project_without_security_setting) { create(:project) }

      before do
        project_without_security_setting.security_setting.delete
      end

      it 'returns the error message' do
        expect(described_class.execute(project: project_without_security_setting.reload,
          source: 'sbom').message).to eq("Security setting does not exist for this project.")
      end
    end
  end
end
