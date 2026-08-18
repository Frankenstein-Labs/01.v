# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integrations::SlackInteractions::DuoFeedbackModalSubmitService, feature_category: :duo_agent_platform do
  describe '#execute' do
    let_it_be(:workflow) { create(:duo_workflows_workflow) }
    let_it_be(:chat_name) { create(:chat_name) }

    let(:reason_value) { 'incorrect' }
    let(:comment_value) { 'The response referenced the wrong project.' }
    let(:private_metadata) { workflow.id.to_s }
    let(:state_values) do
      {
        duo_feedback_reason: {
          reason: { selected_option: { value: reason_value } }
        },
        duo_feedback_comment: {
          comment: { value: comment_value }
        }
      }
    end

    let(:params) do
      {
        team: { id: chat_name.team_id },
        user: { id: chat_name.chat_id },
        view: {
          callback_id: ::Integrations::SlackInteractions::DuoFeedbackModal::CALLBACK_ID,
          private_metadata: private_metadata,
          state: { values: state_values }
        }
      }
    end

    subject(:execute) { described_class.new(params).execute }

    it 'tracks the enriched thumbs_down event' do
      expect { execute }.to trigger_internal_events('ai_duo_messaging_feedback_submitted').with(
        user: chat_name.user,
        namespace: workflow.resource_parent.root_ancestor,
        additional_properties: {
          label: 'thumbs_down',
          value: workflow.id,
          property: 'slack',
          reason: 'incorrect',
          comment: comment_value
        }
      )
    end

    it 'returns a response_action that swaps the modal for a thanks view' do
      expect(execute).to be_success
      expect(execute.payload[:response_action]).to eq('update')
      expect(execute.payload[:view]).to include(type: 'modal')
    end

    context 'without a comment' do
      let(:state_values) do
        {
          duo_feedback_reason: {
            reason: { selected_option: { value: reason_value } }
          }
        }
      end

      it 'tracks the event without a comment property' do
        expect { execute }.to trigger_internal_events('ai_duo_messaging_feedback_submitted').with(
          user: chat_name.user,
          namespace: workflow.resource_parent.root_ancestor,
          additional_properties: {
            label: 'thumbs_down',
            value: workflow.id,
            property: 'slack',
            reason: 'incorrect'
          }
        )
      end
    end

    context 'when the comment exceeds the maximum length' do
      let(:comment_value) { 'a' * (::Integrations::SlackInteractions::DuoFeedbackModal::COMMENT_MAX_LENGTH + 1000) }

      it 'truncates the comment' do
        truncated = 'a' * ::Integrations::SlackInteractions::DuoFeedbackModal::COMMENT_MAX_LENGTH

        expect { execute }.to trigger_internal_events('ai_duo_messaging_feedback_submitted').with(
          user: chat_name.user,
          namespace: workflow.resource_parent.root_ancestor,
          additional_properties: {
            label: 'thumbs_down',
            value: workflow.id,
            property: 'slack',
            reason: 'incorrect',
            comment: truncated
          }
        )
      end
    end

    context 'when the reason is other' do
      let(:reason_value) { 'other' }

      context 'with a comment' do
        it 'tracks the event' do
          expect { execute }.to trigger_internal_events('ai_duo_messaging_feedback_submitted').with(
            user: chat_name.user,
            namespace: workflow.resource_parent.root_ancestor,
            additional_properties: {
              label: 'thumbs_down',
              value: workflow.id,
              property: 'slack',
              reason: 'other',
              comment: comment_value
            }
          )
        end
      end

      context 'without a comment' do
        let(:state_values) do
          {
            duo_feedback_reason: {
              reason: { selected_option: { value: reason_value } }
            }
          }
        end

        it 'returns an inline validation error on the comment block' do
          expect { execute }.not_to trigger_internal_events('ai_duo_messaging_feedback_submitted')

          expect(execute.payload[:response_action]).to eq('errors')
          expect(execute.payload[:errors]).to have_key(
            ::Integrations::SlackInteractions::DuoFeedbackModal::COMMENT_BLOCK_ID
          )
        end
      end
    end

    context 'when no reason was selected' do
      let(:state_values) { {} }

      it 'does not track anything' do
        expect { execute }.not_to trigger_internal_events('ai_duo_messaging_feedback_submitted')
      end

      it 'returns success' do
        expect(execute).to be_success
      end
    end

    context 'when the Slack user has no linked GitLab account' do
      let(:params) { super().merge(user: { id: 'U_UNLINKED' }) }

      it 'does not track anything' do
        expect { execute }.not_to trigger_internal_events('ai_duo_messaging_feedback_submitted')
      end
    end

    context 'when the workflow does not exist' do
      let(:private_metadata) { '0' }

      it 'does not track anything' do
        expect { execute }.not_to trigger_internal_events('ai_duo_messaging_feedback_submitted')
      end
    end

    context 'when the private_metadata is malformed' do
      let(:private_metadata) { 'not-a-number' }

      it 'does not track anything' do
        expect { execute }.not_to trigger_internal_events('ai_duo_messaging_feedback_submitted')
      end
    end
  end
end
