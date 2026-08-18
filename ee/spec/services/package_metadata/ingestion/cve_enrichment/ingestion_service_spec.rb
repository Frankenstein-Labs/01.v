# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PackageMetadata::Ingestion::CveEnrichment::IngestionService, feature_category: :software_composition_analysis do
  describe '.execute' do
    subject(:execute) { described_class.execute(import_data) }

    let(:import_data) { build_list(:pm_cve_enrichment_data_object, 5) }

    describe 'execution' do
      context 'when no errors' do
        it 'calls CveEnrichmentIngestionTask with import data' do
          task_instance = instance_double(PackageMetadata::Ingestion::CveEnrichment::CveEnrichmentIngestionTask)
          expect(PackageMetadata::Ingestion::CveEnrichment::CveEnrichmentIngestionTask)
            .to receive(:new).with(import_data).and_return(task_instance)
          expect(task_instance).to receive(:execute)

          execute
        end
      end

      context 'when error occurs' do
        it 'raises the error' do
          task_instance = instance_double(PackageMetadata::Ingestion::CveEnrichment::CveEnrichmentIngestionTask)
          allow(PackageMetadata::Ingestion::CveEnrichment::CveEnrichmentIngestionTask)
            .to receive(:new).with(import_data).and_return(task_instance)
          allow(task_instance).to receive(:execute).and_raise(StandardError)

          expect { execute }.to raise_error(StandardError)
        end
      end
    end
  end
end
