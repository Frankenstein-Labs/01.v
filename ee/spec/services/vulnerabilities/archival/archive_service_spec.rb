# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Archival::ArchiveService, feature_category: :vulnerability_management do
  describe '.execute' do
    let(:mock_project) { instance_double(Project) }
    let(:date) { Time.zone.today }
    let(:mock_service_object) { instance_spy(described_class) }

    subject(:execute_archival_logic) { described_class.execute(mock_project, date) }

    before do
      allow(described_class).to receive(:new).and_return(mock_service_object)
    end

    it 'instantiates an object and delegates the call to it' do
      execute_archival_logic

      expect(described_class).to have_received(:new).with(mock_project, date)
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute', :freeze_time do
    let_it_be(:date) { 1.day.ago.to_date }
    let_it_be(:project) { create(:project) }

    let(:service_object) { described_class.new(project, date) }

    subject(:archive_vulnerabilities) { service_object.execute }

    context 'when there are no vulnerabilities to archive' do
      it 'creates a new archive record in the database' do
        project_archives = project.vulnerability_archives.where(date: Time.zone.today.beginning_of_month)

        expect { archive_vulnerabilities }.to change { project_archives.count }.by(1)
      end
    end

    context 'when there are vulnerabilities to archive' do
      let_it_be(:archivable_vulnerability_1) { create(:vulnerability, project: project, updated_at: date - 1.day) }
      let_it_be(:archivable_vulnerability_2) { create(:vulnerability, project: project, updated_at: date - 2.days) }
      let_it_be(:not_archivable_vulnerability) { create(:vulnerability, project: project) }
      let_it_be(:vulnerability_from_another_project) { create(:vulnerability, updated_at: date - 1.day) }

      before do
        allow(Vulnerabilities::Archival::ArchiveBatchService).to receive(:execute)
      end

      it 'calls the `ArchiveBatchService` with stale vulnerabilities' do
        archive_vulnerabilities

        expect(Vulnerabilities::Archival::ArchiveBatchService)
          .to have_received(:execute).with(an_instance_of(Vulnerabilities::Archive),
            match_array([archivable_vulnerability_1, archivable_vulnerability_2]))
      end

      it 'creates a new archive record in the database' do
        project_archives = project.vulnerability_archives.where(date: Time.zone.today.beginning_of_month)

        expect { archive_vulnerabilities }.to change { project_archives.count }.by(1)
      end

      context 'when the archive already exists' do
        before do
          create(:vulnerability_archive, project: project)
        end

        it 'does not create a new archive record in the database' do
          expect { archive_vulnerabilities }.not_to change { project.vulnerability_archives.count }
        end
      end

      describe 'batching' do
        before do
          stub_const("#{described_class}::BATCH_SIZE", 1)
        end

        it 'calls the `ArchiveBatchService` twice' do
          archive_vulnerabilities

          expect(Vulnerabilities::Archival::ArchiveBatchService)
            .to have_received(:execute).with(an_instance_of(Vulnerabilities::Archive),
              match_array([archivable_vulnerability_1])).once

          expect(Vulnerabilities::Archival::ArchiveBatchService)
            .to have_received(:execute).with(an_instance_of(Vulnerabilities::Archive),
              match_array([archivable_vulnerability_2])).once
        end
      end
    end
  end
end
