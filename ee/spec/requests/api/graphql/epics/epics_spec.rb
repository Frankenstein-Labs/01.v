# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting epics information', feature_category: :portfolio_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, maintainers: user) }
  let_it_be(:project) { create(:project, group: group) }

  let(:node_path) { %w[group epics nodes] }

  before do
    stub_licensed_features(epics: true)
  end

  describe 'query for epics which start with an iid' do
    let_it_be(:epic1) { create(:epic, group: group, iid: 11) }
    let_it_be(:epic2) { create(:epic, group: group, iid: 22) }
    let_it_be(:epic3) { create(:epic, group: group, iid: 2223) }
    let_it_be(:epic4) { create(:epic, group: group, iid: 29) }

    context 'when a valid iidStartsWith query is provided' do
      it 'returns the expected epics' do
        query_epics_which_start_with_iid('22')

        expect_epics_response([epic2, epic3], node_path: node_path)
      end
    end

    context 'when invalid iidStartsWith query is provided' do
      it 'fails with negative number' do
        query_epics_which_start_with_iid('-2')

        expect(graphql_errors).to include(a_hash_including('message' => 'Invalid `iidStartsWith` query'))
      end

      it 'fails with string' do
        query_epics_which_start_with_iid('foo')

        expect(graphql_errors).to include(a_hash_including('message' => 'Invalid `iidStartsWith` query'))
      end

      it 'fails if query contains line breaks' do
        query_epics_which_start_with_iid('2\nfoo')

        expect(graphql_errors).to include(a_hash_including('message' => 'Invalid `iidStartsWith` query'))
      end
    end

    def query_epics_which_start_with_iid(iid)
      post_graphql(epics_query(group, 'iidStartsWith' => iid), current_user: user)
    end
  end

  describe 'query for epics by created_at and updated_at' do
    let_it_be(:epic1) { create(:epic, group: group, created_at: 2.weeks.ago, updated_at: 10.seconds.ago) }
    let_it_be(:epic2) { create(:epic, group: group, created_at: 8.days.ago, updated_at: 2.minutes.ago) }
    let_it_be(:epic3) { create(:epic, group: group, created_at: 2.hours.ago, updated_at: 9.minutes.ago) }
    let_it_be(:epic4) { create(:epic, group: group, created_at: 15.minutes.ago, updated_at: 14.minutes.ago) }

    it 'filters by createdBefore' do
      post_graphql(epics_query(group, 'createdBefore' => 5.days.ago), current_user: user)

      expect_epics_response([epic1, epic2], node_path: node_path)
    end

    it 'filters by createdAfter' do
      post_graphql(epics_query(group, 'createdAfter' => 5.days.ago), current_user: user)

      expect_epics_response([epic3, epic4], node_path: node_path)
    end

    it 'filters by updatedBefore' do
      post_graphql(epics_query(group, 'updatedBefore' => 7.minutes.ago), current_user: user)

      expect_epics_response([epic3, epic4], node_path: node_path)
    end

    it 'filters by updatedAfter' do
      post_graphql(epics_query(group, 'updatedAfter' => 7.minutes.ago), current_user: user)

      expect_epics_response([epic1, epic2], node_path: node_path)
    end

    it 'filters by a combination of created parameters provided' do
      post_graphql(epics_query(group, { 'createdBefore' => Time.zone.now, 'createdAfter' => 20.minutes.ago }),
        current_user: user)

      expect_epics_response([epic4], node_path: node_path)
    end

    it 'filters by a combination of created/updated parameters provided' do
      post_graphql(epics_query(group, { 'updatedBefore' => 3.minutes.ago, 'createdAfter' => 20.minutes.ago }),
        current_user: user)

      expect_epics_response([epic4], node_path: node_path)
    end

    it 'returns nothing for impossible parameters' do
      post_graphql(epics_query(group, { 'createdBefore' => 7.minutes.ago, 'createdAfter' => Time.zone.now }),
        current_user: user)

      expect_epics_response([], node_path: node_path) # empty set
    end
  end

  describe 'query for epics by time frame' do
    let_it_be(:epic1) { create(:epic, group: group, state: :opened, start_date: "2019-08-13", end_date: "2019-08-20") }
    let_it_be(:epic2) { create(:epic, group: group, state: :closed, start_date: "2019-08-13", end_date: "2019-08-21") }
    let_it_be(:epic3) { create(:epic, group: group, state: :closed, start_date: "2019-08-22", end_date: "2019-08-26") }
    let_it_be(:epic4) { create(:epic, group: group, state: :closed, start_date: "2019-08-10", end_date: "2019-08-12") }

    context "when `start` and `end` are present" do
      it 'returns epics within timeframe' do
        post_graphql(epics_query(group, 'timeframe' => { 'start' => '2019-08-13', 'end' => '2019-08-21' }),
          current_user: user)

        expect_epics_response([epic1, epic2], node_path: node_path)
      end
    end

    context 'when only start is present' do
      it 'raises error' do
        post_graphql(epics_query(group, 'timeframe' => { 'start' => '2019-08-13' }), current_user: user)

        expect(graphql_errors).to include(
          a_hash_including('message' => "Argument 'end' on InputObject 'Timeframe' is required. Expected type Date!"))
      end
    end

    context 'when only end is present' do
      it 'raises error' do
        post_graphql(epics_query(group, 'timeframe' => { 'end' => '2019-08-21' }), current_user: user)

        expect(graphql_errors).to include(
          a_hash_including('message' => "Argument 'start' on InputObject 'Timeframe' is required. Expected type Date!"))
      end
    end
  end

  describe 'query for epics by subscribed' do
    let_it_be(:subscribed_epic) { create(:epic, group: group) }
    let_it_be(:unsubscribed_epic) { create(:epic, group: group) }
    let_it_be(:regular_epic) { create(:epic, group: group) }
    let_it_be(:subscription) { create(:subscription, subscribable: subscribed_epic, user: user, subscribed: true) }
    let_it_be(:unsubscription) { create(:subscription, subscribable: unsubscribed_epic, user: user, subscribed: false) }

    it 'filters to subscribed epics' do
      post_graphql(epics_query(group, subscribed: :EXPLICITLY_SUBSCRIBED), current_user: user)

      expect_epics_response([subscribed_epic], node_path: node_path)
    end

    it 'filters to unsubscribed epics' do
      post_graphql(epics_query(group, subscribed: :EXPLICITLY_UNSUBSCRIBED), current_user: user)

      expect_epics_response([unsubscribed_epic], node_path: node_path)
    end

    it 'does not filter out subscribed epics' do
      post_graphql(epics_query(group), current_user: user)

      expect_epics_response([subscribed_epic, unsubscribed_epic, regular_epic], node_path: node_path)
    end
  end

  context 'when query for epics with events' do
    let_it_be(:epic) { create(:epic, group: group) }

    it 'can lookahead to prevent N+1 queries' do
      create_list(:event, 3, :created, target: epic, group: group)

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        query_epics_with_events(1)
      end

      events = graphql_dig_at(graphql_data, :group, :epics, :nodes, :events, :nodes)
      expect(events.count).to eq(1)

      expect do
        query_epics_with_events(3)
      end.not_to exceed_all_query_limit(control)

      data = graphql_data(fresh_response_data)
      events = graphql_dig_at(data, :group, :epics, :nodes, :events, :nodes)
      expect(events.count).to eq(3)
    end
  end

  context 'when query for epics with ancestors' do
    let_it_be(:cross_group) { create(:group, :private) }
    let_it_be(:parent_epic1) { create(:epic, group: group) }
    let_it_be(:parent_epic2) { create(:epic, parent: parent_epic1, group: cross_group) }
    let_it_be(:parent_epic3) { create(:epic, group: group, parent: parent_epic2) }
    let_it_be(:epic) { create(:epic, group: group, parent: parent_epic3) }

    let(:node_path) { %w[group epic ancestors nodes] }

    it 'returns only ancestors up to the last accessible ancestor' do
      query_epic_with_ancestors(epic.iid)

      expect_epics_response([parent_epic3], node_path: node_path)
    end

    context 'when user is member of cross-hierarchy group' do
      before do
        parent_epic2.group.add_developer(user)
      end

      it 'returns all ancestors' do
        query_epic_with_ancestors(epic.iid)

        expect_epics_response([parent_epic1, parent_epic2, parent_epic3], node_path: node_path)
      end
    end
  end

  context 'when requesting awardEmoji' do
    let_it_be(:epic) do
      create(:epic, group: group) do |epic|
        create(:award_emoji, name: 'rocket', awardable: epic)
        create(:award_emoji, name: 'eyes', awardable: epic.sync_object)
        create(:award_emoji, name: AwardEmoji::THUMBS_UP, awardable: epic)
        create(:award_emoji, name: AwardEmoji::THUMBS_UP, awardable: epic.sync_object)
        create(:award_emoji, name: AwardEmoji::THUMBS_DOWN, awardable: epic)
        create(:award_emoji, name: AwardEmoji::THUMBS_DOWN, awardable: epic)
        create(:award_emoji, name: AwardEmoji::THUMBS_DOWN, awardable: epic.sync_object)
      end
    end

    let_it_be(:query) do
      <<-GQL
      query {
        group(fullPath: "#{group.full_path}") {
          epic(iid: #{epic.iid}) {
            upvotes
            downvotes
            awardEmoji {
              nodes {
                user {
                  username
                }
                name
              }
            }
          }
        }
      }
      GQL
    end

    it 'includes unified award emojis with sync work item' do
      post_graphql(query, current_user: user)

      response = graphql_data_at(:group, :epic, :award_emoji, :nodes)

      expect(response.length).to eq(7)
      expect(response.map do |emoji|
               emoji['user']['username']
             end.uniq).to match_array(epic.award_emoji.map(&:user).map(&:username).uniq)
      expect(response.pluck('name').uniq)
        .to match_array(%W[eyes rocket #{AwardEmoji::THUMBS_UP} #{AwardEmoji::THUMBS_DOWN}])
    end

    it 'includes unified upvotes and downvotes' do
      post_graphql(query, current_user: user)

      response = graphql_data_at(:group, :epic)

      expect(response['upvotes']).to eq(2)
      expect(response['downvotes']).to eq(3)
    end
  end

  describe 'N+1 query checks' do
    let_it_be(:epic_a) { create(:epic, :with_synced_work_item, group: group) }
    let_it_be(:epic_b) { create(:epic, :with_synced_work_item, group: group) }

    let(:extra_iid_for_second_query) { epic_b.iid.to_s }
    let(:search_params) { { iids: [epic_a.iid.to_s] } }

    def execute_query
      query = graphql_query_for(
        :group,
        { full_path: group.full_path },
        query_graphql_field(
          :epics, search_params,
          query_graphql_field(:nodes, nil, requested_fields)
        )
      )
      post_graphql(query, current_user: user)
    end

    context 'when requesting `upvotes` and `downvotes`' do
      let(:requested_fields) { 'upvotes downvotes' }

      before do
        create(:award_emoji, name: AwardEmoji::THUMBS_UP, awardable: epic_a.work_item)
        create(:award_emoji, name: AwardEmoji::THUMBS_UP, awardable: epic_b.work_item)
        create(:award_emoji, name: AwardEmoji::THUMBS_DOWN, awardable: epic_b.work_item, user: create(:user))
      end

      include_examples 'N+1 query check'
    end

    context 'when requesting `awardEmoji`' do
      let(:requested_fields) { 'awardEmoji { nodes { name } }' }

      before do
        create(:award_emoji, awardable: epic_a.work_item, user: user)
        create(:award_emoji, awardable: epic_b.work_item, user: user)
      end

      include_examples 'N+1 query check', threshold: 1

      it 'returns award emoji data' do
        execute_query

        response = graphql_data_at(:group, :epics, :nodes).flat_map { |node| node['awardEmoji']['nodes'] }

        expect(response).not_to be_empty
      end
    end

    context 'when requesting `health_status`' do
      let(:requested_fields) { 'healthStatus { issuesAtRisk issuesNeedingAttention issuesOnTrack }' }

      before do
        # Add children to epic_a
        create(:epic, group: group, title: 'child epic 1', parent: epic_a)
        create(:epic, group: group, title: 'child epic 2', parent: epic_a)
        # Add children to epic_b
        create(:epic, group: group, title: 'child epic 3', parent: epic_b)
        create(:epic, group: group, title: 'child epic 4', parent: epic_b)
      end

      include_examples 'N+1 query check'
    end

    context 'when requesting `linked_work_items`' do
      let_it_be(:blocking_work_items) { create_list(:work_item, 3, :issue, project: project) }
      let_it_be(:blocked_work_items) { create_list(:work_item, 3, :issue, project: project) }

      before do
        blocked_work_items.each do |work_item|
          create(:work_item_link, source: epic_a.work_item, target: work_item, link_type: 'blocks')
          create(:work_item_link, source: epic_b.work_item, target: work_item, link_type: 'blocks')
        end

        blocking_work_items.each do |work_item|
          create(:work_item_link, source: work_item, target: epic_a.work_item, link_type: 'blocks')
          create(:work_item_link, source: work_item, target: epic_b.work_item, link_type: 'blocks')
        end
      end

      shared_examples 'N+1 query check for linked work items' do
        let(:requested_fields) { "linkedWorkItems(filter: #{link_type}) { nodes { workItem { id } } }" }

        # Executes 1 extra query "SELECT issues.*, issue_links.id AS issue_link_id..."
        # related issue: https://gitlab.com/gitlab-org/gitlab/-/issues/512056
        include_examples 'N+1 query check', threshold: 1

        it 'N+1 query test contains data' do
          execute_query

          response = graphql_data_at(:group, :epics, :nodes).flat_map { |node| node['linkedWorkItems']['nodes'] }

          expect(response.count).to eq(3)
        end
      end

      it_behaves_like 'N+1 query check for linked work items' do
        let(:link_type) { 'BLOCKS' }
      end

      it_behaves_like 'N+1 query check for linked work items' do
        let(:link_type) { 'BLOCKED_BY' }
      end
    end
  end

  describe 'query for epics including their count' do
    let(:query) do
      <<~QUERY
        query groupEpics($groupPath: ID!, $firstPageSize: Int) {
          group(fullPath: $groupPath) {
            id
            epics(
              first: $firstPageSize
            ) {
              count
              nodes {
                id
                iid
              }
            }
          }
        }
      QUERY
    end

    before do
      create_list(:epic, 3, group: group)
    end

    it 'returns epics total count' do
      page_size = 2

      post_graphql(
        query,
        current_user: user,
        variables: {
          groupPath: group.full_path,
          firstPageSize: page_size
        }
      )

      epics = graphql_dig_at(graphql_data, :group, :epics)
      expect(epics['nodes'].size).to eq(page_size)
      expect(epics['count']).to eq(3)
    end
  end

  describe 'query for epics including linked work items' do
    let_it_be(:epic) { create(:epic, :with_synced_work_item, group: group) }
    let_it_be(:related_work_item) { create(:work_item, :issue, project: project) }
    let_it_be(:blocked_work_item) { create(:work_item, :issue, project: project) }
    let_it_be(:blocking_work_item) { create(:work_item, :issue, project: project) }

    let_it_be(:related_link) { create(:work_item_link, source: related_work_item, target: epic.work_item) }

    let_it_be(:blocking_link) do
      create(:work_item_link, source: blocking_work_item, target: epic.work_item, link_type: 'blocks')
    end

    let_it_be(:blocked_link) do
      create(:work_item_link, source: epic.work_item, target: blocked_work_item, link_type: 'blocks')
    end

    let(:node_path) { %w[group epic linkedWorkItems nodes] }

    let(:query) do
      <<~QUERY
        query groupEpics($groupPath: ID!, $epicIid: ID, $linkFilter: WorkItemRelatedLinkType) {
          group(fullPath: $groupPath) {
            epic(iid: $epicIid) {
              linkedWorkItems(filter: $linkFilter) {
                nodes {
                  linkId
                  linkType
                  workItem { id }
                }
              }
            }
          }
        }
      QUERY
    end

    shared_examples 'returns linked work items' do
      specify do
        post_graphql(query, current_user: user, variables: {
          groupPath: group.full_path,
          epicIid: epic.iid,
          linkFilter: type_filter
        })

        linked_work_items = graphql_dig_at(graphql_data, *node_path)
        expect(linked_work_items).to contain_exactly(
          {
            'linkId' => expected_link.to_global_id.to_s,
            'linkType' => expected_link_type,
            'workItem' => { 'id' => expected_work_item.to_global_id.to_s }
          }
        )
      end
    end

    it_behaves_like 'returns linked work items' do
      let(:type_filter) { 'RELATED' }
      let(:expected_link) { related_link }
      let(:expected_link_type) { 'relates_to' }
      let(:expected_work_item) { related_work_item }
    end

    it_behaves_like 'returns linked work items' do
      let(:type_filter) { 'BLOCKS' }
      let(:expected_link) { blocked_link }
      let(:expected_link_type) { 'blocks' }
      let(:expected_work_item) { blocked_work_item }
    end

    it_behaves_like 'returns linked work items' do
      let(:type_filter) { 'BLOCKED_BY' }
      let(:expected_link) { blocking_link }
      let(:expected_link_type) { 'is_blocked_by' }
      let(:expected_work_item) { blocking_work_item }
    end
  end

  def query_epics_with_events(number)
    epics_field = <<~NODE
      epics {
        nodes {
          id
          events(first: #{number}) {
            nodes {
              id
            }
          }
        }
      }
    NODE

    post_graphql(
      graphql_query_for('group', { 'fullPath' => group.full_path }, epics_field),
      current_user: user
    )
  end

  def query_epic_with_ancestors(epic_iid)
    epics_field = <<~NODE
      epic(iid: #{epic_iid}) {
        id
        ancestors {
          nodes {
            id
          }
        }
      }
    NODE

    post_graphql(
      graphql_query_for('group', { 'fullPath' => group.full_path }, epics_field),
      current_user: user
    )
  end

  def epics_query(group, args = {})
    fields = <<~QUERY
      nodes {
        id
      }
    QUERY

    graphql_query_for(
      'group',
      { 'fullPath' => group.full_path },
      query_graphql_field('epics', args, fields)
    )
  end

  def expect_epics_response(epics, node_path:)
    epics ||= []
    nodes = graphql_data.dig(*node_path)
    actual_epics = nodes.pluck('id')
    expected_epics = epics.map { |epic| epic.to_global_id.to_s }

    expect(actual_epics).to contain_exactly(*expected_epics)
    expect(graphql_errors).to be_nil
  end
end
