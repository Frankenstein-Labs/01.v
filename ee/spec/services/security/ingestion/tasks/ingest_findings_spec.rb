# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Tasks::IngestFindings, feature_category: :vulnerability_management do
  describe '#execute' do
    let_it_be(:pipeline) { create(:ci_pipeline) }
    let_it_be(:identifier) { create(:vulnerabilities_identifier) }

    let(:finding_maps) { create_list(:finding_map, 4, identifier_ids: [identifier.id], pipeline: pipeline) }
    let!(:existing_finding) { create(:vulnerabilities_finding, :detected, uuid: finding_maps.first.uuid) }

    subject(:ingest_findings) { described_class.new(pipeline, finding_maps).execute }

    it 'ingests findings' do
      expect { ingest_findings }.to change { Vulnerabilities::Finding.count }.by(3)
    end

    it 'sets the finding and vulnerability ids' do
      expected_finding_ids = Array.new(3) { an_instance_of(Integer) }.unshift(existing_finding.id)
      expected_vulnerability_ids = [existing_finding.vulnerability_id, nil, nil, nil]

      expect { ingest_findings }.to change { finding_maps.map(&:finding_id) }.from(Array.new(4)).to(expected_finding_ids)
                               .and change { finding_maps.map(&:vulnerability_id) }.from(Array.new(4)).to(expected_vulnerability_ids)
    end

    context 'when considering the pipeline ids' do
      it 'properly sets initial and latest pipeline ids on the finding' do
        # latest_pipeline_id increases to 4 because the existing_finding is also updated
        expect { ingest_findings }.to change { Vulnerabilities::Finding.where(initial_pipeline_id: pipeline.id).count }.from(0).to(3)
                                        .and change { Vulnerabilities::Finding.where(latest_pipeline_id: pipeline.id).count }.from(0).to(4)
      end

      context 'when the finding is detected in subsequent pipelines' do
        let(:another_pipeline) { create(:ci_pipeline, project: pipeline.project) }
        let(:common_map_attrs) { { identifier_ids: [identifier.id], pipeline: another_pipeline } }
        let(:another_finding_maps) do
          finding_maps.map do |finding_map|
            Vulnerabilities::Finding.find(finding_map.finding_id)
              .then { |finding| common_map_attrs.merge(finding: finding) }
              # needed to prevent new findings from being created
              .then { |map_attrs| map_attrs.merge(security_finding: finding_map.security_finding, tracked_context: finding_map.tracked_context) }
              .then { |map_attrs| create(:finding_map, **map_attrs) }
          end
        end

        subject(:ingest_findings) { described_class.new(another_pipeline, another_finding_maps).execute }

        before do
          described_class.new(pipeline, finding_maps).execute
        end

        it 'does not change the `initial_pipeline_id' do
          expect { ingest_findings }.not_to change { Vulnerabilities::Finding.where(initial_pipeline_id: pipeline.id).count }.from(3)
        end

        it 'updates the `latest_pipeline_id' do
          expect { ingest_findings }.to change { Vulnerabilities::Finding.where(latest_pipeline_id: another_pipeline.id).count }.from(0).to(4)
                                          .and change { Vulnerabilities::Finding.where(latest_pipeline_id: pipeline.id).count }.from(4).to(0)
        end
      end
    end

    context 'when preventing deadlocks' do
      # Explicit uuids in descending order guarantee the finding_maps are not
      # already sorted, so a regression removing the sort in the task fails
      # this spec deterministically.
      let(:unsorted_uuids) do
        %w[
          dddddddd-dddd-4ddd-8ddd-dddddddddddd
          cccccccc-cccc-4ccc-8ccc-cccccccccccc
          bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb
          aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa
        ]
      end

      let(:finding_maps) do
        unsorted_uuids.map do |uuid|
          create(:finding_map,
            identifier_ids: [identifier.id],
            pipeline: pipeline,
            security_finding: create(:security_finding, uuid: uuid))
        end
      end

      it 'upserts the findings ordered by uuid (the ON CONFLICT key)' do
        upserted_uuids = nil
        proxy_klass = described_class.klass

        allow(proxy_klass)
          .to receive(:bulk_upsert!)
          .and_wrap_original do |original, objects, **kwargs, &block|
            upserted_uuids = objects.map(&:uuid)
            original.call(objects, **kwargs, &block)
          end

        ingest_findings

        expect(upserted_uuids).to eq(unsorted_uuids.sort)
      end

      it 'assigns the correct finding_id/vulnerability_id to each finding_map after sorting', :aggregate_failures do
        ingest_findings

        finding_maps.each do |finding_map|
          persisted_finding = Vulnerabilities::Finding.find_by(uuid: finding_map.uuid)

          expect(finding_map.finding_id).to eq(persisted_finding.id)
          expect(finding_map.vulnerability_id).to eq(persisted_finding.vulnerability_id)
        end
      end
    end

    context 'when details contains malicious keys' do
      let(:malicious_details) do
        {
          'code_evidence' => {
            'type' => 'table',
            'name' => 'Evidence',
            'header' => [
              { 'type' => 'text', 'value' => 'Column', 'thAttr' => { 'onclick' => 'alert(1)' } }
            ],
            'rows' => []
          }
        }
      end

      let(:report_finding_with_details) { build(:ci_reports_security_finding, details: malicious_details) }

      let(:target_map) do
        create(:finding_map,
          identifier_ids: [identifier.id],
          pipeline: pipeline,
          report_finding: report_finding_with_details
        )
      end

      subject(:ingest_target_map) { described_class.new(pipeline, [target_map]).execute }

      it 'strips unexpected keys from details during ingestion' do
        ingest_target_map
        finding = Vulnerabilities::Finding.find_by(uuid: target_map.uuid)
        header_item = finding.details['code_evidence']['header'].first
        expect(header_item).not_to have_key('thAttr')
      end

      it 'keeps allowed keys in details during ingestion' do
        ingest_target_map
        finding = Vulnerabilities::Finding.find_by(uuid: target_map.uuid)
        header_item = finding.details['code_evidence']['header'].first
        expect(header_item).to include('type' => 'text', 'value' => 'Column')
      end
    end

    context 'if attribute exceeds database limit' do
      before do
        %w[description solution].each do |attr|
          finding_maps.each do |finding_map|
            finding_map.report_finding.original_data[attr] = "a" * (Vulnerabilities::Finding::COLUMN_LENGTH_LIMITS[attr.to_sym] + 1)
          end
        end
      end

      it 'ingests findings' do
        expect { ingest_findings }.to change { Vulnerabilities::Finding.count }.by(3)
      end
    end

    it_behaves_like 'bulk insertable task'
  end
end
