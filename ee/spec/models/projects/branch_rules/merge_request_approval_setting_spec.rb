# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::BranchRules::MergeRequestApprovalSetting, feature_category: :source_code_management do
  describe 'associations' do
    it { is_expected.to belong_to(:protected_branch).required }
    it { is_expected.to belong_to(:project).required }
  end

  describe 'enums' do
    let(:approval_removals) { { none: 0, all: 1, code_owners: 2 } }

    it 'defines an enum for approval_removals' do
      is_expected.to define_enum_for(:approval_removals)
        .with_values(**approval_removals).with_prefix
    end
  end

  describe 'default values' do
    subject(:merge_request_approval_setting) { described_class.new }

    it 'defaults to :all for approval_removals' do
      expect(merge_request_approval_setting.approval_removals).to eq('all')
    end
  end
end
