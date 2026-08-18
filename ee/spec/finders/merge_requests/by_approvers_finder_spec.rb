# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ByApproversFinder, feature_category: :code_review_workflow do
  let_it_be(:group_user) { create(:user) }
  let_it_be(:second_group_user) { create(:user) }
  let_it_be_with_reload(:group) do
    create(:group).tap do |group|
      group.add_developer(group_user)
      group.add_developer(second_group_user)
    end
  end

  let_it_be_with_reload(:merge_request) { create(:merge_request) }
  let_it_be_with_reload(:project_user) { create(:user) }
  let_it_be_with_refind(:first_user) { create(:user) }
  let_it_be_with_reload(:second_user) { create(:user) }
  let_it_be_with_reload(:second_project_user) { create(:user) }

  let_it_be_with_reload(:merge_request_with_project_approver) do
    rule = create(:approval_project_rule, users: [project_user, second_project_user])
    create(:merge_request, source_project: create(:project, approval_rules: [rule]))
  end

  let_it_be_with_reload(:merge_request_with_approver) do
    mr = create(:merge_request)
    create(:approval_merge_request_rule, merge_request: mr, users: [first_user])
    mr
  end

  let_it_be_with_reload(:merge_request_with_two_approvers) do
    mr = create(:merge_request)
    create(:approval_merge_request_rule, merge_request: mr, users: [first_user, second_user])
    mr
  end

  let_it_be_with_reload(:merge_request_with_group_approver) do
    create(:merge_request).tap do |merge_request|
      rule = create(:approval_merge_request_rule, merge_request: merge_request, groups: [group])
      merge_request.approval_rules << rule
    end
  end

  let_it_be(:merge_request_with_project_group_approver) do
    rule = create(:approval_project_rule, groups: [group])
    create(:merge_request, source_project: create(:project, approval_rules: [rule]))
  end

  def merge_requests(ids: nil, names: [])
    described_class.new(names, ids).execute(MergeRequest.all)
  end

  context 'filter by no approvers' do
    it 'returns merge requests without approvers' do
      expect(merge_requests(ids: 'None')).to eq([merge_request])
      expect(merge_requests(names: ['None'])).to eq([merge_request])
    end
  end

  context 'filter by any approver' do
    it 'returns only merge requests with approvers' do
      expect(merge_requests(ids: 'Any')).to match_array(
        [
          merge_request_with_approver, merge_request_with_two_approvers,
          merge_request_with_group_approver, merge_request_with_project_approver,
          merge_request_with_project_group_approver
        ])
      expect(merge_requests(names: ['Any'])).to match_array(
        [
          merge_request_with_approver, merge_request_with_two_approvers,
          merge_request_with_group_approver, merge_request_with_project_approver,
          merge_request_with_project_group_approver
        ])
    end

    context "with two approval rules targeting the same user on the same MR" do
      let(:double_approval_user) do
        merge_request_with_approver.approval_rules.first.approvers.first
      end

      before do
        2.times { create(:approval_merge_request_rule, merge_request: merge_request_with_approver, users: [double_approval_user]) }
      end

      it 'correctly returns merge request' do
        expect(merge_requests(names: [double_approval_user.username])).to match_array(
          [merge_request_with_approver, merge_request_with_two_approvers])
      end
    end
  end

  context 'filter by second approver' do
    it 'returns only merge requests with the second approver' do
      expect(merge_requests(ids: [second_user.id])).to eq(
        [merge_request_with_two_approvers]
      )
      expect(merge_requests(names: [second_user.username])).to eq(
        [merge_request_with_two_approvers]
      )
    end
  end

  context 'filter by both approvers' do
    it 'returns only merge requests with both approvers' do
      expect(merge_requests(ids: [first_user.id, second_user.id])).to eq(
        [merge_request_with_two_approvers]
      )
      expect(merge_requests(names: [first_user.username, second_user.username])).to eq(
        [merge_request_with_two_approvers]
      )
    end
  end

  context 'pass empty params' do
    it 'returns all merge requests' do
      expect(merge_requests(ids: [])).to match_array(
        [
          merge_request, merge_request_with_approver,
          merge_request_with_two_approvers, merge_request_with_group_approver,
          merge_request_with_project_approver, merge_request_with_project_group_approver
        ])
      expect(merge_requests(names: [])).to match_array(
        [
          merge_request, merge_request_with_approver,
          merge_request_with_two_approvers, merge_request_with_group_approver,
          merge_request_with_project_approver, merge_request_with_project_group_approver
        ])
    end
  end

  context 'filter by an approver from group' do
    it 'returns only merge requests with the approver from group' do
      expect(merge_requests(ids: [group_user.id])).to match_array(
        [merge_request_with_project_group_approver, merge_request_with_group_approver]
      )
      expect(merge_requests(names: [group_user.username])).to match_array(
        [merge_request_with_project_group_approver, merge_request_with_group_approver]
      )
      expect(merge_requests(names: [first_user.username, group_user.username])).to be_empty
      expect(merge_requests(names: [group_user.username, second_group_user.username])).to match_array(
        [merge_request_with_project_group_approver, merge_request_with_group_approver]
      )
    end
  end

  context 'filter by an overridden approver from project' do
    it 'returns only merge requests with the project approver' do
      expect(merge_requests(ids: [project_user.id])).to eq(
        [merge_request_with_project_approver]
      )
      expect(merge_requests(ids: [first_user.id, project_user.id])).to eq([])
      expect(merge_requests(ids: [project_user.id, second_project_user.id])).to eq(
        [merge_request_with_project_approver]
      )
      expect(merge_requests(names: [project_user.username])).to eq(
        [merge_request_with_project_approver]
      )
      expect(merge_requests(names: [first_user.username, project_user.username])).to eq([])
      expect(merge_requests(names: [project_user.username, second_project_user.username])).to eq(
        [merge_request_with_project_approver]
      )
    end
  end

  context 'filter by approvers' do
    let(:mrs_by_ids) { merge_requests(ids: [first_user.id]) }
    let(:mrs_by_usernames) { merge_requests(names: [first_user.username]) }

    it 'can be ordered by popularity' do
      expect(mrs_by_ids.sort_by_attribute("popularity")).to eq([merge_request_with_two_approvers, merge_request_with_approver])
      expect(mrs_by_usernames.sort_by_attribute("popularity")).to eq([merge_request_with_two_approvers, merge_request_with_approver])
    end

    it 'can be ordered by priority' do
      expect(mrs_by_usernames.sort_by_attribute("priority")).to eq([merge_request_with_two_approvers, merge_request_with_approver])
      expect(mrs_by_ids.sort_by_attribute("priority")).to eq([merge_request_with_two_approvers, merge_request_with_approver])
    end
  end
end
