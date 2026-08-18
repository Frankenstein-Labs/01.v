# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integrations::SlackInteractions::SlackBlockActions::DuoFeedbackHandler, feature_category: :duo_agent_platform do
  describe '#execute' do
    let_it_be(:workflow) { create(:duo_workflows_workflow) }
    let_it_be(:chat_name) { create(:chat_name) }

    let(:action_value) { "up:#{workflow.id}" }
    let(:action) { { action_id: 'duo_feedback', value: action_value } }
    let(:params) do
      {
        team: { id: chat_name.team_id },
        user: { id: chat_name.chat_id },
        actions: [action]
      }
    end

    subject(:execute) { described_class.new(params, action).execute }

    context 'with a thumbs up' do
      it 'tracks the feedback event attributed to the linked user' do
        expect { execute }.to trigger_internal_events('ai_duo_messaging_feedback_submitted').with(
          user: chat_name.user,
          namespace: workflow.resource_parent.root_ancestor,
          additional_properties: {
            label: 'thumbs_up',
            value: workflow.id,
            property: 'slack'
          }
        )
      end

      it 'does not open the reason modal' do
        expect(::Slack::API).not_to receive(:new)

        execute
      end
    end

    context 'with a thumbs down' do
      let(:action_value) { "down:#{workflow.id}" }
      let(:params) { super().merge(trigger_id: 'trigger-123') }
      let_it_be(:slack_installation) { create(:slack_integration, team_id: chat_name.team_id) }

      it 'tracks a thumbs_down label' do
        allow_next_instance_of(::Slack::API) do |api|
          allow(api).to receive(:open_view)
        end

        expect { execute }.to trigger_internal_events('ai_duo_messaging_feedback_submitted').with(
          user: chat_name.user,
          namespace: workflow.resource_parent.root_ancestor,
          additional_properties: {
            label: 'thumbs_down',
            value: workflow.id,
            property: 'slack'
          }
        )
      end

      it 'opens the reason modal via views.open' do
        expect_next_instance_of(::Slack::API) do |api|
          expect(api).to receive(:open_view).with(
            trigger_id: 'trigger-123',
            view: hash_including(
              type: 'modal',
              callback_id: ::Integrations::SlackInteractions::DuoFeedbackModal::CALLBACK_ID,
              private_metadata: workflow.id.to_s
            )
          )
        end

        execute
      end

      context 'when the trigger_id is missing' do
        let(:params) { super().except(:trigger_id) }

        it 'still tracks the event without opening a modal' do
          expect(::Slack::API).not_to receive(:new)

          expect { execute }.to trigger_internal_events('ai_duo_messaging_feedback_submitted').with(
            user: chat_name.user,
            namespace: workflow.resource_parent.root_ancestor,
            additional_properties: {
              label: 'thumbs_down',
              value: workflow.id,
              property: 'slack'
            }
          )
        end
      end

      context 'when opening the modal fails' do
        it 'still tracks the event' do
          expect_next_instance_of(::Slack::API) do |api|
            expect(api).to receive(:open_view).and_return({ 'ok' => false, 'error' => 'error' })
          end

          expect { execute }.to trigger_internal_events('ai_duo_messaging_feedback_submitted').with(
            user: chat_name.user,
            namespace: workflow.resource_parent.root_ancestor,
            additional_properties: {
              label: 'thumbs_down',
              value: workflow.id,
              property: 'slack'
            }
          )
        end
      end
    end

    context 'when the Slack user has no linked GitLab account' do
      let(:params) { super().merge(user: { id: 'U_UNLINKED' }) }

      it 'does not track anything' do
        expect { execute }.not_to trigger_internal_events('ai_duo_messaging_feedback_submitted')
      end
    end

    context 'when the workflow does not exist' do
      let(:action_value) { 'up:0' }

      it 'does not track anything' do
        expect { execute }.not_to trigger_internal_events('ai_duo_messaging_feedback_submitted')
      end
    end

    context 'when the action value is malformed' do
      let(:action_value) { 'sideways:abc' }

      it 'does not track anything' do
        expect { execute }.not_to trigger_internal_events('ai_duo_messaging_feedback_submitted')
      end
    end

    context 'when the action value is missing' do
      let(:action) { { action_id: 'duo_feedback' } }

      it 'does not track anything' do
        expect { execute }.not_to trigger_internal_events('ai_duo_messaging_feedback_submitted')
      end
    end
  end
end
