# frozen_string_literal: true

require 'spec_helper'

RSpec.describe '(Group|Project|Organization).analytics.mergeRequests', :click_house, time_travel_to: '2026-01-30',
  feature_category: :value_stream_management do
  include GraphqlHelpers
  include ClickHouseHelpers

  let_it_be(:organization) { create(:organization, :public) }
  let_it_be(:group) { create(:group, organization: organization) }
  let_it_be(:group2) { create(:group, organization: organization) }
  let_it_be(:project1) { create(:project, group: group) }
  let_it_be(:project2) { create(:project, group: group2) }
  let_it_be(:current_user) { create(:user, organization: organization, reporter_of: [group, group2]) }
  let_it_be(:guest) { create(:user, guest_of: [group, group2]) }

  let(:state) { MergeRequest.available_states }

  let(:merge_requests_data) do
    [
      { id: 1, target_branch: 'main', state_id: state[:merged], created_at: 100.days.ago,
        metric_merged_at: 100.days.ago + 100.seconds, project: project1 },
      { id: 2, target_branch: 'main', state_id: state[:merged], created_at: 50.days.ago,
        metric_merged_at: 50.days.ago + 200.seconds, project: project1 },
      { id: 3, target_branch: 'main', state_id: state[:closed], created_at: 15.days.ago, project: project1 },
      { id: 4, target_branch: 'main', state_id: state[:merged], created_at: 12.days.ago,
        metric_merged_at: 12.days.ago + 300.seconds, project: project1 },
      { id: 5, target_branch: 'develop', state_id: state[:opened], created_at: 8.days.ago, project: project1 },
      { id: 6, target_branch: 'develop', state_id: state[:merged], created_at: 8.days.ago,
        metric_merged_at: 8.days.ago + 400.seconds, project: project1 },
      # group2 scope
      { id: 7, target_branch: 'main', state_id: state[:merged], created_at: 8.days.ago,
        metric_merged_at: 8.days.ago + 500.seconds, project: project2 }
    ]
  end

  let(:access_query) do
    <<~QUERY
      query {
        #{resource_query} {
          analytics {
            mergeRequests#{field_arguments} {
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
    stub_licensed_features(license_feature_key => true)
    allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)

    insert_merge_requests_to_click_house(merge_requests_data)
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
      post_graphql(access_query, current_user: guest)

      expect(graphql_errors).to match(
        [hash_including('message' => "The following sources are not accessible: #{group.full_path}")]
      )
    end

    it 'reports the requested sources as inaccessible when cycle_analytics_for_groups is not licensed' do
      stub_licensed_features(license_feature_key => false)

      post_graphql(access_query, current_user: current_user)

      expect(graphql_errors).to match(
        [hash_including('message' => "The following sources are not accessible: #{group.full_path}")]
      )
    end
  end

  shared_examples 'mergeRequests query' do
    context 'when querying with filters and dimensions' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                mergeRequests#{field_arguments(%(
                  targetBranch: ["main"]
                  createdAtFrom: "#{30.days.ago.iso8601}"
                  createdAtTo: "#{5.days.ago.iso8601}"
                ))} {
                  aggregated(
                    orderBy: [{ identifier: "stateId", direction: ASC }]
                  ) {
                    nodes {
                      dimensions {
                        targetBranch
                        stateId
                      }
                      totalCount
                      throughputCount
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'returns filtered and aggregated merge request data', :aggregate_failures do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = graphql_data.dig(query_type, 'analytics', 'mergeRequests', 'aggregated', 'nodes')

        expect(nodes).to eq([
          {
            'dimensions' => { 'targetBranch' => 'main', 'stateId' => 'closed' },
            'totalCount' => 1,
            'throughputCount' => 0
          },
          {
            'dimensions' => { 'targetBranch' => 'main', 'stateId' => 'merged' },
            'totalCount' => 1,
            'throughputCount' => 1
          }
        ])
      end
    end

    context 'when querying without filters' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                mergeRequests#{field_arguments} {
                  aggregated {
                    nodes {
                      totalCount
                      throughputCount
                      timeToMergeQuantile(quantile: 0.5)
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'aggregates all merge requests in scope' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = graphql_data.dig(query_type, 'analytics', 'mergeRequests', 'aggregated', 'nodes')

        expect(nodes.size).to eq(1)
        expect(nodes[0]).to match(
          'totalCount' => expected_total_count,
          'throughputCount' => expected_throughput_count,
          'timeToMergeQuantile' => be_within(50_000).of(250_000.0)
        )
      end
    end

    context 'when querying count' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                mergeRequests#{field_arguments(%(targetBranch: ["main", "develop"]))} {
                  aggregated {
                    count
                    nodes {
                      dimensions {
                        targetBranch
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

        data = graphql_data.dig(query_type, 'analytics', 'mergeRequests', 'aggregated')
        expect(data['count']).to eq(expected_branch_count)
      end
    end

    context 'when filtering by state name and merge time range' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                mergeRequests#{field_arguments(%(
                  stateId: ["merged"]
                  metricMergedAtFrom: "#{20.days.ago.iso8601}"
                  metricMergedAtTo: "#{5.days.ago.iso8601}"
                ))} {
                  aggregated {
                    nodes { totalCount }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'returns merge requests matching the state and merge time filters' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = graphql_data.dig(query_type, 'analytics', 'mergeRequests', 'aggregated', 'nodes')
        expect(nodes).to eq([{ 'totalCount' => expected_merged_in_range_count }])
      end
    end
  end

  context 'for group' do
    let(:query_type) { 'group' }
    let(:resource_query) { %(group(fullPath: "#{group.full_path}")) }
    let(:scope_arguments) { '' }
    let(:license_feature_key) { :cycle_analytics_for_groups }
    # project1 has 6 merge requests in the group scope (project2 is outside the group)
    let(:expected_total_count) { 6 }
    let(:expected_throughput_count) { 4 }
    let(:expected_branch_count) { 2 } # main and develop
    let(:expected_merged_in_range_count) { 2 } # ids 4 and 6

    it_behaves_like 'mergeRequests query'
    it_behaves_like 'reports inaccessible sources'

    it_behaves_like 'authorizing granular token permissions for GraphQL',
      [:read_cycle_analytics, :read_group] do
      let(:user) { current_user }
      let(:boundary_object) { group }
      let(:request) { post_graphql(access_query, token: { personal_access_token: pat }) }
    end
  end

  context 'for project' do
    let(:query_type) { 'project' }
    let(:resource_query) { %(project(fullPath: "#{project1.full_path}")) }
    let(:scope_arguments) { '' }
    let(:license_feature_key) { :cycle_analytics_for_projects }
    # project1 has 6 merge requests
    let(:expected_total_count) { 6 }
    let(:expected_throughput_count) { 4 }
    let(:expected_branch_count) { 2 } # main and develop
    let(:expected_merged_in_range_count) { 2 } # ids 4 and 6

    it_behaves_like 'mergeRequests query'

    it 'returns data for guest (value stream analytics for a single project is unrestricted)' do
      post_graphql(access_query, current_user: guest)

      nodes = graphql_data.dig(query_type, 'analytics', 'mergeRequests', 'aggregated', 'nodes')
      expect(nodes).to eq([{ 'totalCount' => expected_total_count }])
    end

    it 'returns data even when cycle_analytics_for_projects is not licensed' do
      stub_licensed_features(license_feature_key => false)

      post_graphql(access_query, current_user: current_user)

      nodes = graphql_data.dig(query_type, 'analytics', 'mergeRequests', 'aggregated', 'nodes')
      expect(nodes).to eq([{ 'totalCount' => expected_total_count }])
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL',
      [:read_cycle_analytics, :read_project] do
      let(:user) { current_user }
      let(:boundary_object) { project1 }
      let(:request) { post_graphql(access_query, token: { personal_access_token: pat }) }
    end
  end

  context 'for organization' do
    let(:query_type) { 'organization' }
    let(:resource_query) { %(organization(id: "#{organization.to_global_id}")) }
    let(:scope_arguments) { %(descendantsScope: { groupFullPaths: #{full_paths_argument(group)} }) }
    let(:license_feature_key) { :cycle_analytics_for_groups }
    # group has 6 merge requests (project2 belongs to group2)
    let(:expected_total_count) { 6 }
    let(:expected_throughput_count) { 4 }
    let(:expected_branch_count) { 2 } # main and develop
    let(:expected_merged_in_range_count) { 2 } # ids 4 and 6

    it_behaves_like 'mergeRequests query'
    it_behaves_like 'reports inaccessible sources'

    context 'when requesting multiple groups' do
      let(:scope_arguments) { %(descendantsScope: { groupFullPaths: #{full_paths_argument(group, group2)} }) }

      it 'aggregates data across the requested groups' do
        post_graphql(access_query, current_user: current_user)

        expect(graphql_errors).to be_nil
        expect(graphql_data.dig(query_type, 'analytics', 'mergeRequests', 'aggregated', 'nodes'))
          .to eq([{ 'totalCount' => 7 }])
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
        expect(graphql_data.dig(query_type, 'analytics', 'mergeRequests', 'aggregated', 'nodes'))
          .to eq([{ 'totalCount' => 7 }])
      end
    end
  end
end
