# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::ProcessProjectTransferEventsWorker, feature_category: :security_asset_inventories do
  let(:worker) { described_class.new }

  describe '#handle_event' do
    let_it_be(:old_namespace) { create(:group) }
    let_it_be(:new_namespace) { create(:group) }

    let!(:project) { create(:project, namespace: old_namespace) }
    let!(:projct_analyzer_status) { create(:analyzer_project_status, analyzer_type: :sast, project: project) }
    let!(:inventory_filter) { create(:security_inventory_filters, project: project) }
    let_it_be(:security_category) { create(:security_category, namespace: old_namespace) }
    let_it_be(:security_attribute) do
      create(:security_attribute, namespace: old_namespace, security_category: security_category)
    end

    let!(:project_to_security_attribute) do
      create(:project_to_security_attribute,
        project: project,
        security_attribute: security_attribute,
        traversal_ids: old_namespace.traversal_ids)
    end

    let(:update_ancestors_service) { Security::AnalyzersStatus::UpdateProjectAncestorsStatusesService }
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

    subject(:handle_event) { worker.handle_event(project_event) }

    before do
      allow(update_ancestors_service).to receive(:execute)
      project.update!(namespace: new_namespace)
    end

    context 'when there is no project associated with the event' do
      let(:project_id) { non_existing_record_id }

      it 'does not call the service layer logic' do
        handle_event

        expect(update_ancestors_service).not_to have_received(:execute)
      end
    end

    context 'when there is a project associated with the event' do
      it 'updates analyzer statuses traversal_id and calls the service layer logic' do
        expect { handle_event }.to change { projct_analyzer_status.reload.traversal_ids }
          .from(old_namespace.traversal_ids).to(new_namespace.traversal_ids)

        expect(update_ancestors_service).to have_received(:execute).with(project)
      end
    end

    context 'when there is an inventory_filter record' do
      it 'updates inventory_filter record with new traversal ids' do
        expect { handle_event }.to change { inventory_filter.reload.traversal_ids }
          .from(old_namespace.traversal_ids).to(new_namespace.traversal_ids)
      end
    end

    context 'when there is a project_to_security_attribute record' do
      it 'updates project_to_security_attribute record with new traversal ids' do
        expect { handle_event }.to change { project_to_security_attribute.reload.traversal_ids }
          .from(old_namespace.traversal_ids).to(new_namespace.traversal_ids)
      end
    end
  end
end
