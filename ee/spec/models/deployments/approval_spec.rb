# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Deployments::Approval, feature_category: :continuous_delivery do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:deployment) }
    it { is_expected.to belong_to(:ci_build) }
    it { is_expected.to belong_to(:approval_rule).class_name('ProtectedEnvironments::ApprovalRule').with_foreign_key(:approval_rule_id).inverse_of(:deployment_approvals) }
  end

  describe 'validations' do
    subject { create(:deployment_approval) }

    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_uniqueness_of(:user).scoped_to([:deployment_id, :approval_rule_id]) }
    it { is_expected.to validate_presence_of(:deployment) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_length_of(:comment).is_at_most(255) }
  end

  describe '#hook_attrs' do
    let(:approval) do
      build_stubbed(
        :deployment_approval,
        status: :approved,
        comment: 'LGTM',
        approval_rule: approval_rule
      )
    end

    subject(:hook_attrs) { approval.hook_attrs }

    context 'without an approval rule' do
      let(:approval_rule) { nil }

      it 'returns a static set of attributes', :aggregate_failures do
        expect(hook_attrs.keys).to eq(%i[id status comment created_at approval_rule])
        expect(hook_attrs[:id]).to eq(approval.id)
        expect(hook_attrs[:status]).to eq('approved')
        expect(hook_attrs[:comment]).to eq('LGTM')
        expect(hook_attrs[:created_at]).to eq(approval.created_at)
        expect(hook_attrs[:approval_rule]).to be_nil
      end
    end

    context 'with an approval rule' do
      let(:approval_rule) { build_stubbed(:protected_environment_approval_rule, :maintainer_access) }

      it 'delegates the rule shape to ApprovalRule#hook_attrs' do
        expect(hook_attrs[:approval_rule]).to eq(approval_rule.hook_attrs)
      end
    end
  end
end
