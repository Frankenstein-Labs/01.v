# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VisibleApprovable, feature_category: :code_review_workflow do
  let(:resource) { create(:merge_request, source_project: project) }
  let!(:project) { create(:project, :small_repo) }
  let!(:user) { project.creator }

  describe '#overall_approvers' do
    let(:approver) { create(:user) }
    let(:code_owner) { build(:user) }

    let!(:project_regular_rule) { create(:approval_project_rule, project: project, users: [approver]) }
    let!(:code_owner_rule) { create(:code_owner_rule, merge_request: resource, users: [code_owner]) }

    before do
      project.add_developer(approver)
      project.add_developer(code_owner)
    end

    subject { resource.overall_approvers }

    it 'returns a list of all the project approvers' do
      is_expected.to contain_exactly(approver, code_owner)
    end

    context 'when exclude_code_owners is true' do
      subject { resource.overall_approvers(exclude_code_owners: true) }

      it 'excludes code owners' do
        is_expected.to contain_exactly(approver)
      end
    end

    context 'when approvers are overwritten' do
      let!(:merge_request_regular_rule) { create(:approval_merge_request_rule, merge_request: resource, users: [create(:user)]) }

      it 'returns the list of all the merge request level approvers' do
        is_expected.to contain_exactly(*merge_request_regular_rule.users, code_owner)
      end
    end

    context 'when author is an approver' do
      let!(:approver) { resource.author }

      it 'includes author regardless of project setting because filtering happens at rule level' do
        project.update!(merge_requests_author_approval: false)
        mr = resource.class.find(resource.id)

        expect(mr.overall_approvers).to include(approver)
      end

      it 'includes author if author is able to approve' do
        project.update!(merge_requests_author_approval: true)
        mr = resource.class.find(resource.id)

        expect(mr.overall_approvers).to include(approver)
      end
    end

    context 'when a committer is an approver' do
      let!(:project) { create(:project, :repository) }
      let!(:approver) { create(:user, email: resource.commits.without_merge_commits.first.committer_email) }

      it 'includes committer regardless of project setting because filtering happens at rule level' do
        project.update!(merge_requests_disable_committers_approval: true)

        is_expected.to include(approver)
      end

      it 'includes the committer if committers are able to approve' do
        project.update!(merge_requests_disable_committers_approval: false)

        is_expected.to include(approver)
      end
    end
  end

  describe '#reset_approval_cache!' do
    it 'deletes the approval mergeability cache', :clean_gitlab_redis_cache do
      check = MergeRequests::Mergeability::CheckApprovedService.new(merge_request: resource, params: {})
      cache_key = "#{check.cache_key}:#{Gitlab::MergeRequests::Mergeability::RedisInterface::VERSION}"

      Gitlab::Redis::Cache.with { |redis| redis.set(cache_key, '{"status":"success"}', ex: 30) }
      expect(Gitlab::Redis::Cache.with { |redis| redis.exists?(cache_key) }).to be true

      resource.reset_approval_cache!

      expect(Gitlab::Redis::Cache.with { |redis| redis.exists?(cache_key) }).to be false
    end
  end

  describe '#authors_can_approve?' do
    subject { resource.authors_can_approve? }

    it 'returns false when merge_requests_author_approval flag is off' do
      is_expected.to be_falsey
    end

    it 'returns true when merge_requests_author_approval flag is turned on' do
      project.update!(merge_requests_author_approval: true)

      is_expected.to be_truthy
    end
  end
end
