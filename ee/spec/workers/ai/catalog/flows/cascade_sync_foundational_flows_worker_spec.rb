# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::CascadeSyncFoundationalFlowsWorker, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:subgroup, freeze: false) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:subgroup_project, freeze: false) { create(:project, group: subgroup) }

  subject(:worker) { described_class.new }

  describe '#perform' do
    let(:seed_service) { instance_double(Ai::Catalog::Flows::SeedFoundationalFlowsService) }
    let(:sync_service) { instance_double(Ai::Catalog::Flows::SyncFoundationalFlowsService) }
    let(:batch_sync_service) { instance_double(Ai::Catalog::Flows::SyncBatchFoundationalFlowsService) }

    before do
      allow(Ai::Catalog::Flows::SeedFoundationalFlowsService).to receive(:new).and_return(seed_service)
      allow(seed_service).to receive(:execute)

      allow(Ai::Catalog::Flows::SyncFoundationalFlowsService).to receive(:new).and_return(sync_service)
      allow(sync_service).to receive(:execute)

      allow(Ai::Catalog::Flows::SyncBatchFoundationalFlowsService).to receive(:new).and_return(batch_sync_service)
      allow(batch_sync_service).to receive(:execute)
    end

    it 'calls SeedFoundationalFlowsService for the organization' do
      expect(Ai::Catalog::Flows::SeedFoundationalFlowsService)
        .to receive(:new).with(organization: group.organization)
                         .and_return(seed_service)
      expect(seed_service).to receive(:execute)

      worker.perform(group.id, user.id, nil)
    end

    it 'syncs the parent group' do
      expect(Ai::Catalog::Flows::SyncFoundationalFlowsService)
        .to receive(:new).with(group, current_user: user)
                         .and_return(sync_service)
      expect(sync_service).to receive(:execute)

      worker.send(:sync_groups, group, user)
    end

    context 'when user_id is not provided' do
      it 'passes nil as current_user to the services' do
        expect(Ai::Catalog::Flows::SeedFoundationalFlowsService)
          .to receive(:new).with(organization: group.organization)
                           .and_return(seed_service)

        expect(Ai::Catalog::Flows::SyncFoundationalFlowsService)
          .to receive(:new).with(group, current_user: nil)
                           .and_return(sync_service)

        worker.perform(group.id, nil, nil)
      end
    end

    context 'when user does not exist' do
      it 'passes nil as current_user to the services' do
        expect(Ai::Catalog::Flows::SeedFoundationalFlowsService)
          .to receive(:new).with(organization: group.organization)
                           .and_return(seed_service)

        expect(Ai::Catalog::Flows::SyncFoundationalFlowsService)
          .to receive(:new).with(group, current_user: nil)
                           .and_return(sync_service)

        worker.perform(group.id, non_existing_record_id, nil)
      end
    end

    context 'when group does not exist' do
      it 'does not call any service' do
        expect(Ai::Catalog::Flows::SeedFoundationalFlowsService).not_to receive(:new)
        expect(Ai::Catalog::Flows::SyncFoundationalFlowsService).not_to receive(:new)

        worker.perform(non_existing_record_id, user.id)
        worker.perform(non_existing_record_id, user.id, nil)
      end
    end

    context 'when group has enabled flows with parent consumers' do
      let_it_be(:catalog_item) { create(:ai_catalog_item, :flow, :with_foundational_flow_reference) }
      let_it_be(:service_account) { create(:user, :service_account, provisioned_by_group: group) }
      let_it_be(:parent_consumer) do
        create(:ai_catalog_item_consumer, group: group, item: catalog_item, service_account: service_account)
      end

      before do
        create(:ai_catalog_enabled_foundational_flow, namespace: group, catalog_item: catalog_item)
        group.namespace_settings.update!(duo_foundational_flows_enabled: true)
      end

      it 'calls SyncBatchFoundationalFlowsService for project batches' do
        expect(Ai::Catalog::Flows::SyncBatchFoundationalFlowsService)
          .to receive(:new).at_least(:once).and_return(batch_sync_service)
        expect(batch_sync_service).to receive(:execute).at_least(:once)

        worker.perform(group.id, user.id, nil)
      end

      it 'does not call SyncFoundationalFlowsService for individual projects' do
        expect(Ai::Catalog::Flows::SyncFoundationalFlowsService)
          .to receive(:new).with(group, current_user: user).and_return(sync_service)
        expect(Ai::Catalog::Flows::SyncFoundationalFlowsService)
          .not_to receive(:new).with(kind_of(Project), any_args)

        worker.perform(group.id, user.id, nil)
      end

      context 'when cascading from a subgroup' do
        before do
          subgroup.namespace_settings.update!(duo_foundational_flows_enabled: true)
          subgroup_project.project_setting.update!(duo_foundational_flows_enabled: true)
        end

        it 'uses parent consumers from the root ancestor' do
          expect(Ai::Catalog::Flows::SyncBatchFoundationalFlowsService)
            .to receive(:new).with(
              include(subgroup_project),
              parent_consumers: { catalog_item.id => parent_consumer },
              catalog_items: kind_of(Hash),
              flow_triggers_by_item: kind_of(Hash),
              current_user: user
            ).and_return(batch_sync_service)
          expect(batch_sync_service).to receive(:execute)

          worker.perform(subgroup.id, user.id, nil)
        end
      end

      context 'when foundational flows are disabled on a project' do
        let_it_be(:project_consumer) do
          create(:ai_catalog_item_consumer, project: project, item: catalog_item,
            parent_item_consumer: parent_consumer)
        end

        before do
          project.project_setting.update!(duo_foundational_flows_enabled: false)
        end

        it 'removes foundational flow consumers from the disabled project' do
          expect { worker.perform(group.id, user.id, nil) }
            .to change { Ai::Catalog::ItemConsumer.where(project: project).count }.from(1).to(0)
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

    it 'has external dependencies' do
      expect(described_class.worker_has_external_dependencies?).to be(true)
    end
  end
end
