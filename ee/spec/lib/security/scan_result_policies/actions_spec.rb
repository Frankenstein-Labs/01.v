# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::Actions, feature_category: :security_policy_management do
  describe '#require_approval_actions' do
    let(:actions_data) do
      [
        { type: 'require_approval', approvals_required: 2, user_approvers: %w[username] },
        { type: 'send_bot_message', enabled: true },
        { type: 'require_approval', approvals_required: 1, role_approvers: %w[maintainer] }
      ]
    end

    it 'returns only actions with type require_approval' do
      actions = described_class.new(actions_data)
      require_approval_actions = actions.require_approval_actions

      expect(require_approval_actions.length).to eq(2)
      expect(require_approval_actions).to all(be_a(Security::ScanResultPolicies::Action))
      expect(require_approval_actions.map(&:type)).to all(eq('require_approval'))
      expect(require_approval_actions.map(&:approvals_required)).to match_array([2, 1])
      expect(require_approval_actions.map(&:user_approvers)).to match_array([%w[username], []])
      expect(require_approval_actions.map(&:role_approvers)).to match_array([%w[maintainer], []])
    end

    context 'when no require_approval actions exist' do
      let(:actions_data) do
        [
          { type: 'send_bot_message', enabled: true }
        ]
      end

      it 'returns an empty array' do
        actions = described_class.new(actions_data)
        expect(actions.require_approval_actions).to eq([])
      end
    end
  end

  describe '#send_bot_message_actions' do
    let(:actions_data) do
      [
        { type: 'require_approval', approvals_required: 2, user_approvers: %w[username] },
        { type: 'send_bot_message', enabled: true },
        { type: 'send_bot_message', enabled: false }
      ]
    end

    it 'returns only actions with type send_bot_message' do
      actions = described_class.new(actions_data)
      send_bot_message_actions = actions.send_bot_message_actions

      expect(send_bot_message_actions.length).to eq(2)
      expect(send_bot_message_actions).to all(be_a(Security::ScanResultPolicies::Action))
      expect(send_bot_message_actions.map(&:type)).to all(eq('send_bot_message'))
    end

    context 'when no send_bot_message actions exist' do
      let(:actions_data) do
        [
          { type: 'require_approval', approvals_required: 2, user_approvers: %w[username] }
        ]
      end

      it 'returns an empty array' do
        actions = described_class.new(actions_data)
        expect(actions.send_bot_message_actions).to eq([])
      end
    end
  end
end
