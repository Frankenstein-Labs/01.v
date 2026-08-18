# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::DestroyRequestedChangesService, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) do
    create(:merge_request, target_project: project, source_project: project, assignees: create_list(:user, 2),
      reviewers: create_list(:user, 2))
  end

  let_it_be(:reviewer) do
    create(:merge_request_reviewer, merge_request: merge_request, reviewer: user, state: 'requested_changes')
  end

  subject(:result) { described_class.new(project: project, current_user: user).execute(merge_request) }

  context 'when project has incorrect license' do
    before do
      stub_licensed_features(requested_changes_block_merge_request: false)
    end

    it 'returns error' do
      expect(result[:status]).to eq :error
      expect(result[:message]).to eq 'Invalid permissions'
    end
  end

  context 'when user does not have update permissions' do
    before do
      stub_licensed_features(requested_changes_block_merge_request: true)
    end

    it 'returns error' do
      expect(result[:message]).to eq 'Invalid permissions'
    end
  end

  context 'when user has not requested changes' do
    before_all do
      project.add_developer(user)
    end

    before do
      stub_licensed_features(requested_changes_block_merge_request: true)
    end

    it 'returns error' do
      expect(result[:status]).to eq :error
      expect(result[:message]).to eq 'User has not requested changes for this merge request'
    end
  end

  context 'when project has correct license and user has update permissions' do
    let_it_be(:requested_change) do
      create(:merge_request_requested_changes, merge_request: merge_request, project: project,
        user: user)
    end

    before_all do
      project.add_developer(user)
    end

    before do
      stub_licensed_features(requested_changes_block_merge_request: true)
    end

    it 'returns success' do
      expect(result[:status]).to eq :success
    end

    it 'updates reviewers state' do
      expect { result }.to change { reviewer.reload.state }.from('requested_changes').to('unreviewed')
    end

    it 'destroys requested change' do
      expect { result }.to change { merge_request.requested_changes.count }.from(1).to(0)
    end

    it_behaves_like 'triggers GraphQL subscription mergeRequestReviewersUpdated' do
      let(:action) { result }
    end

    it_behaves_like 'triggers GraphQL subscription mergeRequestMergeStatusUpdated' do
      let(:action) { result }
    end

    it 'invalidates cache counts for all assignees' do
      expect(merge_request.assignees).to all(receive(:invalidate_merge_request_cache_counts))

      expect(result[:status]).to eq :success
    end

    it 'invalidates cache counts for all reviewers' do
      expect(merge_request.reviewers).to all(receive(:invalidate_merge_request_cache_counts))

      expect(result[:status]).to eq :success
    end

    it 'invalidates cache counts for current user' do
      expect(user).to receive(:invalidate_merge_request_cache_counts)

      expect(result[:status]).to eq :success
    end
  end
end
