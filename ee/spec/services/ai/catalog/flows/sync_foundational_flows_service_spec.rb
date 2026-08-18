# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::SyncFoundationalFlowsService, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group, owners: user) }
  let_it_be_with_reload(:project) { create(:project, group: group) }

  let_it_be(:flow1) do
    create(:ai_catalog_item, :with_foundational_flow_reference, :public, organization: group.organization)
  end

  let_it_be(:flow2) do
    create(:ai_catalog_item, :with_foundational_flow_reference, :public, organization: group.organization)
  end

  let_it_be(:flow3) do
    create(:ai_catalog_item, :with_foundational_flow_reference, :public, organization: group.organization)
  end

  let(:container) { group }
  let(:current_user) { user }

  subject(:service) { described_class.new(container, current_user: current_user) }

  def expect_sync_failure_log(container, current_user)
    container_id_field = container.is_a?(Project) ? Labkit::Fields::GL_PROJECT_ID : Labkit::Fields::GL_NAMESPACE_ID
    expected_fields = {
      Labkit::Fields::LOG_MESSAGE => 'Foundational flow was not synchronized',
      container_id_field => container.id
    }
    expected_fields[Labkit::Fields::GL_USER_ID] = current_user.id if current_user

    expect(Gitlab::AppLogger).to receive(:warn).with(hash_including(expected_fields))
  end

  before do
    allow(Ai::Catalog::Item).to receive(:foundational_flow_ids).and_return([flow1.id, flow2.id, flow3.id])
  end

  describe '#execute' do
    context 'when foundational flows are enabled' do
      context 'when container is a group' do
        before do
          container.namespace_settings.update!(duo_foundational_flows_enabled: true)
        end

        it 'calls CreateService for each enabled flow' do
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id, flow2.id])
          allow(Ability).to receive(:allowed?).and_return(true)

          create_service = instance_double(Ai::Catalog::ItemConsumers::CreateService)
          allow(create_service).to receive(:execute).and_return(ServiceResponse.success)
          allow(Ai::Catalog::ItemConsumers::CreateService).to receive(:new).and_return(create_service)

          service.execute

          expect(Ai::Catalog::ItemConsumers::CreateService).to have_received(:new).twice
        end

        it 'removes consumers not in the enabled list' do
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])
          allow(Ability).to receive(:allowed?).and_return(true)

          expect(container).to receive(:remove_foundational_flow_consumers).with([flow2.id, flow3.id])

          service.execute
        end

        it 'handles empty enabled flows list' do
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([])

          expect(container).to receive(:remove_foundational_flow_consumers).with([flow1.id, flow2.id, flow3.id])

          service.execute
        end
      end

      context 'when container is a project' do
        let(:container) { project }

        before do
          container.project_setting.update!(duo_foundational_flows_enabled: true)
          allow(Ability).to receive(:allowed?).and_return(true)
        end

        it 'creates consumers with parent consumer for flows' do
          parent_consumer = create(:ai_catalog_item_consumer, group: group, item: flow1)
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])
          allow(group).to receive(:configured_ai_catalog_items).and_return([parent_consumer])

          create_service = instance_double(Ai::Catalog::ItemConsumers::CreateService)
          allow(create_service).to receive(:execute).and_return(
            ServiceResponse.success(payload: { item_consumer: parent_consumer }))

          expect(Ai::Catalog::ItemConsumers::CreateService).to receive(:new)
            .with(
              container: container,
              current_user: user,
              params: hash_including(item: flow1, parent_item_consumer: parent_consumer)
            ).and_return(create_service)

          service.execute

          expect(create_service).to have_received(:execute)
        end

        it 'skips flows without parent consumers' do
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])

          expect(Ai::Catalog::ItemConsumers::CreateService).not_to receive(:new)
          expect_sync_failure_log(container, current_user)

          service.execute
        end
      end

      context 'when trigger creation' do
        let(:container) { project }
        let(:create_service) { instance_double(Ai::Catalog::ItemConsumers::CreateService) }
        let(:flow) do
          create(:ai_catalog_item, :flow, :public, foundational_flow_reference: 'developer/v1',
            organization: group.organization)
        end

        before do
          container.project_setting.update!(duo_foundational_flows_enabled: true)
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow.id])
          allow(Ability).to receive(:allowed?).with(user, :provision_ai_catalog, container).and_return(true)
          allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_item, flow).and_return(true)
          allow(Ability).to receive(:allowed?).with(user, :manage_ai_flow_triggers, container).and_return(true)
          allow(Ai::Catalog::ItemConsumers::CreateService).to receive(:new).and_return(create_service)
        end

        context 'when consumer is group-level' do
          before do
            group_consumer = build(:ai_catalog_item_consumer, group: group, item: flow)
            allow(create_service).to receive(:execute).and_return(
              ServiceResponse.success(payload: { item_consumer: group_consumer })
            )
          end

          it 'does not create triggers' do
            expect(Ai::FlowTriggers::CreateService).not_to receive(:new)

            described_class.new(container, current_user: user).execute
          end
        end

        context 'when parent consumer has no service account' do
          before do
            parent_consumer = create(:ai_catalog_item_consumer, group: group, item: flow)
            allow(parent_consumer).to receive(:service_account).and_return(nil)

            project_consumer = build(:ai_catalog_item_consumer,
              project: container,
              item: flow1,
              parent_item_consumer: parent_consumer
            )

            allow(create_service).to receive(:execute).and_return(
              ServiceResponse.success(payload: { item_consumer: project_consumer })
            )
          end

          it 'does not create triggers' do
            expect(Ai::FlowTriggers::CreateService).not_to receive(:new)

            described_class.new(container, current_user: user).execute
          end
        end

        context 'when CreateService reports the item is already configured on re-enable' do
          # Regression test for the item_already_configured? fix. The sync
          # service now relies on the structured :already_configured reason
          # returned by CreateService rather than matching translated
          # messages. This test is red on master (no reason-based matcher)
          # and green with the fix.
          let(:service_account) do
            create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: group)
          end

          let!(:parent_consumer) do
            create(:ai_catalog_item_consumer, group: group, item: flow, service_account: service_account)
          end

          let!(:project_consumer) do
            create(:ai_catalog_item_consumer, project: container, item: flow, parent_item_consumer: parent_consumer)
          end

          it 'falls back to the existing consumer and creates triggers when CreateService reports already_configured' do
            allow(create_service).to receive(:execute).and_return(
              ServiceResponse.error(message: ['Agent or flow already enabled'], reason: :already_configured)
            )

            expect_next_instance_of(::Ai::FlowTriggers::CreateService) do |instance|
              expect(instance).to receive(:execute).with(
                hash_including(ai_catalog_item_consumer_id: project_consumer.id)
              ).and_call_original
            end

            described_class.new(container, current_user: user).execute
          end

          it 'does not fall back when the failure reason is not already_configured' do
            allow(create_service).to receive(:execute).and_return(
              ServiceResponse.error(message: ['Agent or flow already enabled'])
            )

            expect(::Ai::FlowTriggers::CreateService).not_to receive(:new)
            expect_sync_failure_log(container, current_user)

            described_class.new(container, current_user: user).execute
          end
        end

        context 'when parent consumer has service account' do
          let(:service_account) do
            create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: group)
          end

          let(:parent_consumer) do
            create(:ai_catalog_item_consumer, group: group, item: flow, service_account: service_account)
          end

          let(:project_consumer) do
            create(:ai_catalog_item_consumer, project: container, item: flow, parent_item_consumer: parent_consumer)
          end

          before do
            allow(create_service).to receive(:execute).and_return(
              ServiceResponse.success(payload: { item_consumer: project_consumer })
            )
          end

          it 'creates triggers' do
            expect_next_instance_of(::Ai::FlowTriggers::CreateService) do |instance|
              expect(instance).to receive(:execute).with(
                hash_including(ai_catalog_item_consumer_id: project_consumer.id)
              ).and_call_original
            end
            described_class.new(container, current_user: user).execute
          end

          context 'when all triggers already exist as separate rows' do
            before do
              create(:ai_flow_trigger,
                :for_catalog_consumer,
                project: container,
                ai_catalog_item_consumer: project_consumer,
                event_types: [::Ai::FlowTrigger::EVENT_TYPES[:assign]]
              )
              create(:ai_flow_trigger,
                :for_catalog_consumer,
                project: container,
                ai_catalog_item_consumer: project_consumer,
                event_types: [::Ai::FlowTrigger::EVENT_TYPES[:mention]]
              )
              create(:ai_flow_trigger,
                :for_catalog_consumer,
                project: container,
                ai_catalog_item_consumer: project_consumer,
                event_types: [::Ai::FlowTrigger::EVENT_TYPES[:merge_request]]
              )
            end

            it 'does not create a duplicate trigger' do
              expect(Ai::FlowTriggers::CreateService).not_to receive(:new)

              described_class.new(container, current_user: user).execute
            end
          end

          context 'when all triggers already exist in a single row' do
            before do
              create(:ai_flow_trigger,
                :for_catalog_consumer,
                ai_catalog_item_consumer: project_consumer,
                project: container,
                event_types: [
                  ::Ai::FlowTrigger::EVENT_TYPES[:assign],
                  ::Ai::FlowTrigger::EVENT_TYPES[:mention],
                  ::Ai::FlowTrigger::EVENT_TYPES[:merge_request]
                ]
              )
            end

            it 'does not create a duplicate trigger' do
              expect(Ai::FlowTriggers::CreateService).not_to receive(:new)

              described_class.new(container, current_user: user).execute
            end
          end
        end

        context 'when flow definition does not have triggers' do
          let(:service_account) do
            create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: group)
          end

          before do
            parent_consumer = create(:ai_catalog_item_consumer, group: group, item: flow)
            allow(parent_consumer).to receive(:service_account).and_return(service_account)

            project_consumer = build(:ai_catalog_item_consumer,
              project: container,
              item: flow,
              parent_item_consumer: parent_consumer
            )

            allow(create_service).to receive(:execute).and_return(
              ServiceResponse.success(payload: { item_consumer: project_consumer })
            )
            allow(group).to receive(:configured_ai_catalog_items).and_return([parent_consumer])
          end

          it 'does not create triggers when flow definition is missing' do
            allow(Ai::Catalog::FoundationalFlow).to receive(:[]).and_return(nil)

            expect(Ai::FlowTriggers::CreateService).not_to receive(:new)

            described_class.new(container, current_user: user).execute
          end

          it 'does not create triggers when flow definition has no triggers' do
            flow_def = instance_double(Ai::Catalog::FoundationalFlow, triggers: [])
            allow(Ai::Catalog::FoundationalFlow).to receive(:[]).and_return(flow_def)

            expect(Ai::FlowTriggers::CreateService).not_to receive(:new)

            described_class.new(container, current_user: user).execute
          end
        end

        context 'when flow has triggers but some of the triggers already exist' do
          let(:service_account) do
            create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: group)
          end

          before do
            parent_consumer = create(:ai_catalog_item_consumer, group: group, item: flow)
            allow(parent_consumer).to receive(:service_account).and_return(service_account)

            project_consumer = build(:ai_catalog_item_consumer,
              project: container,
              item: flow,
              parent_item_consumer: parent_consumer
            )

            allow(create_service).to receive(:execute).and_return(
              ServiceResponse.success(payload: { item_consumer: project_consumer })
            )
            allow(group).to receive(:configured_ai_catalog_items).and_return([parent_consumer])

            # Create existing trigger for 'assign' event
            create(:ai_flow_trigger,
              project: container,
              user: service_account,
              event_types: [::Ai::FlowTrigger::EVENT_TYPES[:assign]]
            )
          end

          it 'only creates triggers for new events' do
            flow_def = instance_double(Ai::Catalog::FoundationalFlow, triggers: [
              ::Ai::FlowTrigger::EVENT_TYPES[:assign], ::Ai::FlowTrigger::EVENT_TYPES[:mention]
            ])
            allow(Ai::Catalog::FoundationalFlow).to receive(:[]).and_return(flow_def)

            expect_next_instance_of(::Ai::FlowTriggers::CreateService) do |instance|
              expect(instance).to receive(:execute).with(
                hash_including(event_types: [::Ai::FlowTrigger::EVENT_TYPES[:mention]])
              ).and_call_original
            end

            described_class.new(container, current_user: user).execute
          end
        end

        context 'when event type mapping is invalid' do
          let(:service_account) do
            create(:user, :service_account, composite_identity_enforced: true, provisioned_by_group: group)
          end

          before do
            parent_consumer = create(:ai_catalog_item_consumer, group: group, item: flow)
            allow(parent_consumer).to receive(:service_account).and_return(service_account)

            project_consumer = build(:ai_catalog_item_consumer,
              project: container,
              item: flow,
              parent_item_consumer: parent_consumer
            )

            allow(create_service).to receive(:execute).and_return(
              ServiceResponse.success(payload: { item_consumer: project_consumer })
            )
            allow(group).to receive(:configured_ai_catalog_items).and_return([parent_consumer])
          end

          it 'skips invalid event types' do
            flow_def = instance_double(Ai::Catalog::FoundationalFlow,
              triggers: [::Ai::FlowTrigger::EVENT_TYPES[:assign], 'Invalid trigger'])
            allow(Ai::Catalog::FoundationalFlow).to receive(:[]).and_return(flow_def)

            expect_next_instance_of(::Ai::FlowTriggers::CreateService) do |instance|
              expect(instance).to receive(:execute).with(
                hash_including(event_types: [::Ai::FlowTrigger::EVENT_TYPES[:assign]])
              ).and_call_original
            end

            described_class.new(container, current_user: user).execute
          end
        end
      end

      context 'when user does not have permission' do
        before do
          container.namespace_settings.update!(duo_foundational_flows_enabled: true)
        end

        let(:unauthorized_user) { create(:user) }
        let(:current_user) { unauthorized_user }

        it 'does not create consumers' do
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])

          expect(Ai::Catalog::ItemConsumers::CreateService).not_to receive(:new)

          service.execute
        end

        it 'still removes consumers not in the enabled list' do
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])

          expect(container).to receive(:remove_foundational_flow_consumers).with([flow2.id, flow3.id])

          service.execute
        end

        it 'logs that synchronization was skipped' do
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])
          expect_sync_failure_log(container, unauthorized_user)

          service.execute
        end
      end

      context 'when current_user is nil' do
        before do
          container.namespace_settings.update!(duo_foundational_flows_enabled: true)
        end

        let(:current_user) { nil }

        it 'does not create consumers' do
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])
          expect(Ai::Catalog::ItemConsumers::CreateService).not_to receive(:new)
          expect_sync_failure_log(container, nil)

          service.execute
        end
      end

      context 'when item is already configured' do
        before do
          container.namespace_settings.update!(duo_foundational_flows_enabled: true)
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])
          allow(Ability).to receive(:allowed?).with(user, :provision_ai_catalog, container).and_return(true)
          allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_item, flow1).and_return(true)
        end

        it 'treats an already_configured reason as already-configured and continues without raising' do
          create_service = instance_double(Ai::Catalog::ItemConsumers::CreateService)
          error_result = ServiceResponse.error(
            message: ['Agent or flow already enabled'],
            reason: :already_configured
          )
          allow(create_service).to receive(:execute).and_return(error_result)
          allow(Ai::Catalog::ItemConsumers::CreateService).to receive(:new).and_return(create_service)

          expect { service.execute }.not_to raise_error
        end
      end

      context 'when catalog item is not found' do
        before do
          container.namespace_settings.update!(duo_foundational_flows_enabled: true)
          allow(Ability).to receive(:allowed?).and_return(true)
        end

        it 'tracks the exception and continues' do
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([999])

          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            instance_of(ActiveRecord::RecordNotFound),
            catalog_item_id: 999,
            container_id: container.id
          )
          expect_sync_failure_log(container, current_user)

          expect { service.execute }.not_to raise_error
        end
      end

      context 'when user cannot read catalog item' do
        before do
          container.namespace_settings.update!(duo_foundational_flows_enabled: true)
          allow(Ability).to receive(:allowed?).with(user, :provision_ai_catalog, container).and_return(true)
          allow(Ability).to receive(:allowed?).with(user, :read_ai_catalog_item, flow1).and_return(false)
        end

        it 'does not create consumer' do
          allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])

          expect(Ai::Catalog::ItemConsumers::CreateService).not_to receive(:new)
          expect_sync_failure_log(container, current_user)

          service.execute
        end
      end
    end

    context 'when duo_features_enabled is false (off by default)' do
      before do
        container.namespace_settings.update!(
          duo_foundational_flows_enabled: true,
          duo_features_enabled: false,
          lock_duo_features_enabled: false
        )
        allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])
      end

      it 'creates consumers using provision_ai_catalog permission' do
        create_service = instance_double(Ai::Catalog::ItemConsumers::CreateService)
        allow(create_service).to receive(:execute).and_return(ServiceResponse.success)
        allow(Ai::Catalog::ItemConsumers::CreateService).to receive(:new).and_return(create_service)

        # Regression check to ensure the admin_ai_catalog_item_consumer is not used
        # since it is prevented during provisioning
        allow(Ability).to receive(:allowed?).and_call_original
        expect(Ability).to receive(:allowed?).with(user, :provision_ai_catalog, container).at_least(:once)
          .and_call_original
        expect(Ability).not_to receive(:allowed?).with(user, :admin_ai_catalog_item_consumer, container)

        service.execute

        expect(Ai::Catalog::ItemConsumers::CreateService).to have_received(:new)
      end

      it 'allows provisioning' do
        create_service = instance_double(Ai::Catalog::ItemConsumers::CreateService)
        allow(create_service).to receive(:execute).and_return(ServiceResponse.success)
        allow(Ai::Catalog::ItemConsumers::CreateService).to receive(:new).and_return(create_service)

        expect { service.execute }.not_to raise_error
        expect(Ai::Catalog::ItemConsumers::CreateService).to have_received(:new)
      end

      it 'removes consumers not in the enabled list' do
        expect(container).to receive(:remove_foundational_flow_consumers).with([flow2.id, flow3.id])

        service.execute
      end
    end

    context 'when duo_features_enabled is locked (never on)' do
      before do
        container.namespace_settings.update!(
          duo_foundational_flows_enabled: true,
          duo_features_enabled: false,
          lock_duo_features_enabled: true
        )
        allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])
        container.add_maintainer(maintainer)
      end

      let(:maintainer) { create(:user) }
      let(:current_user) { maintainer }

      it 'does not create consumers' do
        expect(Ai::Catalog::ItemConsumers::CreateService).not_to receive(:new)

        service.execute
      end

      it 'still removes consumers not in the enabled list' do
        expect(container).to receive(:remove_foundational_flow_consumers).with([flow2.id, flow3.id])

        service.execute
      end
    end

    context 'when foundational flows are disabled' do
      before do
        container.namespace_settings.update!(duo_foundational_flows_enabled: false)
      end

      it 'removes all foundational flow consumers' do
        expect(container).to receive(:remove_foundational_flow_consumers).with([flow1.id, flow2.id, flow3.id])

        service.execute
      end

      it 'does not create any consumers' do
        expect(Ai::Catalog::ItemConsumers::CreateService).not_to receive(:new)

        service.execute
      end
    end
  end

  describe 'end-to-end provisioning (no Ability stubs)' do
    let(:e2e_user) { create(:user) }
    let(:e2e_group) { create(:group, owners: e2e_user) }
    let(:foundational_flow) do
      create(:ai_catalog_item, :with_foundational_flow_reference, :with_released_version, :public,
        organization: e2e_group.organization)
    end

    let(:container) { e2e_group }
    let(:current_user) { e2e_user }

    before do
      allow(Ai::Catalog::Item).to receive(:foundational_flow_ids).and_return([foundational_flow.id])
      allow(e2e_group).to receive(:enabled_flow_catalog_item_ids).and_return([foundational_flow.id])
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
    end

    context 'when duo_features_enabled is false and not locked (off by default SaaS scenario)' do
      before do
        e2e_group.namespace_settings.update!(
          duo_foundational_flows_enabled: true,
          duo_features_enabled: false,
          lock_duo_features_enabled: false
        )
      end

      it 'creates the expected service account via the full policy + service chain' do
        expect { service.execute }.to change { e2e_group.reload.service_accounts.count }.from(0).to(1)

        service_account = e2e_group.service_accounts.first
        expect(service_account.username).to start_with('duo-')
        expect(e2e_group.configured_ai_catalog_items.count).to eq(1)
      end
    end

    context 'when duo_features_enabled is locked to false (never on)' do
      before do
        e2e_group.namespace_settings.update!(
          duo_foundational_flows_enabled: true,
          duo_features_enabled: false,
          lock_duo_features_enabled: true
        )
      end

      it 'does not create a service account' do
        expect { service.execute }.not_to change { e2e_group.reload.service_accounts.count }
        expect(e2e_group.configured_ai_catalog_items.count).to eq(0)
      end
    end

    context 'when duo_features_enabled is true (on by default)' do
      before do
        e2e_group.namespace_settings.update!(
          duo_foundational_flows_enabled: true,
          duo_features_enabled: true,
          lock_duo_features_enabled: false
        )
      end

      it 'creates the expected service account via the full policy + service chain' do
        expect { service.execute }.to change { e2e_group.reload.service_accounts.count }.from(0).to(1)
        expect(e2e_group.configured_ai_catalog_items.count).to eq(1)
      end
    end
  end

  describe '#foundational_flows_enabled?' do
    context 'when container is a Project' do
      let(:container) { project }

      it 'returns true when duo_foundational_flows_enabled is true' do
        container.project_setting.update!(duo_foundational_flows_enabled: true)

        expect(service.send(:foundational_flows_enabled?)).to be(true)
      end

      it 'returns false when duo_foundational_flows_enabled is false' do
        container.project_setting.update!(duo_foundational_flows_enabled: false)

        expect(service.send(:foundational_flows_enabled?)).to be(false)
      end

      it 'returns nil when project_setting is nil' do
        allow(container).to receive(:project_setting).and_return(nil)

        expect(service.send(:foundational_flows_enabled?)).to be_nil
      end
    end

    context 'when container is a Group' do
      let(:container) { group }

      it 'returns true when duo_foundational_flows_enabled is true' do
        container.namespace_settings.update!(duo_foundational_flows_enabled: true)

        expect(service.send(:foundational_flows_enabled?)).to be(true)
      end

      it 'returns false when duo_foundational_flows_enabled is false' do
        container.namespace_settings.update!(duo_foundational_flows_enabled: false)

        expect(service.send(:foundational_flows_enabled?)).to be(false)
      end

      it 'returns nil when namespace_settings is nil' do
        allow(container).to receive(:namespace_settings).and_return(nil)

        expect(service.send(:foundational_flows_enabled?)).to be_nil
      end
    end

    context 'when project is in a subgroup' do
      let_it_be(:subgroup) { create(:group, parent: group) }
      let_it_be(:subgroup_project) { create(:project, group: subgroup) }
      let(:container) { subgroup_project }

      before do
        container.project_setting.update!(duo_foundational_flows_enabled: true)
        allow(Ability).to receive(:allowed?).and_return(true)
      end

      it 'looks up parent consumer from root ancestor, not immediate parent' do
        # Parent consumer is on the root group, not the subgroup
        parent_consumer = create(:ai_catalog_item_consumer, group: group, item: flow1)
        allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])

        create_service = instance_double(Ai::Catalog::ItemConsumers::CreateService)
        allow(create_service).to receive(:execute).and_return(ServiceResponse.success)
        allow(group).to receive(:configured_ai_catalog_items).and_return([parent_consumer])

        expect(Ai::Catalog::ItemConsumers::CreateService).to receive(:new)
           .with(
             container: container,
             current_user: user,
             params: hash_including(item: flow1, parent_item_consumer: parent_consumer)
           ).and_return(create_service)

        service.execute

        expect(create_service).to have_received(:execute)
      end

      it 'skips flows when parent consumer does not exist on root ancestor' do
        # No parent consumer on root ancestor
        allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])

        expect(Ai::Catalog::ItemConsumers::CreateService).not_to receive(:new)

        service.execute
      end
    end

    context 'when container is a Namespace' do
      let(:container) { create(:namespace) }

      it 'checks namespace_settings' do
        allow(container).to receive_message_chain(:namespace_settings, :duo_foundational_flows_enabled).and_return(true)

        expect(service.send(:foundational_flows_enabled?)).to be(true)
      end
    end

    context 'when container is an unsupported type' do
      let(:container) { instance_double(User) }

      it 'returns false' do
        expect(service.send(:foundational_flows_enabled?)).to be(false)
      end
    end
  end

  describe 'integration with CreateService' do
    before do
      container.namespace_settings.update!(duo_foundational_flows_enabled: true)
      allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([flow1.id])
      allow(Ability).to receive(:allowed?).and_return(true)
    end

    it 'calls CreateService with correct parameters' do
      create_service = instance_double(Ai::Catalog::ItemConsumers::CreateService)
      allow(create_service).to receive(:execute).and_return(ServiceResponse.success)

      expect(Ai::Catalog::ItemConsumers::CreateService).to receive(:new).with(
        container: container,
        current_user: user,
        params: { item: flow1 }
      ).and_return(create_service)

      service.execute
    end
  end

  describe 'error handling' do
    before do
      container.namespace_settings.update!(duo_foundational_flows_enabled: true)
    end

    it 'continues processing after missing item' do
      allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([999, flow1.id])
      allow(Ability).to receive(:allowed?).and_return(true)

      create_service = instance_double(Ai::Catalog::ItemConsumers::CreateService)
      allow(create_service).to receive(:execute).and_return(ServiceResponse.success)
      allow(Ai::Catalog::ItemConsumers::CreateService).to receive(:new).and_return(create_service)

      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
        having_attributes(message: include('999')),
        hash_including(catalog_item_id: 999, container_id: container.id)
      )

      service.execute

      expect(Ai::Catalog::ItemConsumers::CreateService).to have_received(:new).once
    end

    it 'tracks container_id in exception' do
      allow(container).to receive(:enabled_flow_catalog_item_ids).and_return([999])
      allow(Ability).to receive(:allowed?).and_return(true)

      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
        anything,
        hash_including(container_id: container.id)
      )

      service.execute
    end
  end
end
