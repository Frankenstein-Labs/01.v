# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FlowTriggers::UpdateService, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:different_group) { create(:group) }
  let_it_be(:human_user) { create(:user, maintainer_of: project) }
  let_it_be(:composite_identity_enforced) { false }
  let_it_be(:service_account_provisioned_by_group) do
    create(:service_account, developer_of: project, provisioned_by_group: project.group,
      composite_identity_enforced: composite_identity_enforced)
  end

  let_it_be(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_core, :self_managed) }

  let(:current_user) { human_user }
  let(:service_account) { service_account_provisioned_by_group }

  let(:event_types) { [Ai::FlowTrigger::EVENT_TYPES[:mention]] }
  let(:params) { { user_id: service_account.id, event_types: event_types } }
  let(:trigger) { create(:ai_flow_trigger, project: project, user: service_account) }
  let(:service) { described_class.new(project: project, current_user: current_user, trigger: trigger) }

  before do
    stub_ee_application_setting(duo_features_enabled: true)
    allow(Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
    ::Ai::Setting.for_organization(project.organization).update!(duo_core_features_enabled: true)
  end

  describe '#execute' do
    it 'updates a flow trigger' do
      response = service.execute(params)
      expect(response).to be_success
      flow_trigger = response.payload

      expect(flow_trigger).to be_persisted
      expect(flow_trigger.user).to eq(service_account)
      expect(flow_trigger.event_types).to contain_exactly(Ai::FlowTrigger::EVENT_TYPES[:mention])
      expect(flow_trigger.project).to eq(project)
      expect(service_account.reload.composite_identity_enforced).to be(true)
    end

    it 'emits a flow_trigger_updated audit event on success' do
      expect { service.execute(params) }.to change { AuditEventReader.count }.by(1)

      audit_event = AuditEventReader.last

      expect(audit_event).to have_attributes(
        author: current_user,
        entity_type: 'Project',
        entity_id: project.id,
        target_details: "#{trigger.description} (ID: #{trigger.id})"
      )
      expect(audit_event.details).to include(
        event_name: 'flow_trigger_updated',
        target_type: 'Ai::FlowTrigger'
      )
    end

    it 'does not emit an audit event when update fails' do
      invalid_params = params.merge(event_types: [99])
      expect { service.execute(invalid_params) }.not_to change { AuditEventReader.count }
    end

    context 'when using invalid params' do
      let(:event_types) { [99] }

      it 'returns the error' do
        response = service.execute(params)
        expect(response).not_to be_success
        expect(response.message).to include('invalid event types: 99')
      end
    end

    context 'when the current_user is not a maintainer of the project' do
      let(:current_user) { create(:user, developer_of: project) }

      it 'returns an error and does not create the flow trigger' do
        response = service.execute(params)
        expect(response).not_to be_success
      end
    end

    context 'when the provisioning group is not the root ancestor of the project' do
      let(:service_account) { create(:service_account, developer_of: project, provisioned_by_group: different_group) }

      it 'returns an error and does not create the flow trigger' do
        response = service.execute(params)
        expect(response).not_to be_success
      end
    end

    context 'when updating catalog item configuration' do
      let_it_be(:item_consumer1) { create(:ai_catalog_item_consumer, :child_item_consumer, project: project) }
      let_it_be(:item_consumer2) { create(:ai_catalog_item_consumer, :child_item_consumer, project: project) }

      context 'when switching from config_path to catalog item' do
        let(:trigger) do
          create(:ai_flow_trigger, project: project, user: service_account, config_path: 'path/config.yml')
        end

        let(:params) do
          {
            ai_catalog_item_consumer_id: item_consumer1.id,
            config_path: nil
          }
        end

        it 'updates to use catalog item' do
          response = service.execute(params)
          flow_trigger = response.payload

          expect(response).to be_success
          expect(flow_trigger.ai_catalog_item_consumer).to eq(item_consumer1)
          expect(flow_trigger.config_path).to be_nil
        end

        context 'when ai_catalog_create_third_party_flows is disabled' do
          before do
            stub_feature_flags(ai_catalog_create_third_party_flows: false)
          end

          it 'does not return an error' do
            response = service.execute(params)

            expect(response).to be_success
          end
        end
      end

      context 'when switching from catalog item to config_path' do
        let(:trigger) do
          create(:ai_flow_trigger,
            :for_catalog_consumer,
            project: project,
            ai_catalog_item_consumer: item_consumer1)
        end

        let(:params) do
          {
            user_id: service_account.id,
            config_path: 'new/path/config.yml',
            ai_catalog_item_consumer_id: nil
          }
        end

        it 'updates to use config_path' do
          response = service.execute(params)
          expect(response).to be_success
          flow_trigger = response.payload

          expect(flow_trigger.config_path).to eq('new/path/config.yml')
          expect(flow_trigger.ai_catalog_item_consumer).to be_nil
        end

        context 'when ai_catalog_create_third_party_flows is disabled' do
          before do
            stub_feature_flags(ai_catalog_create_third_party_flows: false)
          end

          it 'returns an error' do
            response = service.execute(params)

            expect(response).to be_error
            expect(response.message).to include('You have insufficient permissions')
          end
        end
      end

      context 'when updating catalog item' do
        let(:trigger) do
          create(:ai_flow_trigger,
            :for_catalog_consumer,
            project: project,
            ai_catalog_item_consumer: item_consumer1
          )
        end

        it 'updates to different catalog item' do
          update_params = {
            ai_catalog_item_consumer_id: item_consumer2.id
          }

          response = service.execute(update_params)
          expect(response).to be_success
          flow_trigger = response.payload

          expect(flow_trigger.ai_catalog_item_consumer).to eq(item_consumer2)
        end
      end

      context 'when also passing a matching user_id' do
        let(:params) do
          {
            user_id: item_consumer1.active_service_account.id,
            ai_catalog_item_consumer_id: item_consumer1.id,
            config_path: nil
          }
        end

        it 'updates the flow trigger, but does not set the user ID' do
          response = service.execute(params)
          expect(response).to be_success
          flow_trigger = response.payload

          expect(flow_trigger.ai_catalog_item_consumer).to eq(item_consumer1)
          expect(flow_trigger.user_id).to be_nil
        end
      end

      context 'with invalid catalog item parameters' do
        let_it_be(:other_project) { create(:project, :in_group) }
        let_it_be(:item_consumer) { create(:ai_catalog_item_consumer, :child_item_consumer, project: other_project) }

        it 'returns an error' do
          catalog_params = {
            ai_catalog_item_consumer_id: item_consumer.id,
            config_path: nil
          }

          response = service.execute(catalog_params)
          expect(response).to be_error
          expect(response.message).to include('ai_catalog_item_consumer project does not match project')
        end
      end
    end
  end
end
