# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ProtectedEnvironmentApprovalRuleForSummary'],
  feature_category: :deployment_management do
  specify { expect(described_class.graphql_name).to eq('ProtectedEnvironmentApprovalRuleForSummary') }

  it 'includes the expected fields' do
    expected_fields = %w[
      approvals
      approved_count
      can_approve
      pending_approval_count
      required_approvals
      status
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  describe '#can_approve' do
    include_context 'with an approval rule and approver'

    subject(:result) do
      described_class.send(
        :new, approval_rule, { current_user: user_being_checked }
      ).can_approve
    end

    context 'when user can approve' do
      let_it_be(:user_being_checked) { approver }

      it { is_expected.to be(true) }
    end

    context 'when user cannot approve' do
      include_context 'with a non approver'

      let_it_be(:user_being_checked) { non_approver }

      it { is_expected.to be(false) }
    end

    context 'when user is nil' do
      let_it_be(:user_being_checked) { nil }

      it { is_expected.to be(false) }
    end
  end
end
