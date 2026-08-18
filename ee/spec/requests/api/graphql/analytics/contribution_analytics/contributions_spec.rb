# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group.contributions', feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let(:query) do
    <<~QUERY
      query($fullPath: ID!, $cursor: String) {
        group(fullPath: $fullPath) {
          contributions(from: "2022-01-01", to: "2022-01-10", after: $cursor, first: 1) {
            nodes {
              user {
                id
              }
              totalEvents
              repoPushed
              issuesClosed
            }
            pageInfo {
              endCursor
            }
          }
        }
      }
    QUERY
  end

  let_it_be(:banned_user) { create(:user, :banned) }
  let_it_be(:another_user) { create(:user) }
  let_it_be(:group) { create(:group, developers: [user, another_user]) }
  let_it_be(:project) { create(:project, group: group) }

  context 'when the license is not available' do
    it 'returns no data' do
      stub_licensed_features(contribution_analytics: false)

      post_graphql(query, current_user: user, variables: { fullPath: group.full_path })

      expect(graphql_data).to eq({ 'group' => { 'contributions' => nil } })
    end
  end

  context 'when the license is available' do
    before do
      stub_licensed_features(contribution_analytics: true)
      create(:event, :pushed, project: project, author: user, created_at: Date.parse('2022-01-05'))
      create(:event, :pushed, project: project, author: banned_user, created_at: Date.parse('2022-01-05'))
      create(:closed_issue_event, project: project, author: another_user, created_at: Date.parse('2022-01-05'))
    end

    shared_examples 'returns correct data' do
      it 'returns data' do
        post_graphql(query, current_user: user, variables: { fullPath: group.full_path })

        expect(graphql_data_at('group', 'contributions', 'nodes')).to eq([
          { 'user' => { 'id' => user.to_gid.to_s },
            'totalEvents' => 1,
            'repoPushed' => 1,
            'issuesClosed' => 0 }
        ])
      end

      context 'when paginating to the second page' do
        it 'returns the correct data' do
          post_graphql(query, current_user: user, variables: { fullPath: group.full_path })

          cursor = graphql_data_at('group', 'contributions', 'pageInfo', 'endCursor')

          post_graphql(query, current_user: user, variables: { fullPath: group.full_path, cursor: cursor })

          expect(graphql_data_at('group', 'contributions', 'nodes')).to eq([
            { 'user' => { 'id' => another_user.to_gid.to_s },
              'totalEvents' => 1,
              'repoPushed' => 0,
              'issuesClosed' => 1 }
          ])
        end
      end

      context 'when bogus cursor is passed' do
        it 'raises error' do
          cursor = Base64.strict_encode64('invalid')

          post_graphql(query, current_user: user, variables: { fullPath: group.full_path, cursor: cursor })

          expect { graphql_data }.to raise_error(GraphqlHelpers::NoData)
        end
      end
    end

    context 'when postgres is the data source' do
      it_behaves_like 'returns correct data'

      context 'with events from different users' do
        def run_query
          post_graphql(query, current_user: user, variables: { fullPath: group.full_path })
        end

        it 'does not create N+1 queries' do
          # warm the query to avoid flakiness
          run_query

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) { run_query }

          create(:event, :pushed, project: project, author: create(:user), created_at: Date.parse('2022-01-05'))
          expect { run_query }.not_to exceed_all_query_limit(control)
        end
      end
    end

    context 'when clickhouse is the data source', :click_house do
      before do
        allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)

        insert_events_into_click_house
      end

      it_behaves_like 'returns correct data'
    end
  end
end
