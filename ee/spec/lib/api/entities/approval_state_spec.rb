# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::ApprovalState, feature_category: :source_code_management do
  let(:merge_request) { create(:merge_request) }
  let(:project) { merge_request.project }
  let(:user) { create(:user, developer_of: project) }
  let(:approval_state) { merge_request.approval_state }
  let(:approval) { create(:approval, merge_request: merge_request, user: user) }
  let(:expected_attributes) do
    %i[
      id
      iid
      project_id
      title
      description
      state
      created_at
      updated_at
      merge_status
      approved
      approvals_required
      approvals_left
      require_password_to_approve
      approved_by
      suggested_approvers
      approvers
      approver_groups
      user_has_approved
      user_can_approve
      approval_rules_left
      has_approval_rules
      merge_request_approvers_available
      multiple_approval_rules_available
      invalid_approvers_rules
    ]
  end

  subject(:entity) { described_class.new(approval_state, current_user: user).as_json }

  before do
    approval
  end

  it 'serializes a merge request approval state' do
    expect(entity.keys).to match_array(expected_attributes)
    expect(entity[:id]).to eq(merge_request.id)
    expect(entity[:iid]).to eq(merge_request.iid)
    expect(entity[:project_id]).to eq(merge_request.project_id)
    expect(entity[:title]).to eq(merge_request.title)
    expect(entity[:description]).to eq(merge_request.description)
    expect(entity[:state]).to eq(merge_request.state)
    expect(entity[:created_at]).to eq(merge_request.created_at)
    expect(entity[:updated_at]).to eq(merge_request.updated_at)
    expect(entity[:merge_status]).to eq(merge_request.public_merge_status)
    expect(entity[:approved]).to eq(approval_state.approved?)
    expect(entity[:approvals_required]).to eq(approval_state.approvals_required)
    expect(entity[:approvals_left]).to eq(approval_state.approvals_left)
    expect(entity[:require_password_to_approve]).to eq(project.require_password_to_approve?)
    expect(entity[:approved_by].count).to eq(1)
    approved_by = entity[:approved_by].first
    expect(approved_by[:user]).to eq(API::Entities::UserBasic.new(user).as_json)
    # Some systems have different precision so we need to use be_within(1.second) to prevent flakiness
    expect(approved_by[:approved_at]).to be_within(1.second).of(approval.created_at)
    expect(entity[:suggested_approvers]).to eq([])
    expect(entity[:approvers]).to eq([])
    expect(entity[:approver_groups]).to eq([])
    expect(entity[:user_has_approved]).to be(true)
    expect(entity[:user_can_approve]).to be(false)
    expect(entity[:approval_rules_left]).to eq([])
    expect(entity[:has_approval_rules]).to be(false)
    expect(entity[:merge_request_approvers_available]).to be(true)
    expect(entity[:multiple_approval_rules_available]).to be(false)
    expect(entity[:invalid_approvers_rules]).to eq([])
  end
end
