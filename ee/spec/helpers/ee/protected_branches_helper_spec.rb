# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProtectedBranchesHelper, feature_category: :source_code_management do
  describe '#allow_protected_branch_push?' do
    subject { helper.allow_protected_branch_push?(branches_protected_from_push, protected_branch, entity) }

    let(:branches_protected_from_push) { %w[main feature-a] }
    let(:protected_branch) { build(:protected_branch, name: 'main') }
    let(:entity) { build(:project) }

    it { is_expected.to be false }

    context 'with group entity' do
      let(:entity) { build(:group) }

      it { is_expected.to be true }
    end

    context 'when there are no branches protected from force push' do
      let(:branches_protected_from_push) { [] }

      it { is_expected.to be true }
    end

    context 'when branch is not included in the list' do
      let(:branches_protected_from_push) { %w[feature-a] }

      it { is_expected.to be true }
    end

    context 'when branches_protected_from_push are nil' do
      let(:branches_protected_from_push) { nil }

      it { is_expected.to be true }
    end

    context 'with wildcard pattern' do
      let(:branches_protected_from_push) { %w[ma*] }

      it { is_expected.to be false }
    end
  end
end
