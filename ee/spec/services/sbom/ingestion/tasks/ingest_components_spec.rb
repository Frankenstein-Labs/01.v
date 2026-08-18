# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::Tasks::IngestComponents, feature_category: :dependency_management do
  describe '#execute' do
    let!(:organization) { create(:organization) }

    let_it_be(:pipeline) { create(:ci_pipeline) }

    let(:occurrence_maps) { create_list(:sbom_occurrence_map, 4) }
    let(:occurrence_map) { create(:sbom_occurrence_map) }
    let!(:existing_component) { create(:sbom_component, **occurrence_map.to_h.slice(:component_type, :name)) }

    subject(:ingest_components) { described_class.execute(pipeline, occurrence_maps) }

    it_behaves_like 'bulk insertable task'

    it 'is idempotent' do
      expect { ingest_components }.to change { Sbom::Component.count }.by(4)
      expect { ingest_components }.not_to change { Sbom::Component.count }
    end

    it 'sets the component_id' do
      expected_component_ids = Array.new(4) { an_instance_of(Integer) }

      expect { ingest_components }.to change { occurrence_maps.map(&:component_id) }
        .from(Array.new(4)).to(expected_component_ids)
    end

    it 'does not update existing component' do
      expect { ingest_components }.not_to change { existing_component.reload.updated_at }
    end

    context 'when there are duplicate components' do
      let(:components) do
        [
          create(
            :ci_reports_sbom_component,
            name: "golang.org/x/sys",
            version: "v0.0.0-20190422165155-953cdadca894",
            purl_type: "golang"
          ),
          create(
            :ci_reports_sbom_component,
            name: "golang.org/x/sys",
            version: "v0.0.0-20191026070338-33540a1f6037",
            purl_type: "golang"
          )
        ]
      end

      let(:occurrence_maps) { components.map { |component| create(:sbom_occurrence_map, report_component: component) } }

      it 'fills in component_id for both records' do
        ingest_components

        ids = occurrence_maps.map(&:component_id)

        expect(ids).to all(be_present)
        expect(ids.first).to eq(ids.last)
      end
    end

    context 'when components have the same name but different purl_types' do
      let(:components) do
        [
          create(
            :ci_reports_sbom_component,
            name: "pg",
            version: "v0.0.1",
            purl_type: "gem"
          ),
          create(
            :ci_reports_sbom_component,
            name: "pg",
            version: "v0.0.1",
            purl_type: "pypi"
          )
        ]
      end

      let(:occurrence_maps) { components.map { |component| create(:sbom_occurrence_map, report_component: component) } }

      it 'creates two distinct components' do
        expect { ingest_components }.to change { Sbom::Component.count }.by(2)
      end
    end

    context 'when there is a pypi component' do
      let(:purl) { ::Sbom::PackageUrl.parse('pkg:pypi/Flask_SQLAlchemy@v0.0.1') }

      let(:report_component) do
        create(
          :ci_reports_sbom_component,
          name: 'Flask_SQLAlchemy',
          version: 'v0.0.1',
          purl: purl
        )
      end

      let(:occurrence_maps) { [create(:sbom_occurrence_map, report_component: report_component)] }

      it 'normalizes component name' do
        ingest_components

        component = Sbom::Component.find_by(purl_type: :pypi)

        expect(component).to have_attributes(
          name: 'flask-sqlalchemy',
          purl_type: 'pypi',
          component_type: 'library'
        )
      end
    end

    describe 'attributes' do
      let(:ingested_source_package) { Sbom::Component.last }

      it 'sets the correct attributes for the component' do
        ingest_components

        expect(ingested_source_package.attributes).to include(
          'name' => occurrence_maps.last.name,
          'purl_type' => occurrence_maps.last.purl_type,
          'component_type' => 'library',
          'organization_id' => pipeline.project.namespace.organization_id
        )
      end
    end
  end
end
