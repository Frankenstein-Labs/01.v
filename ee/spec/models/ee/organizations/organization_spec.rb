# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::Organization, feature_category: :organization do
  let_it_be_with_reload(:organization) { create(:organization) }
  let_it_be(:project) { create(:project, organization: organization) }

  describe 'associations' do
    it { is_expected.to have_many(:vulnerability_exports).class_name('Vulnerabilities::Export') }
    it { is_expected.to have_many(:sbom_sources).class_name('Sbom::Source') }
    it { is_expected.to have_many(:sbom_source_packages).class_name('Sbom::SourcePackage') }
    it { is_expected.to have_many(:sbom_components).class_name('Sbom::Component') }
    it { is_expected.to have_many(:sbom_component_versions).class_name('Sbom::ComponentVersion') }

    it 'has one artifact_registry_namespace_mapping' do
      is_expected.to have_one(:artifact_registry_namespace_mapping)
        .class_name('ArtifactRegistry::NamespaceMapping').inverse_of(:organization)
    end
  end

  describe '#policy_store_experiment_active?' do
    subject { organization.policy_store_experiment_active? }

    before do
      stub_licensed_features(security_orchestration_policies: true)
      stub_application_setting(policy_store_experiment_enabled: true)
    end

    it { is_expected.to be(true) }

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(security_policies_v2: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when the experiment is disabled for the instance' do
      before do
        stub_application_setting(policy_store_experiment_enabled: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when the license is not available' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it { is_expected.to be(false) }
    end
  end

  describe 'Foundational agents settings' do
    let_it_be_with_reload(:organization) { create(:organization) }

    it_behaves_like 'settings with foundational agents statuses' do
      let_it_be(:instance) { organization }
    end

    describe '.foundational_agents_default_enabled' do
      before do
        Ai::Setting.for_organization(organization).update!(foundational_agents_default_enabled: false)
      end

      it 'returns setting value' do
        expect(organization.foundational_agents_default_enabled).to be false
      end
    end
  end
end
