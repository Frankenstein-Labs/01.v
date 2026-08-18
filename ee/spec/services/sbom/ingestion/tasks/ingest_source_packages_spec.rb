# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::Tasks::IngestSourcePackages, feature_category: :dependency_management do
  describe '#execute' do
    let!(:organization) { create(:organization) }

    let_it_be(:pipeline) { create(:ci_pipeline) }
    let_it_be(:occurrence_maps, freeze: false) { build_list(:sbom_occurrence_map, 2, :with_source_package) }

    subject(:ingest_source_package) { described_class.new(pipeline, occurrence_maps) }

    it_behaves_like 'bulk insertable task'

    it 'creates source packages' do
      expect { ingest_source_package.execute }.to change { Sbom::SourcePackage.count }.by(2)
      expect(occurrence_maps).to all(have_attributes(source_package_id: Integer))
    end

    context 'when there is existing source package' do
      before do
        map = occurrence_maps.first.to_h
        create(:sbom_source_package,
          name: map[:source_package_name],
          purl_type: map[:purl_type],
          organization_id: pipeline.project.namespace.organization_id)
      end

      it 'does not create a new record for the existing source package' do
        expect { ingest_source_package.execute }.to change { Sbom::SourcePackage.count }.by(1)
        expect(occurrence_maps).to all(have_attributes(source_package_id: Integer))
      end
    end

    context 'with same source package for multiple occurrences' do
      let_it_be(:source_package) { build(:sbom_source_package) }

      let_it_be(:sbom_components) do
        [
          build(:ci_reports_sbom_component, purl_type: source_package.purl_type,
            source_package_name: source_package.name),
          build(:ci_reports_sbom_component, purl_type: source_package.purl_type,
            source_package_name: source_package.name),
          build(:ci_reports_sbom_component, purl_type: source_package.purl_type,
            source_package_name: "other_source_package"),
          build(:ci_reports_sbom_component, purl_type: 'wolfi', source_package_name: source_package.name)
        ]
      end

      let_it_be(:occurrence_maps, freeze: false) do
        sbom_components.map do |component|
          build(:sbom_occurrence_map, report_component: component)
        end
      end

      it 'maps source package id with correct occurrence_maps' do
        expect { ingest_source_package.execute }.to change { Sbom::SourcePackage.count }.by(3)
        expect(occurrence_maps).to all(have_attributes(source_package_id: Integer))
      end
    end

    describe 'attributes' do
      let(:ingested_source_package) { Sbom::SourcePackage.last }

      it 'sets the correct attributes for the source package' do
        ingest_source_package.execute

        expect(ingested_source_package.attributes).to include(
          'name' => occurrence_maps.last.source_package_name,
          'purl_type' => occurrence_maps.last.purl_type,
          'organization_id' => pipeline.project.namespace.organization_id
        )
      end
    end
  end
end
