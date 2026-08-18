# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Archival::Export::ExportService, feature_category: :vulnerability_management do
  describe '.export' do
    let(:mock_archive_export) { instance_double(Vulnerabilities::ArchiveExport) }
    let(:mock_service_object) { instance_spy(described_class) }

    subject(:export) { described_class.export(mock_archive_export) }

    before do
      allow(described_class).to receive(:new).with(mock_archive_export).and_return(mock_service_object)
    end

    it 'allocates a service object and delegates the call to it' do
      export

      expect(mock_service_object).to have_received(:export)
    end
  end

  describe '#export' do
    let(:archive_export) { create(:vulnerability_archive_export) }
    let(:archive_1) { create(:vulnerability_archive) }
    let(:archive_2) { create(:vulnerability_archive) }
    let(:service_object) { described_class.new(archive_export) }

    subject(:export) { service_object.export }

    around do |example|
      travel_to('23/04/2025') { example.run }
    end

    before do
      allow(archive_export).to receive(:archives).and_return([archive_1, archive_2])
      allow(archive_export.project).to receive(:full_path).and_return('full_path')
      allow(Vulnerabilities::Archival::Export::PurgeWorker).to receive(:perform_in)

      create(:vulnerability_archived_record, archive: archive_1)
      create(:vulnerability_archived_record, archive: archive_2)
    end

    it 'creates the export file' do
      expect { export }.to change { archive_export.reload.status }.to('finished')
                       .and change { archive_export.file.file }.from(nil)
    end

    it 'sets the correct filename for the export' do
      expected_file_name = 'full_path_vulnerabilities_archive_2025-04-18..2025-04-23_2025-04-23T0000.csv'

      expect { export }.to change { archive_export.file.filename }.from(nil).to(expected_file_name)
    end

    it 'creates the export for all archived records' do
      export

      csv = CSV.parse(archive_export.file.read, headers: true)

      expect(csv.length).to be(2)
    end

    it 'schedules the deletion of the export' do
      export

      expect(Vulnerabilities::Archival::Export::PurgeWorker)
        .to have_received(:perform_in).with(24.hours, archive_export.id)
    end

    context 'when an error happens' do
      before do
        allow(Vulnerabilities::Archival::Export::Exporters::CsvService).to receive(:new).and_raise('Foo')
      end

      it 'does not change the status of the export and propagates the error' do
        expect { export }.to raise_error('Foo')
                         .and not_change { archive_export.reload.status }.from('created')
      end
    end
  end
end
