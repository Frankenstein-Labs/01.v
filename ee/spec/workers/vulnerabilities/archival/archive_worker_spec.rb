# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Archival::ArchiveWorker, feature_category: :vulnerability_management do
  describe '#perform' do
    let(:worker) { described_class.new }
    let(:date) { Time.zone.today }
    let(:date_parameter) { Time.zone.today.to_s }

    subject(:perform_worker) { worker.perform(project_id, date_parameter) }

    before do
      allow(Vulnerabilities::Archival::ArchiveService).to receive(:execute)
    end

    context 'when the given project does not exist' do
      let(:project_id) { non_existing_record_id }

      it 'does not run the service layer logic' do
        perform_worker

        expect(Vulnerabilities::Archival::ArchiveService).not_to have_received(:execute)
      end
    end

    context 'when the given project exists' do
      let_it_be(:project) { create(:project) }
      let_it_be(:project_id) { project.id }

      context 'when the given date is not valid' do
        let(:date_parameter) { 'invalid date' }

        before do
          allow(Gitlab::ErrorTracking).to receive(:track_exception)
        end

        it 'does not raise an exception' do
          expect { perform_worker }.not_to raise_error
        end

        it 'does not run the service layer logic' do
          perform_worker

          expect(Vulnerabilities::Archival::ArchiveService).not_to have_received(:execute)
        end

        it 'tracks the exception' do
          perform_worker

          expect(Gitlab::ErrorTracking).to have_received(:track_exception)
        end
      end

      context 'when the given date is valid' do
        it 'runs the service layer logic' do
          perform_worker

          expect(Vulnerabilities::Archival::ArchiveService).to have_received(:execute).with(project, date)
        end
      end
    end
  end
end
