# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query current user recently viewed items (EE)', feature_category: :user_profile do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, :wiki_repo, developers: current_user) }
  let_it_be(:work_item) { create(:work_item, project: project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:wiki_page_meta) { create(:wiki_page_meta, project: project) }

  # In EE the union's resolve_type is *prepended* (EE::Types::Users::RecentlyViewedItemUnion),
  # so it intercepts every resolve_type call (calling super for non-Epic objects). Running the
  # real schema execution path in EE context therefore exercises the EE override's signature for
  # all union members. This is the guard against the (object) -> (object, _context) regression.
  let(:fields) do
    <<~FIELDS
      item {
        __typename
        ... on WorkItem { id }
        ... on MergeRequest { id }
        ... on WikiPage { id }
      }
    FIELDS
  end

  let(:query) do
    graphql_query_for('currentUser', {}, query_graphql_field('recentlyViewedItems', {}, fields))
  end

  let(:work_item_service) { instance_double(Gitlab::Search::RecentWorkItems) }
  let(:mr_service) { instance_double(Gitlab::Search::RecentMergeRequests) }
  let(:wiki_service) { instance_double(Gitlab::Search::RecentWikiPages) }

  before do
    # The Recent* search classes are Redis-backed; stub them so the data set is
    # deterministic while the query still runs end-to-end through the schema.
    allow(Gitlab::Search::RecentWorkItems).to receive(:new).with(user: current_user).and_return(work_item_service)
    allow(Gitlab::Search::RecentMergeRequests).to receive(:new).with(user: current_user).and_return(mr_service)
    allow(Gitlab::Search::RecentWikiPages).to receive(:new).with(user: current_user).and_return(wiki_service)

    allow(work_item_service).to receive(:latest_with_timestamps).and_return({ work_item => 1.hour.ago })
    allow(mr_service).to receive(:latest_with_timestamps).and_return({ merge_request => 2.hours.ago })
    allow(wiki_service).to receive(:latest_with_timestamps).and_return({ wiki_page_meta => 3.hours.ago })

    post_graphql(query, current_user: current_user)
  end

  subject(:items) { graphql_data.dig('currentUser', 'recentlyViewedItems') }

  it_behaves_like 'a working graphql query that returns data'

  it 'resolves each union member through the EE-prepended resolve_type' do
    expect(items.map { |item| item.dig('item', '__typename') })
      .to contain_exactly('WorkItem', 'MergeRequest', 'WikiPage')
  end
end
