# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ReviewerAssignment::CodeOwnersStrategy, feature_category: :code_review_workflow do
  describe '.strategy_name' do
    it 'returns code_owners' do
      expect(described_class.strategy_name).to eq('code_owners')
    end
  end

  describe '#select_reviewers' do
    let_it_be_with_reload(:author) { create(:user) }
    let_it_be_with_reload(:user1) { create(:user) }
    let_it_be_with_reload(:user2) { create(:user) }
    let_it_be_with_reload(:user3) { create(:user) }
    let_it_be_with_reload(:project) { create(:project, developers: [author, user1, user2, user3]) }

    let(:merge_request) { create(:merge_request, source_project: project, author: author) }

    let(:rule1) { create(:code_owner_rule, merge_request: merge_request, users: [user1, user2]) }
    let(:rule2) { create(:code_owner_rule, merge_request: merge_request, users: [user2, user3]) }

    subject(:strategy) { described_class.new(merge_request) }

    before do
      rule1
      rule2
    end

    it 'returns all unique eligible users from all rules' do
      result = strategy.select_reviewers

      expect(result).to match_array([user1, user2, user3])
    end

    it 'excludes the merge request author' do
      rule1.update!(users: [author, user1])

      result = strategy.select_reviewers

      expect(result).not_to include(author)
    end

    it 'excludes inactive users' do
      inactive_user = create(:user, :blocked)
      project.add_developer(inactive_user)
      rule1.update!(users: [inactive_user, user1])

      result = strategy.select_reviewers

      expect(result).not_to include(inactive_user)
      expect(result).to include(user1)
    end

    context 'when there are no code owner rules' do
      let(:rule1) { nil }
      let(:rule2) { nil }

      it 'returns an empty array' do
        expect(strategy.select_reviewers).to be_empty
      end
    end

    context 'with role approvers' do
      it 'includes users matching role approvers on the rule' do
        create(:code_owner_rule, merge_request: merge_request,
          users: [], role_approvers: [Gitlab::Access::DEVELOPER])

        result = strategy.select_reviewers

        expect(result).to include(user1, user2, user3)
        expect(result).not_to include(author)
      end
    end

    context 'with group members' do
      let(:group) { create(:group) }

      before do
        group.add_developer(user1)
        group.add_developer(user2)
        project.project_group_links.create!(group: group)
      end

      it 'includes group members' do
        create(:code_owner_rule, merge_request: merge_request, groups: [group])

        result = strategy.select_reviewers

        expect(result).to include(user1, user2)
      end
    end

    context 'when only non-code-owner rules exist' do
      let(:rule1) { nil }
      let(:rule2) { nil }

      it 'does not include approvers from other rule types' do
        create(:approval_merge_request_rule, merge_request: merge_request, users: [user1])

        expect(strategy.select_reviewers).to be_empty
      end
    end

    it 'excludes service accounts' do
      service_account = create(:user, :service_account)
      project.add_developer(service_account)
      rule1.update!(users: [service_account, user1])

      result = strategy.select_reviewers

      expect(result).not_to include(service_account)
      expect(result).to include(user1)
    end
  end
end
