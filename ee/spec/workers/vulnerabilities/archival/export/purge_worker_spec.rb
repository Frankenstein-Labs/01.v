# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Archival::Export::PurgeWorker, feature_category: :vulnerability_management do
  describe '#perform' do
    let(:worker) { described_class.new }

    subject(:perform_worker) { worker.perform(archive_export_id) }

    before do
      allow(Vulnerabilities::Archival::Export::PurgeService).to receive(:purge)
    end

    context 'when there is no record for the given ID' do
      let(:archive_export_id) { non_existing_record_id }

      it 'does not run the service layer logic' do
        perform_worker

        expect(Vulnerabilities::Archival::Export::PurgeService).not_to have_received(:purge)
      end
    end

    context 'when there is a record for the given ID' do
      let(:archive_export) { create(:vulnerability_archive_export) }
      let(:archive_export_id) { archive_export.id }

      it 'runs the service layer logic' do
        perform_worker

        expect(Vulnerabilities::Archival::Export::PurgeService).to have_received(:purge)
      end
    end
  end
end
