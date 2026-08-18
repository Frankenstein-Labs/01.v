# frozen_string_literal: true

require 'spec_helper'
require_relative './shared_examples/events_tracking'

RSpec.describe Ai::Catalog::ItemConsumers::DestroyService, feature_category: :workflow_catalog do
  using RSpec::Parameterized::TableSyntax
  include Ai::Catalog::TestHelpers

  it_behaves_like 'ItemConsumers::EventsTracking' do
    subject { described_class.new(build(:ai_catalog_item_consumer), build(:user)) }
  end

  before do
    enable_ai_catalog
  end

  describe '#execute' do
    let_it_be(:developer) { create(:user) }
    let_it_be(:maintainer) { create(:user) }
    let_it_be(:owner) { create(:user) }

    let_it_be(:group) { create(:group, developers: developer, maintainers: maintainer, owners: owner) }

    let_it_be(:service_account) { create(:user, :service_account) }
    let_it_be(:service_account_user_details) do
      create(:user_detail, user: service_account, provisioned_by_group: group)
    end

    let_it_be(:project) { create(:project, developers: service_account, group: group) }
    let_it_be(:item) { create(:ai_catalog_flow) }

    let_it_be(:third_party_flow_item) { create(:ai_catalog_third_party_flow, project: project) }

    let_it_be(:parent_item_consumer) { create(:ai_catalog_item_consumer, group:, item:, service_account:) }

    subject(:response) { described_class.new(item_consumer, current_user).execute }

    shared_examples 'creates an audit event on deletion' do |entity_type:|
      it 'creates an audit event on successful deletion', :aggregate_failures do
        event_name = "disable_ai_catalog_#{item_consumer.item.item_type}"
        entity_id = entity_type == 'Project' ? project.id : group.id
        entity_name = entity_type == 'Project' ? 'project' : 'group'

        type_display_name = if item_consumer.item.item_type == 'third_party_flow'
                              'external agent'
                            else
                              item_consumer.item.item_type
                            end

        expect { response }.to change { AuditEventReader.count }

        audit_event = AuditEventReader.last

        expect(audit_event).to have_attributes(
          author: current_user,
          entity_type: entity_type,
          entity_id: entity_id,
          target_details: "#{item_consumer.item.name} (ID: #{item_consumer.item.id})"
        )
        expect(audit_event.details).to include(
          custom_message: "Disabled AI #{type_display_name} for #{entity_name}",
          event_name: event_name,
          target_type: 'Ai::Catalog::Item'
        )
      end
    end

    context 'with a project level item consumer' do
      let_it_be_with_refind(:item_consumer) do
        create(:ai_catalog_item_consumer, item:, project:, parent_item_consumer:)
      end

      context 'when user does not have permission' do
        let(:current_user) { developer }

        it 'returns an error' do
          expect(response).to be_error
          expect(response.message).to contain_exactly("You don't have permission to disable this agent or flow")
        end

        it 'does not track internal event on failure' do
          expect { response }.not_to trigger_internal_events('delete_ai_catalog_item_consumer')
        end
      end

      context 'when user has a custom role with admin_ai_catalog_item_consumer' do
        let_it_be(:custom_role_user) { create(:user) }
        let_it_be(:custom_role) do
          create(:member_role, :guest, :admin_ai_catalog_item_consumer, namespace: group)
        end

        let_it_be(:custom_role_membership) do
          create(:project_member, :guest, member_role: custom_role, user: custom_role_user, project: project)
        end

        let(:current_user) { custom_role_user }

        before do
          stub_licensed_features(custom_roles: true)
        end

        it 'deletes the item consumer' do
          expect { response }.to change { Ai::Catalog::ItemConsumer.count }.by(-1)
          expect(response).to be_success
        end
      end

      context 'when user has permission' do
        let(:current_user) { maintainer }

        it 'deletes the item consumer' do
          expect { response }.to change { Ai::Catalog::ItemConsumer.count }.by(-1)
          expect(response).to be_success
        end

        it 'removes the service account from the project' do
          expect { response }.to change { project.team.members.count }.by(-1)
          expect(project.team.users.pluck(:id)).not_to include(service_account.id)
        end

        it 'removes the service account with skip_authorization' do
          expect(Members::DestroyService).to receive(:new)
            .with(anything, hash_including(skip_authorization: true))
            .and_call_original

          response
        end

        context 'when removing the service account member fails' do
          before do
            allow_next_instance_of(Members::DestroyService) do |instance|
              allow(instance).to receive(:execute) do
                instance.send(:member).errors.add(:base, 'Deletion failed')
              end
            end
          end

          it 'does not delete the item consumer' do
            expect { response }.not_to change { Ai::Catalog::ItemConsumer.count }
            expect(response).to be_error
            expect(response.message).to contain_exactly('Service account membership: Deletion failed')
          end
        end

        context 'when there is no service account membership in the project' do
          let_it_be(:project) { create(:project, group: group) }
          let_it_be_with_refind(:item_consumer) do
            create(:ai_catalog_item_consumer, parent_item_consumer:, project:, item:)
          end

          it 'does not fail' do
            expect { response }.to change { Ai::Catalog::ItemConsumer.count }.by(-1)
            expect(response).to be_success
          end
        end

        it 'tracks internal event on successful deletion' do
          stub_event_properties_builder(item_consumer)

          expect { response }.to trigger_internal_events('delete_ai_catalog_item_consumer').with(
            user: maintainer,
            project: project,
            namespace: nil,
            additional_properties: stubbed_event_properties.merge(
              label: item_consumer.enabled.to_s,
              property: item_consumer.locked.to_s
            )
          ).and increment_usage_metrics('counts.count_total_delete_ai_catalog_item_consumer')
        end

        context 'when the item consumer has a flow_trigger' do
          let_it_be_with_refind(:flow_trigger) do
            create(:ai_flow_trigger,
              project: project,
              user: nil,
              config_path: nil,
              ai_catalog_item_consumer: item_consumer,
              event_types: [
                Ai::FlowTrigger::EVENT_TYPES[:mention],
                Ai::FlowTrigger::EVENT_TYPES[:merge_request]
              ])
          end

          it 'tracks the triggers captured before the cascade deletion' do
            stub_event_properties_builder(item_consumer)

            expect { response }.to change { Ai::Catalog::ItemConsumer.count }.by(-1)
              .and change { Ai::FlowTrigger.count }.by(-1)
              .and trigger_internal_events('delete_ai_catalog_item_consumer').with(
                user: maintainer,
                project: project,
                namespace: nil,
                additional_properties: stubbed_event_properties.merge(
                  label: item_consumer.enabled.to_s,
                  property: item_consumer.locked.to_s,
                  triggers: 'mention,merge_request'
                )
              )
          end
        end

        it_behaves_like 'creates an audit event on deletion', entity_type: 'Project'

        context 'when item is an agent' do
          let_it_be(:agent_item) { create(:ai_catalog_agent, project: project) }
          let_it_be_with_refind(:item_consumer) do
            create(:ai_catalog_item_consumer, project: project, item: agent_item)
          end

          it_behaves_like 'creates an audit event on deletion', entity_type: 'Project'
        end

        context 'when item is a third_party_flow' do
          let_it_be_with_refind(:item_consumer) do
            create(:ai_catalog_item_consumer, project: project, item: third_party_flow_item)
          end

          it_behaves_like 'creates an audit event on deletion', entity_type: 'Project'
        end

        context 'when destroy fails' do
          before do
            allow(item_consumer).to receive(:destroy) do
              item_consumer.errors.add(:base, 'Deletion failed')
              false
            end
          end

          it 'returns an error' do
            expect { response }.not_to change { Ai::Catalog::ItemConsumer.count }
            expect(response).to be_error
            expect(response.message).to contain_exactly('Deletion failed')
          end

          it 'does not track internal event on failure' do
            expect { response }.not_to trigger_internal_events('delete_ai_catalog_item_consumer')
          end

          it 'does not create an audit event on failure' do
            expect { response }.not_to change { AuditEventReader.count }
          end
        end
      end
    end

    context 'with a group level item consumer' do
      let(:item_consumer) { parent_item_consumer }
      let(:cannot_delete_consumer_message) { "You don't have permission to disable this agent or flow" }

      context 'when user is maintainer with all permissions' do
        let(:current_user) { maintainer }

        before do
          stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
        end

        it 'deletes the item consumer' do
          expect { response }.to change { Ai::Catalog::ItemConsumer.count }.by(-1)

          expect(response).to be_success
        end

        it 'tracks internal event with group namespace' do
          stub_event_properties_builder(item_consumer)

          expect { response }.to trigger_internal_events('delete_ai_catalog_item_consumer').with(
            user: current_user,
            project: nil,
            namespace: group,
            additional_properties: stubbed_event_properties.merge(
              label: item_consumer.enabled.to_s,
              property: item_consumer.locked.to_s
            )
          )
        end

        it_behaves_like 'creates an audit event on deletion', entity_type: 'Group'

        it 'enqueues the worker to remove the service account from all projects' do
          expect(Ai::Catalog::DeleteServiceAccountMembersFromHierarchyWorker).to receive(:perform_async)
            .with(current_user.id, service_account.id, group.id, { 'skip_authorization' => true })

          # Since specs run inside a transaction which gets rolled back, we need to manually trigger the execution
          expect(item_consumer).to receive(:run_after_commit) do |&block|
            item_consumer.instance_eval(&block)
          end

          response
        end
      end

      context 'when user does not have permission' do
        let(:current_user) { developer }

        it 'returns an error' do
          expect(response).to be_error
          expect(response.message).to contain_exactly(cannot_delete_consumer_message)
        end

        it 'does not track internal event' do
          expect { response }.not_to trigger_internal_events('delete_ai_catalog_item_consumer')
        end

        it 'does not create an audit event on failure' do
          expect { response }.not_to change { AuditEventReader.count }
        end
      end
    end

    context 'with a group level foundational flow item consumer' do
      let_it_be(:foundational_item) { create(:ai_catalog_item, :with_foundational_flow_reference) }

      let_it_be(:item_consumer) do
        create(:ai_catalog_item_consumer, group: group, item: foundational_item)
      end

      let_it_be(:foundational_flow_enablement) do
        create(:ai_catalog_enabled_foundational_flow, namespace: group, catalog_item: foundational_item)
      end

      let(:current_user) { owner }

      it 'returns an error and does not delete the item consumer' do
        expect { response }.not_to change { Ai::Catalog::ItemConsumer.count }

        expect(response).to be_error
        expect(response.message).to contain_exactly(
          "Foundational flows can only be disabled for a group in the group's GitLab Duo settings"
        )
      end
    end

    context 'with a project level foundational flow item consumer' do
      let_it_be(:foundational_item) { create(:ai_catalog_item, :with_foundational_flow_reference) }

      let_it_be(:foundational_parent_consumer) do
        create(:ai_catalog_item_consumer, group: group, item: foundational_item)
      end

      let_it_be_with_refind(:item_consumer) do
        create(
          :ai_catalog_item_consumer,
          item: foundational_item,
          project: project,
          parent_item_consumer: foundational_parent_consumer
        )
      end

      let(:current_user) { maintainer }

      let_it_be(:foundational_flow_enablement) do
        create(:ai_catalog_enabled_foundational_flow, namespace: group, catalog_item: foundational_item)
      end

      it 'deletes the item consumer' do
        expect { response }.to change { Ai::Catalog::ItemConsumer.count }.by(-1)

        expect(response).to be_success
      end
    end
  end
end
