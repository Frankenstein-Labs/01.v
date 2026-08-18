# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attributes::CleanupBatchWorker, feature_category: :security_asset_inventories do
  let(:worker) { described_class.new }
  let(:project_ids) { [1, 2, 3, 4, 5] }
  let(:new_root_namespace_id) { 123 }

  subject(:perform) { worker.perform(project_ids, new_root_namespace_id) }

  describe '#perform' do
    let(:update_service) { Security::Attributes::UpdateProjectConnectionsService }

    before do
      allow(update_service).to receive(:execute)
    end

    it 'calls the update service with correct parameters' do
      perform

      expect(update_service).to have_received(:execute).with(
        project_ids: project_ids,
        new_root_namespace_id: new_root_namespace_id
      )
    end
  end
end
