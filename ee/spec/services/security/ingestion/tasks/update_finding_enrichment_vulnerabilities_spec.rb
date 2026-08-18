# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Tasks::UpdateFindingEnrichmentVulnerabilities, feature_category: :vulnerability_management do
  describe '#execute' do
    let_it_be(:pipeline) { create(:ci_pipeline) }
    let_it_be(:project) { pipeline.project }

    let_it_be(:finding_map_1) { create(:finding_map, :new_record, pipeline: pipeline) }
    let_it_be(:finding_map_2) { create(:finding_map, :new_record, pipeline: pipeline) }
    let_it_be(:finding_map_without_vulnerability) { create(:finding_map, pipeline: pipeline) }
    let_it_be(:existing_finding_map) { create(:finding_map, pipeline: pipeline, new_record: false) }

    let(:finding_maps) { [finding_map_1, finding_map_2, finding_map_without_vulnerability, existing_finding_map] }

    let_it_be_with_reload(:enrichment_1) do
      create(:security_finding_enrichment,
        project: project,
        finding_uuid: finding_map_1.uuid)
    end

    let_it_be_with_reload(:enrichment_2) do
      create(:security_finding_enrichment,
        project: project,
        finding_uuid: finding_map_2.uuid)
    end

    let_it_be(:enrichment_without_finding_map) do
      create(:security_finding_enrichment, project: project)
    end

    let_it_be(:enrichment_for_existing) do
      create(:security_finding_enrichment,
        project: project,
        finding_uuid: existing_finding_map.uuid)
    end

    subject(:execute) { described_class.new(pipeline, finding_maps).execute }

    it 'updates enrichments with vulnerability_id for finding_maps that have vulnerabilities' do
      expect { execute }
        .to change { enrichment_1.reload.vulnerability_id }.from(nil).to(finding_map_1.vulnerability_id)
        .and change { enrichment_2.reload.vulnerability_id }.from(nil).to(finding_map_2.vulnerability_id)
    end

    it 'does not update enrichments that do not match any finding_map' do
      expect { execute }.not_to change { enrichment_without_finding_map.reload.vulnerability_id }
    end

    it 'does not update enrichments for existing vulnerabilities (finding_map with new record: false)' do
      expect { execute }.not_to change { enrichment_for_existing.reload.vulnerability_id }
    end

    context 'when finding_map has no vulnerability_id' do
      let(:finding_maps) { [finding_map_without_vulnerability] }

      it 'does not update any enrichments' do
        expect { execute }.not_to change { enrichment_1.reload.vulnerability_id }
      end
    end

    context 'when there are no matching enrichments' do
      let_it_be(:other_pipeline) { create(:ci_pipeline) }
      let_it_be(:unmatched_finding_map) { create(:finding_map, :new_record, pipeline: other_pipeline) }

      let(:finding_maps) { [unmatched_finding_map] }

      it 'does not execute any updates' do
        expect(Security::FindingEnrichment).not_to receive(:where)

        expect { execute }.not_to raise_error
      end
    end

    context 'when finding_maps is empty' do
      let(:finding_maps) { [] }

      it 'does not execute any updates' do
        expect(Security::FindingEnrichment).not_to receive(:where)

        expect { execute }.not_to raise_error
      end
    end

    context 'when a finding has multiple enrichments with the same uuid (different CVEs)' do
      let_it_be_with_reload(:enrichment_cve_1) do
        create(:security_finding_enrichment,
          project: project,
          finding_uuid: finding_map_1.uuid,
          cve: 'CVE-2024-0001')
      end

      let_it_be_with_reload(:enrichment_cve_2) do
        create(:security_finding_enrichment,
          project: project,
          finding_uuid: finding_map_1.uuid,
          cve: 'CVE-2024-0002')
      end

      let(:finding_maps) { [finding_map_1] }

      it 'updates all enrichments for that finding' do
        expect { execute }
          .to change { enrichment_cve_1.reload.vulnerability_id }.from(nil).to(finding_map_1.vulnerability_id)
          .and change { enrichment_cve_2.reload.vulnerability_id }.from(nil).to(finding_map_1.vulnerability_id)
      end
    end
  end
end
