# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attributes::ProcessProjectTransferEventsWorker, feature_category: :security_asset_inventories do
  let_it_be(:old_root_namespace) { create(:namespace) }
  let_it_be(:new_root_namespace) { create(:namespace) }
  let_it_be(:project) { create(:project) }

  let(:worker) { described_class.new }
  let(:project_transfer_event) do
    ::Projects::ProjectTransferedEvent.new(data: {
      project_id: project_id,
      old_namespace_id: old_root_namespace.id,
      old_root_namespace_id: old_root_namespace.id,
      new_namespace_id: new_root_namespace.id,
      new_root_namespace_id: new_root_namespace.id
    })
  end

  let(:update_service) { Security::Attributes::UpdateProjectConnectionsService }

  subject(:handle_event) { worker.handle_event(project_transfer_event) }

  describe '#handle_event' do
    before do
      allow(update_service).to receive(:execute)
    end

    context 'when project does not exist' do
      let(:project_id) { non_existing_record_id }

      it 'does not call the update service' do
        handle_event

        expect(update_service).not_to have_received(:execute)
      end
    end

    context 'when project exists' do
      let(:project_id) { project.id }

      it 'calls the update service with correct parameters' do
        handle_event

        expect(update_service).to have_received(:execute).with(
          project_ids: [project.id],
          new_root_namespace_id: new_root_namespace.id
        )
      end
    end
  end
end
