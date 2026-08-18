# frozen_string_literal: true

RSpec.shared_examples 'reacting to archived and traversal_ids changes' do
  describe 'scheduling `Vulnerabilities::UpdateArchivedAttributeOfVulnerabilityReadsWorker`' do
    before do
      allow(Vulnerabilities::UpdateArchivedAttributeOfVulnerabilityReadsWorker).to receive(:perform_async)
    end

    context 'when the `archived` attribute of the project does not change while creating the vulnerability' do
      it 'does not schedule the worker' do
        create_vulnerability

        expect(Vulnerabilities::UpdateArchivedAttributeOfVulnerabilityReadsWorker)
          .not_to have_received(:perform_async)
      end
    end

    context 'when the `archived` attribute of the project changes while creating the vulnerability' do
      before do
        allow(service_object).to receive(:initialize_vulnerability).and_wrap_original do |method, *args|
          project.update_column(:archived, true)

          method.call(*args)
        end
      end

      it 'schedules the worker' do
        create_vulnerability

        expect(Vulnerabilities::UpdateArchivedAttributeOfVulnerabilityReadsWorker).to have_received(:perform_async)
      end
    end
  end

  describe 'scheduling `Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker`' do
    before do
      allow(Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker).to receive(:perform_async)
    end

    context 'when the `traversal_ids` attribute of the namespace does not change while creating the record' do
      it 'does not schedule the worker' do
        create_vulnerability

        expect(Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker)
          .not_to have_received(:perform_async)
      end
    end

    context 'when the `traversal_ids` attribute of the namespace changes while creating the vulnereability' do
      before do
        allow(service_object).to receive(:initialize_vulnerability).and_wrap_original do |method, *args|
          project.namespace.update_column(:traversal_ids, [-1])

          method.call(*args)
        end
      end

      it 'schedules the worker' do
        create_vulnerability

        expect(Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker).to have_received(:perform_async)
      end
    end

    context 'when the project moves to another namespace' do
      let(:new_namespace) { create(:namespace) }

      before do
        allow(service_object).to receive(:initialize_vulnerability).and_wrap_original do |method, *args|
          project.update_column(:namespace_id, new_namespace.id)

          method.call(*args)
        end
      end

      it 'schedules the worker' do
        create_vulnerability

        expect(Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker).to have_received(:perform_async)
      end
    end
  end
end
