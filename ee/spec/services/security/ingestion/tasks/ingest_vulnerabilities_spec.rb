# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Tasks::IngestVulnerabilities, feature_category: :vulnerability_management do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:pipeline) { create(:ci_pipeline, user: user) }
    let_it_be(:identifier) { create(:vulnerabilities_identifier) }
    let_it_be(:existing_vulnerability) do
      create(
        :vulnerability,
        :detected,
        :with_finding,
        resolved_on_default_branch: true,
        present_on_default_branch: false
      )
    end

    let_it_be(:resolved_vulnerability) do
      create(
        :vulnerability,
        :resolved,
        :with_finding,
        resolved_on_default_branch: true,
        present_on_default_branch: true
      )
    end

    let(:finding_maps) { create_list(:finding_map, 5, pipeline: pipeline) }
    let_it_be(:some_findings) { create_list(:vulnerabilities_finding, 3) }

    subject(:ingest_vulnerabilities) { described_class.new(pipeline, finding_maps).execute }

    before do
      finding_maps.first.vulnerability_id = existing_vulnerability.id
      finding_maps.first.finding_id = existing_vulnerability.finding.id

      finding_maps.second.vulnerability_id = resolved_vulnerability.id
      finding_maps.second.finding_id = resolved_vulnerability.finding.id

      finding_maps.third.finding_id = some_findings.first.id
      finding_maps.fourth.finding_id = some_findings.second.id
      finding_maps.fifth.finding_id = some_findings.third.id

      finding_maps.each { |finding_map| finding_map.identifier_ids << identifier.id }
    end

    it 'creates new vulnerabilities' do
      expect { ingest_vulnerabilities }.to change { Vulnerability.count }.by(3)
    end

    it 'fills in the finding_id column' do
      ingest_vulnerabilities

      ids = Vulnerability.pluck(:finding_id)

      expect(ids).to all be_an(Integer)
    end

    it 'marks the existing vulnerability as not resolved on default branch' do
      expect { ingest_vulnerabilities }.to change { existing_vulnerability.reload.resolved_on_default_branch }.to(false)
    end

    it 'backfills the finding_id column' do
      expect { ingest_vulnerabilities }.to change { existing_vulnerability.reload.finding_id }
        .to(existing_vulnerability.finding.id).and change { resolved_vulnerability.reload.finding_id }
        .to(resolved_vulnerability.finding.id)
    end

    it 'creates new vulnerabilities with present_on_default_branch set to true' do
      ingest_vulnerabilities
      expect(Vulnerability.last.present_on_default_branch).to be_truthy
    end

    it 'updates present_on_default_branch to true for existing vulnerabilities' do
      expect { ingest_vulnerabilities }.to change { existing_vulnerability.reload.present_on_default_branch }.to(true)
    end

    context 'when the existing vulnerabilities are not ordered by vulnerability_id' do
      let(:ordered_vulnerabilities) { [existing_vulnerability, resolved_vulnerability].sort_by(&:id) }

      before do
        # Assign the higher vulnerability_id to an earlier finding_map so the maps
        # are in reverse id order before ingestion sorts them.
        finding_maps.first.vulnerability_id = ordered_vulnerabilities.last.id
        finding_maps.first.finding_id = ordered_vulnerabilities.last.finding.id

        finding_maps.second.vulnerability_id = ordered_vulnerabilities.first.id
        finding_maps.second.finding_id = ordered_vulnerabilities.first.finding.id
      end

      it 'orders every vulnerabilities bulk update by id to prevent deadlocks', :aggregate_failures do
        recorder = ActiveRecord::QueryRecorder.new { ingest_vulnerabilities }

        lower_id = ordered_vulnerabilities.first.id
        higher_id = ordered_vulnerabilities.last.id

        bulk_updates = recorder.log.select do |query|
          query.match?(/UPDATE\s+vulnerabilities/i) && query.include?('VALUES')
        end

        expect(bulk_updates).not_to be_empty
        bulk_updates.each do |query|
          expect(query.index(/\(\s*#{lower_id}\s*,/)).to be < query.index(/\(\s*#{higher_id}\s*,/)
        end
      end
    end

    context 'when a resolved Vulnerability shows up in a subsequent scan' do
      let(:existing_vulnerabilities) { finding_maps.select(&:vulnerability_id) }

      it 'changes the state to detected' do
        expect(described_class::MarkResolvedAsDetected).to receive(:execute)
          .with(pipeline, existing_vulnerabilities)

        ingest_vulnerabilities
      end
    end

    describe '#mark_redetected_vulnerabilities_as_not_removed_from_code' do
      context 'when a redetected vulnerability has removed_from_code set to true' do
        let_it_be(:representation_info) do
          create(:vulnerability_representation_information,
            vulnerability: existing_vulnerability,
            removed_from_code: true
          )
        end

        it 'sets removed_from_code to false' do
          expect { ingest_vulnerabilities }
            .to change { representation_info.reload.removed_from_code }
            .from(true)
            .to(false)
        end
      end

      context 'when a redetected secret detection vulnerability has removed_from_code set to true' do
        let_it_be(:secret_detection_vulnerability) do
          create(:vulnerability,
            :detected,
            :with_finding,
            :secret_detection,
            resolved_on_default_branch: true,
            present_on_default_branch: false
          )
        end

        let_it_be(:representation_info) do
          create(:vulnerability_representation_information,
            vulnerability: secret_detection_vulnerability,
            removed_from_code: true
          )
        end

        let(:secret_finding_map) { create(:finding_map, pipeline: pipeline) }
        let(:finding_maps) { create_list(:finding_map, 4, pipeline: pipeline) + [secret_finding_map] }

        before do
          finding_maps.first.vulnerability_id = existing_vulnerability.id
          finding_maps.first.finding_id = existing_vulnerability.finding.id
          finding_maps.second.vulnerability_id = resolved_vulnerability.id
          finding_maps.second.finding_id = resolved_vulnerability.finding.id
          finding_maps.third.finding_id = some_findings.first.id
          finding_maps.fourth.finding_id = some_findings.second.id
          finding_maps.fifth.finding_id = some_findings.third.id
          secret_finding_map.vulnerability_id = secret_detection_vulnerability.id
          secret_finding_map.finding_id = secret_detection_vulnerability.finding.id
          finding_maps.each { |finding_map| finding_map.identifier_ids << identifier.id }
        end

        it 'sets removed_from_code to false' do
          expect { ingest_vulnerabilities }
            .to change { representation_info.reload.removed_from_code }
            .from(true)
            .to(false)
        end
      end

      context 'when a vulnerability not in the current scan has removed_from_code set to true' do
        let_it_be(:other_vulnerability) do
          create(:vulnerability,
            :detected,
            :with_finding,
            resolved_on_default_branch: true,
            present_on_default_branch: false
          )
        end

        let_it_be(:representation_info) do
          create(:vulnerability_representation_information,
            vulnerability: other_vulnerability,
            removed_from_code: true
          )
        end

        it 'does not reset removed_from_code' do
          expect { ingest_vulnerabilities }
            .not_to change { representation_info.reload.removed_from_code }
        end
      end

      context 'when a redetected vulnerability has no representation information' do
        it 'does not raise an error' do
          expect { ingest_vulnerabilities }.not_to raise_error
        end
      end
    end

    shared_examples 'creates detection transitions' do
      context 'when non-resolved vulnerability has a stale detected: false transition' do
        let!(:stale_detection_transition) do
          create(:vulnerability_detection_transition,
            finding: existing_vulnerability.finding,
            project: existing_vulnerability.project,
            detected: false
          )
        end

        it 'creates a detection transition with detected: true', :aggregate_failures do
          finding_ids = existing_vulnerability.findings.pluck(:id)

          expect { ingest_vulnerabilities }.to change {
            Vulnerabilities::DetectionTransition.where(vulnerability_occurrence_id: finding_ids).count
          }.by(1)

          latest_transition = Vulnerabilities::DetectionTransition
            .where(vulnerability_occurrence_id: finding_ids)
            .order(id: :desc)
            .first
          expect(latest_transition.detected).to be(true)
        end

        it 'does not change the state of non-resolved vulnerabilities' do
          expect { ingest_vulnerabilities }.not_to change { existing_vulnerability.reload.state }.from('detected')
        end
      end

      context 'when non-resolved vulnerability does not have a detected: false transition' do
        it 'does not create detection transitions for vulnerabilities without stale transitions' do
          finding_ids = existing_vulnerability.findings.pluck(:id)

          expect { ingest_vulnerabilities }.not_to change {
            Vulnerabilities::DetectionTransition.where(vulnerability_occurrence_id: finding_ids).count
          }
        end
      end
    end

    it_behaves_like 'creates detection transitions'

    context 'when pipeline is nil' do
      subject(:ingest_vulnerabilities) { described_class.new(nil, finding_maps).execute }

      it_behaves_like 'creates detection transitions'
    end
  end
end
