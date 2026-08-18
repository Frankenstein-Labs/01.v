# frozen_string_literal: true

require 'spec_helper'

RSpec.describe '(Group|Project|Organization).analytics.duoCodeSuggestions', :click_house, time_travel_to: '2026-01-30', feature_category: :code_suggestions do
  include GraphqlHelpers
  include ClickHouseHelpers

  let_it_be(:organization) { create(:organization, :public) }
  let(:suggestions_data) do
    [
      {
        uid: 'uid-1',
        user_id: user1.id,
        language: 'ruby',
        ide_name: 'VSCode',
        suggestion_size: 10,
        project: project1,
        shown_at: 100.days.ago,
        accepted_at: 100.days.ago + 5.seconds
      },
      {
        uid: 'uid-2',
        user_id: user1.id,
        language: 'ruby',
        ide_name: 'VSCode',
        suggestion_size: 20,
        project: project1,
        shown_at: 50.days.ago,
        accepted_at: 50.days.ago + 3.seconds
      },
      {
        uid: 'uid-3',
        user_id: user1.id,
        language: 'ruby',
        ide_name: 'VSCode',
        suggestion_size: 15,
        project: project1,
        shown_at: 15.days.ago
      },
      {
        uid: 'uid-4',
        user_id: user2.id,
        language: 'python',
        ide_name: 'JetBrains',
        suggestion_size: 30,
        project: project1,
        shown_at: 12.days.ago,
        rejected_at: 12.days.ago + 2.seconds
      },
      {
        uid: 'uid-5',
        user_id: user2.id,
        language: 'python',
        ide_name: 'JetBrains',
        suggestion_size: 25,
        project: project1,
        shown_at: 8.days.ago
      },
      {
        uid: 'uid-6',
        user_id: user3.id,
        language: 'go',
        ide_name: 'VSCode',
        suggestion_size: 50,
        project: project1,
        shown_at: 8.days.ago,
        accepted_at: 8.days.ago + 1.second
      },
      {
        uid: 'uid-7',
        user_id: user1.id,
        language: 'go',
        ide_name: 'VSCode',
        suggestion_size: 40,
        project: project1,
        shown_at: 10.days.ago,
        accepted_at: 10.days.ago + 2.seconds
      },
      {
        uid: 'uid-8',
        user_id: user1.id,
        language: 'go',
        ide_name: 'VSCode',
        suggestion_size: 35,
        project: project1,
        shown_at: 8.days.ago,
        rejected_at: 8.days.ago + 3.seconds
      },
      # group2 scope
      {
        uid: 'uid-9',
        user_id: user1.id,
        language: 'ruby',
        ide_name: 'VSCode',
        suggestion_size: 12,
        project: project2,
        shown_at: 8.days.ago,
        accepted_at: 8.days.ago + 1.second
      }
    ]
  end

  let(:minimal_query) do
    <<~QUERY
      query {
        #{resource_query} {
          analytics {
            duoCodeSuggestions#{field_arguments} {
              aggregated {
                nodes { totalCount }
              }
            }
          }
        }
      }
    QUERY
  end

  let_it_be(:other_organization) { create(:organization, :public) }
  let_it_be(:group) { create(:group, organization: organization) }
  let_it_be(:group2) { create(:group, organization: organization) }
  let_it_be(:group3) { create(:group, organization: organization) }
  let_it_be(:other_organization_group) { create(:group, organization: other_organization) }
  let_it_be(:project1) { create(:project, group: group) }
  let_it_be(:project2) { create(:project, group: group2) }

  let_it_be(:current_user) { create(:user, reporter_of: [group, group2, group3, other_organization_group]) }
  let_it_be(:partial_member) { create(:user, reporter_of: group) }
  let_it_be(:guest) { create(:user, guest_of: [group, group2]) }
  let_it_be(:admin) { create(:admin) }

  let_it_be(:user1) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:user3) { create(:user) }

  def shown_event
    Ai::UsageEvent.events[:code_suggestion_shown_in_ide]
  end

  def accepted_event
    Ai::UsageEvent.events[:code_suggestion_accepted_in_ide]
  end

  def rejected_event
    Ai::UsageEvent.events[:code_suggestion_rejected_in_ide]
  end

  before do
    stub_licensed_features(ai_analytics: true)
    allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)

    events_data = suggestions_data.flat_map do |s|
      namespace_path = s[:project].project_namespace.traversal_path(with_organization: false)
      extras = {
        unique_tracking_id: s[:uid],
        language: s[:language],
        ide_name: s[:ide_name],
        suggestion_size: s[:suggestion_size]
      }.to_json

      rows = []

      if s[:shown_at]
        rows << {
          user_id: s[:user_id],
          event: shown_event,
          timestamp: s[:shown_at],
          namespace_path: namespace_path,
          extras: extras
        }
      end

      if s[:accepted_at]
        rows << {
          user_id: s[:user_id],
          event: accepted_event,
          timestamp: s[:accepted_at],
          namespace_path: namespace_path,
          extras: extras
        }
      end

      if s[:rejected_at]
        rows << {
          user_id: s[:user_id],
          event: rejected_event,
          timestamp: s[:rejected_at],
          namespace_path: namespace_path,
          extras: extras
        }
      end

      rows
    end

    clickhouse_fixture(:ai_usage_events, events_data)
  end

  def full_paths_argument(*records)
    "[#{records.map { |record| "\"#{record.respond_to?(:full_path) ? record.full_path : record}\"" }.join(', ')}]"
  end

  def field_arguments(filters = nil)
    args = [scope_arguments, filters].compact_blank.join("\n")

    args.blank? ? '' : "(#{args})"
  end

  # Builds an organization-rooted query for the organization-specific tests
  # where the requested sources vary per example.
  def build_query(
    group_full_paths_argument = nil, project_full_paths_argument: nil, engine_arguments: '',
    aggregated_fields: 'nodes { totalCount }')
    scope_fields = []
    scope_fields << "groupFullPaths: #{group_full_paths_argument}" if group_full_paths_argument
    scope_fields << "projectFullPaths: #{project_full_paths_argument}" if project_full_paths_argument

    arguments = []
    arguments << "descendantsScope: { #{scope_fields.join(' ')} }" if scope_fields.any?
    arguments << engine_arguments if engine_arguments.present?
    arguments_string = arguments.any? ? "(#{arguments.join(' ')})" : ''

    <<~QUERY
      query {
        organization(id: "#{organization.to_global_id}") {
          analytics {
            duoCodeSuggestions#{arguments_string} {
              aggregated {
                #{aggregated_fields}
              }
            }
          }
        }
      }
    QUERY
  end

  def aggregated_data
    graphql_data.dig('organization', 'analytics', 'duoCodeSuggestions', 'aggregated')
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

  shared_examples 'duoCodeSuggestions query' do
    context 'when querying all possible filters and fields' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                duoCodeSuggestions#{field_arguments(%(
                  userId: ["#{user1.to_global_id}", "#{user2.to_global_id}"]
                  language: ["ruby", "python"]
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
                        language
                        ideName
                        user {
                          id
                        }
                        timestampMonthly: timestamp(granularity: "monthly")
                      }
                      totalCount
                      usersCount
                      acceptanceRate
                      suggestionSizeSum
                      acceptedCount
                      rejectedCount
                      shownCount
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'returns filtered and aggregated suggestion data with all metrics and dimensions', :aggregate_failures do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = graphql_data.dig(query_type, 'analytics', 'duoCodeSuggestions', 'aggregated', 'nodes')

        expect(nodes.size).to eq(3)

        expect(nodes[0]).to eq(
          'dimensions' => {
            'language' => 'python',
            'ideName' => 'JetBrains',
            'user' => { 'id' => user2.to_global_id.to_s },
            'timestampMonthly' => '2026-01-01'
          },
          'totalCount' => 2,
          'usersCount' => 1,
          'acceptanceRate' => 0.0,
          'suggestionSizeSum' => 55,
          'acceptedCount' => 0,
          'rejectedCount' => 1,
          'shownCount' => 2
        )

        expect(nodes[1]).to eq(
          'dimensions' => {
            'language' => 'ruby',
            'ideName' => 'VSCode',
            'user' => { 'id' => user1.to_global_id.to_s },
            'timestampMonthly' => '2025-12-01'
          },
          'totalCount' => 1,
          'usersCount' => 1,
          'acceptanceRate' => 1.0,
          'suggestionSizeSum' => 20,
          'acceptedCount' => 1,
          'rejectedCount' => 0,
          'shownCount' => 1
        )

        expect(nodes[2]).to eq(
          'dimensions' => {
            'language' => 'ruby',
            'ideName' => 'VSCode',
            'user' => { 'id' => user1.to_global_id.to_s },
            'timestampMonthly' => '2026-01-01'
          },
          'totalCount' => 1,
          'usersCount' => 1,
          'acceptanceRate' => 0.0,
          'suggestionSizeSum' => 15,
          'acceptedCount' => 0,
          'rejectedCount' => 0,
          'shownCount' => 1
        )
      end
    end

    context 'when querying with single filter values' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                duoCodeSuggestions#{field_arguments(%(
                  userId: ["#{user1.to_global_id}"]
                  language: ["ruby"]
                ))} {
                  aggregated {
                    nodes {
                      dimensions {
                        language
                        user {
                          id
                        }
                      }
                      totalCount
                      acceptedCount
                      shownCount
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'returns only suggestions matching single filter values' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = graphql_data.dig(query_type, 'analytics', 'duoCodeSuggestions', 'aggregated', 'nodes')

        expect(nodes).to eq([{
          'dimensions' => {
            'language' => 'ruby',
            'user' => { 'id' => user1.to_global_id.to_s }
          },
          'totalCount' => 3,
          'acceptedCount' => 2,
          'shownCount' => 3
        }])
      end
    end

    context 'when querying without filters' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                duoCodeSuggestions#{field_arguments} {
                  aggregated {
                    nodes {
                      totalCount
                      usersCount
                      acceptanceRate
                      suggestionSizeSum
                      acceptedCount
                      rejectedCount
                      shownCount
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      it 'aggregates all suggestions in scope' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = graphql_data.dig(query_type, 'analytics', 'duoCodeSuggestions', 'aggregated', 'nodes')

        expect(nodes.size).to eq(1)
        expect(nodes[0]).to match(
          'totalCount' => 8,
          'usersCount' => 3,
          'acceptanceRate' => be_within(0.01).of(0.5),
          'suggestionSizeSum' => 225,
          'acceptedCount' => 4,
          'rejectedCount' => 2,
          'shownCount' => 8
        )
      end
    end

    context 'when querying count' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                duoCodeSuggestions#{field_arguments(%(language: ["ruby", "go"]))} {
                  aggregated {
                    count
                    nodes {
                      dimensions {
                        language
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

        data = graphql_data.dig(query_type, 'analytics', 'duoCodeSuggestions', 'aggregated')
        # ruby and go are 2 distinct language groups
        expect(data['count']).to eq(2)
      end
    end

    context 'when ordering by parameterized dimension with parameters' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                duoCodeSuggestions#{field_arguments(%(
                  userId: ["#{user1.to_global_id}"]
                  language: ["ruby"]
                ))} {
                  aggregated(
                    orderBy: [
                      { identifier: "timestamp", parameters: { granularity: "monthly" }, direction: DESC }
                    ]
                  ) {
                    nodes {
                      dimensions {
                        timestamp(granularity: "monthly")
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

        nodes = graphql_data.dig(query_type, 'analytics', 'duoCodeSuggestions', 'aggregated', 'nodes')

        expect(nodes[0]['dimensions']['timestamp']).to eq('2026-01-01')
        expect(nodes[1]['dimensions']['timestamp']).to eq('2025-12-01')
        expect(nodes[2]['dimensions']['timestamp']).to eq('2025-10-01')
      end
    end

    context 'when ordering by parameterized dimension without providing parameters' do
      let(:query) do
        <<~QUERY
          query {
            #{resource_query} {
              analytics {
                duoCodeSuggestions#{field_arguments(%(userId: ["#{user1.to_global_id}"]))} {
                  aggregated(
                    orderBy: [
                      { identifier: "timestamp", direction: DESC }
                    ]
                  ) {
                    nodes {
                      dimensions {
                        timestamp(granularity: "monthly")
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
          [hash_including('message' => "the specified identifier is not available: 'timestamp'")]
        )
        nodes = graphql_data.dig(query_type, 'analytics', 'duoCodeSuggestions', 'aggregated', 'nodes')

        expect(nodes).to be_nil
      end
    end
  end

  context 'for group' do
    let(:query_type) { 'group' }
    let(:resource_query) { %(group(fullPath: "#{group.full_path}")) }
    let(:scope_arguments) { '' }
    let(:inaccessible_source) { group }

    it_behaves_like 'duoCodeSuggestions query'
    it_behaves_like 'reports inaccessible sources'

    context 'when requesting projects within the group' do
      let(:scope_arguments) { %(descendantsScope: { projectFullPaths: #{full_paths_argument(project1)} }) }

      it 'scopes the aggregation to the requested project' do
        post_graphql(minimal_query, current_user: current_user)

        expect(graphql_errors).to be_nil
        expect(graphql_data.dig(query_type, 'analytics', 'duoCodeSuggestions', 'aggregated', 'nodes'))
          .to eq([{ 'totalCount' => 8 }])
      end
    end

    context 'when requesting sources outside the group hierarchy' do
      let(:scope_arguments) { %(descendantsScope: { groupFullPaths: #{full_paths_argument(group2)} }) }

      it 'reports the out-of-hierarchy group as inaccessible even though the user is a member' do
        post_graphql(minimal_query, current_user: current_user)

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

    it_behaves_like 'duoCodeSuggestions query'
    it_behaves_like 'reports inaccessible sources'

    context 'when passing source arguments' do
      let(:scope_arguments) { %(descendantsScope: { projectFullPaths: #{full_paths_argument(project1)} }) }

      it 'rejects the arguments' do
        post_graphql(minimal_query, current_user: current_user)

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

    it_behaves_like 'duoCodeSuggestions query'

    context 'when querying multiple groups without filters' do
      let(:query) do
        build_query(
          full_paths_argument(group, group2),
          aggregated_fields: <<~FIELDS
            nodes {
              totalCount
              usersCount
              acceptanceRate
              suggestionSizeSum
              acceptedCount
              rejectedCount
              shownCount
            }
          FIELDS
        )
      end

      it 'aggregates all suggestions from the requested groups' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        nodes = aggregated_data['nodes']

        expect(nodes.size).to eq(1)
        expect(nodes[0]).to match(
          'totalCount' => 9,
          'usersCount' => 3,
          'acceptanceRate' => be_within(0.01).of(5.0 / 9),
          'suggestionSizeSum' => 237,
          'acceptedCount' => 5,
          'rejectedCount' => 2,
          'shownCount' => 9
        )
      end
    end

    context 'when querying multiple groups with filters' do
      let(:query) do
        build_query(
          full_paths_argument(group, group2),
          engine_arguments: %(
            userId: ["#{user1.to_global_id}"]
            language: ["ruby"]
            timestampFrom: "#{30.days.ago.iso8601}"
            timestampTo: "#{5.days.ago.iso8601}"
          ),
          aggregated_fields: <<~FIELDS
            nodes {
              totalCount
              acceptedCount
              shownCount
            }
          FIELDS
        )
      end

      it 'aggregates matching suggestions across group boundaries' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil

        # uid-3 (group) and uid-9 (group2) are aggregated together
        expect(aggregated_data['nodes']).to eq([{
          'totalCount' => 2,
          'acceptedCount' => 1,
          'shownCount' => 2
        }])
      end
    end

    context 'when requesting a single group' do
      let(:query) { build_query(full_paths_argument(group2)) }

      it 'scopes the aggregation to that group only' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil
        expect(aggregated_data['nodes']).to eq([{ 'totalCount' => 1 }])
      end
    end

    context 'when requesting duplicate group paths' do
      let(:query) { build_query(full_paths_argument(group2, group2)) }

      it 'deduplicates the groups and returns data' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil
        expect(aggregated_data['nodes']).to eq([{ 'totalCount' => 1 }])
      end
    end

    context 'when requesting a single project' do
      let(:query) { build_query(project_full_paths_argument: full_paths_argument(project2)) }

      it 'scopes the aggregation to that project only' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil
        expect(aggregated_data['nodes']).to eq([{ 'totalCount' => 1 }])
      end
    end

    context 'when requesting a mix of groups and projects' do
      let(:query) do
        build_query(full_paths_argument(group), project_full_paths_argument: full_paths_argument(project2))
      end

      it 'aggregates data from both the group and the project' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil
        expect(aggregated_data['nodes']).to eq([{ 'totalCount' => 9 }])
      end
    end

    context 'when a requested project overlaps with a requested group' do
      let(:query) do
        build_query(full_paths_argument(group), project_full_paths_argument: full_paths_argument(project1))
      end

      it 'does not double count overlapping scopes' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil
        expect(aggregated_data['nodes']).to eq([{ 'totalCount' => 8 }])
      end
    end

    context 'when requesting nested group hierarchies' do
      let_it_be(:subgroup) { create(:group, parent: group, organization: organization) }

      let(:query) { build_query(full_paths_argument(group, subgroup)) }

      it 'does not double count overlapping scopes' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_nil
        expect(aggregated_data['nodes']).to eq([{ 'totalCount' => 8 }])
      end
    end

    describe 'authorization' do
      context 'when user is a member of only one requested group' do
        let(:query) { build_query(full_paths_argument(group, group2)) }

        it 'fails the whole request and reports the inaccessible group' do
          post_graphql(query, current_user: partial_member)

          expect(graphql_data.dig('organization', 'analytics', 'duoCodeSuggestions')).to be_nil
          expect(graphql_errors).to match(
            [hash_including('message' => "The following sources are not accessible: #{group2.full_path}")]
          )
        end
      end

      context 'when user is a guest of the requested groups' do
        let(:query) { build_query(full_paths_argument(group, group2)) }

        it 'reports all requested groups as inaccessible' do
          post_graphql(query, current_user: guest)

          expect(graphql_errors).to match(
            [hash_including('message' =>
              "The following sources are not accessible: #{group.full_path}, #{group2.full_path}")]
          )
        end
      end

      context 'when requesting a group from another organization' do
        let(:query) { build_query(full_paths_argument(group, other_organization_group)) }

        it 'reports the foreign group as inaccessible even though the user is a member' do
          post_graphql(query, current_user: current_user)

          expect(graphql_errors).to match(
            [hash_including('message' =>
              "The following sources are not accessible: #{other_organization_group.full_path}")]
          )
        end
      end

      context 'when requesting a non-existent group' do
        let(:missing_path) { "missing-group-path-#{non_existing_record_id}" }
        let(:query) { build_query(full_paths_argument(group, missing_path)) }

        it 'reports the missing group as inaccessible' do
          post_graphql(query, current_user: current_user)

          expect(graphql_errors).to match(
            [hash_including('message' => "The following sources are not accessible: #{missing_path}")]
          )
        end
      end

      context 'when user is not a member of the requested project' do
        let(:query) do
          build_query(full_paths_argument(group), project_full_paths_argument: full_paths_argument(project2))
        end

        it 'fails the whole request and reports the inaccessible project' do
          post_graphql(query, current_user: partial_member)

          expect(graphql_errors).to match(
            [hash_including('message' => "The following sources are not accessible: #{project2.full_path}")]
          )
        end
      end

      context 'when requesting a project from another organization' do
        let_it_be(:other_organization_project) { create(:project, group: other_organization_group) }

        let(:query) do
          build_query(full_paths_argument(group),
            project_full_paths_argument: full_paths_argument(other_organization_project))
        end

        it 'reports the foreign project as inaccessible even though the user is a member' do
          post_graphql(query, current_user: current_user)

          expect(graphql_errors).to match(
            [hash_including('message' =>
              "The following sources are not accessible: #{other_organization_project.full_path}")]
          )
        end
      end

      context 'when requesting a non-existent project' do
        let(:missing_path) { "missing/project-path-#{non_existing_record_id}" }
        let(:query) do
          build_query(full_paths_argument(group), project_full_paths_argument: full_paths_argument(missing_path))
        end

        it 'reports the missing project as inaccessible' do
          post_graphql(query, current_user: current_user)

          expect(graphql_errors).to match(
            [hash_including('message' => "The following sources are not accessible: #{missing_path}")]
          )
        end
      end

      context 'when ai_analytics feature is not licensed' do
        let(:query) { build_query(full_paths_argument(group, group2)) }

        it 'reports all requested groups as inaccessible' do
          stub_licensed_features(ai_analytics: false)

          post_graphql(query, current_user: current_user)

          expect(graphql_errors).to match(
            [hash_including('message' =>
              "The following sources are not accessible: #{group.full_path}, #{group2.full_path}")]
          )
        end
      end

      context 'when user is not a member of the organization' do
        let(:query) { build_query(full_paths_argument(group, group2)) }

        it 'returns no analytics' do
          post_graphql(query, current_user: create(:user))

          expect(graphql_data.dig('organization', 'analytics')).to be_nil
        end
      end

      context 'when user is anonymous' do
        let(:query) { build_query(full_paths_argument(group, group2)) }

        it 'returns no analytics' do
          post_graphql(query, current_user: nil)

          expect(graphql_data.dig('organization', 'analytics')).to be_nil
        end
      end

      context 'when user is an admin', :enable_admin_mode do
        let(:query) { build_query(full_paths_argument(group, group2)) }

        it 'returns aggregated data' do
          post_graphql(query, current_user: admin)

          expect(graphql_errors).to be_nil
          expect(aggregated_data['nodes']).to eq([{ 'totalCount' => 9 }])
        end
      end
    end

    describe 'source arguments validation' do
      let(:max_sources) { ::Types::Analytics::Aggregation::ScopeInputType::MAX_SOURCES }

      it 'requires at least one of groupFullPaths or projectFullPaths' do
        post_graphql(build_query, current_user: current_user)

        expect(graphql_errors).to match(
          [hash_including('message' => 'at least one of the groupFullPaths or projectFullPaths arguments is required')]
        )
      end

      it 'rejects empty groupFullPaths and projectFullPaths lists' do
        post_graphql(build_query('[]', project_full_paths_argument: '[]'), current_user: current_user)

        expect(graphql_errors).to match(
          [hash_including('message' => 'at least one of the groupFullPaths or projectFullPaths arguments is required')]
        )
      end

      it 'rejects requests where groupFullPaths and projectFullPaths combined exceed the limit' do
        group_paths = Array.new(max_sources) { |i| "group-path-#{i + 1}" }
        project_paths = ["group-path/project-1"]

        post_graphql(
          build_query(full_paths_argument(*group_paths),
            project_full_paths_argument: full_paths_argument(*project_paths)),
          current_user: current_user
        )

        expect(graphql_errors).to match(
          [hash_including(
            'message' => "groupFullPaths and projectFullPaths arguments combined must not exceed #{max_sources}")]
        )
      end
    end

    describe 'query performance' do
      it 'does not scale the number of PostgreSQL queries with the number of groups' do
        control = ActiveRecord::QueryRecorder.new do
          post_graphql(
            build_query(full_paths_argument(group, group2), project_full_paths_argument: full_paths_argument(project2)),
            current_user: current_user
          )
        end

        expect do
          post_graphql(
            build_query(full_paths_argument(group, group2, group3),
              project_full_paths_argument: full_paths_argument(project2)),
            current_user: current_user
          )
        end.not_to exceed_query_limit(control)
      end
    end
  end
end
