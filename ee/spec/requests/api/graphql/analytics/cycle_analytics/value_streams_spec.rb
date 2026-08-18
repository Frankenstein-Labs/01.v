# frozen_string_literal: true

require 'spec_helper'

RSpec.describe '(Project|Group).value_streams', feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }

  let(:variables) { { fullPath: resource.full_path } }

  let_it_be(:current_time) { Time.current }

  let(:query) do
    <<~QUERY
      query($fullPath: ID!, $valueStreamId: ID, $stageId: ID) {
        #{resource_type}(fullPath: $fullPath) {
          valueStreams(id: $valueStreamId) {
            nodes {
              name
              stages(id: $stageId) {
                name
                endEventHtmlDescription
                startEventHtmlDescription
                startEventLabel {
                  title
                }
                endEventLabel {
                  title
                }
              }
            }
          }
        }
      }
    QUERY
  end

  shared_context 'for value stream metrics query' do
    let(:metrics_query) do
      <<~QUERY
      query($fullPath: ID!, $valueStreamId: ID, $stageId: ID, $from: Date!, $to: Date!, $assigneeUsernames: [String!], $milestoneTitle: String, $labelNames: [String!], $projectIds: [ProjectID!], $epicId: ID, $weight: Int) {
        #{resource_type}(fullPath: $fullPath) {
          valueStreams(id: $valueStreamId) {
            nodes {
              stages(id: $stageId) {
                metrics(timeframe: { start: $from, end: $to }, assigneeUsernames: $assigneeUsernames, milestoneTitle: $milestoneTitle, labelNames: $labelNames, projectIds: $projectIds, epicId: $epicId, weight: $weight) {
                  count {
                    value
                  }
                }
              }
            }
          }
        }
      }
      QUERY
    end
  end

  shared_examples 'unsupported filter examples' do
    it 'returns error message' do
      perform_request

      message = json_response['errors'].first['message']
      expect(message).to eq("Unsupported filter argument for Merge Request based stages: #{field}")
    end
  end

  shared_examples 'value streams query' do
    context 'when value streams are licensed' do
      let_it_be(:value_streams) do
        [
          create(
            :cycle_analytics_value_stream,
            namespace: namespace,
            name: 'Custom 1'
          ),
          create(
            :cycle_analytics_value_stream,
            namespace: namespace,
            name: 'Custom 2'
          )
        ]
      end

      before do
        stub_licensed_features(
          cycle_analytics_for_projects: true,
          cycle_analytics_for_groups: true
        )
      end

      context 'when current user has permissions' do
        before_all do
          resource.add_reporter(current_user)
        end

        it 'returns custom value streams' do
          post_graphql(query, current_user: current_user, variables: variables)

          expect(graphql_data_at(resource_type.to_sym, :value_streams, :nodes)).to have_attributes(size: 2)
          expect(graphql_data_at(resource_type.to_sym, :value_streams, :nodes, 0, :name)).to eq('Custom 1')
          expect(graphql_data_at(resource_type.to_sym, :value_streams, :nodes, 1, :name)).to eq('Custom 2')
        end

        context 'when specifying the value stream id argument' do
          let(:value_stream) { value_streams.last }
          let(:variables) { { fullPath: resource.full_path, valueStreamId: value_stream.to_gid.to_s } }

          before do
            post_graphql(query, current_user: current_user, variables: variables)
          end

          it 'returns only one value stream' do
            expect(graphql_data_at(resource_type.to_sym, :value_streams,
              :nodes)).to match([hash_including('name' => 'Custom 2')])
          end

          context 'when value stream id outside of the group is given' do
            let(:value_stream) { create(:cycle_analytics_value_stream, name: 'outside') }

            it 'returns no data error' do
              expect(graphql_data_at(resource_type.to_sym, :value_streams, :nodes)).to be_empty
            end
          end
        end

        context 'when value stream has stages' do
          def perform_request
            post_graphql(query, current_user: current_user, variables: variables)
          end

          context 'with associated labels' do
            let_it_be(:stage_with_label) do
              create(:cycle_analytics_stage, {
                name: 'stage-with-label',
                namespace: namespace,
                value_stream: value_streams[0],
                start_event_identifier: :issue_label_added,
                start_event_label_id: start_label.id,
                end_event_identifier: :issue_label_removed,
                end_event_label_id: end_label.id
              })
            end

            it 'returns label event attributes' do
              perform_request

              expect(graphql_data_at(resource_type.to_sym, :value_streams, :nodes, 0, :stages, 0, :start_event_label,
                :title)).to eq('Start Label')
              expect(graphql_data_at(resource_type.to_sym, :value_streams, :nodes, 0, :stages, 0, :end_event_label,
                :title)).to eq('End Label')
            end

            it 'renders the html descriptions' do
              perform_request

              expect(graphql_data_at(resource_type.to_sym, :value_streams, :nodes, 0, :stages, 0)).to match(
                hash_including(
                  'startEventHtmlDescription' => include("#{start_label.title}</span>"),
                  'endEventHtmlDescription' => include("#{end_label.title}</span>")
                )
              )
            end
          end

          it 'prevents n+1 queries' do
            perform_request # warmup
            create(:cycle_analytics_stage, value_stream: value_streams[0], namespace: namespace, name: 'Test')
            control = ActiveRecord::QueryRecorder.new { perform_request }
            value_stream_3 = create(
              :cycle_analytics_value_stream,
              namespace: namespace,
              name: 'Custom 3'
            )
            create(:cycle_analytics_stage, value_stream: value_stream_3, namespace: namespace, name: 'Code')

            expect { perform_request }.to issue_same_number_of_queries_as(control)
          end

          context 'when specifying the stage id argument' do
            let(:value_stream) { value_streams.first }
            let!(:stage) { create(:cycle_analytics_stage, value_stream: value_stream, namespace: namespace) }

            let(:variables) do
              {
                fullPath: resource.full_path,
                valueStreamId: value_stream.to_gid.to_s,
                stageId: stage.to_gid.to_s
              }
            end

            before do
              # should not show up in the results
              create(:cycle_analytics_stage, value_stream: value_stream, namespace: namespace)
            end

            it 'returns the queried stage' do
              perform_request

              expect(graphql_data_at(resource_type.to_sym, :value_streams, :nodes, 0, :stages)).to match([
                hash_including('name' => stage.name)
              ])
            end

            context 'when passing bogus stage id' do
              before do
                variables[:stageId] = create(:cycle_analytics_stage).to_gid.to_s
              end

              it 'returns no stages' do
                perform_request

                expect(graphql_data_at(resource_type.to_sym, :value_streams, :nodes, 0, :stages)).to be_empty
              end
            end

            context 'when requesting aggregated metrics' do
              let_it_be_with_reload(:assignee) { create(:user) }
              let_it_be(:epic) { create(:epic, group: resource.root_ancestor) }
              let_it_be(:milestone) { create(:milestone, group: resource.root_ancestor) }
              let_it_be(:filter_label) { create(:group_label, group: resource.root_ancestor) }

              let_it_be_with_reload(:merge_request1) do
                create(:merge_request, :unique_branches, source_project: project, created_at: current_time,
                  assignees: [assignee]).tap do |mr|
                  mr.metrics.update!(merged_at: current_time + 2.hours)
                end
              end

              let_it_be(:merge_request2) do
                create(:merge_request, :unique_branches, source_project: project,
                  labels: [filter_label],
                  milestone: milestone,
                  created_at: current_time).tap do |mr|
                  mr.metrics.update!(merged_at: current_time + 3.hours)
                end
              end

              let_it_be(:merge_request3) do
                create(:merge_request, :unique_branches, source_project: project, milestone: milestone,
                  created_at: current_time).tap do |mr|
                  mr.metrics.update!(merged_at: current_time + 2.hours)
                end
              end

              let(:query) do
                <<~QUERY
                  query($fullPath: ID!, $valueStreamId: ID, $stageId: ID, $from: Date!, $to: Date!, $assigneeUsernames: [String!], $milestoneTitle: String, $labelNames: [String!], $projectIds: [ProjectID!],  $epicId: ID, $weight: Int) {
                    #{resource_type}(fullPath: $fullPath) {
                      valueStreams(id: $valueStreamId) {
                        nodes {
                          stages(id: $stageId) {
                            metrics(timeframe: { start: $from, end: $to }, assigneeUsernames: $assigneeUsernames, milestoneTitle: $milestoneTitle, labelNames: $labelNames, projectIds: $projectIds, epicId: $epicId, weight: $weight) {
                              count {
                                value
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                QUERY
              end

              before do
                variables.merge!({
                  from: (current_time - 10.days).to_date,
                  to: (current_time + 10.days).to_date
                })

                Analytics::CycleAnalytics::DataLoaderService.new(namespace: resource.root_ancestor,
                  model: MergeRequest).execute
              end

              subject(:record_count) do
                graphql_data_at(resource_type.to_sym, :value_streams, :nodes, 0, :stages,
                  0)['metrics']['count']['value']
              end

              it 'returns the correct count' do
                perform_request

                expect(record_count).to eq(3)
              end

              context 'when requesting averageDurations series', :freeze_time do
                let(:query) do
                  <<~QUERY
                    query($fullPath: ID!, $valueStreamId: ID, $stageId: ID, $from: Date!, $to: Date!) {
                      #{resource_type}(fullPath: $fullPath) {
                        valueStreams(id: $valueStreamId) {
                          nodes {
                            stages(id: $stageId) {
                              metrics(timeframe: { start: $from, end: $to }) {
                                series {
                                  averageDurations {
                                    date
                                    value
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  QUERY
                end

                it 'returns the correct duration data' do
                  perform_request

                  duration_item = graphql_data_at(resource_type.to_sym, :value_streams, :nodes, :stages, :metrics,
                    :series, :averageDurations, 0)

                  expect(duration_item).to eq({
                    'date' => current_time.to_date.to_s,
                    'value' => (7200 + 7200 + 10800) / 3 # durations: 2 hours, 2 hours, 3 hours
                  })
                end
              end

              context 'when filtering for assignee' do
                before do
                  variables[:assigneeUsernames] = [assignee.username]
                end

                it 'returns the correct count' do
                  perform_request

                  expect(record_count).to eq(1)
                end

                context 'when assigneeUsernames is null' do
                  before do
                    variables[:assigneeUsernames] = nil
                  end

                  it 'returns the correct count' do
                    perform_request

                    expect(record_count).to eq(3)
                  end
                end
              end

              context 'when filtering for label' do
                before do
                  variables[:labelNames] = [filter_label.name]
                end

                it 'returns the correct count' do
                  perform_request

                  expect(record_count).to eq(1)
                end
              end

              context 'when filtering for milestone title' do
                before do
                  variables[:milestoneTitle] = milestone.title
                end

                it 'returns the correct count' do
                  perform_request

                  expect(record_count).to eq(2)
                end
              end

              context 'when filtering by the unsupported epic id field' do
                before do
                  variables[:epic_id] = epic.to_gid.to_s
                end

                include_examples 'unsupported filter examples' do
                  let(:field) { 'epic_id' }
                end
              end

              context 'when filtering by the unsupported weight field' do
                before do
                  variables[:weight] = 10
                end

                include_examples 'unsupported filter examples' do
                  let(:field) { 'weight' }
                end
              end

              context 'when using negated filters' do
                let(:query) do
                  <<~QUERY
                    query($fullPath: ID!, $valueStreamId: ID, $stageId: ID, $from: Date!, $to: Date!, $notAssigneeUsernames: [String!], $notMilestoneTitle: String, $notLabelNames: [String!], $notWeight: Int, $notEpicId: ID) {
                      #{resource_type}(fullPath: $fullPath) {
                        valueStreams(id: $valueStreamId) {
                          nodes {
                            stages(id: $stageId) {
                              metrics(timeframe: { start: $from, end: $to }, not: { assigneeUsernames: $notAssigneeUsernames, milestoneTitle: $notMilestoneTitle, labelNames: $notLabelNames, weight: $notWeight, epicId: $notEpicId }) {
                                count {
                                  value
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  QUERY
                end

                context 'when filtering for assignee' do
                  before do
                    variables[:notAssigneeUsernames] = [assignee.username]
                  end

                  it 'returns the correct count' do
                    perform_request

                    expect(record_count).to eq(2)
                  end
                end

                context 'when filtering for label' do
                  before do
                    variables[:notLabelNames] = [filter_label.name]
                  end

                  it 'returns the correct count' do
                    perform_request

                    expect(record_count).to eq(2)
                  end
                end

                context 'when filtering for milestone title' do
                  before do
                    variables[:notMilestoneTitle] = milestone.title
                  end

                  it 'returns the correct count' do
                    perform_request

                    expect(record_count).to eq(1)
                  end
                end

                context 'when filtering by the unsupported weight field' do
                  before do
                    variables[:notWeight] = 10
                  end

                  include_examples 'unsupported filter examples' do
                    let(:field) { 'weight' }
                  end
                end

                context 'when filtering by the unsupported epicId field' do
                  before do
                    variables[:notEpicId] = epic.to_gid.to_s
                  end

                  include_examples 'unsupported filter examples' do
                    let(:field) { 'epic_id' }
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  context 'for projects' do
    let(:resource_type) { 'project' }

    let_it_be(:resource) { create(:project, namespace: create(:group)) }
    let_it_be_with_reload(:project) { resource }
    let_it_be(:namespace) { resource.project_namespace }
    let_it_be(:start_label) { create(:label, project: resource, title: 'Start Label') }
    let_it_be(:end_label) { create(:label, project: resource, title: 'End Label') }

    include_context 'for value stream metrics query'

    before_all do
      resource.add_reporter(current_user)
    end

    subject(:record_count) do
      graphql_data_at(resource_type.to_sym, :value_streams, :nodes, 0, :stages,
        0)['metrics']['count']['value']
    end

    context 'when quarantined shared example',
      quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24062' do
      it_behaves_like 'value streams query'
    end

    context 'when filtering for project ids' do
      let_it_be(:value_stream) do
        create(
          :cycle_analytics_value_stream,
          namespace: namespace,
          name: 'Custom 2'
        )
      end

      let_it_be(:stage) do
        create(:cycle_analytics_stage, value_stream: value_stream, namespace: namespace, name: 'Code')
      end

      before do
        variables.merge!({
          from: (current_time - 10.days).to_date,
          to: (current_time + 10.days).to_date,
          projectIds: [project.to_gid.to_s],
          fullPath: resource.full_path
        })

        stub_licensed_features(cycle_analytics_for_projects: true, cycle_analytics_for_groups: true)
      end

      it 'returns a GraphQL error when filtering project value streams by project IDs' do
        post_graphql(metrics_query, current_user: current_user, variables: variables)

        expect(
          graphql_errors[0]['message']
        ).to eq("Project value streams don't support the projectIds filter")
      end
    end

    context 'when using aggregated metrics' do
      before do
        # Enables use of aggregated values
        stub_licensed_features(cycle_analytics_for_projects: true, cycle_analytics_for_groups: true)

        # Load stages data
        Analytics::CycleAnalytics::DataLoaderService.new(namespace: resource.root_ancestor,
          model: MergeRequest).execute

        Analytics::CycleAnalytics::DataLoaderService.new(namespace: resource.root_ancestor,
          model: Issue).execute
      end

      it_behaves_like 'value stream related stage items query', 'project' do
        let_it_be(:resource) { project }

        let_it_be(:value_stream) do
          create(:cycle_analytics_value_stream, namespace: namespace, name: 'custom stream', stages: [
            create(
              :cycle_analytics_stage,
              namespace: resource.project_namespace,
              name: "Issue",
              relative_position: 1,
              start_event_identifier: :issue_created,
              end_event_identifier: :issue_stage_end
            ),
            create(
              :cycle_analytics_stage,
              namespace: resource.project_namespace,
              name: "Test",
              relative_position: 2,
              start_event_identifier: :merge_request_last_build_started,
              end_event_identifier: :merge_request_last_build_finished
            )
          ])
        end

        let(:stage_id_to_paginate) { value_stream.stages.find_by_name('Test').to_global_id.to_s }
      end
    end

    context 'when value streams are not licensed' do
      before_all do
        resource.add_reporter(current_user)
      end

      it 'returns default value stream' do
        post_graphql(query, current_user: current_user, variables: variables)

        expect(graphql_data_at(:project, :value_streams, :nodes, 0, :name)).to eq('default')
        expect(graphql_data_at(:project, :value_streams)).to have_attributes(size: 1)
      end
    end
  end

  context 'for groups' do
    let(:resource_type) { 'group' }

    let_it_be(:resource) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: resource) }
    let_it_be(:namespace) { resource }
    let_it_be(:start_label) { create(:group_label, group: resource, title: 'Start Label') }
    let_it_be(:end_label) { create(:group_label, group: resource, title: 'End Label') }
    let_it_be(:project_2) { create(:project, group: resource) }
    let_it_be(:project_3) { create(:project, group: resource) }
    let(:value_stream) { value_streams.last }
    let_it_be_with_reload(:assignee) { create(:user) }

    before_all do
      resource.add_reporter(current_user)
    end

    subject(:record_count) do
      graphql_data_at(resource_type.to_sym, :value_streams, :nodes, 0, :stages,
        0)['metrics']['count']['value']
    end

    context 'when qurantined shared example',
      quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24063' do
      it_behaves_like 'value streams query'
    end

    context 'when filtering for project ids' do
      include_context 'for value stream metrics query'

      let_it_be_with_reload(:merge_request1) do
        create(:merge_request, :unique_branches, source_project: project, created_at: current_time).tap do |mr|
          mr.metrics.update!(merged_at: current_time + 2.hours)
        end
      end

      let_it_be(:merge_request2) do
        create(:merge_request, :unique_branches, source_project: project, created_at: 5.days.ago).tap do |mr|
          mr.metrics.update!(merged_at: current_time + 3.hours)
        end
      end

      let_it_be(:merge_request3) do
        create(:merge_request, :unique_branches, source_project: project, created_at: 5.days.ago).tap do |mr|
          mr.metrics.update!(merged_at: current_time + 4.hours)
        end
      end

      let_it_be(:merge_request4) do
        create(:merge_request, :unique_branches, source_project: project_2, created_at: 5.days.ago).tap do |mr|
          mr.metrics.update!(merged_at: current_time + 4.hours)
        end
      end

      let_it_be(:value_stream) do
        create(:cycle_analytics_value_stream, namespace: resource, name: 'custom stream', stages: [
          create(:cycle_analytics_stage,
            namespace: resource,
            name: "Code",
            start_event_identifier: :merge_request_created,
            end_event_identifier: :merge_request_merged
          )
        ])
      end

      before do
        stub_licensed_features(cycle_analytics_for_projects: true, cycle_analytics_for_groups: true)

        variables.merge!({
          from: (current_time - 10.days).to_date,
          to: (current_time + 10.days).to_date,
          fullPath: resource.full_path
        })

        Analytics::CycleAnalytics::DataLoaderService.new(
          namespace: resource.root_ancestor,
          model: MergeRequest
        ).execute
      end

      it 'returns the correct count when there is data' do
        variables[:projectIds] = [project.to_gid.to_s]

        post_graphql(metrics_query, current_user: current_user, variables: variables)

        expect(record_count).to eq(3)
      end

      it 'returns the combined count when filtering by multiple projects with data' do
        variables[:projectIds] = [project.to_gid.to_s, project_2.to_gid.to_s]

        post_graphql(metrics_query, current_user: current_user, variables: variables)

        expect(record_count).to eq(4)
      end

      it 'returns the correct count when there is no data' do
        variables[:projectIds] = [project_3.to_gid.to_s]

        post_graphql(metrics_query, current_user: current_user, variables: variables)

        expect(record_count).to eq(0)
      end
    end

    context 'when using aggregated metrics' do
      let_it_be_with_refind(:resource) { create(:group) }
      # Only needed by shared examples to store issues and merge requests
      let_it_be_with_reload(:project) do
        create(:project, group: resource)
      end

      before do
        # Enables use of aggregated values
        stub_licensed_features(cycle_analytics_for_projects: true, cycle_analytics_for_groups: true)

        # Load stages data
        Analytics::CycleAnalytics::DataLoaderService.new(namespace: resource.root_ancestor,
          model: MergeRequest).execute

        Analytics::CycleAnalytics::DataLoaderService.new(namespace: resource.root_ancestor,
          model: Issue).execute
      end

      it_behaves_like 'value stream related stage items query', 'group' do
        let_it_be(:value_stream) do
          create(:cycle_analytics_value_stream, namespace: resource, name: 'custom stream', stages: [
            create(:cycle_analytics_stage,
              namespace: resource,
              name: "Issue",
              relative_position: 1,
              start_event_identifier: :issue_created,
              end_event_identifier: :issue_stage_end
            ),
            create(:cycle_analytics_stage,
              namespace: resource,
              name: "Test",
              relative_position: 2,
              start_event_identifier: :merge_request_last_build_started,
              end_event_identifier: :merge_request_last_build_finished
            )
          ])
        end

        let(:stage_id_to_paginate) { value_stream.stages.find_by_name('Test').to_global_id.to_s }
      end
    end

    context 'when current user does not have permissions' do
      it 'does not return value streams' do
        post_graphql(query, current_user: current_user, variables: variables)

        expect(graphql_data_at(:group, :value_streams)).to be_nil
      end
    end
  end
end
