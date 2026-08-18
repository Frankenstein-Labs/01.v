# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Sbom::DependencyAggregationType, feature_category: :dependency_management do
  include GraphqlHelpers

  let(:fields) do
    %i[
      id
      name
      version
      componentVersion
      packager
      location
      licenses
      reachability
      malware
      vulnerability_count
      vulnerabilities
      dependencyPaths
      occurrence_count
      project_count
    ]
  end

  it 'implements the DependencyInterface interface' do
    expect(described_class.interfaces).to include(Types::Sbom::DependencyInterface)
  end

  it { expect(described_class.graphql_name).to eq('DependencyAggregation') }

  it { expect(described_class).to have_graphql_fields(fields) }

  describe '#occurrence_count' do
    subject(:resolved_count) { resolve_field(:occurrence_count, object) }

    context 'when the object exposes an aggregated occurrence_count' do
      let(:object) { build(:sbom_occurrence).tap { |o| allow(o).to receive(:occurrence_count).and_return(7) } }

      it 'returns the aggregated count' do
        expect(resolved_count).to eq(7)
      end
    end

    context 'when the object does not expose an occurrence_count' do
      let(:object) { build(:sbom_occurrence) }

      it 'falls back to 1' do
        expect(resolved_count).to eq(1)
      end
    end
  end

  describe '#project_count' do
    subject(:resolved_count) { resolve_field(:project_count, object) }

    context 'when the object exposes an aggregated project_count' do
      let(:object) { build(:sbom_occurrence).tap { |o| allow(o).to receive(:project_count).and_return(3) } }

      it 'returns the aggregated count' do
        expect(resolved_count).to eq(3)
      end
    end

    context 'when the object does not expose a project_count' do
      let(:object) { build(:sbom_occurrence) }

      it 'falls back to 1' do
        expect(resolved_count).to eq(1)
      end
    end
  end

  describe '#vulnerability_count' do
    subject(:resolved_count) { resolve_field(:vulnerability_count, object) }

    context 'when the object exposes an aggregated vulnerability_count' do
      let(:object) { build(:sbom_occurrence).tap { |o| allow(o).to receive(:vulnerability_count).and_return(5) } }

      it 'returns the aggregated count' do
        expect(resolved_count).to eq(5)
      end
    end

    context 'when the object is a plain occurrence (project_ids filter path)' do
      let(:object) { build(:sbom_occurrence, vulnerability_count: 2) }

      it 'returns the value from the occurrence column' do
        expect(resolved_count).to eq(2)
      end

      it 'does not compute the count from the vulnerabilities association' do
        expect(object).not_to receive(:vulnerabilities)

        resolved_count
      end
    end
  end

  describe '#licenses' do
    let_it_be(:group) { create(:group) }

    let(:license_data) { [{ 'spdx_identifier' => 'MIT', 'name' => 'MIT' }] }
    let(:object) do
      instance_double(
        ::Sbom::Occurrence,
        licenses: license_data,
        purl_type: 'gem',
        component_name: 'rails',
        version: '7.0'
      )
    end

    let(:context) { { group: group } }
    let(:type_instance) do
      instance = described_class.allocate
      instance.instance_variable_set(:@object, object)
      instance.instance_variable_set(:@context, context)
      instance
    end

    context 'when experiment is not enabled for the group' do
      before do
        allow(Security::LicenseOverrideApplicator).to receive(:experiment_enabled_for_group?)
          .with(group).and_return(false)
      end

      it 'returns original licenses' do
        expect(type_instance.licenses).to eq(license_data)
      end
    end

    context 'when no group is in context' do
      let(:context) { {} }

      it 'returns original licenses' do
        expect(type_instance.licenses).to eq(license_data)
      end
    end

    context 'when experiment is enabled and overrides are present' do
      let(:overridden) { [{ 'spdx_identifier' => 'Apache-2.0', 'name' => 'Apache-2.0' }] }
      let(:applicator) { instance_double(Security::LicenseOverrideApplicator, overrides?: true) }

      before do
        allow(Security::LicenseOverrideApplicator).to receive(:experiment_enabled_for_group?)
          .with(group).and_return(true)
        allow(Security::LicenseOverrideApplicator).to receive(:new_for_group).with(group).and_return(applicator)
        allow(applicator).to receive(:apply).and_return(overridden)
      end

      it 'applies group license overrides' do
        expect(type_instance.licenses).to eq(overridden)
      end
    end

    context 'when experiment is enabled but applicator has no overrides' do
      let(:applicator) { instance_double(Security::LicenseOverrideApplicator, overrides?: false) }

      before do
        allow(Security::LicenseOverrideApplicator).to receive(:experiment_enabled_for_group?)
          .with(group).and_return(true)
        allow(Security::LicenseOverrideApplicator).to receive(:new_for_group).with(group).and_return(applicator)
      end

      it 'returns the input licenses unchanged' do
        expect(type_instance.licenses).to eq(license_data)
      end
    end

    context 'when occurrence has no purl_type' do
      let(:applicator) { instance_double(Security::LicenseOverrideApplicator, overrides?: true) }
      let(:object) do
        instance_double(
          ::Sbom::Occurrence,
          licenses: license_data,
          purl_type: nil,
          component_name: 'rails',
          version: '7.0'
        )
      end

      before do
        allow(Security::LicenseOverrideApplicator).to receive(:experiment_enabled_for_group?)
          .with(group).and_return(true)
        allow(Security::LicenseOverrideApplicator).to receive(:new_for_group).with(group).and_return(applicator)
      end

      it 'returns the input licenses unchanged' do
        expect(type_instance.licenses).to eq(license_data)
      end
    end

    context 'when occurrence has no version' do
      let(:overridden) { [{ 'spdx_identifier' => 'Apache-2.0', 'name' => 'Apache-2.0' }] }
      let(:applicator) { instance_double(Security::LicenseOverrideApplicator, overrides?: true) }
      let(:object) do
        instance_double(
          ::Sbom::Occurrence,
          licenses: license_data,
          purl_type: 'gem',
          component_name: 'rails',
          version: nil
        )
      end

      before do
        allow(Security::LicenseOverrideApplicator).to receive(:experiment_enabled_for_group?)
          .with(group).and_return(true)
        allow(Security::LicenseOverrideApplicator).to receive(:new_for_group).with(group).and_return(applicator)
        allow(applicator).to receive(:apply).with(license_data, purl: 'pkg:gem/rails').and_return(overridden)
      end

      it 'builds a versionless purl and applies overrides' do
        expect(type_instance.licenses).to eq(overridden)
      end
    end

    context 'when object has no licenses' do
      let(:object) { instance_double(::Sbom::Occurrence, licenses: nil) }

      it 'returns an empty array' do
        expect(type_instance.licenses).to eq([])
      end
    end
  end
end
