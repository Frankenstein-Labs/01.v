# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::ApprovalSettings, feature_category: :security_policy_management do
  describe '#prevent_approval_by_author' do
    it 'returns the prevent_approval_by_author value' do
      approval_settings = described_class.new({ prevent_approval_by_author: true })
      expect(approval_settings.prevent_approval_by_author).to be true
    end

    context 'when not set' do
      it 'returns nil' do
        approval_settings = described_class.new({})
        expect(approval_settings.prevent_approval_by_author).to be_nil
      end
    end
  end

  describe '#prevent_approval_by_commit_author' do
    it 'returns the prevent_approval_by_commit_author value' do
      approval_settings = described_class.new({ prevent_approval_by_commit_author: false })
      expect(approval_settings.prevent_approval_by_commit_author).to be false
    end

    context 'when not set' do
      it 'returns nil' do
        approval_settings = described_class.new({})
        expect(approval_settings.prevent_approval_by_commit_author).to be_nil
      end
    end
  end

  describe '#remove_approvals_with_new_commit' do
    it 'returns the remove_approvals_with_new_commit value' do
      approval_settings = described_class.new({ remove_approvals_with_new_commit: true })
      expect(approval_settings.remove_approvals_with_new_commit).to be true
    end

    context 'when not set' do
      it 'returns nil' do
        approval_settings = described_class.new({})
        expect(approval_settings.remove_approvals_with_new_commit).to be_nil
      end
    end
  end

  describe '#require_password_to_approve' do
    it 'returns the require_password_to_approve value' do
      approval_settings = described_class.new({ require_password_to_approve: true })
      expect(approval_settings.require_password_to_approve).to be true
    end

    context 'when not set' do
      it 'returns nil' do
        approval_settings = described_class.new({})
        expect(approval_settings.require_password_to_approve).to be_nil
      end
    end
  end

  describe '#block_branch_modification' do
    it 'returns the block_branch_modification value' do
      approval_settings = described_class.new({ block_branch_modification: true })
      expect(approval_settings.block_branch_modification).to be true
    end

    context 'when not set' do
      it 'returns nil' do
        approval_settings = described_class.new({})
        expect(approval_settings.block_branch_modification).to be_nil
      end
    end
  end

  describe '#prevent_pushing_and_force_pushing' do
    it 'returns the prevent_pushing_and_force_pushing value' do
      approval_settings = described_class.new({ prevent_pushing_and_force_pushing: true })
      expect(approval_settings.prevent_pushing_and_force_pushing).to be true
    end

    context 'when not set' do
      it 'returns nil' do
        approval_settings = described_class.new({})
        expect(approval_settings.prevent_pushing_and_force_pushing).to be_nil
      end
    end
  end

  describe '#prevent_editing_approval_rules' do
    it 'returns the prevent_editing_approval_rules value' do
      approval_settings = described_class.new({ prevent_editing_approval_rules: true })
      expect(approval_settings.prevent_editing_approval_rules).to be true
    end

    context 'when not set' do
      it 'returns nil' do
        approval_settings = described_class.new({})
        expect(approval_settings.prevent_editing_approval_rules).to be_nil
      end
    end
  end

  describe '#block_group_branch_modification' do
    context 'when block_group_branch_modification is present' do
      it 'returns the block_group_branch_modification hash' do
        approval_settings = described_class.new({ block_group_branch_modification: { enabled: true } })
        expect(approval_settings.block_group_branch_modification).to eq({ enabled: true })
      end
    end

    context 'when block_group_branch_modification is not present' do
      it 'returns nil' do
        approval_settings = described_class.new({})
        expect(approval_settings.block_group_branch_modification).to be_nil
      end
    end
  end

  describe '#block_group_branch_modification_enabled?' do
    context 'when set to true' do
      it 'returns true' do
        approval_settings = described_class.new({ block_group_branch_modification: true })
        expect(approval_settings.block_group_branch_modification_enabled?).to be true
      end
    end

    context 'when set to false' do
      it 'returns false' do
        approval_settings = described_class.new({ block_group_branch_modification: false })
        expect(approval_settings.block_group_branch_modification_enabled?).to be false
      end
    end

    context 'when set to a hash with enabled true' do
      it 'returns true' do
        approval_settings = described_class.new({ block_group_branch_modification: { enabled: true } })
        expect(approval_settings.block_group_branch_modification_enabled?).to be true
      end
    end

    context 'when set to a hash with enabled false' do
      it 'returns false' do
        approval_settings = described_class.new({ block_group_branch_modification: { enabled: false } })
        expect(approval_settings.block_group_branch_modification_enabled?).to be false
      end
    end

    context 'when not set' do
      it 'returns false' do
        approval_settings = described_class.new({})
        expect(approval_settings.block_group_branch_modification_enabled?).to be false
      end
    end
  end

  describe '#block_group_branch_modification_exception_group_ids' do
    context 'when set to a hash with exceptions' do
      it 'returns the exception group ids' do
        approval_settings = described_class.new(
          { block_group_branch_modification: { enabled: true, exceptions: [{ id: 1 }, { id: 2 }] } }
        )
        expect(approval_settings.block_group_branch_modification_exception_group_ids).to match_array([1, 2])
      end
    end

    context 'when set to a hash without exceptions' do
      it 'returns an empty array' do
        approval_settings = described_class.new({ block_group_branch_modification: { enabled: true } })
        expect(approval_settings.block_group_branch_modification_exception_group_ids).to be_empty
      end
    end

    context 'when set to a boolean' do
      it 'returns an empty array' do
        approval_settings = described_class.new({ block_group_branch_modification: true })
        expect(approval_settings.block_group_branch_modification_exception_group_ids).to be_empty
      end
    end

    context 'when not set' do
      it 'returns an empty array' do
        approval_settings = described_class.new({})
        expect(approval_settings.block_group_branch_modification_exception_group_ids).to be_empty
      end
    end
  end
end
