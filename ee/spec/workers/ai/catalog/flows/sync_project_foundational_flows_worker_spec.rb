# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::SyncProjectFoundationalFlowsWorker, feature_category: :ai_abstraction_layer do
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, group: group, creator: user) }

  subject(:worker) { described_class.new }

  describe '#perform' do
    let(:sync_service) { instance_double(Ai::Catalog::Flows::SyncFoundationalFlowsService) }

    before do
      allow(Ai::Catalog::Flows::SyncFoundationalFlowsService).to receive(:new).and_return(sync_service)
      allow(sync_service).to receive(:execute)
    end

    context 'when project does not exist' do
      it 'returns early without error' do
        expect(Ai::Catalog::Flows::SyncFoundationalFlowsService).not_to receive(:new)

        expect { worker.perform(non_existing_record_id, user.id) }.not_to raise_error
      end
    end

    context 'when project has no group' do
      let_it_be(:personal_project) { create(:project, :in_user_namespace) }

      it 'returns early without syncing' do
        expect(Ai::Catalog::Flows::SyncFoundationalFlowsService).not_to receive(:new)

        worker.perform(personal_project.id, user.id)
      end
    end

    context 'when duo_foundational_flows_enabled is false' do
      before do
        project.project_setting.update!(duo_foundational_flows_enabled: false)
      end

      it 'returns early without syncing' do
        expect(Ai::Catalog::Flows::SyncFoundationalFlowsService).not_to receive(:new)

        worker.perform(project.id, user.id)
      end
    end

    context 'when duo_foundational_flows_enabled is true' do
      before do
        project.project_setting.update!(duo_foundational_flows_enabled: true)
        group.namespace_settings.update!(duo_foundational_flows_enabled: true)
      end

      it 'syncs foundational flows and calls service' do
        expect(Ai::Catalog::Flows::SyncFoundationalFlowsService).to receive(:new)
          .with(project, current_user: user)
          .and_return(sync_service)
        expect(sync_service).to receive(:execute)

        worker.perform(project.id, user.id)
      end

      context 'when user_id is nil' do
        it 'calls service with nil user' do
          expect(Ai::Catalog::Flows::SyncFoundationalFlowsService).to receive(:new)
            .with(project, current_user: nil)
            .and_return(sync_service)
          expect(sync_service).to receive(:execute)

          worker.perform(project.id, nil)
        end
      end

      context 'when user does not exist' do
        it 'calls service with nil user' do
          expect(Ai::Catalog::Flows::SyncFoundationalFlowsService).to receive(:new)
            .with(project, current_user: nil)
            .and_return(sync_service)
          expect(sync_service).to receive(:execute)

          worker.perform(project.id, non_existing_record_id)
        end
      end
    end
  end

  describe 'worker attributes' do
    it 'has the correct feature category' do
      expect(described_class.get_feature_category).to eq(:ai_abstraction_layer)
    end

    it 'has the correct urgency' do
      expect(described_class.get_urgency).to eq(:low)
    end

    it 'is idempotent' do
      expect(described_class.idempotent?).to be(true)
    end

    it 'does not have external dependencies' do
      expect(described_class.worker_has_external_dependencies?).to be(false)
    end
  end
end
