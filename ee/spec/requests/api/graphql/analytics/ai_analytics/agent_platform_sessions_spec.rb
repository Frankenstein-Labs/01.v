# frozen_string_literal: true

require 'spec_helper'

RSpec.describe '(Group|Project|Organization).analytics.agentPlatformSessions', :click_house, time_travel_to: '2026-01-30', feature_category: :code_suggestions do
  include GraphqlHelpers
  include ClickHouseHelpers

  let_it_be(:organization) { create(:organization, :public) }
  let_it_be(:group) { create(:group, organization: organization) }
  let_it_be(:group2) { create(:group, organization: organization) }
  let_it_be(:project1) { create(:project, group: group) }
  let_it_be(:project2) { create(:project, group: group2) }
  let_it_be(:current_user) { create(:user, reporter_of: [group, group2]) }
  let_it_be(:guest) { create(:user, guest_of: [group, group2]) }
  let_it_be(:session_events_map) do
    {
      created_at: Ai::UsageEvent.events[:agent_platform_session_created],
      finished_at: Ai::UsageEvent.events[:agent_platform_session_finished],
      dropped_at: Ai::UsageEvent.events[:agent_platform_session_dropped],
      stopped_at: Ai::UsageEvent.events[:agent_platform_session_stopped],
      resumed_at: Ai::UsageEvent.events[:agent_platform_session_resumed]
    }
  end

  let_it_be(:user1) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:user3) { create(:user) }

  let(:sessions_data) do
    [
      # User 1, very old
      {
        session_id: 1,
        user_id: user1.id,
        flow_type: 'duo_chat',
        project: project1,
        created_at: 100.days.ago,
        finished_at: 100.days.ago + 45.seconds,
        environment: 'prod'
      },
      {
        session_id: 2,
        user_id: user1.id,
        flow_type: 'duo_chat',
        project: project1,
        created_at: 50.days.ago,
        finished_at: 50.days.ago + 90.seconds,
        environment: 'prod'
      },
      {
        session_id: 3,
        user_id: user1.id,
        flow_type: 'duo_chat',
        project: project1,
        created_at: 15.days.ago,
        environment: 'prod'
      },
      # User 2, code_review sessions
      {
        session_id: 4,
        user_id: user2.id,
        flow_type: 'code_review',
        project: project1,
        created_at: 12.days.ago,
        finished_at: 12.days.ago + 60.seconds,
        environment: 'prod'
      },
      # Not finished
      {
        session_id: 5,
        user_id: user2.id,
        flow_type: 'code_review',
        project: project1,
        created_at: 8.days.ago,
        environment: 'prod' # Not finished
      },
      # User 3
      {
        session_id: 6,
        user_id: user3.id,
        flow_type: 'code_generation',
        project: project1,
        created_at: 8.days.ago,
        finished_at: 8.days.ago + 30.seconds,
        environment: 'prod'
      },
      # code_review
      {
        session_id: 7,
        user_id: user1.id,
        flow_type: 'code_review',
        project: project1,
        created_at: 10.days.ago,
        finished_at: 10.days.ago + 150.seconds,
        environment: 'prod'
      },
      # code generation
      {
        session_id: 8,
        user_id: user1.id,
        flow_type: 'code_generation',
        project: project1,
        created_at: 8.days.ago,
        finished_at: 8.days.ago + 30.seconds,
        environment: 'prod'
      },
      # different project (group2 scope)
      {
        session_id: 9,
        user_id: user1.id,
        flow_type: 'code_review',
        project: project2,
        created_at: 8.days.ago,
        finished_at: 8.days.ago + 30.seconds,
        environment: 'prod'
      }
    ]
  end

  let(:minimal_query) do
    <<~QUERY
      query {
        #{resource_query} {
          analytics {
            agentPlatformSessions#{field_arguments} { aggregated { nodes { totalCount } } }
          }
        }
      }
    QUERY
  end

  before do
    stub_licensed_features(ai_analytics: true)
    allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)

    events_data = sessions_data.flat_map do |session|
      session_events_map.map do |timestamp_name, event_value|
        next unless session[timestamp_name]

        event_data(session.merge(
          event: event_value,
          timestamp: session[timestamp_name]))
      end
    end.compact

    clickhouse_fixture(:ai_usage_events, events_data)
  end

  def event_data(data)
    data.slice(*%i[user_id event timestamp]).merge(
      namespace_path: data[:project].project_namespace.traversal_path(with_organization: false),
      extras: data.slice(*%i[environment flow_type session_id]).merge(project_id: data[:project].id)
    )
  end

  def full_paths_argument(*records)
    "[#{records.map { |record| "\"#{record.full_path}\"" }.join(', ')}]"
  end

  def field_arguments(filters = nil)
    args = [scope_arguments, filters].compact_blank.join("\n")

    args.blank? ? '' : "(#{args})"
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

  shared_examples 'agentPlatformSessions query' do
    context 'when querying all possible filters and fields' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                agentPlatformSessions#{field_arguments(%(
                  userId: ["#{user1.to_global_id}", "#{user2.to_global_id}"]
                  flowType: ["duo_chat", "code_review"]
                  createdEventAtFrom: "#{60.days.ago.iso8601}"
                  createdEventAtTo: "#{5.days.ago.iso8601}"
                ))} {
                  aggregated(
                    orderBy: [
                      { identifier: "user", direction: DESC }
                      { identifier: "mean_duration", direction: DESC }
                    ]
                  ) {
                    nodes {
                      dimensions {
                        flowType
                        user {
                          id
                        }
                        createdEventAtMonthly: createdEventAt(granularity: "monthly")
                        createdEventAtWeekly: createdEventAt(granularity: "weekly")
                      }
                      totalCount
                      finishedCount
                      usersCount
                      meanDuration
                      completionRate
                      durationQuantile50: durationQuantile
                      durationQuantile95: durationQuantile(quantile: 0.95)
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'returns filtered and aggregated session data with all metrics and dimensions', :aggregate_failures do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = graphql_data.dig(query_type, 'analytics', 'agentPlatformSessions', 'aggregated', 'nodes')

        expect(nodes.size).to eq(5)

        # Sessions 1,6,8,9 should be filtered out.
        expect(nodes[0]).to eq(
          'dimensions' => {
            'flowType' => 'code_review',
            'user' => {
              'id' => user2.to_global_id.to_s
            },
            'createdEventAtMonthly' => '2026-01-01',
            'createdEventAtWeekly' => '2026-01-12'
          },
          'totalCount' => 1,
          'finishedCount' => 1,
          'usersCount' => 1,
          'meanDuration' => 60.0,
          'completionRate' => 1.0,
          'durationQuantile50' => 60.0,
          'durationQuantile95' => 60.0
        )
        expect(nodes[1]).to eq(
          'dimensions' => {
            'flowType' => 'code_review',
            'user' => {
              'id' => user2.to_global_id.to_s
            },
            'createdEventAtMonthly' => '2026-01-01',
            'createdEventAtWeekly' => '2026-01-19'
          },
          'totalCount' => 1,
          'finishedCount' => 0,
          'usersCount' => 1,
          'meanDuration' => nil,
          'completionRate' => 0.0,
          'durationQuantile50' => nil,
          'durationQuantile95' => nil
        )
        expect(nodes[2]).to eq(
          'dimensions' => {
            'flowType' => 'code_review',
            'user' => {
              'id' => user1.to_global_id.to_s
            },
            'createdEventAtMonthly' => '2026-01-01',
            'createdEventAtWeekly' => '2026-01-19'
          },
          'totalCount' => 1,
          'finishedCount' => 1,
          'usersCount' => 1,
          'meanDuration' => 150.0,
          'completionRate' => 1.0,
          'durationQuantile50' => 150.0,
          'durationQuantile95' => 150.0
        )
        expect(nodes[3]).to eq(
          'dimensions' => {
            'flowType' => 'duo_chat',
            'user' => {
              'id' => user1.to_global_id.to_s
            },
            'createdEventAtMonthly' => '2025-12-01',
            'createdEventAtWeekly' => '2025-12-08'
          },
          'totalCount' => 1,
          'finishedCount' => 1,
          'usersCount' => 1,
          'meanDuration' => 90.0,
          'completionRate' => 1.0,
          'durationQuantile50' => 90.0,
          'durationQuantile95' => 90.0
        )
        expect(nodes[4]).to eq(
          'dimensions' => {
            'flowType' => 'duo_chat',
            'user' => {
              'id' => user1.to_global_id.to_s
            },
            'createdEventAtMonthly' => '2026-01-01',
            'createdEventAtWeekly' => '2026-01-12'
          },
          'totalCount' => 1,
          'finishedCount' => 0,
          'usersCount' => 1,
          'meanDuration' => nil,
          'completionRate' => 0.0,
          'durationQuantile50' => nil,
          'durationQuantile95' => nil
        )
      end
    end

    context 'when querying for different quantiles' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                agentPlatformSessions#{field_arguments(%(userId: ["#{user1.to_global_id}"]))} {
                  aggregated {
                    nodes {
                      durationQuantile50: durationQuantile
                      durationQuantile95: durationQuantile(quantile: 0.95)
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'returns different quantiles within the same request', :aggregate_failures do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = graphql_data.dig(query_type, 'analytics', 'agentPlatformSessions', 'aggregated', 'nodes')

        expect(nodes.size).to eq(1)
        expect(nodes[0]).to match(
          'durationQuantile50' => 67.5,
          'durationQuantile95' => within(1).of(141.0)
        )
      end
    end

    context 'when querying with single filter values' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                agentPlatformSessions#{field_arguments(%(
                  userId: ["#{user1.to_global_id}"]
                  flowType: ["duo_chat"]
                ))} {
                  aggregated {
                    nodes {
                      dimensions {
                        flowType
                        user {
                          id
                        }
                      }
                      totalCount
                      finishedCount
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'returns only sessions matching single filter values' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = graphql_data.dig(query_type, 'analytics', 'agentPlatformSessions', 'aggregated', 'nodes')

        expect(nodes).to eq([{
          'totalCount' => 3,
          'finishedCount' => 2,
          'dimensions' => {
            'flowType' => 'duo_chat',
            'user' => {
              'id' => user1.to_global_id.to_s
            }
          }
        }])
      end
    end

    context 'when querying without filters' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                agentPlatformSessions#{field_arguments} {
                  aggregated {
                    nodes {
                      totalCount
                      finishedCount
                      usersCount
                      meanDuration
                      completionRate
                      durationQuantile
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'aggregates all sessions' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = graphql_data.dig(query_type, 'analytics', 'agentPlatformSessions', 'aggregated', 'nodes')

        # Should include 8 sessions
        expect(nodes.size).to eq(1)
        expect(nodes[0]).to match(
          'totalCount' => 8,
          'finishedCount' => 6,
          'usersCount' => 3,
          'meanDuration' => 67.5,
          'completionRate' => 0.75,
          'durationQuantile' => 52.5
        )
      end
    end

    context 'when querying the duration measurement group' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                agentPlatformSessions#{field_arguments} {
                  aggregated {
                    nodes {
                      meanDuration
                      duration {
                        min
                        max
                        mean
                        quantile50: quantile
                        quantile95: quantile(quantile: 0.95)
                      }
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'returns nested aggregates alongside the flat duration metrics', :aggregate_failures do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = graphql_data.dig(query_type, 'analytics', 'agentPlatformSessions', 'aggregated', 'nodes')

        expect(nodes.size).to eq(1)
        expect(nodes[0]).to match(
          'meanDuration' => 67.5,
          'duration' => {
            'min' => 30,
            'max' => 150,
            'mean' => 67.5,
            'quantile50' => 52.5,
            'quantile95' => within(1).of(135.0)
          }
        )
      end

      it 'supports ordering by a dotted metric identifier' do
        order_query = <<~QUERY
          query {
            #{resource_query} {
              analytics {
                agentPlatformSessions#{field_arguments} {
                  aggregated(
                    orderBy: [
                      { identifier: "duration.max", direction: DESC }
                    ]
                  ) {
                    nodes {
                      dimensions {
                        flowType
                      }
                      duration {
                        max
                      }
                    }
                  }
                }
              }
            }
          }
        QUERY

        post_graphql(order_query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = graphql_data.dig(query_type, 'analytics', 'agentPlatformSessions', 'aggregated', 'nodes')

        expect(nodes).to eq([
          { 'dimensions' => { 'flowType' => 'code_review' }, 'duration' => { 'max' => 150 } },
          { 'dimensions' => { 'flowType' => 'duo_chat' }, 'duration' => { 'max' => 90 } },
          { 'dimensions' => { 'flowType' => 'code_generation' }, 'duration' => { 'max' => 30 } }
        ])
      end
    end

    context 'when querying count' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                agentPlatformSessions#{field_arguments(%(flowType: ["duo_chat", "code_review"]))} {
                  aggregated {
                    count
                    nodes {
                      dimensions {
                        flowType
                      }
                      totalCount
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'returns the number of aggregated rows independently of pagination' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        data = graphql_data.dig(query_type, 'analytics', 'agentPlatformSessions', 'aggregated')
        # duo_chat and code_review are 2 distinct flow_type groups
        expect(data['count']).to eq(2)
      end
    end

    context 'when ordering by parameterized dimension with parameters' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                agentPlatformSessions#{field_arguments(%(
                  userId: ["#{user1.to_global_id}"]
                  flowType: ["duo_chat"]
                ))} {
                  aggregated(
                    orderBy: [
                      { identifier: "createdEventAt", parameters: { granularity: "monthly" }, direction: DESC }
                    ]
                  ) {
                    nodes {
                      dimensions {
                        createdEventAt(granularity: "monthly")
                      }
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

        nodes = graphql_data.dig(query_type, 'analytics', 'agentPlatformSessions', 'aggregated', 'nodes')

        expect(nodes[0]['dimensions']['createdEventAt']).to eq('2026-01-01')
        expect(nodes[1]['dimensions']['createdEventAt']).to eq('2025-12-01')
        expect(nodes[2]['dimensions']['createdEventAt']).to eq('2025-10-01')
      end
    end

    context 'when ordering by parameterized dimension without providing parameters' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                agentPlatformSessions#{field_arguments(%(userId: ["#{user1.to_global_id}"]))} {
                  aggregated(
                    orderBy: [
                      { identifier: "createdEventAt", direction: DESC }
                    ]
                  ) {
                    nodes {
                      dimensions {
                        createdEventAt(granularity: "monthly")
                      }
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
          [hash_including('message' => "the specified identifier is not available: 'created_event_at'")]
        )
        nodes = graphql_data.dig(query_type, 'analytics', 'agentPlatformSessions', 'aggregated', 'nodes')

        expect(nodes).to be_nil
      end
    end

    context 'when query is empty' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                agentPlatformSessions#{field_arguments} {
                  aggregated { count }
                }
              }
            }
          }
        QUERY
      end

      it 'returns errors' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to match(
          [hash_including('message' => "Metrics at least one metric is required")]
        )
        count = graphql_data.dig(query_type, 'analytics', 'agentPlatformSessions', 'aggregated', 'count')

        expect(count).to be_nil
      end
    end

    context 'when querying with Apollo metadata fields like __typename' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                agentPlatformSessions#{field_arguments} {
                  aggregated {
                    nodes {
                      __typename
                      totalCount
                      dimensions {
                        __typename
                        flowType
                      }
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'ignores metadata fields and returns data without errors' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil
        nodes = graphql_data.dig(query_type, 'analytics', 'agentPlatformSessions', 'aggregated', 'nodes')
        expect(nodes).not_to be_nil
      end
    end

    context 'when query is invalid' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                agentPlatformSessions#{field_arguments} {
                  aggregated(
                    orderBy: [
                      { identifier: "invalid_order", direction: DESC }
                    ]
                  ) {
                    nodes {
                      totalCount
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'returns errors' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to match(
          [hash_including('message' => "the specified identifier is not available: 'invalid_order'")]
        )
        nodes = graphql_data.dig(query_type, 'analytics', 'agentPlatformSessions', 'aggregated', 'nodes')

        expect(nodes).to be_nil
      end
    end
  end

  context 'for group' do
    let(:query_type) { 'group' }
    let(:resource_query) { %(group(fullPath: "#{group.full_path}")) }
    let(:scope_arguments) { '' }
    let(:inaccessible_source) { group }

    it_behaves_like 'agentPlatformSessions query'
    it_behaves_like 'reports inaccessible sources'
  end

  context 'for project' do
    let(:query_type) { 'project' }
    let(:resource_query) { %(project(fullPath: "#{project1.full_path}")) }
    let(:scope_arguments) { '' }
    let(:inaccessible_source) { project1 }

    it_behaves_like 'agentPlatformSessions query'
    it_behaves_like 'reports inaccessible sources'
  end

  context 'for organization' do
    let(:query_type) { 'organization' }
    let(:resource_query) { %(organization(id: "#{organization.to_global_id}")) }
    let(:scope_arguments) { %(descendantsScope: { groupFullPaths: #{full_paths_argument(group)} }) }
    let(:inaccessible_source) { group }

    it_behaves_like 'agentPlatformSessions query'
    it_behaves_like 'reports inaccessible sources'

    context 'when requesting multiple groups' do
      let(:scope_arguments) { %(descendantsScope: { groupFullPaths: #{full_paths_argument(group, group2)} }) }

      it 'aggregates data across the requested groups' do
        post_graphql(minimal_query, current_user: current_user)

        expect(graphql_errors).to be_nil
        expect(graphql_data.dig(query_type, 'analytics', 'agentPlatformSessions', 'aggregated', 'nodes'))
          .to eq([{ 'totalCount' => 9 }])
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
        expect(graphql_data.dig(query_type, 'analytics', 'agentPlatformSessions', 'aggregated', 'nodes'))
          .to eq([{ 'totalCount' => 9 }])
      end
    end
  end
end
