# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FlowTriggers::DestroyService, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:service_account) do
    create(:service_account, developer_of: project, provisioned_by_group: project.group)
  end

  let_it_be(:trigger) do
    create(:ai_flow_trigger, project: project, user: service_account)
  end

  let(:current_user) { maintainer }
  let(:service) { described_class.new(trigger: trigger, current_user: current_user) }

  describe '#execute' do
    it 'destroys the flow trigger' do
      expect { service.execute }.to change { Ai::FlowTrigger.count }.by(-1)
    end

    it 'returns a success response' do
      expect(service.execute).to be_success
    end

    it 'emits a flow_trigger_deleted audit event' do
      expect { service.execute }.to change { AuditEventReader.count }.by(1)

      audit_event = AuditEventReader.last

      expect(audit_event).to have_attributes(
        author: current_user,
        entity_type: 'Project',
        entity_id: project.id,
        target_details: "#{trigger.description} (ID: #{trigger.id})"
      )
      expect(audit_event.details).to include(
        event_name: 'flow_trigger_deleted',
        target_type: 'Ai::FlowTrigger'
      )
    end

    context 'when destroy fails' do
      before do
        allow(trigger).to receive(:destroy).and_return(false)
      end

      it 'returns an error response' do
        expect(service.execute).to be_error
      end

      it 'returns the failure message' do
        expect(service.execute.message).to eq('Failed to delete the flow trigger')
      end

      it 'does not emit an audit event' do
        expect { service.execute }.not_to change { AuditEventReader.count }
      end
    end
  end
end
