# frozen_string_literal: true

require 'spec_helper'

RSpec.describe '(Group|Project|Organization).analytics.pipelines', :click_house, time_travel_to: '2026-01-30',
  feature_category: :pipeline_composition do
  include GraphqlHelpers
  include ClickHouseHelpers

  let_it_be(:organization) { create(:organization, :public) }
  let_it_be(:group) { create(:group, organization: organization) }
  let_it_be(:group2) { create(:group, organization: organization) }
  let_it_be(:project1) { create(:project, group: group) }
  let_it_be(:project2) { create(:project, group: group2) }
  let_it_be(:current_user) { create(:user, reporter_of: [group, group2]) }
  let_it_be(:guest) { create(:user, guest_of: [group, group2]) }

  let(:sources) { ::Enums::Ci::Pipeline.sources }

  let(:pipelines_data) do
    [
      { id: 1, ref: 'main', source: :push, status: 'success', duration: 60,
        started_at: 100.days.ago, project: project1 },
      { id: 2, ref: 'main', source: :push, status: 'success', duration: 120,
        started_at: 50.days.ago, project: project1 },
      { id: 3, ref: 'main', source: :push, status: 'failed', duration: 30,
        started_at: 15.days.ago, project: project1 },
      { id: 4, ref: 'main', source: :schedule, status: 'success', duration: 90,
        started_at: 12.days.ago, project: project1 },
      { id: 5, ref: 'develop', source: :push, status: 'canceled', duration: 20,
        started_at: 8.days.ago, project: project1 },
      { id: 6, ref: 'develop', source: :push, status: 'skipped', duration: 0,
        started_at: 8.days.ago, project: project1 },
      { id: 7, ref: 'main', source: :push, status: 'success', duration: 45,
        started_at: 8.days.ago, project: project1 },
      { id: 8, ref: 'main', source: :push, status: 'success', duration: 75,
        started_at: 10.days.ago, project: project1 },
      # group2 scope
      { id: 9, ref: 'main', source: :push, status: 'success', duration: 55,
        started_at: 8.days.ago, project: project2 }
    ]
  end

  let(:access_query) do
    <<~QUERY
      query {
        #{resource_query} {
          analytics {
            pipelines#{field_arguments} {
              aggregated {
                nodes { totalCount }
              }
            }
          }
        }
      }
    QUERY
  end

  before do
    allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)

    rows = pipelines_data.map do |p|
      {
        id: p[:id],
        partition_id: 100,
        project_id: p[:project].id,
        traversal_path: p[:project].project_namespace.traversal_path(with_organization: true).to_s,
        ref: p[:ref],
        source: sources[p[:source]],
        status: p[:status],
        duration: p[:duration],
        started_at: p[:started_at],
        finished_at: p[:started_at] + p[:duration].seconds,
        _siphon_replicated_at: Time.current,
        _siphon_deleted: false
      }
    end

    clickhouse_fixture(:siphon_p_ci_pipelines, rows)
  end

  def full_paths_argument(*records)
    "[#{records.map { |record| "\"#{record.full_path}\"" }.join(', ')}]"
  end

  def field_arguments(filters = nil)
    args = [scope_arguments, filters].compact_blank.join("\n")

    args.blank? ? '' : "(#{args})"
  end

  shared_examples 'reports inaccessible sources for guest' do
    it 'reports the requested sources as inaccessible for guest' do
      post_graphql(access_query, current_user: guest)

      expect(graphql_errors).to match(
        [hash_including('message' => "The following sources are not accessible: #{inaccessible_source.full_path}")]
      )
    end
  end

  shared_examples 'pipelines query' do
    context 'when querying with all filters and dimensions' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                pipelines#{field_arguments(%(
                  ref: ["main"]
                  source: ["push"]
                  startedAtFrom: "#{30.days.ago.iso8601}"
                  startedAtTo: "#{5.days.ago.iso8601}"
                ))} {
                  aggregated(
                    orderBy: [
                      { identifier: "status", direction: ASC }
                      { identifier: "startedAt", direction: ASC, parameters: { granularity: "monthly" } }
                    ]
                  ) {
                    nodes {
                      dimensions {
                        status
                        ref
                        source
                        startedAtMonthly: startedAt(granularity: "monthly")
                      }
                      totalCount
                      successOutcome: outcomeRate(status: "success")
                      failureOutcome: outcomeRate(status: "failed")
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'returns filtered and aggregated pipeline data', :aggregate_failures do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = graphql_data.dig(query_type, 'analytics', 'pipelines', 'aggregated', 'nodes')

        expect(nodes.size).to eq(2)

        expect(nodes[0]).to eq(
          'dimensions' => {
            'status' => 'failed',
            'ref' => 'main',
            'source' => 'push',
            'startedAtMonthly' => '2026-01-01'
          },
          'totalCount' => 1,
          'successOutcome' => 0.0,
          'failureOutcome' => 1.0
        )

        expect(nodes[1]).to eq(
          'dimensions' => {
            'status' => 'success',
            'ref' => 'main',
            'source' => 'push',
            'startedAtMonthly' => '2026-01-01'
          },
          'totalCount' => 2,
          'successOutcome' => 1.0,
          'failureOutcome' => 0.0
        )
      end
    end

    context 'when querying without filters' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                pipelines#{field_arguments} {
                  aggregated {
                    nodes {
                      totalCount
                      successOutcome: outcomeRate(status: "success")
                      failureOutcome: outcomeRate(status: "failed")
                      canceledOutcome: outcomeRate(status: "canceled")
                      skippedOutcome: outcomeRate(status: "skipped")
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'aggregates all pipelines in scope' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = graphql_data.dig(query_type, 'analytics', 'pipelines', 'aggregated', 'nodes')

        expect(nodes.size).to eq(1)
        expect(nodes[0]).to match(
          'totalCount' => 8,
          # denominator is completed pipelines (8), not all pipelines
          'successOutcome' => be_within(0.01).of(0.625),
          'failureOutcome' => be_within(0.01).of(0.125),
          'canceledOutcome' => be_within(0.01).of(0.125),
          'skippedOutcome' => be_within(0.01).of(0.125)
        )
      end
    end

    context 'when querying durationQuantile' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                pipelines#{field_arguments} {
                  aggregated {
                    nodes {
                      p50Duration: durationQuantile
                      p90Duration: durationQuantile(quantile: 0.9)
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'returns duration quantiles across all pipelines in scope' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = graphql_data.dig(query_type, 'analytics', 'pipelines', 'aggregated', 'nodes')

        expect(nodes.size).to eq(1)
        expect(nodes[0]).to match(
          'p50Duration' => be_within(0.01).of(52.5),
          'p90Duration' => be_within(0.01).of(99.0)
        )
      end
    end

    context 'when querying outcomeRate with an array of statuses' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                pipelines#{field_arguments} {
                  aggregated {
                    nodes {
                      totalCount
                      failedOrCanceled: outcomeRate(status: ["failed", "canceled"])
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'treats the array as OR and returns the combined rate among completed pipelines' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = graphql_data.dig(query_type, 'analytics', 'pipelines', 'aggregated', 'nodes')
        # 8 completed pipelines in scope; 1 failed + 1 canceled = 2
        expect(nodes.first['failedOrCanceled']).to be_within(0.01).of(0.25)
      end
    end

    context 'when querying totalCount with source and status parameters' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                pipelines#{field_arguments} {
                  aggregated {
                    nodes {
                      totalCount
                      scheduleCount: totalCount(source: "schedule")
                      pushOrScheduleCount: totalCount(source: ["push", "schedule"])
                      failedCount: totalCount(status: "failed")
                      pushSuccessCount: totalCount(source: "push", status: "success")
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'returns total and filtered counts from a single field', :aggregate_failures do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = graphql_data.dig(query_type, 'analytics', 'pipelines', 'aggregated', 'nodes')

        expect(nodes.size).to eq(1)
        expect(nodes[0]).to eq(
          'totalCount' => 8,
          'scheduleCount' => 1,
          'pushOrScheduleCount' => 8,
          'failedCount' => 1,
          'pushSuccessCount' => 4
        )
      end
    end

    context 'when querying count' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                pipelines#{field_arguments(%(status: ["success", "failed"]))} {
                  aggregated {
                    count
                    nodes {
                      dimensions { status }
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

        data = graphql_data.dig(query_type, 'analytics', 'pipelines', 'aggregated')
        expect(data['count']).to eq(2)
      end
    end
  end

  context 'for group' do
    let(:query_type) { 'group' }
    let(:resource_query) { %(group(fullPath: "#{group.full_path}")) }
    let(:scope_arguments) { '' }
    let(:inaccessible_source) { group }

    it_behaves_like 'pipelines query'
    it_behaves_like 'reports inaccessible sources for guest'

    context 'when requesting projects within the group' do
      let(:scope_arguments) { %(descendantsScope: { projectFullPaths: #{full_paths_argument(project1)} }) }

      it 'scopes the aggregation to the requested project' do
        post_graphql(access_query, current_user: current_user)

        expect(graphql_errors).to be_nil
        expect(graphql_data.dig(query_type, 'analytics', 'pipelines', 'aggregated', 'nodes'))
          .to eq([{ 'totalCount' => 8 }])
      end
    end

    context 'when requesting sources outside the group hierarchy' do
      let(:scope_arguments) { %(descendantsScope: { groupFullPaths: #{full_paths_argument(group2)} }) }

      it 'reports the out-of-hierarchy group as inaccessible even though the user is a member' do
        post_graphql(access_query, current_user: current_user)

        expect(graphql_errors).to match(
          [hash_including('message' => "The following sources are not accessible: #{group2.full_path}")]
        )
      end
    end
  end

  context 'for project' do
    let(:query_type) { 'project' }
    let(:resource_query) { %(project(fullPath: "#{project1.full_path}")) }
    let(:scope_arguments) { '' }
    let(:inaccessible_source) { project1 }

    it_behaves_like 'pipelines query'
    it_behaves_like 'reports inaccessible sources for guest'

    context 'when passing source arguments' do
      let(:scope_arguments) { %(descendantsScope: { groupFullPaths: #{full_paths_argument(group)} }) }

      it 'rejects the arguments' do
        post_graphql(access_query, current_user: current_user)

        expect(graphql_errors).to match(
          [hash_including(
            'message' => 'groupFullPaths and projectFullPaths arguments are not supported at project level')]
        )
      end
    end
  end

  context 'for organization' do
    let(:query_type) { 'organization' }
    let(:resource_query) { %(organization(id: "#{organization.to_global_id}")) }
    let(:scope_arguments) { %(descendantsScope: { groupFullPaths: #{full_paths_argument(group)} }) }
    let(:inaccessible_source) { group }

    it_behaves_like 'pipelines query'
    it_behaves_like 'reports inaccessible sources for guest'

    context 'when requesting multiple groups' do
      let(:scope_arguments) { %(descendantsScope: { groupFullPaths: #{full_paths_argument(group, group2)} }) }

      it 'aggregates data across the requested groups' do
        post_graphql(access_query, current_user: current_user)

        expect(graphql_errors).to be_nil
        expect(graphql_data.dig(query_type, 'analytics', 'pipelines', 'aggregated', 'nodes'))
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
        post_graphql(access_query, current_user: current_user)

        expect(graphql_errors).to be_nil
        expect(graphql_data.dig(query_type, 'analytics', 'pipelines', 'aggregated', 'nodes'))
          .to eq([{ 'totalCount' => 9 }])
      end
    end

    describe 'project dimension' do
      let_it_be(:project3) { create(:project, group: group) }

      let(:scope_arguments) { %(descendantsScope: { groupFullPaths: #{full_paths_argument(group, group2)} }) }

      let(:pipelines_data) do
        [
          { id: 1, ref: 'main', source: :push, status: 'success', duration: 60,
            started_at: 10.days.ago, project: project1 },
          { id: 2, ref: 'main', source: :push, status: 'success', duration: 30,
            started_at: 10.days.ago, project: project1 },
          { id: 3, ref: 'main', source: :push, status: 'failed', duration: 90,
            started_at: 10.days.ago, project: project3 },
          { id: 4, ref: 'main', source: :push, status: 'success', duration: 45,
            started_at: 10.days.ago, project: project2 }
        ]
      end

      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                pipelines#{field_arguments} {
                  aggregated(
                    orderBy: [{ identifier: "project", direction: ASC }]
                  ) {
                    nodes {
                      dimensions {
                        project {
                          id
                          fullPath
                        }
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

      it 'returns pipelines grouped by project for all projects in the requested groups', :aggregate_failures do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = graphql_data.dig(query_type, 'analytics', 'pipelines', 'aggregated', 'nodes')

        expect(nodes.size).to eq(3)
        project_paths = nodes.map { |n| n.dig('dimensions', 'project', 'fullPath') }
        expect(project_paths).to match_array([project1.full_path, project2.full_path, project3.full_path])
      end
    end
  end

  describe 'project dimension' do
    let_it_be(:project3) { create(:project, group: group) }

    let(:pipelines_data) do
      [
        { id: 1, ref: 'main', source: :push, status: 'success', duration: 60,
          started_at: 10.days.ago, project: project1 },
        { id: 2, ref: 'main', source: :push, status: 'success', duration: 30,
          started_at: 10.days.ago, project: project1 },
        { id: 3, ref: 'main', source: :push, status: 'failed', duration: 90,
          started_at: 10.days.ago, project: project3 },
        { id: 4, ref: 'main', source: :push, status: 'success', duration: 45,
          started_at: 10.days.ago, project: project2 }
      ]
    end

    let(:query) do
      <<~QUERY
        query {
          group(fullPath: "#{group.full_path}") {
            analytics {
              pipelines {
                aggregated(
                  orderBy: [{ identifier: "project", direction: ASC }]
                ) {
                  nodes {
                    dimensions {
                      project {
                        id
                        fullPath
                      }
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

    it 'returns pipelines grouped by project for all projects in the group', :aggregate_failures do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to be_nil

      nodes = graphql_data.dig('group', 'analytics', 'pipelines', 'aggregated', 'nodes')

      expect(nodes.size).to eq(2)
      project_paths = nodes.map { |n| n.dig('dimensions', 'project', 'fullPath') }
      expect(project_paths).to match_array([project1.full_path, project3.full_path])
    end
  end
end
