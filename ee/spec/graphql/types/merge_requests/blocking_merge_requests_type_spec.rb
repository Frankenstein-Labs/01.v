# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['BlockingMergeRequests'], feature_category: :code_review_workflow do
  include GraphqlHelpers

  let(:fields) do
    %i[total_count hidden_count visible_merge_requests]
  end

  it { expect(described_class).to have_graphql_fields(fields) }

  describe 'fields' do
    let(:merge_request) { create(:merge_request) }
    let(:current_user) { merge_request.target_project.first_owner }

    let_it_be(:mr_to_ignore) { create(:merge_request) }
    let_it_be(:mr_to_add) { create(:merge_request) }
    let_it_be(:mr_to_keep) { create(:merge_request) }
    let_it_be(:mr_to_del) { create(:merge_request) }
    let_it_be(:hidden_mr) { create(:merge_request) }

    let(:query) do
      %(
        query{
          project(fullPath:"#{merge_request.project.full_path}"){
            mergeRequest(iid: "#{merge_request.iid}") {
              blockingMergeRequests {
                totalCount
                hiddenCount
                visibleMergeRequests {
                  id
                }
              }
            }
          }
        }
    )
    end

    before do
      [mr_to_add, mr_to_keep, mr_to_del].each do |mr|
        mr.target_project.team.add_maintainer(current_user)
      end

      create(:merge_request_block, blocking_merge_request: mr_to_keep, blocked_merge_request: merge_request)
      create(:merge_request_block, blocking_merge_request: mr_to_del, blocked_merge_request: merge_request)
      create(:merge_request_block, blocking_merge_request: mr_to_add, blocked_merge_request: merge_request)
      create(:merge_request_block, blocking_merge_request: mr_to_ignore, blocked_merge_request: merge_request)
      create(:merge_request_block, blocking_merge_request: hidden_mr, blocked_merge_request: merge_request)
    end

    subject { GitlabSchema.execute(query, context: { current_user: current_user }).as_json }

    describe '#total_count' do
      it 'returns the correct total count' do
        expect(response["totalCount"]).to eq(5)
      end
    end

    describe '#hidden_count' do
      it 'returns the hidden total count' do
        expect(response["hiddenCount"]).to eq(2)
      end
    end

    describe '#visible_merge_requests' do
      it 'returns the correct visible merge request IDs' do
        visible_mrs = response["visibleMergeRequests"]

        global_ids = visible_mrs.pluck("id")
        expected_ids = [
          mr_to_keep.id,
          mr_to_add.id,
          mr_to_del.id
        ].map { |id| "gid://gitlab/MergeRequest/#{id}" }

        expect(global_ids).to match_array(expected_ids)
      end
    end

    def response
      subject.dig("data", "project", "mergeRequest", "blockingMergeRequests")
    end
  end
end
