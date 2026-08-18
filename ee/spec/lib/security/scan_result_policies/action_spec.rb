# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::Action, feature_category: :security_policy_management do
  describe '#type' do
    it 'returns the action type' do
      action = described_class.new({ type: 'require_approval' })
      expect(action.type).to eq('require_approval')
    end
  end

  describe '#type_require_approval?' do
    context 'when type is require_approval' do
      it 'returns true' do
        action = described_class.new({ type: 'require_approval' })
        expect(action.type_require_approval?).to be true
      end
    end

    context 'when type is not require_approval' do
      it 'returns false' do
        action = described_class.new({ type: 'send_bot_message' })
        expect(action.type_require_approval?).to be false
      end
    end
  end

  describe '#type_send_bot_message?' do
    context 'when type is send_bot_message' do
      it 'returns true' do
        action = described_class.new({ type: 'send_bot_message' })
        expect(action.type_send_bot_message?).to be true
      end
    end

    context 'when type is not send_bot_message' do
      it 'returns false' do
        action = described_class.new({ type: 'require_approval' })
        expect(action.type_send_bot_message?).to be false
      end
    end
  end

  describe '#approvals_required' do
    it 'returns the approvals_required value' do
      action = described_class.new({ approvals_required: 3 })
      expect(action.approvals_required).to eq(3)
    end
  end

  describe '#enabled' do
    it 'returns the enabled value' do
      action = described_class.new({ enabled: true })
      expect(action.enabled).to be true
    end
  end

  describe '#user_approvers' do
    context 'when user_approvers is present' do
      it 'returns the user_approvers array' do
        action = described_class.new({ user_approvers: %w[user1 user2] })
        expect(action.user_approvers).to match_array(%w[user1 user2])
      end
    end

    context 'when user_approvers is not present' do
      it 'returns an empty array' do
        action = described_class.new({})
        expect(action.user_approvers).to be_empty
      end
    end
  end

  describe '#user_approvers_ids' do
    context 'when user_approvers_ids is present' do
      it 'returns the user_approvers_ids array' do
        action = described_class.new({ user_approvers_ids: [1, 2, 3] })
        expect(action.user_approvers_ids).to match_array([1, 2, 3])
      end
    end

    context 'when user_approvers_ids is not present' do
      it 'returns an empty array' do
        action = described_class.new({})
        expect(action.user_approvers_ids).to be_empty
      end
    end
  end

  describe '#group_approvers' do
    context 'when group_approvers is present' do
      it 'returns the group_approvers array' do
        action = described_class.new({ group_approvers: %w[group1 group2] })
        expect(action.group_approvers).to match_array(%w[group1 group2])
      end
    end

    context 'when group_approvers is not present' do
      it 'returns an empty array' do
        action = described_class.new({})
        expect(action.group_approvers).to be_empty
      end
    end
  end

  describe '#group_approvers_ids' do
    context 'when group_approvers_ids is present' do
      it 'returns the group_approvers_ids array' do
        action = described_class.new({ group_approvers_ids: [3, 4, 5] })
        expect(action.group_approvers_ids).to match_array([3, 4, 5])
      end
    end

    context 'when group_approvers_ids is not present' do
      it 'returns an empty array' do
        action = described_class.new({})
        expect(action.group_approvers_ids).to be_empty
      end
    end
  end

  describe '#role_approvers' do
    context 'when role_approvers is present' do
      it 'returns the role_approvers array' do
        action = described_class.new({ role_approvers: %w[maintainer developer] })
        expect(action.role_approvers).to match_array(%w[maintainer developer])
      end
    end

    context 'when role_approvers is not present' do
      it 'returns an empty array' do
        action = described_class.new({})
        expect(action.role_approvers).to be_empty
      end
    end
  end
end
