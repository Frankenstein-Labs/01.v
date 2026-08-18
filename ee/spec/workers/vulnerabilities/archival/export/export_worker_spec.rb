# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Archival::Export::ExportWorker, feature_category: :vulnerability_management do
  describe '.sidekiq_retries_exhausted' do
    let(:archive_export_id) { 1 }
    let(:job) { { 'args' => [1] } }

    subject(:retries_exhausted) { described_class.sidekiq_retries_exhausted_block.call(job) }

    before do
      allow(Vulnerabilities::Archival::Export::PurgeWorker).to receive(:perform_in)
    end

    it 'schedules the purge job' do
      retries_exhausted

      expect(Vulnerabilities::Archival::Export::PurgeWorker)
        .to have_received(:perform_in).with(24.hours, archive_export_id)
    end
  end

  describe '#perform' do
    let(:worker) { described_class.new }

    subject(:perform_worker) { worker.perform(archive_export_id) }

    before do
      allow(Vulnerabilities::Archival::Export::ExportService).to receive(:export)
    end

    context 'when there is no record for the given ID' do
      let(:archive_export_id) { non_existing_record_id }

      it 'does not run the service layer logic' do
        perform_worker

        expect(Vulnerabilities::Archival::Export::ExportService).not_to have_received(:export)
      end
    end

    context 'when there is a record for the given ID' do
      let(:archive_export) { create(:vulnerability_archive_export) }
      let(:archive_export_id) { archive_export.id }

      it 'runs the service layer logic' do
        perform_worker

        expect(Vulnerabilities::Archival::Export::ExportService).to have_received(:export)
      end
    end
  end
end
