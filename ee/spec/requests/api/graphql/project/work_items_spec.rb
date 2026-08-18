# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a work item list for a project', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:current_user) { create(:user) }

  let(:items_data) { graphql_data['project']['workItems']['edges'] }
  let(:item_ids) { graphql_dig_at(items_data, :node, :id) }
  let(:item_filter_params) { {} }

  let(:fields) do
    <<~QUERY
      edges {
        node {
          #{all_graphql_fields_for('workItems'.classify)}
        }
      }
    QUERY
  end

  let(:query) do
    graphql_query_for(
      'project',
      { 'fullPath' => project.full_path },
      query_graphql_field('workItems', item_filter_params, fields)
    )
  end

  describe 'work items with features' do
    let(:features_data) { graphql_dig_at(items_data, :node, :features) }

    context 'with verification status widget' do
      let_it_be(:work_item1) { create(:work_item, :satisfied_status, project: project) }
      let_it_be(:work_item2) { create(:work_item, :failed_status, project: project) }
      let_it_be(:work_item3) { create(:work_item, :requirement, project: project) }

      let(:fields) do
        <<~QUERY
          edges {
            node {
              id
              features {
                verificationStatus {
                  verificationStatus
                }
              }
            }
          }
        QUERY
      end

      before do
        stub_licensed_features(requirements: true, okrs: true)
      end

      it 'returns work items including verification status', :aggregate_failures do
        post_graphql(query, current_user: current_user)

        expect(item_ids).to contain_exactly(
          work_item1.to_global_id.to_s,
          work_item2.to_global_id.to_s,
          work_item3.to_global_id.to_s
        )
        expect(graphql_dig_at(features_data, 'verificationStatus')).to include(
          a_hash_including('verificationStatus' => 'satisfied'),
          a_hash_including('verificationStatus' => 'failed'),
          a_hash_including('verificationStatus' => 'unverified')
        )
      end

      it 'avoids N+1 queries', :use_sql_query_cache do
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user)
        end

        create_list(:work_item, 3, :satisfied_status, project: project)

        expect { post_graphql(query, current_user: current_user) }.not_to exceed_all_query_limit(control)
      end

      context 'when filtering' do
        context 'with verification status widget' do
          let(:item_filter_params) { 'verificationStatusWidget: { verificationStatus: FAILED }' }

          it 'filters by status argument' do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(item_ids).to contain_exactly(work_item2.to_global_id.to_s)
          end
        end
      end
    end

    context 'with legacy requirement widget' do
      let_it_be(:work_item1) { create(:work_item, :requirement, project: project) }
      let_it_be(:work_item2) { create(:work_item, :requirement, project: project) }
      let_it_be(:work_item3) { create(:work_item, :requirement, project: project) }
      let_it_be(:work_item3_different_project) { create(:work_item, :requirement, iid: work_item3.iid) }

      let(:fields) do
        <<~QUERY
          edges {
            node {
              id
              features {
                requirementLegacy {
                  legacyIid
                }
              }
            }
          }
        QUERY
      end

      before do
        stub_licensed_features(requirements: true)
      end

      it 'returns work items including legacy iid', :aggregate_failures do
        post_graphql(query, current_user: current_user)

        expect(item_ids).to contain_exactly(
          work_item1.to_global_id.to_s,
          work_item2.to_global_id.to_s,
          work_item3.to_global_id.to_s
        )

        expect(graphql_dig_at(features_data, 'requirementLegacy')).to include(
          a_hash_including('legacyIid' => work_item1.requirement.iid),
          a_hash_including('legacyIid' => work_item2.requirement.iid),
          a_hash_including('legacyIid' => work_item3.requirement.iid)
        )
      end

      it 'avoids N+1 queries', :use_sql_query_cache do
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user)
        end

        create_list(:work_item, 3, :requirement, project: project)

        expect { post_graphql(query, current_user: current_user) }.not_to exceed_all_query_limit(control)
      end

      context 'when filtering' do
        context 'with legacy requirement widget' do
          let(:item_filter_params) { "requirementLegacyWidget: { legacyIids: [\"#{work_item2.requirement.iid}\"] }" }

          it 'filters by legacy IID argument' do
            post_graphql(query, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(item_ids).to contain_exactly(work_item2.to_global_id.to_s)
          end
        end
      end
    end

    context 'with progress widget' do
      let_it_be(:work_item1) { create(:work_item, :objective, project: project) }
      let_it_be(:progress) { create(:progress, work_item: work_item1) }

      let(:fields) do
        <<~QUERY
          edges {
            node {
              id
              features {
                progress {
                  progress
                  updatedAt
                  currentValue
                  startValue
                  endValue
                }
              }
            }
          }
        QUERY
      end

      before do
        stub_licensed_features(okrs: true)
      end

      it 'avoids N+1 queries', :use_sql_query_cache do
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user)
        end

        create_list(:work_item, 3, :objective, project: project)

        expect { post_graphql(query, current_user: current_user) }.not_to exceed_all_query_limit(control)
      end
    end

    context 'with test reports widget' do
      let_it_be(:requirement_work_item_1) { create(:work_item, :requirement, project: project) }
      let_it_be(:test_report) { create(:test_report, requirement_issue: requirement_work_item_1) }

      let(:fields) do
        <<~GRAPHQL
          edges {
            node {
              id
              features {
                testReports {
                  testReports {
                    nodes {
                      id
                      author {
                        username
                      }
                    }
                  }
                }
              }
            }
          }
        GRAPHQL
      end

      before do
        stub_licensed_features(requirements: true)
      end

      it 'avoids N+1 queries' do
        post_graphql(query, current_user: current_user) # warmup

        control = ActiveRecord::QueryRecorder.new do
          post_graphql(query, current_user: current_user)
        end

        requirement_work_item_2 = create(:work_item, :requirement, project: project)
        create(:test_report, requirement_issue: requirement_work_item_2)

        expect { post_graphql(query, current_user: current_user) }
          .not_to exceed_query_limit(control)
      end
    end

    context 'with development widget' do
      let_it_be(:work_item) { create(:work_item, project: project) }

      context 'for the feature flags field' do
        before_all do
          2.times do
            create_feature_flag_for(work_item)
          end
        end

        let(:fields) do
          <<~GRAPHQL
            nodes {
              id
              features {
                development {
                  featureFlags {
                    nodes {
                      id
                      name
                    }
                  }
                }
              }
            }
          GRAPHQL
        end

        it 'avoids N+1 queries' do
          post_graphql(query, current_user: current_user) # warmup

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            post_graphql(query, current_user: current_user)
          end

          2.times do
            new_work_item = create(:work_item, project: project)
            create_feature_flag_for(new_work_item)
          end

          expect { post_graphql(query, current_user: current_user) }
            .to issue_same_number_of_queries_as(control)
        end
      end
    end

    context 'with iteration widget' do
      let_it_be(:iteration_cadence) { create(:iterations_cadence, group: project.group) }
      let_it_be(:iteration) { create(:iteration, iterations_cadence: iteration_cadence) }
      let_it_be(:work_item1) { create(:work_item, :issue, project: project, iteration: iteration) }

      let(:fields) do
        <<~QUERY
          edges {
            node {
              features {
                iteration {
                  iteration {
                    id
                    iterationCadence {
                      title
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      before do
        stub_licensed_features(iterations: true)
      end

      it 'avoids N+1 queries', :use_sql_query_cache do
        post_graphql(query, current_user: current_user) # warmup

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user)
        end

        create_list(:iterations_cadence, 3, group: project.group) do |cadence|
          iteration = create(:iteration, iterations_cadence: cadence)
          create(:work_item, :issue, project: project, iteration: iteration)
        end

        expect { post_graphql(query, current_user: current_user) }.not_to exceed_all_query_limit(control)
        expect(response).to have_gitlab_http_status(:success)
      end
    end

    context 'with status widget' do
      let_it_be(:namespace) { group }
      let_it_be(:work_item_1) { create(:work_item, :task, project: project) }
      let_it_be(:work_item_2) { create(:work_item, :task, project: project) }
      let_it_be(:work_item_3) { create(:work_item, :task, project: project) }

      let(:fields) do
        <<~QUERY
          edges {
            node {
              id
              features {
                status {
                  status {
                    id
                    name
                    color
                    iconName
                    position
                  }
                }
              }
            }
          }
        QUERY
      end

      RSpec.shared_examples 'checks for N+1 queries' do
        it 'avoids N+1 queries', :use_sql_query_cache do
          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            post_graphql(query, current_user: current_user)
          end

          additional_work_item_1 = create(:work_item, :task, project: project)
          additional_work_item_2 = create(:work_item, :task, project: project)

          create(:work_item_current_status, :system_defined, work_item: additional_work_item_1)
          create(:work_item_current_status, :system_defined, work_item: additional_work_item_2)

          expect do
            post_graphql(query, current_user: current_user)
          end.not_to exceed_query_limit(control).allow_skip_cache_inconsistency
        end
      end

      context 'when feature is licensed' do
        before do
          stub_licensed_features(work_item_status: true)
        end

        context 'with current statuses' do
          context 'with system-defined status' do
            let_it_be(:current_status) do
              create(:work_item_current_status, :system_defined, work_item: work_item_1)
            end

            it 'returns status data' do
              post_graphql(query, current_user: current_user)

              expect(graphql_dig_at(features_data, 'status')).to include(
                hash_including(
                  'status' => {
                    'id' => 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/1',
                    'name' => 'To do',
                    'iconName' => 'status-waiting',
                    'color' => "#737278",
                    'position' => 0
                  }
                )
              )
            end
          end

          context 'with custom lifecycle' do
            let_it_be(:work_item_type) { build(:work_item_system_defined_type, :task) }

            let_it_be(:lifecycle) do
              create(:work_item_custom_lifecycle, namespace: namespace)
            end

            let_it_be(:custom_status) { lifecycle.default_open_status }

            context 'with custom status' do
              it 'returns status data' do
                create(:work_item_type_custom_lifecycle, lifecycle: lifecycle, work_item_type: work_item_type,
                  namespace: namespace)

                current_status = create(:work_item_current_status, :custom, custom_status: custom_status,
                  work_item: work_item_1)

                post_graphql(query, current_user: current_user)

                expect(graphql_dig_at(features_data, 'status')).to include(
                  hash_including(
                    'status' => {
                      'id' => "gid://gitlab/WorkItems::Statuses::Custom::Status/#{current_status.custom_status_id}",
                      'name' => custom_status.name,
                      'iconName' => 'status-waiting',
                      'color' => "#737278",
                      'position' => 0
                    }
                  )
                )
              end
            end

            context 'with mixed statuses' do
              it 'returns correct status data for each work item' do
                create(:work_item_current_status,
                  work_item: work_item_1,
                  system_defined_status_id:
                    lifecycle.default_closed_status.converted_from_system_defined_status_identifier
                )

                create(:work_item_type_custom_lifecycle, lifecycle: lifecycle, work_item_type: work_item_type,
                  namespace: namespace)

                current_status_2 = create(:work_item_current_status, :custom, custom_status: custom_status,
                  work_item: work_item_2)

                post_graphql(query, current_user: current_user)

                expect(graphql_dig_at(features_data, 'status')).to include(
                  hash_including(
                    'status' => hash_including(
                      'id' => "gid://gitlab/WorkItems::Statuses::Custom::Status/#{lifecycle.default_closed_status_id}"
                    )
                  ),
                  hash_including(
                    'status' => hash_including(
                      'id' => "gid://gitlab/WorkItems::Statuses::Custom::Status/#{current_status_2.custom_status_id}"
                    )
                  ),
                  hash_including(
                    'status' => hash_including(
                      'id' => "gid://gitlab/WorkItems::Statuses::Custom::Status/#{lifecycle.default_open_status_id}"
                    )
                  )
                )
              end

              it 'avoids N+1 queries', :use_sql_query_cache do
                create(:work_item_current_status, :system_defined, work_item: work_item_1)

                create(:work_item_type_custom_lifecycle, lifecycle: lifecycle, work_item_type: work_item_type,
                  namespace: namespace)

                create(:work_item_current_status, :custom, custom_status: custom_status,
                  work_item: work_item_2)

                control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
                  post_graphql(query, current_user: current_user)
                end

                additional_work_item_1 = create(:work_item, :task, project: project)
                additional_work_item_2 = create(:work_item, :task, project: project)

                create(:work_item_current_status, :custom, custom_status: custom_status,
                  work_item: additional_work_item_1)
                create(:work_item_current_status, :custom, custom_status: custom_status,
                  work_item: additional_work_item_2)

                expect do
                  post_graphql(query, current_user: current_user)
                end.not_to exceed_query_limit(control).allow_skip_cache_inconsistency
              end
            end
          end
        end

        context 'without current statuses' do
          it 'returns default status data' do
            post_graphql(query, current_user: current_user)

            expect(graphql_dig_at(features_data, 'status')).to include(
              hash_including(
                'status' => {
                  'id' => 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/1',
                  'name' => 'To do',
                  'iconName' => 'status-waiting',
                  'color' => "#737278",
                  'position' => 0
                }
              )
            )
          end

          it_behaves_like 'checks for N+1 queries'
        end
      end

      context 'when feature is unlicensed' do
        before do
          stub_licensed_features(work_item_status: false)
        end

        context 'with current statuses' do
          let_it_be(:current_status) { create(:work_item_current_status, work_item: work_item_1) }

          it 'does not return status widget' do
            post_graphql(query, current_user: current_user)

            expect(graphql_dig_at(features_data, 'status')).not_to include(
              hash_including('type' => 'STATUS')
            )
          end

          it_behaves_like 'checks for N+1 queries'
        end

        context 'without current statuses' do
          it 'does not return status widget' do
            post_graphql(query, current_user: current_user)

            expect(graphql_dig_at(features_data, 'status')).not_to include(
              hash_including('type' => 'STATUS')
            )
          end

          it_behaves_like 'checks for N+1 queries'
        end
      end
    end

    context 'with linked items widget' do
      describe 'with ai workflow token' do
        let_it_be(:work_item1) { create(:work_item, project: project) }
        let_it_be(:work_item2) { create(:work_item, project: project) }
        let_it_be(:other_project) { create(:project, :repository, :public, group: group) }
        let_it_be(:other_milestone) { create(:milestone, project: other_project) }
        let_it_be(:related_items) do
          create_list(:work_item, 3, project: other_project, milestone: other_milestone)
        end

        let_it_be(:ai_workflows_oauth_token) do
          create(:oauth_access_token, user: current_user, scopes: [:ai_workflows])
        end

        let(:fields) do
          <<~GRAPHQL
          nodes {
            features {
              linkedItems {
                linkedItems {
                  nodes {
                    linkType
                    workItem {
                      id
                      iid
                      namespace {
                        id
                        fullPath
                      }
                      workItemType {
                        name
                      }
                      title
                      state
                      createdAt
                      closedAt
                      webUrl
                    }
                  }
                }
              }
            }
          }
          GRAPHQL
        end

        let(:items_data) { graphql_data['project']['workItems']['nodes'] }

        let(:linked_items) { graphql_dig_at(items_data, 'features', 'linkedItems', 'linkedItems', 'nodes', 'workItem') }

        before do
          create(:work_item_link, source: work_item1, target: related_items[0], link_type: 'relates_to')
          create(:work_item_link, source: work_item2, target: related_items[0], link_type: 'relates_to')
        end

        it 'fetches linked items' do
          post_graphql(query, token: { oauth_access_token: ai_workflows_oauth_token })

          linked_items_iids = graphql_dig_at(linked_items, 'iid')

          expect(linked_items_iids).to include(related_items[0].iid.to_s)
        end

        it 'returns value for webUrl' do
          post_graphql(query, token: { oauth_access_token: ai_workflows_oauth_token })
          linked_items_web_urls = graphql_dig_at(linked_items, 'webUrl')

          web_url = Gitlab::Routing.url_helpers.project_work_item_url(related_items[0].project, related_items[0])

          expect(linked_items_web_urls).to include(web_url)
        end
      end
    end
  end

  context 'with top level filters' do
    let_it_be(:now) { Time.current }

    let_it_be(:past_work_item) do
      create(:work_item, project: project, created_at: 1.day.ago, due_date: 1.day.ago, closed_at: 1.day.ago,
        updated_at: 1.day.ago)
    end

    let_it_be(:current_work_item) do
      create(:work_item, project: project, created_at: now, updated_at: now, closed_at: now, due_date: now)
    end

    shared_examples 'filters work items by date' do |field_name|
      context "with #{field_name}_before filter" do
        let(:item_filter_params) { "#{field_name.camelize(:lower)}Before: \"#{now.iso8601}\"" }

        it "filters work items by #{field_name} before" do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(item_ids).to contain_exactly(past_work_item.to_global_id.to_s)
        end
      end

      context "with #{field_name}_after filter" do
        let(:item_filter_params) { "#{field_name.camelize(:lower)}After: \"#{(now - 1).iso8601}\"" }

        it "filters work items by #{field_name} after" do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(item_ids).to contain_exactly(current_work_item.to_global_id.to_s)
        end
      end
    end

    %w[created updated due closed].each do |field|
      it_behaves_like 'filters work items by date', field
    end
  end

  describe 'sorting' do
    let_it_be(:status_1) { build(:work_item_system_defined_status, :to_do) }
    let_it_be(:status_2) { build(:work_item_system_defined_status, :in_progress) }
    let_it_be(:work_item_1) do
      create(:work_item, project: project, system_defined_status_id: status_1.id)
    end

    let_it_be(:work_item_2) do
      create(:work_item, :closed, project: project, system_defined_status_id: status_2.id)
    end

    let(:data_path) { [:project, :work_items] }

    def pagination_query(params)
      graphql_query_for(
        'project',
        { 'fullPath' => project.full_path },
        query_graphql_field('workItems', params, "#{page_info} nodes { id }")
      )
    end

    context 'when sorting by STATUS_ASC' do
      it_behaves_like 'sorted paginated query' do
        let(:sort_param) { :STATUS_ASC }
        let(:first_param) { 2 }
        let(:all_records) { [work_item_1, work_item_2].map { |item| item.to_global_id.to_s } }
      end
    end

    context 'when sorting by STATUS_DESC' do
      it_behaves_like 'sorted paginated query' do
        let(:sort_param) { :STATUS_DESC }
        let(:first_param) { 2 }
        let(:all_records) { [work_item_2, work_item_1].map { |item| item.to_global_id.to_s } }
      end
    end
  end

  context 'with agent plan widget' do
    let_it_be(:agent_plan_work_item1) { create(:work_item, project: project) }
    let_it_be(:agent_plan_work_item2) { create(:work_item, project: project) }
    let_it_be(:agent_plan1) do
      create(:work_item_agent_plan, work_item: agent_plan_work_item1, content: 'plan 1')
    end

    let_it_be(:agent_plan2) do
      create(:work_item_agent_plan, work_item: agent_plan_work_item2, content: 'plan 2')
    end

    before_all do
      project.add_reporter(current_user)
    end

    before do
      stub_licensed_features(ai_workflows: true)
    end

    context 'for content field across multiple work items' do
      let(:fields) do
        <<~GRAPHQL
          nodes {
            id
            features {
              agentPlan {
                content
              }
            }
          }
        GRAPHQL
      end

      it 'limits the field to 1 execution' do
        post_graphql(query, current_user: current_user)

        expect_graphql_errors_to_include(
          '"content" field can be requested only for 1 WorkItemWidgetAgentPlan(s) at a time.'
        )
      end
    end

    context 'for contentHtml field across multiple work items' do
      let(:fields) do
        <<~GRAPHQL
          nodes {
            id
            features {
              agentPlan {
                contentHtml
              }
            }
          }
        GRAPHQL
      end

      it 'limits the field to 1 execution' do
        post_graphql(query, current_user: current_user)

        expect_graphql_errors_to_include(
          '"contentHtml" field can be requested only for 1 WorkItemWidgetAgentPlan(s) at a time.'
        )
      end
    end

    context 'for a single work item' do
      let(:item_filter_params) { { iids: [agent_plan_work_item1.iid.to_s] } }

      let(:fields) do
        <<~GRAPHQL
          nodes {
            id
            features {
              agentPlan {
                content
                contentHtml
              }
            }
          }
        GRAPHQL
      end

      it 'returns the content without errors' do
        post_graphql(query, current_user: current_user)

        expect_graphql_errors_to_be_empty
      end
    end
  end

  context 'when work item epics are present' do
    let_it_be(:epic1) { create(:work_item, :epic, project: project) }
    let_it_be(:epic2) { create(:work_item, :epic, project: project) }
    let_it_be(:issue) { create(:work_item, :issue, project: project) }

    context 'when licensed feature is available' do
      before do
        stub_licensed_features(epics: true)
      end

      it 'returns work items including epics' do
        post_graphql(query, current_user: current_user)

        expect(item_ids).to contain_exactly(
          epic1.to_global_id.to_s,
          epic2.to_global_id.to_s,
          issue.to_global_id.to_s
        )
      end

      context 'when feature flag project_work_item_epics is disabled' do
        before do
          stub_feature_flags(project_work_item_epics: false)
        end

        it 'returns work items excluding epics' do
          post_graphql(query, current_user: current_user)

          expect(item_ids).to contain_exactly(issue.to_global_id.to_s)
        end
      end
    end

    context 'when licensed feature is not available' do
      before do
        stub_licensed_features(epics: false)
      end

      it 'returns work items excluding epics' do
        post_graphql(query, current_user: current_user)

        expect(item_ids).to contain_exactly(issue.to_global_id.to_s)
      end
    end
  end

  def create_feature_flag_for(work_item)
    feature_flag = create(:operations_feature_flag, project: project)
    create(:feature_flag_issue, issue_id: work_item.id, feature_flag: feature_flag)
  end
end
