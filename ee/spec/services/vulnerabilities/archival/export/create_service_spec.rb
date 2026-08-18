# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Archival::Export::CreateService, feature_category: :vulnerability_management do
  describe '#execute' do
    let_it_be_with_refind(:project) { create(:project) }
    let_it_be_with_refind(:author) { create(:user) }

    let(:start_date) { 5.days.ago.to_date }
    let(:end_date) { 2.days.ago.to_date }
    let(:service_object) { described_class.new(project, author, start_date, end_date, format: :csv) }

    subject(:create_export) { service_object.execute }

    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'when the user does not have permission to create export' do
      it 'raises AccessDenied error' do
        expect { create_export }.to raise_error(Gitlab::Access::AccessDeniedError)
      end
    end

    context 'when the user has permission to create export' do
      before_all do
        project.add_developer(author)
      end

      before do
        allow(Vulnerabilities::Archival::Export::ExportWorker).to receive(:perform_async)
      end

      it 'creates a new export record in the database' do
        expect { create_export }.to change { Vulnerabilities::ArchiveExport.count }.by(1)
      end

      it 'creates the export record with correct attributes and returns it' do
        expect(create_export).to have_attributes(
          project_id: project.id,
          author_id: author.id,
          date_range: (start_date..end_date),
          format: 'csv'
        )
      end

      it 'schedules the export generation' do
        create_export

        expect(Vulnerabilities::Archival::Export::ExportWorker).to have_received(:perform_async)
      end
    end
  end
end
