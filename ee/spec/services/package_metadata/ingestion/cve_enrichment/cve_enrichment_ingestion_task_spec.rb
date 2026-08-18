# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PackageMetadata::Ingestion::CveEnrichment::CveEnrichmentIngestionTask, feature_category: :software_composition_analysis do
  describe '.execute' do
    let(:cve_id) { 'CVE-2023-12345' }
    let(:new_epss_score) { 0.75 }
    let(:old_epss_score) { 0.5 }
    let(:new_is_known_exploit) { true }
    let(:default_is_known_exploit) { false }

    let!(:existing_cve_enrichment) do
      create(:pm_cve_enrichment, cve: cve_id, epss_score: old_epss_score)
    end

    let(:import_data) do
      [
        build(:pm_cve_enrichment_data_object, cve_id: cve_id, epss_score: new_epss_score,
          is_known_exploit: new_is_known_exploit),
        build(:pm_cve_enrichment_data_object)
      ]
    end

    subject(:execute) { described_class.execute(import_data) }

    context 'when CVE enrichments are valid' do
      it 'adds all new CVE enrichments in import data' do
        expect { execute }.to change { PackageMetadata::CveEnrichment.count }.from(1).to(2)
      end

      context 'when both epss_score and is_known_exploit change' do
        it 'updates existing CVE enrichments' do
          expect { execute }.to change { existing_cve_enrichment.reload.epss_score }
            .from(old_epss_score)
            .to(new_epss_score)
            .and change { existing_cve_enrichment.reload.is_known_exploit }
            .from(default_is_known_exploit)
            .to(new_is_known_exploit)
        end
      end

      context 'when neither epss_score nor is_known_exploit changes' do
        before do
          existing_cve_enrichment.update!(epss_score: new_epss_score, is_known_exploit: new_is_known_exploit)
        end

        it 'does not update existing CVE enrichments', :aggregate_failures do
          original_updated_at = existing_cve_enrichment.updated_at
          original_epss_score = existing_cve_enrichment.epss_score
          original_is_known_exploit = existing_cve_enrichment.is_known_exploit

          execute

          existing_cve_enrichment.reload
          expect(existing_cve_enrichment.epss_score).to eq(original_epss_score)
          expect(existing_cve_enrichment.is_known_exploit).to eq(original_is_known_exploit)
          # Ruby has nanosecond precision on timestamps, while PostgreSQL has microsecond precision.
          # This causes the timestamp to be rounded down to the nearest microsecond when the record is reloaded.
          # We need to make the comparison in microseconds to avoid a false-negative.
          expect(existing_cve_enrichment.updated_at.floor(6)).to eq(original_updated_at.floor(6))
        end
      end

      context 'when only epss score changes' do
        before do
          existing_cve_enrichment.update!(is_known_exploit: new_is_known_exploit)
        end

        it 'updates existing CVE enrichments' do
          expect { execute }.to change { existing_cve_enrichment.reload.epss_score }
                                  .from(old_epss_score)
                                  .to(new_epss_score)
                                  .and change { existing_cve_enrichment.reload.updated_at.floor(6) }
        end
      end

      context 'when only is_known_exploit changes' do
        before do
          existing_cve_enrichment.update!(epss_score: new_epss_score)
        end

        it 'updates existing CVE enrichments' do
          expect { execute }.to change { existing_cve_enrichment.reload.is_known_exploit }
                                  .from(default_is_known_exploit)
                                  .to(new_is_known_exploit)
                                  .and change { existing_cve_enrichment.reload.updated_at.floor(6) }
        end
      end
    end

    context 'when CVE enrichments are invalid' do
      let(:valid_cve_enrichment) { build(:pm_cve_enrichment_data_object) }
      let(:invalid_cve_enrichment) { build(:pm_cve_enrichment_data_object, cve_id: 'invalid') }
      let(:import_data) { [valid_cve_enrichment, invalid_cve_enrichment] }

      it 'creates only valid CVE enrichments' do
        expect { execute }.to change { PackageMetadata::CveEnrichment.count }.by(1)
      end

      it 'logs invalid CVE enrichments as an error' do
        expect(Gitlab::ErrorTracking)
          .to receive(:track_exception)
                .with(
                  an_instance_of(described_class::Error),
                  hash_including(
                    cve: 'invalid',
                    epss_score: invalid_cve_enrichment.epss_score,
                    is_known_exploit: invalid_cve_enrichment.is_known_exploit,
                    errors: { cve: ["is invalid"] }
                  )
                )
        execute
      end

      context 'when all the records are invalid' do
        let(:import_data) { [invalid_cve_enrichment] }

        it 'does not execute the upsert' do
          expect(ApplicationRecord).not_to receive(:connection)

          execute
        end
      end
    end
  end
end
