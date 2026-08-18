# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::UpdateReviewerStateService, feature_category: :code_review_workflow do
  let_it_be_with_reload(:current_user) { create(:user) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, reviewers: [current_user]) }
  let(:reviewer) { merge_request.merge_request_reviewers.find_by(user_id: current_user.id) }
  let(:project) { merge_request.project }
  let(:service) { described_class.new(project: project, current_user: current_user) }
  let(:state) { 'requested_changes' }
  let(:result) { service.execute(merge_request, state) }

  before do
    project.add_developer(current_user)
  end

  describe '#execute' do
    context 'when changes were requested' do
      it 'creates a requested changes record' do
        expect { result }.to change { merge_request.requested_changes.count }.from(0).to(1)
      end

      context 'when user is not a reviewer' do
        let_it_be_with_reload(:merge_request) { create(:merge_request) }

        it 'creates a requested changes record' do
          expect { result }.to change { merge_request.requested_changes.count }.from(0).to(1)
        end
      end
    end

    context 'when approving' do
      let(:state) { 'approved' }

      before do
        create(:merge_request_requested_changes, merge_request: merge_request, project: merge_request.project,
          user: current_user)
      end

      it 'removes requested changes' do
        expect { result }.to change { merge_request.requested_changes.count }.from(1).to(0)
      end

      context 'when user is not a reviewer' do
        let_it_be_with_reload(:merge_request) { create(:merge_request) }

        it 'creates a requested changes record' do
          expect { result }.to change { merge_request.requested_changes.count }.from(1).to(0)
        end
      end
    end
  end
end
