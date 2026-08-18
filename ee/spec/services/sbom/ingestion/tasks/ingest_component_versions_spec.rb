# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::Tasks::IngestComponentVersions, feature_category: :dependency_management do
  describe '#execute' do
    let_it_be(:pipeline) { create(:ci_pipeline) }

    let(:occurrence_maps) { create_list(:sbom_occurrence_map, 4, :with_component) }

    subject(:ingest_component_versions) { described_class.execute(pipeline, occurrence_maps) }

    it_behaves_like 'bulk insertable task'

    it 'is idempotent' do
      expect { ingest_component_versions }.to change { Sbom::ComponentVersion.count }.by(4)
      expect { ingest_component_versions }.not_to change { Sbom::ComponentVersion.count }
    end

    context 'when there is an existing version' do
      let!(:existing_version) do
        create(:sbom_component_version, **occurrence_maps.first.to_h.slice(:component_id, :version))
      end

      it 'does not create a new record for the existing version' do
        expect { ingest_component_versions }.to change { Sbom::ComponentVersion.count }.by(3)
      end

      it 'does not update existing version' do
        expect { ingest_component_versions }.not_to change { existing_version.reload.updated_at }
      end

      it 'sets the component_id' do
        expected_component_ids = Array.new(3) { an_instance_of(Integer) }.unshift(existing_version.id)

        expect { ingest_component_versions }.to change { occurrence_maps.map(&:component_version_id) }
          .from(Array.new(4)).to(expected_component_ids)
      end
    end

    context 'when there is no version attribute' do
      let(:good_occurrence_map_1) { create(:sbom_occurrence_map, :with_component) }
      let(:good_occurrence_map_2) { create(:sbom_occurrence_map, :with_component) }
      let(:report_component) { create(:ci_reports_sbom_component, version: nil) }
      let(:nil_occurence_map) { create(:sbom_occurrence_map, :with_component, report_component: report_component) }
      let(:occurrence_maps) { [good_occurrence_map_1, nil_occurence_map, good_occurrence_map_2] }

      it 'skips creation for missing version' do
        expect { ingest_component_versions }.to change { Sbom::ComponentVersion.count }.by(2)
      end

      it 'does not set component_version_id when skipped' do
        expect { ingest_component_versions }.to change { occurrence_maps.map(&:component_version_id) }
          .from(Array.new(3)).to([an_instance_of(Integer), nil, an_instance_of(Integer)])
      end
    end

    context 'when occurrence maps contains two of the same component_version' do
      let_it_be(:component) { create(:sbom_component) }
      let_it_be(:report_component) { create(:ci_reports_sbom_component, version: 'v0.0.1') }

      let(:occurrence_maps) do
        create_list(:sbom_occurrence_map, 2, component: component, report_component: report_component)
      end

      it 'fills in both ids' do
        expect { ingest_component_versions }.to change { occurrence_maps.map(&:component_version_id) }
          .from(Array.new(2)).to([an_instance_of(Integer), an_instance_of(Integer)])
      end
    end

    describe 'attributes' do
      let(:ingested_component_version) { Sbom::ComponentVersion.last }

      it 'sets the correct attributes for the component' do
        ingest_component_versions

        expect(ingested_component_version.attributes).to include(
          'component_id' => occurrence_maps.last.component_id,
          'version' => occurrence_maps.last.version,
          'organization_id' => pipeline.project.namespace.organization_id
        )
      end
    end

    context 'when the new org-scoped unique index does not yet exist (legacy deploy-window fallback)' do
      # Simulate the post-deployment migration window: the new code runs while the org-scoped
      # index (idx_sbom_comp_versions_on_comp_id_version_and_org_id) has not been created yet,
      # so the service must fall back to upserting against the legacy [component_id, version] index.
      before do
        connection = Sbom::ComponentVersion.connection

        allow(connection).to receive(:index_name_exists?).and_call_original
        allow(connection).to receive(:index_name_exists?)
          .with(Sbom::ComponentVersion.table_name, described_class::NEW_UNIQUE_INDEX_NAME)
          .and_return(false)

        # The legacy unique index still physically exists during the deploy window; recreate it so
        # the ON CONFLICT (component_id, version) target resolves. The non-concurrent CREATE INDEX
        # runs inside the spec transaction and rolls back automatically.
        connection.execute(<<~SQL)
          CREATE UNIQUE INDEX index_sbom_component_versions_on_component_id_and_version
          ON sbom_component_versions (component_id, version)
        SQL

        # Rails resolves the upsert's ON CONFLICT target from the cached index list, which earlier
        # examples may have populated without the legacy index. Clear it so the new index is seen.
        connection.schema_cache.clear!
      end

      it 'falls back to the legacy unique_by' do
        task = described_class.new(pipeline, occurrence_maps)

        expect(task.send(:unique_by)).to eq(described_class::LEGACY_UNIQUE_BY)
      end

      it 'creates a record for each version and is idempotent' do
        expect { ingest_component_versions }.to change { Sbom::ComponentVersion.count }.by(4)
        expect { ingest_component_versions }.not_to change { Sbom::ComponentVersion.count }
      end

      it 'still persists organization_id on new records' do
        ingest_component_versions

        map = occurrence_maps.first
        ingested = Sbom::ComponentVersion.find_by(component_id: map.component_id, version: map.version)

        expect(ingested).not_to be_nil,
          "expected a ComponentVersion record for component_id=#{map.component_id}, version=#{map.version}"
        expect(ingested.organization_id).to eq(pipeline.project.namespace.organization_id)
      end

      context 'when there is an existing version' do
        let!(:existing_version) do
          create(:sbom_component_version, **occurrence_maps.first.to_h.slice(:component_id, :version))
        end

        it 'does not create a duplicate for the existing version' do
          expect { ingest_component_versions }.to change { Sbom::ComponentVersion.count }.by(3)
        end

        it 'reuses the existing record id' do
          expected_component_ids = Array.new(3) { an_instance_of(Integer) }.unshift(existing_version.id)

          expect { ingest_component_versions }.to change { occurrence_maps.map(&:component_version_id) }
            .from(Array.new(4)).to(expected_component_ids)
        end
      end
    end
  end
end
