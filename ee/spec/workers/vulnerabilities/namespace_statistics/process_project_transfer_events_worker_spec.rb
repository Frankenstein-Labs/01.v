# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceStatistics::ProcessProjectTransferEventsWorker, feature_category: :security_asset_inventories do
  let(:worker) { described_class.new }

  describe '#handle_event' do
    let_it_be(:old_namespace) { create(:group) }
    let_it_be(:new_namespace) { create(:group) }
    let_it_be(:project) { create(:project, namespace: new_namespace) }
    let(:project_id) { project.id }

    let(:project_event) do
      ::Projects::ProjectTransferedEvent.new(data: {
        project_id: project_id,
        old_namespace_id: old_namespace.id,
        old_root_namespace_id: old_namespace.id,
        new_namespace_id: new_namespace.id,
        new_root_namespace_id: new_namespace.id
      })
    end

    let(:update_ancestors_service) { Vulnerabilities::NamespaceStatistics::UpdateProjectAncestorsStatisticsService }

    subject(:handle_event) { worker.handle_event(project_event) }

    before do
      allow(update_ancestors_service).to receive(:execute)
    end

    context 'when there is no project associated with the event' do
      let(:project_id) { non_existing_record_id }

      it 'does not call the service layer logic' do
        handle_event

        expect(update_ancestors_service).not_to have_received(:execute)
      end
    end

    context 'when there is a project associated with the event' do
      it 'calls the service layer logic' do
        handle_event

        expect(update_ancestors_service).to have_received(:execute).with(project)
      end
    end
  end
end
