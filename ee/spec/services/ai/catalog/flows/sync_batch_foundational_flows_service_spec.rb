# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::SyncBatchFoundationalFlowsService, feature_category: :ai_abstraction_layer do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:group) { create(:group, organization: organization) }
  let_it_be(:project1) { create(:project, group: group) }
  let_it_be(:project2) { create(:project, group: group) }
  let_it_be(:service_account) { create(:user, :service_account, provisioned_by_group: group) }
  let_it_be(:catalog_item) do
    create(:ai_catalog_item, :flow, :with_foundational_flow_reference, organization: organization)
  end

  let_it_be(:parent_consumer) do
    create(:ai_catalog_item_consumer,
      group: group,
      item: catalog_item,
      service_account: service_account,
      pinned_version_prefix: '1.0.0'
    )
  end

  let(:projects) { [project1, project2] }
  let_it_be(:current_user) { create(:user) }

  let(:parent_consumers) { { catalog_item.id => parent_consumer } }
  let(:catalog_items) { { catalog_item.id => catalog_item } }
  let(:flow_triggers_by_item) { {} }

  subject(:service) do
    described_class.new(
      projects,
      parent_consumers: parent_consumers,
      catalog_items: catalog_items,
      flow_triggers_by_item: flow_triggers_by_item,
      current_user: current_user
    )
  end

  describe '#execute' do
    context 'when projects have no enabled flows' do
      before do
        allow(project1).to receive(:enabled_flow_catalog_item_ids).and_return([])
        allow(project2).to receive(:enabled_flow_catalog_item_ids).and_return([])
      end

      it 'does not create any records' do
        expect { service.execute }.not_to change { Ai::Catalog::ItemConsumer.count }
      end
    end

    context 'when projects have enabled flows' do
      before do
        allow(project1).to receive(:enabled_flow_catalog_item_ids).and_return([catalog_item.id])
        allow(project2).to receive(:enabled_flow_catalog_item_ids).and_return([catalog_item.id])
      end

      it 'creates item consumers for each project' do
        expect { service.execute }.to change { Ai::Catalog::ItemConsumer.count }.by(2)
      end

      it 'creates project members for the service account' do
        expect { service.execute }.to change { ProjectMember.where(user_id: service_account.id).count }.by(2)
      end

      it 'creates project authorizations for the service account' do
        expect { service.execute }.to change { ProjectAuthorization.where(user_id: service_account.id).count }.by(2)
      end

      it 'sets correct attributes on item consumers' do
        service.execute

        consumer = Ai::Catalog::ItemConsumer.find_by(project: project1, ai_catalog_item_id: catalog_item.id)

        expect(consumer).to have_attributes(
          parent_item_consumer_id: parent_consumer.id,
          pinned_version_prefix: '1.0.0',
          enabled: true,
          locked: true
        )
      end

      context 'when item consumers already exist' do
        before do
          create(:ai_catalog_item_consumer, project: project1, item: catalog_item,
            parent_item_consumer: parent_consumer)
        end

        it 'skips existing consumers' do
          expect { service.execute }.to change { Ai::Catalog::ItemConsumer.count }.by(1)
        end
      end

      context 'when members already exist' do
        before do
          create(:project_member, :developer, source: project1, user: service_account)
        end

        it 'skips existing members' do
          expect { service.execute }.to change { ProjectMember.where(user_id: service_account.id).count }.by(1)
        end
      end
    end

    context 'when flow has triggers defined' do
      let(:flow_triggers_by_item) { { catalog_item.id => [1] } }

      before do
        allow(project1).to receive(:enabled_flow_catalog_item_ids).and_return([catalog_item.id])
        allow(project2).to receive(:enabled_flow_catalog_item_ids).and_return([])
      end

      it 'creates flow triggers' do
        expect { service.execute }.to change { Ai::FlowTrigger.count }.by(1)
      end

      it 'sets correct attributes on flow trigger' do
        service.execute

        consumer = Ai::Catalog::ItemConsumer.find_by(project: project1, ai_catalog_item_id: catalog_item.id)
        trigger = Ai::FlowTrigger.find_by(project: project1, ai_catalog_item_consumer: consumer)

        expect(trigger).to have_attributes(
          event_types: [1],
          description: "Foundational flow trigger for #{catalog_item.name}"
        )
      end

      it 'emits a flow_trigger_created audit event for each inserted trigger' do
        expect { service.execute }.to change { AuditEventReader.count }.by(1)

        audit_event = AuditEventReader.last
        trigger = Ai::FlowTrigger.last

        expect(audit_event).to have_attributes(
          author: current_user,
          entity_type: 'Project',
          entity_id: project1.id,
          target_details: "#{trigger.description} (ID: #{trigger.id})"
        )
        expect(audit_event.details).to include(
          event_name: 'flow_trigger_created',
          target_type: 'Ai::FlowTrigger'
        )
      end

      context 'when current_user is nil' do
        let(:current_user) { nil }

        it 'does not emit audit events' do
          expect { service.execute }.not_to change { AuditEventReader.count }
        end
      end

      context 'when multiple projects have the flow enabled' do
        before do
          allow(project2).to receive(:enabled_flow_catalog_item_ids).and_return([catalog_item.id])
        end

        it 'emits one audit event per inserted trigger' do
          expect { service.execute }.to change { AuditEventReader.count }.by(2)
        end
      end
    end

    context 'with multiple flows enabled' do
      let_it_be(:catalog_item2) do
        create(:ai_catalog_item, :flow, :with_foundational_flow_reference, organization: organization)
      end

      let_it_be(:service_account2) { create(:user, :service_account, provisioned_by_group: group) }
      let_it_be(:parent_consumer2) do
        create(:ai_catalog_item_consumer,
          group: group,
          item: catalog_item2,
          service_account: service_account2,
          pinned_version_prefix: '2.0.0'
        )
      end

      let(:parent_consumers) do
        {
          catalog_item.id => parent_consumer,
          catalog_item2.id => parent_consumer2
        }
      end

      let(:catalog_items) do
        {
          catalog_item.id => catalog_item,
          catalog_item2.id => catalog_item2
        }
      end

      before do
        allow(project1).to receive(:enabled_flow_catalog_item_ids).and_return([catalog_item.id, catalog_item2.id])
        allow(project2).to receive(:enabled_flow_catalog_item_ids).and_return([catalog_item.id])
      end

      it 'creates item consumers for all enabled flows' do
        expect { service.execute }.to change { Ai::Catalog::ItemConsumer.count }.by(3)
      end

      it 'creates members for each service account' do
        service.execute

        expect(ProjectMember.where(source: project1, user_id: service_account.id)).to exist
        expect(ProjectMember.where(source: project1, user_id: service_account2.id)).to exist
        expect(ProjectMember.where(source: project2, user_id: service_account.id)).to exist
      end
    end
  end
end
