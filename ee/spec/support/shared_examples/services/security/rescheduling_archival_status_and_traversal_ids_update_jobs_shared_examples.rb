# frozen_string_literal: true

RSpec.shared_examples 'rescheduling archival status and traversal_ids update jobs' do
  describe 'scheduling `Vulnerabilities::UpdateArchivedAttributeOfVulnerabilityReadsWorker`' do
    before do
      allow(Vulnerabilities::UpdateArchivedAttributeOfVulnerabilityReadsWorker).to receive(scheduling_method)
    end

    context 'when the `archived` attribute of the project does not change while ingesting the report' do
      it 'does not schedule the worker' do
        ingest_vulnerabilities

        expect(Vulnerabilities::UpdateArchivedAttributeOfVulnerabilityReadsWorker)
          .not_to have_received(scheduling_method)
      end
    end

    context 'when the `archived` attribute of the project changes while ingesting the report' do
      before do
        update_archived_after_start
      end

      it 'schedules the worker' do
        ingest_vulnerabilities

        expect(Vulnerabilities::UpdateArchivedAttributeOfVulnerabilityReadsWorker)
          .to have_received(scheduling_method).with(*job_args)
      end
    end
  end

  describe 'scheduling `Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker`' do
    before do
      allow(Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker).to receive(scheduling_method)
    end

    context 'when the `traversal_ids` attribute of the namespace does not change while ingesting the report' do
      it 'does not schedule the worker' do
        ingest_vulnerabilities

        expect(Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker)
          .not_to have_received(scheduling_method)
      end
    end

    context 'when the `traversal_ids` attribute of the namespace changes while ingesting the report' do
      before do
        update_traversal_ids_after_start
      end

      it 'schedules the worker' do
        ingest_vulnerabilities

        expect(Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker)
          .to have_received(scheduling_method).with(*job_args)
      end
    end

    context 'when the project moves to another namespace' do
      let(:new_namespace) { create(:namespace) }

      before do
        update_namespace_after_start
      end

      it 'schedules the worker' do
        ingest_vulnerabilities

        expect(Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker)
          .to have_received(scheduling_method).with(*job_args)
      end
    end
  end
end
