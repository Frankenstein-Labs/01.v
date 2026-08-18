# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::UpdateWebSearchService, feature_category: :duo_agent_platform do
  describe '#execute' do
    subject(:result) do
      described_class.new(
        workflow: workflow,
        web_search_enabled: web_search_enabled,
        current_user: user
      ).execute
    end

    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user, maintainer_of: project) }

    let(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }
    let(:web_search_enabled) { true }

    context 'when user does not have permission to update workflow' do
      before do
        allow(user).to receive(:can?).with(:update_duo_workflow, workflow).and_return(false)
      end

      it 'returns unauthorized error', :aggregate_failures do
        expect(result.error?).to be true
        expect(result.message).to eq('Cannot update workflow')
        expect(result.reason).to eq(:unauthorized)
      end
    end

    context 'when user has permission to update workflow' do
      before do
        allow(user).to receive(:can?).with(:update_duo_workflow, workflow).and_return(true)
      end

      context 'when enabling web search' do
        let(:web_search_enabled) { true }

        it 'updates web_search_enabled and returns success', :aggregate_failures do
          expect(result.success?).to be true
          expect(result.message).to eq('Web search setting updated successfully')
          expect(result.payload[:workflow]).to eq(workflow)
          expect(workflow.reload.web_search_enabled).to be true
        end
      end

      context 'when disabling web search' do
        let(:web_search_enabled) { false }

        before do
          workflow.update!(web_search_enabled: true)
        end

        it 'updates web_search_enabled and returns success', :aggregate_failures do
          expect(result.success?).to be true
          expect(workflow.reload.web_search_enabled).to be false
        end
      end

      context 'when the workflow fails to save' do
        before do
          allow(workflow).to receive(:save).and_return(false)
          allow(workflow).to receive_message_chain(:errors, :full_messages).and_return(['some error'])
        end

        it 'returns an error response', :aggregate_failures do
          expect(result.error?).to be true
          expect(result.message).to eq('Failed to update web search setting: some error')
          expect(result.reason).to eq(:bad_request)
        end
      end
    end
  end
end
