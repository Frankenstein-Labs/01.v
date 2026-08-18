# frozen_string_literal: true

require 'spec_helper'

RSpec.describe '(Group|Project|Organization).analytics.duoUsageEvents', :click_house, time_travel_to: '2026-01-30', feature_category: :code_suggestions do
  include GraphqlHelpers
  include ClickHouseHelpers

  let_it_be(:organization) { create(:organization, :public) }
  let_it_be(:group) { create(:group, organization: organization) }
  let_it_be(:group2) { create(:group, organization: organization) }
  let_it_be(:project1) { create(:project, group: group) }
  let_it_be(:project2) { create(:project, group: group2) }
  let_it_be(:current_user) { create(:user, reporter_of: [group, group2]) }
  let_it_be(:guest) { create(:user, guest_of: [group, group2]) }

  let_it_be(:user1) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:user3) { create(:user) }

  let(:code_suggestion_event) { Ai::UsageEvent.events[:code_suggestion_shown_in_ide] }
  let(:chat_event) { Ai::UsageEvent.events[:request_duo_chat_response] }
  let(:troubleshoot_job_event) { Ai::UsageEvent.events[:troubleshoot_job] }

  let(:events_data) do
    [
      # code_suggestions feature, Dec 2025
      event_row(user: user1, event: code_suggestion_event, timestamp: 50.days.ago),
      # chat feature, Jan 2026
      event_row(user: user1, event: chat_event, timestamp: 15.days.ago),
      event_row(user: user2, event: chat_event, timestamp: 12.days.ago),
      # troubleshoot_job feature, Jan 2026
      event_row(user: user2, event: troubleshoot_job_event, timestamp: 10.days.ago),
      # code_suggestions feature, Jan 2026
      event_row(user: user3, event: code_suggestion_event, timestamp: 8.days.ago),
      # group2 scope
      event_row(user: user1, event: chat_event, timestamp: 8.days.ago, project: project2)
    ]
  end

  # Minimal query used for authorization checks - only requests what is needed
  # to trigger the resolver without exercising any real data logic.
  let(:minimal_query) do
    <<~QUERY
      query {
        #{resource_query} {
          analytics {
            duoUsageEvents#{field_arguments} {
              aggregated {
                nodes { totalCount }
              }
            }
          }
        }
      }
    QUERY
  end

  # Builds a single row for the ai_usage_events ClickHouse fixture.
  def event_row(user:, event:, timestamp:, project: project1)
    {
      user_id: user.id,
      event: event,
      timestamp: timestamp,
      namespace_path: project.project_namespace.traversal_path(with_organization: false),
      extras: '{}'
    }
  end

  def full_paths_argument(*records)
    "[#{records.map { |record| "\"#{record.full_path}\"" }.join(', ')}]"
  end

  def field_arguments(filters = nil)
    args = [scope_arguments, filters].compact_blank.join("\n")

    args.blank? ? '' : "(#{args})"
  end

  before do
    stub_licensed_features(ai_analytics: true)
    allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)

    clickhouse_fixture(:ai_usage_events, events_data)
  end

  shared_examples 'reports inaccessible sources' do
    it 'reports the requested sources as inaccessible for guest' do
      post_graphql(minimal_query, current_user: guest)

      expect(graphql_errors).to match(
        [hash_including('message' => "The following sources are not accessible: #{inaccessible_source.full_path}")]
      )
    end

    it 'reports the requested sources as inaccessible when ai_analytics is not licensed' do
      stub_licensed_features(ai_analytics: false)

      post_graphql(minimal_query, current_user: current_user)

      expect(graphql_errors).to match(
        [hash_including('message' => "The following sources are not accessible: #{inaccessible_source.full_path}")]
      )
    end
  end

  shared_examples 'duoUsageEvents query' do
    # Shorthand for the aggregated connection returned by the query under test.
    let(:aggregated_data) { graphql_data.dig(query_type, 'analytics', 'duoUsageEvents', 'aggregated') }

    context 'when querying all possible filters and fields' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                duoUsageEvents#{field_arguments(%(
                  userId: ["#{user1.to_global_id}", "#{user2.to_global_id}"]
                  event: ["code_suggestion_shown_in_ide", "request_duo_chat_response"]
                  timestampFrom: "#{60.days.ago.iso8601}"
                  timestampTo: "#{5.days.ago.iso8601}"
                ))} {
                  aggregated(
                    orderBy: [
                      { identifier: "user", direction: DESC }
                      { identifier: "timestamp", direction: ASC, parameters: { granularity: "monthly" } }
                    ]
                  ) {
                    nodes {
                      dimensions {
                        feature
                        event
                        user { id }
                        timestampMonthly: timestamp(granularity: "monthly")
                      }
                      totalCount
                      usersCount
                      featuresCount
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'returns filtered and aggregated event data with all metrics and dimensions', :aggregate_failures do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = aggregated_data['nodes']
        expect(nodes.size).to eq(3)

        expect(nodes[0]).to eq(
          'dimensions' => {
            'feature' => 'chat',
            'event' => 'request_duo_chat_response',
            'user' => { 'id' => user2.to_global_id.to_s },
            'timestampMonthly' => '2026-01-01'
          },
          'totalCount' => 1, 'usersCount' => 1, 'featuresCount' => 1
        )

        expect(nodes[1]).to eq(
          'dimensions' => {
            'feature' => 'code_suggestions',
            'event' => 'code_suggestion_shown_in_ide',
            'user' => { 'id' => user1.to_global_id.to_s },
            'timestampMonthly' => '2025-12-01'
          },
          'totalCount' => 1, 'usersCount' => 1, 'featuresCount' => 1
        )

        expect(nodes[2]).to eq(
          'dimensions' => {
            'feature' => 'chat',
            'event' => 'request_duo_chat_response',
            'user' => { 'id' => user1.to_global_id.to_s },
            'timestampMonthly' => '2026-01-01'
          },
          'totalCount' => 1, 'usersCount' => 1, 'featuresCount' => 1
        )
      end
    end

    context 'when querying with single filter values' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                duoUsageEvents#{field_arguments(%(
                  userId: ["#{user1.to_global_id}"]
                  event: ["code_suggestion_shown_in_ide"]
                ))} {
                  aggregated {
                    nodes {
                      dimensions {
                        event
                        user { id }
                      }
                      totalCount
                      usersCount
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'returns only events matching single filter values' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        expect(aggregated_data['nodes']).to eq([{
          'dimensions' => {
            'event' => 'code_suggestion_shown_in_ide',
            'user' => { 'id' => user1.to_global_id.to_s }
          },
          'totalCount' => 1,
          'usersCount' => 1
        }])
      end
    end

    context 'when querying without filters' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                duoUsageEvents#{field_arguments} {
                  aggregated {
                    nodes {
                      totalCount
                      usersCount
                      featuresCount
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'aggregates all events in scope' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = aggregated_data['nodes']
        expect(nodes.size).to eq(1)
        expect(nodes[0]).to match('totalCount' => 5, 'usersCount' => 3, 'featuresCount' => 3)
      end
    end

    context 'when querying by feature filter' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                duoUsageEvents#{field_arguments(%(feature: ["code_suggestions", "chat"]))} {
                  aggregated {
                    count
                    nodes {
                      dimensions { feature }
                      totalCount
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'returns the number of aggregated rows for matching features' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        # code_suggestions and chat are 2 distinct feature groups
        expect(aggregated_data['count']).to eq(2)
      end
    end

    context 'when ordering by parameterized dimension with parameters' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                duoUsageEvents#{field_arguments(%(userId: ["#{user1.to_global_id}"]))} {
                  aggregated(
                    orderBy: [
                      { identifier: "timestamp", parameters: { granularity: "monthly" }, direction: DESC }
                    ]
                  ) {
                    nodes {
                      dimensions { timestamp(granularity: "monthly") }
                      totalCount
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'orders results by parameterized dimension correctly' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = aggregated_data['nodes']
        expect(nodes[0]['dimensions']['timestamp']).to eq('2026-01-01')
        expect(nodes[1]['dimensions']['timestamp']).to eq('2025-12-01')
      end
    end

    context 'when filtering by featuresCount range' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                duoUsageEvents#{field_arguments} {
                  aggregated(
                    orderBy: [{ identifier: "user", direction: ASC }]
                    featuresCountFrom: 2
                    featuresCountTo: 2
                  ) {
                    nodes {
                      dimensions { user { id } }
                      featuresCount
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'returns only users matching the metric range' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        expect(aggregated_data['nodes']).to eq([
          {
            'dimensions' => { 'user' => { 'id' => user1.to_global_id.to_s } },
            'featuresCount' => 2
          },
          {
            'dimensions' => { 'user' => { 'id' => user2.to_global_id.to_s } },
            'featuresCount' => 2
          }
        ])
      end
    end

    context 'when ordering by parameterized dimension without providing parameters' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                duoUsageEvents#{field_arguments(%(userId: ["#{user1.to_global_id}"]))} {
                  aggregated(
                    orderBy: [
                      { identifier: "timestamp", direction: DESC }
                    ]
                  ) {
                    nodes {
                      dimensions { timestamp(granularity: "monthly") }
                      totalCount
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'returns an error indicating the identifier is not available' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to match(
          [hash_including('message' => "the specified identifier is not available: 'timestamp'")]
        )
        expect(aggregated_data).to be_nil
      end
    end
  end

  context 'for group' do
    let(:query_type) { 'group' }
    let(:resource_query) { %(group(fullPath: "#{group.full_path}")) }
    let(:scope_arguments) { '' }
    let(:inaccessible_source) { group }

    it_behaves_like 'duoUsageEvents query'
    it_behaves_like 'reports inaccessible sources'
  end

  context 'for project' do
    let(:query_type) { 'project' }
    let(:resource_query) { %(project(fullPath: "#{project1.full_path}")) }
    let(:scope_arguments) { '' }
    let(:inaccessible_source) { project1 }

    it_behaves_like 'duoUsageEvents query'
    it_behaves_like 'reports inaccessible sources'
  end

  context 'for organization' do
    let(:query_type) { 'organization' }
    let(:resource_query) { %(organization(id: "#{organization.to_global_id}")) }
    let(:scope_arguments) { %(descendantsScope: { groupFullPaths: #{full_paths_argument(group)} }) }
    let(:inaccessible_source) { group }

    it_behaves_like 'duoUsageEvents query'
    it_behaves_like 'reports inaccessible sources'

    context 'when requesting multiple groups' do
      let(:scope_arguments) { %(descendantsScope: { groupFullPaths: #{full_paths_argument(group, group2)} }) }

      it 'aggregates data across the requested groups' do
        post_graphql(minimal_query, current_user: current_user)

        expect(graphql_errors).to be_nil
        expect(graphql_data.dig(query_type, 'analytics', 'duoUsageEvents', 'aggregated', 'nodes'))
          .to eq([{ 'totalCount' => 6 }])
      end
    end

    context 'when requesting a mix of groups and projects' do
      let(:scope_arguments) do
        <<~ARGS
          descendantsScope: {
            groupFullPaths: #{full_paths_argument(group)}
            projectFullPaths: #{full_paths_argument(project2)}
          }
        ARGS
      end

      it 'aggregates data from both the group and the project' do
        post_graphql(minimal_query, current_user: current_user)

        expect(graphql_errors).to be_nil
        expect(graphql_data.dig(query_type, 'analytics', 'duoUsageEvents', 'aggregated', 'nodes'))
          .to eq([{ 'totalCount' => 6 }])
      end
    end
  end
end
