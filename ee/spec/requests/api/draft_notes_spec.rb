# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::DraftNotes, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public, :repository, developers: user) }
  let_it_be(:merge_request) do
    create(:merge_request, source_project: project, target_project: project, author: user)
  end

  let_it_be(:base_url) { "/projects/#{project.id}/merge_requests/#{merge_request.iid}/draft_notes" }

  describe "Bulk publishing draft notes with reviewer_state" do
    before do
      stub_licensed_features(requested_changes_block_merge_request: true)
      merge_request.reviewers << user
    end

    let!(:draft_note) { create(:draft_note, merge_request: merge_request, author: user) }

    context "when the caller has previously requested changes" do
      before do
        create(:merge_request_requested_changes, merge_request: merge_request, project: project, user: user)
      end

      it "clears the requested changes when reviewer_state is 'reviewed'", :aggregate_failures do
        expect(merge_request.reset.has_changes_requested?).to be(true)

        post api("#{base_url}/bulk_publish", user), params: { reviewer_state: 'reviewed' }

        expect(response).to have_gitlab_http_status(:no_content)
        expect(merge_request.reset.has_changes_requested?).to be(false)

        reviewer = merge_request.merge_request_reviewers.find_by(user_id: user.id)
        expect(reviewer.state).to eq('reviewed')
      end

      it "keeps the requested changes when reviewer_state is 'requested_changes'", :aggregate_failures do
        post api("#{base_url}/bulk_publish", user), params: { reviewer_state: 'requested_changes' }

        expect(response).to have_gitlab_http_status(:no_content)
        expect(merge_request.reset.has_changes_requested?).to be(true)

        reviewer = merge_request.merge_request_reviewers.find_by(user_id: user.id)
        expect(reviewer.state).to eq('requested_changes')
      end

      it "records no formal approval when clearing via 'reviewed'" do
        expect do
          post api("#{base_url}/bulk_publish", user), params: { reviewer_state: 'reviewed' }
        end.not_to change { merge_request.approvals.count }
      end
    end

    context "when the caller has no prior requested changes" do
      it "is a harmless no-op and still sets the reviewer state", :aggregate_failures do
        expect(merge_request.reset.has_changes_requested?).to be(false)

        post api("#{base_url}/bulk_publish", user), params: { reviewer_state: 'reviewed' }

        expect(response).to have_gitlab_http_status(:no_content)
        expect(merge_request.reset.has_changes_requested?).to be(false)

        reviewer = merge_request.merge_request_reviewers.find_by(user_id: user.id)
        expect(reviewer.state).to eq('reviewed')
      end
    end

    context "when the requested_changes feature is unavailable" do
      before do
        stub_licensed_features(requested_changes_block_merge_request: false)
        create(:merge_request_requested_changes, merge_request: merge_request, project: project, user: user)
      end

      it "does not clear the requested changes and still sets the reviewer state", :aggregate_failures do
        post api("#{base_url}/bulk_publish", user), params: { reviewer_state: 'reviewed' }

        expect(response).to have_gitlab_http_status(:no_content)
        expect(merge_request.reset.has_changes_requested?).to be(true)
        reviewer = merge_request.merge_request_reviewers.find_by(user_id: user.id)
        expect(reviewer.state).to eq('reviewed')
      end
    end
  end
end
