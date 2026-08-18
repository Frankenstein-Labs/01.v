# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::UpdateEventService, type: :service, feature_category: :duo_agent_platform do
  let(:workflow) { create(:duo_workflows_workflow) }
  let_it_be(:project) { create(:project) }
  let(:event) do
    create(
      :duo_workflows_event,
      workflow: workflow,
      project: project,
      event_type: 'pause',
      event_status: 'queued',
      message: 'Initial message'
    )
  end

  describe '#execute' do
    context 'when valid parameters are provided' do
      let(:valid_params) do
        {
          event_status: 'delivered',
          message: 'Updated message'
        }
      end

      it 'updates the event and returns success' do
        service = described_class.new(event: event, params: valid_params)
        result = service.execute

        expect(result[:status]).to eq(:success)
        expect(result[:event].event_status).to eq('delivered')
        expect(result[:event].message).to eq('Updated message')
      end
    end

    context 'when invalid parameters are provided' do
      let(:invalid_params) do
        {
          event_type: nil
        }
      end

      it 'does not update the event and returns an error' do
        service = described_class.new(event: event, params: invalid_params)
        result = service.execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to include("Event type can't be blank")
        expect(event.reload.event_type).to eq('pause')
      end
    end
  end
end
