# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integrations::SlackInteractions::BlockActionService, feature_category: :duo_agent_platform do
  describe '#execute' do
    let(:action) { { action_id: 'duo_feedback', value: 'up:1' } }
    let(:params) do
      {
        team: { id: 'T0001' },
        user: { id: 'U0001' },
        actions: [action]
      }
    end

    subject(:execute) { described_class.new(params).execute }

    it 'routes duo_feedback actions to the DuoFeedbackHandler' do
      expect_next_instance_of(
        Integrations::SlackInteractions::SlackBlockActions::DuoFeedbackHandler, params, action
      ) do |handler|
        expect(handler).to receive(:execute)
      end

      execute
    end
  end
end
