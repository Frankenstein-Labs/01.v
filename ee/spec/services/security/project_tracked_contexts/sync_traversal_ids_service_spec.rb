# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectTrackedContexts::SyncTraversalIdsService, feature_category: :vulnerability_management do
  describe '.execute' do
    it 'instantiates a new service object and calls execute' do
      expect_next_instance_of(described_class, :project_id) do |instance|
        expect(instance).to receive(:execute)
      end

      described_class.execute(:project_id)
    end
  end

  describe '#execute' do
    let(:service_object) { described_class.new(project_id) }

    subject(:update_traversal_ids) { service_object.execute }

    context 'when there is no project with given id' do
      let(:project_id) { non_existing_record_id }

      it 'does not raise an error' do
        expect { update_traversal_ids }.not_to raise_error
      end
    end

    context 'when there is a project with given id' do
      let(:project_id) { project.id }

      let_it_be(:project) { create(:project) }
      let_it_be_with_reload(:tracked_context) do
        create(:security_project_tracked_context, :tracked, project: project)
      end

      let_it_be(:old_namespace) { create(:namespace) }

      before do
        tracked_context.update_column(:traversal_ids, old_namespace.traversal_ids)
      end

      it 'changes the traversal_ids of the tracked context record' do
        expect { update_traversal_ids }
          .to change {
                tracked_context.reload.traversal_ids
              }.from(old_namespace.traversal_ids).to(project.namespace.traversal_ids)
      end
    end
  end
end
