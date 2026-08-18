# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a work item list for a group', feature_category: :team_planning do
  include_context 'with work items list request'

  let(:work_items_data) { graphql_data['group']['workItems']['nodes'] }
  let(:query_full_path) { group.full_path }

  describe 'N + 1 queries' do
    let_it_be(:sub_group) { create(:group, parent: group) }
    let_it_be(:label1) { create(:group_label, group: group) }
    let_it_be(:label2) { create(:group_label, group: group) }
    let_it_be(:milestone1) { create(:milestone, group: group) }
    let_it_be(:milestone2) { create(:milestone, group: group) }

    let_it_be(:project_work_item) { create(:work_item, project: project) }
    let_it_be(:sub_group_work_item) do
      create(
        :work_item,
        namespace: sub_group,
        author: reporter,
        milestone: milestone1,
        labels: [label1]
      ) do |work_item|
        create(:award_emoji, name: 'star', awardable: work_item)
      end
    end

    let_it_be(:group_work_item) do
      create(
        :work_item,
        :epic_with_legacy_epic,
        namespace: group,
        author: reporter,
        title: 'search_term',
        milestone: milestone2,
        labels: [label2]
      ) do |work_item|
        create(:award_emoji, name: 'star', awardable: work_item)
        create(:award_emoji, name: 'rocket', awardable: work_item.sync_object)
      end
    end

    let_it_be(:confidential_work_item) do
      create(:work_item, :confidential, namespace: group, author: reporter)
    end

    let_it_be(:other_work_item) { create(:work_item) }

    shared_examples 'work items resolver without N + 1 queries' do
      it 'avoids N+1 queries', :use_sql_query_cache do
        post_graphql(query, current_user: current_user) # Warmup

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user)
        end

        expect_graphql_errors_to_be_empty

        create_list(
          :work_item,
          3,
          :epic_with_legacy_epic,
          namespace: group,
          labels: [label1, label2],
          milestone: milestone2,
          author: reporter
        ) do |work_item|
          create(:award_emoji, name: 'eyes', awardable: work_item)
          create(:award_emoji, name: 'rocket', awardable: work_item.sync_object)
          create(:award_emoji, name: AwardEmoji::THUMBS_UP, awardable: work_item.sync_object)
        end

        expect do
          post_graphql(query, current_user: current_user)
        end.not_to exceed_all_query_limit(control)
        expect_graphql_errors_to_be_empty
      end
    end

    context 'when querying root fields' do
      it_behaves_like 'work items resolver without N + 1 queries'
    end

    # We need a separate example since all_graphql_fields_for will not fetch fields from types
    # that implement the widget interface. Only `type` for the widgets field.
    context 'when querying the widget interface' do
      before do
        stub_licensed_features(epics: true, subepics: true, work_item_status: true)
      end

      let(:fields) do
        <<~GRAPHQL
          nodes {
            widgets {
              type
              ... on WorkItemWidgetDescription {
                edited
                lastEditedAt
                lastEditedBy {
                  webPath
                  username
                }
                taskCompletionStatus {
                  completedCount
                  count
                }
              }
              ... on WorkItemWidgetAssignees {
                assignees { nodes { id } }
              }
              ... on WorkItemWidgetHierarchy {
                parent { id }
                children {
                  nodes {
                    id
                  }
                }
              }
              ... on WorkItemWidgetLabels {
                labels { nodes { id } }
                allowsScopedLabels
              }
              ... on WorkItemWidgetMilestone {
                milestone {
                  id
                }
              }
              ... on WorkItemWidgetAwardEmoji {
                upvotes
                downvotes
                awardEmoji {
                  nodes {
                    name
                  }
                }
              }
              ... on WorkItemWidgetStatus {
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
        GRAPHQL
      end

      it_behaves_like 'work items resolver without N + 1 queries'

      context 'when querying for WorkItemWidgetAwardEmoji' do
        it 'queries unified award emojis correctly' do
          post_graphql(query, current_user: current_user)

          data = graphql_data_at(:group, :workItems, :nodes, 0, :widgets)
          data = data.find { |k| k if k['type'] == 'AWARD_EMOJI' }['awardEmoji']['nodes']
          expect(data.flat_map(&:values)).to match_array(%w[star rocket])
        end

        it 'fetches unified upvotes and downvotes' do
          create(:award_emoji, name: AwardEmoji::THUMBS_UP, awardable: group_work_item)
          create(:award_emoji, name: AwardEmoji::THUMBS_UP, awardable: group_work_item.sync_object)
          create(:award_emoji, name: AwardEmoji::THUMBS_UP, awardable: group_work_item.sync_object)
          create(:award_emoji, name: AwardEmoji::THUMBS_DOWN, awardable: group_work_item.sync_object)

          post_graphql(query, current_user: current_user)

          data = graphql_data_at(:group, :workItems, :nodes, 0, :widgets)
          upvotes = data.find { |k| k if k['type'] == 'AWARD_EMOJI' }['upvotes']
          downvotes = data.find { |k| k if k['type'] == 'AWARD_EMOJI' }['downvotes']

          expect(upvotes).to eq(3)
          expect(downvotes).to eq(1)
        end
      end

      context 'when querying for WorkItemWidgetStatus' do
        let_it_be(:work_item_1) { create(:work_item, :task, namespace: group) }
        let_it_be(:work_item_2) { create(:work_item, :task, namespace: group) }
        let_it_be(:work_item_type) { build(:work_item_system_defined_type, :task) }

        let(:work_items) { graphql_data_at(:group, :workItems, :nodes) }

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
          context 'with current statuses' do
            context 'with system-defined status' do
              it 'returns system-defined status data' do
                create(:work_item_current_status, :system_defined, work_item: work_item_1)

                post_graphql(query, current_user: current_user)

                expect(work_items).to include(
                  'widgets' => include(
                    hash_including(
                      'type' => 'STATUS',
                      'status' => {
                        'id' => 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/1',
                        'name' => 'To do',
                        'iconName' => 'status-waiting',
                        'color' => "#737278",
                        'position' => 0
                      }
                    )
                  )
                )
              end
            end

            context 'with custom lifecycle' do
              let_it_be(:lifecycle) do
                create(:work_item_custom_lifecycle, namespace: group)
              end

              let_it_be(:custom_status) { lifecycle.default_open_status }

              context 'with custom status' do
                it 'returns custom status data' do
                  create(:work_item_type_custom_lifecycle, lifecycle: lifecycle, work_item_type: work_item_type,
                    namespace: group)

                  current_status = create(:work_item_current_status, :custom, custom_status: custom_status,
                    work_item: work_item_1)

                  post_graphql(query, current_user: current_user)

                  expect(work_items).to include(
                    'widgets' => include(
                      hash_including(
                        'type' => 'STATUS',
                        'status' => {
                          'id' => "gid://gitlab/WorkItems::Statuses::Custom::Status/#{current_status.custom_status_id}",
                          'name' => custom_status.name,
                          'iconName' => 'status-waiting',
                          'color' => "#737278",
                          'position' => 0
                        }
                      )
                    )
                  )
                end
              end

              context 'with mixed statuses' do
                it 'returns correct status data for each work item' do
                  create(:work_item, :task, namespace: group)

                  create(:work_item_current_status,
                    work_item: work_item_1,
                    system_defined_status_id:
                      lifecycle.default_closed_status.converted_from_system_defined_status_identifier
                  )

                  create(:work_item_type_custom_lifecycle, lifecycle: lifecycle, work_item_type: work_item_type,
                    namespace: group)

                  current_status_2 = create(:work_item_current_status, :custom, custom_status: custom_status,
                    work_item: work_item_2)

                  post_graphql(query, current_user: current_user)

                  status_widgets = work_items.filter_map { |item| item['widgets'].find { |w| w['type'] == 'STATUS' } }

                  expect(status_widgets).to include(
                    hash_including(
                      'type' => 'STATUS',
                      'status' => hash_including(
                        'id' => "gid://gitlab/WorkItems::Statuses::Custom::Status/#{lifecycle.default_closed_status_id}"
                      )
                    ),
                    hash_including(
                      'type' => 'STATUS',
                      'status' => hash_including(
                        'id' => "gid://gitlab/WorkItems::Statuses::Custom::Status/#{current_status_2.custom_status_id}"
                      )
                    ),
                    hash_including(
                      'type' => 'STATUS',
                      'status' => hash_including(
                        'id' => "gid://gitlab/WorkItems::Statuses::Custom::Status/#{lifecycle.default_open_status_id}"
                      )
                    )
                  )
                end

                it 'avoids N+1 queries', :use_sql_query_cache do
                  create(:work_item_current_status, :system_defined, work_item: work_item_1)

                  create(:work_item_type_custom_lifecycle, lifecycle: lifecycle, work_item_type: work_item_type,
                    namespace: group)

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

              expect(work_items).to include(
                'widgets' => include(
                  hash_including(
                    'type' => 'STATUS',
                    'status' => {
                      'id' => 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/1',
                      'name' => 'To do',
                      'iconName' => 'status-waiting',
                      'color' => "#737278",
                      'position' => 0
                    }
                  )
                )
              )
            end

            it_behaves_like 'checks for N+1 queries'
          end
        end

        context 'when feature is unlicensed' do
          before do
            stub_licensed_features(epics: true, subepics: true, work_item_status: false)

            post_graphql(query, current_user: current_user)
          end

          it 'does not return status widget' do
            expect(work_items).not_to include(
              'widgets' => include(
                hash_including(
                  'type' => 'STATUS'
                )
              )
            )
          end
        end
      end

      context 'when querying the notifications widget' do
        let(:fields) do
          <<~GRAPHQL
            nodes {
              id
              features {
                notifications {
                  subscribed
                }
              }
            }
          GRAPHQL
        end

        it 'returns correct subscription status for group-level work items' do
          create(:subscription, subscribable: group_work_item, user: current_user,
            project: nil, subscribed: true)

          post_graphql(query, current_user: current_user)

          expect_graphql_errors_to_be_empty

          items_data = graphql_data_at(:group, :workItems, :nodes)
          subscription_data = items_data.to_h do |item|
            [item['id'], item.dig('features', 'notifications', 'subscribed')]
          end

          expect(subscription_data[group_work_item.to_gid.to_s]).to be true
        end

        it 'returns false for anonymous users' do
          post_graphql(query, current_user: nil)

          expect_graphql_errors_to_be_empty

          items_data = graphql_data_at(:group, :workItems, :nodes)
          subscription_data = items_data.to_h do |item|
            [item['id'], item.dig('features', 'notifications', 'subscribed')]
          end

          expect(subscription_data[group_work_item.to_gid.to_s]).to be false
        end
      end

      context 'when querying for WorkItemWidgetCustomFields' do
        include_context 'with group configured with custom fields'

        let_it_be(:cf_work_item) { create(:work_item, work_item_type: issue_type, namespace: group) }

        let(:query) do
          graphql_query_for(
            :group, { full_path: group.full_path },
            query_graphql_field(:work_items, {}, <<~FIELDS)
              nodes {
                id
                widgets {
                  type
                  ... on WorkItemWidgetCustomFields {
                    customFieldValues {
                      customField {
                        id
                        createdBy { id }
                        updatedBy { id }
                        selectOptions { id }
                        workItemTypes { id }
                      }
                      ... on WorkItemTextFieldValue { value }
                      ... on WorkItemNumberFieldValue { value }
                      ... on WorkItemSelectFieldValue { selectedOptions { id } }
                    }
                  }
                }
              }
            FIELDS
          )
        end

        before do
          stub_licensed_features(custom_fields: true)

          create(:work_item_text_field_value, work_item: cf_work_item, custom_field: text_field, value: 'text value')
          create(:work_item_select_field_value, work_item: cf_work_item, custom_field: multi_select_field,
            custom_field_select_option: multi_select_option_1)
        end

        it 'avoids N+1 queries', :use_sql_query_cache do
          post_graphql(query, current_user: current_user) # Warmup

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            post_graphql(query, current_user: current_user)
          end
          expect_graphql_errors_to_be_empty

          additional_work_item = create(:work_item, work_item_type: issue_type, namespace: group)
          create(:work_item_text_field_value, work_item: additional_work_item, custom_field: text_field,
            value: 'more text')
          create(:work_item_number_field_value, work_item: additional_work_item, custom_field: number_field, value: 7)

          expect do
            post_graphql(query, current_user: current_user)
          end.not_to exceed_all_query_limit(control)
          expect_graphql_errors_to_be_empty
        end
      end
    end
  end

  context 'when querying WorkItemWidgetLinkedItems' do
    let_it_be(:private_group) { create(:group, :private, reporters: reporter) }
    let_it_be(:work_items) { create_list(:work_item, 2, :issue, namespace: group) }
    let_it_be(:related_items) { create_list(:work_item, 3, namespace: private_group) }
    let_it_be(:blocked_items) { create_list(:work_item, 3, namespace: private_group) }
    let_it_be(:blocking_items) { create_list(:work_item, 3, namespace: private_group) }

    let(:work_items_data) { graphql_data_at(:group, :workItems, :nodes) }

    let(:item_filter_params) { { iids: [work_items[0].iid.to_s, work_items[1].iid.to_s] } }
    let(:linked_type_filter) { '' }

    let(:fields) do
      <<~GRAPHQL
        nodes {
          widgets {
            type
            ... on WorkItemWidgetLinkedItems {
              linkedItems#{linked_type_filter} {
                nodes {
                  linkType
                  workItem { id }
                }
              }
            }
          }
        }
      GRAPHQL
    end

    before do
      stub_licensed_features(epics: true)
      create(:work_item_link, source: work_items[0], target: related_items[0], link_type: 'relates_to')
      create(:work_item_link, source: work_items[1], target: related_items[1], link_type: 'relates_to')
      create(:work_item_link, source: work_items[0], target: blocked_items[0], link_type: 'blocks')
      create(:work_item_link, source: work_items[1], target: blocked_items[1], link_type: 'blocks')
      create(:work_item_link, source: blocking_items[0], target: work_items[0], link_type: 'blocks')
      create(:work_item_link, source: blocking_items[1], target: work_items[1], link_type: 'blocks')
    end

    context 'when user is not authorized to read linked items' do
      it 'returns empty linked items data' do
        post_graphql(query, current_user: current_user)

        expect(work_items_data).to include(
          'widgets' => include(
            hash_including(
              'type' => 'LINKED_ITEMS',
              'linkedItems' => { 'nodes' => [] }
            )
          )
        )
      end
    end

    context 'when user is authorized to read linked items' do
      let(:current_user) { reporter }

      it 'returns linked items data' do
        post_graphql(query, current_user: current_user)

        expect(work_items_data).to include(
          hash_including(
            'widgets' => include(
              'type' => 'LINKED_ITEMS',
              'linkedItems' => { 'nodes' => [
                { 'linkType' => 'is_blocked_by', 'workItem' => { 'id' => blocking_items[1].to_global_id.to_s } },
                { 'linkType' => 'blocks', 'workItem' => { 'id' => blocked_items[1].to_global_id.to_s } },
                { 'linkType' => 'relates_to', 'workItem' => { 'id' => related_items[1].to_global_id.to_s } }
              ] }
            )
          ),
          hash_including(
            'widgets' => include(
              'type' => 'LINKED_ITEMS',
              'linkedItems' => { 'nodes' => [
                { 'linkType' => 'is_blocked_by', 'workItem' => { 'id' => blocking_items[0].to_global_id.to_s } },
                { 'linkType' => 'blocks', 'workItem' => { 'id' => blocked_items[0].to_global_id.to_s } },
                { 'linkType' => 'relates_to', 'workItem' => { 'id' => related_items[0].to_global_id.to_s } }
              ] }
            )
          )
        )
      end

      context 'when filtering by link type' do
        using RSpec::Parameterized::TableSyntax

        where(:linked_type_filter, :items, :expected_link_type) do
          '(filter: RELATED)'    | ref(:related_items)  | 'relates_to'
          '(filter: BLOCKS)'     | ref(:blocked_items)  | 'blocks'
          '(filter: BLOCKED_BY)' | ref(:blocking_items) | 'is_blocked_by'
        end

        with_them do
          it 'returns linked items data filtered by link type' do
            post_graphql(query, current_user: current_user)

            expect(work_items_data).to include(
              hash_including(
                'widgets' => include({
                  'type' => 'LINKED_ITEMS',
                  'linkedItems' => { 'nodes' => [
                    { 'linkType' => expected_link_type, 'workItem' => { 'id' => items[0].to_global_id.to_s } }
                  ] }
                })
              ),
              hash_including(
                'widgets' => include({
                  'type' => 'LINKED_ITEMS',
                  'linkedItems' => { 'nodes' => [
                    { 'linkType' => expected_link_type, 'workItem' => { 'id' => items[1].to_global_id.to_s } }
                  ] }
                })
              )
            )
          end
        end
      end

      context 'for N+1 queries' do
        shared_examples 'avoids N+1 queries' do
          it 'does not execute extra queries' do
            post_graphql(query, current_user: current_user) # Warmup

            control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
              post_graphql(query, current_user: current_user)
            end

            expect_graphql_errors_to_be_empty

            work_item2 = create(:work_item, :issue, namespace: group)
            create(:work_item_link, source: work_item2, target: related_items[2], link_type: 'relates_to')
            create(:work_item_link, source: work_item2, target: blocked_items[2], link_type: 'blocks')
            create(:work_item_link, source: blocking_items[2], target: work_item2, link_type: 'blocks')

            new_params = { iids: [work_items[0].iid.to_s, work_items[1].iid.to_s, work_item2.iid.to_s] }

            expect do
              post_graphql(query(new_params), current_user: current_user)
            end.not_to exceed_all_query_limit(control)
            expect_graphql_errors_to_be_empty
          end
        end

        it_behaves_like 'avoids N+1 queries'

        context 'with link type filter' do
          let(:linked_type_filter) { '(filter: BLOCKED_BY)' }

          it_behaves_like 'avoids N+1 queries'
        end
      end

      context 'when widget is present for nested work items' do
        let_it_be(:nested_linked_item) { create(:work_item, :issue, namespace: group) }

        let(:item_filter_params) { { iids: [work_items[0].iid.to_s] } }

        let(:fields) do
          <<~GRAPHQL
            nodes {
              widgets {
                ... on WorkItemWidgetLinkedItems {
                  linkedItems {
                    nodes {
                      linkType
                      workItem {
                        id
                        widgets {
                          ... on WorkItemWidgetLinkedItems {
                            linkedItems {
                              nodes {
                                linkType
                                workItem { id }
                              }
                            }
                          }
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
          create(:work_item_link, source: related_items[0], target: nested_linked_item)
        end

        it 'returns nested linked items data' do
          post_graphql(query, current_user: current_user)

          expect(work_items_data).to include(
            hash_including(
              'widgets' => include('linkedItems' => { 'nodes' => [
                {
                  'linkType' => 'is_blocked_by',
                  'workItem' => { 'id' => blocking_items[0].to_global_id.to_s,
                                  'widgets' => include('linkedItems' => { 'nodes' => [
                                    { 'linkType' => 'blocks',
                                      'workItem' => { 'id' => work_items[0].to_global_id.to_s } }
                                  ] }) }
                },
                {
                  'linkType' => 'blocks',
                  'workItem' => { 'id' => blocked_items[0].to_global_id.to_s,
                                  'widgets' => include('linkedItems' => { 'nodes' => [
                                    { 'linkType' => 'is_blocked_by',
                                      'workItem' => { 'id' => work_items[0].to_global_id.to_s } }
                                  ] }) }
                },
                {
                  'linkType' => 'relates_to',
                  'workItem' => { 'id' => related_items[0].to_global_id.to_s,
                                  'widgets' => include('linkedItems' => { 'nodes' => [
                                    { 'linkType' => 'relates_to',
                                      'workItem' => { 'id' => nested_linked_item.to_global_id.to_s } },
                                    { 'linkType' => 'relates_to',
                                      'workItem' => { 'id' => work_items[0].to_global_id.to_s } }
                                  ] }) }
                }
              ] }
                                  )
            )
          )
        end
      end
    end
  end

  context 'for epic license checks' do
    let_it_be(:group_work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

    context 'when epic license is enabled' do
      before do
        stub_licensed_features(epics: true)
      end

      it 'returns group work items' do
        post_graphql(query, current_user: current_user)

        work_items = graphql_data_at(:group, :workItems, :nodes)

        expect(work_items.size).to eq(1)
        expect(work_items[0]['workItemType']['name']).to eq('Epic')
      end
    end

    context 'when epic feature is disabled' do
      before do
        stub_licensed_features(epics: false)
      end

      it 'does not return group work items' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:group, :workItems, :nodes)).to eq([])
      end
    end
  end

  describe 'license check' do
    let_it_be(:group_issuables) { create_list(:work_item, 10, :epic, namespace: group) }
    let_it_be(:project_issues) { create_list(:work_item, 5, :issue, project: project) }
    let_it_be(:project_epics) { create_list(:work_item, 5, :epic, project: project) }
    let_it_be(:project_issuables) { project_issues + project_epics }

    let(:field_name) { 'workItems' }
    let(:container_name) { 'group' }
    let(:container) { group }
    let(:count_path) { ['data', container_name, field_name, 'count'] }

    let(:page_size) { 20 }

    subject(:execute) do
      GitlabSchema.execute(
        query,
        context: { current_user: user },
        variables: {
          fullPath: container.full_path,
          first: page_size
        }
      ).to_h
    end

    context 'with group level work items' do
      context 'with group level work item license' do
        before do
          stub_licensed_features(epics: true)
        end

        it_behaves_like 'issuables pagination and count' do
          let(:issuables) { group_issuables }
        end
      end

      context 'without group level work item license' do
        let(:issuables) { group_issuables }

        let(:query) do
          <<~GRAPHQL
            query #{container_name}($fullPath: ID!, $first: Int, $after: String) {
              #{container_name}(fullPath: $fullPath) {
                #{field_name}(first: $first, after: $after) {
                  count
                  edges {
                    node {
                      id
                    }
                  }
                  pageInfo {
                    endCursor
                    hasNextPage
                  }
                }
              }
            }
          GRAPHQL
        end

        before do
          stub_licensed_features(epics: false)
        end

        it 'does not return an error' do
          expect(execute['errors']).to be_nil
        end

        it 'does not return work items' do
          data = execute['data'][container_name]['workItems']

          expect(data['edges']).to be_empty
          expect(data['count']).to eq(0)
        end
      end
    end

    context 'with group and project level work items' do
      let(:work_items_query) do
        <<~GRAPHQL
          query #{container_name}($fullPath: ID!, $first: Int, $after: String) {
            #{container_name}(fullPath: $fullPath) {
              #{field_name}(first: $first, after: $after, includeDescendants: true) {
                count
                edges {
                  node {
                    id
                  }
                }
                pageInfo {
                  endCursor
                  hasNextPage
                }
              }
            }
          }
        GRAPHQL
      end

      context 'with group level work item license' do
        before do
          stub_licensed_features(epics: true)
        end

        it_behaves_like 'issuables pagination and count' do
          let_it_be(:issuables) { [group_issuables, project_issuables].flatten }

          let(:per_page) { 19 }
          let(:query) { work_items_query }
        end

        context 'when project_work_item_epics feature flag is disabled' do
          let_it_be(:issuables) { [group_issuables, project_issues].flatten }

          let(:query) { work_items_query }

          before do
            stub_feature_flags(project_work_item_epics: false)
          end

          it 'does not return an error' do
            expect(execute['errors']).to be_nil
          end

          it 'does not return disabled work item types' do
            data = execute['data'][container_name]['workItems']

            expect(data['count']).to eq(15)
            expect(data['edges'].count).to eq(15)
            expect(data['edges'].map { |node| node.dig('node', 'id') }).to match_array(
              issuables.flat_map(&:to_gid).map(&:to_s)
            )
          end
        end
      end

      context 'without group level work item license' do
        let_it_be(:issuables) { [group_issuables, project_issues] }

        let(:query) { work_items_query }

        before do
          stub_licensed_features(epics: false)
        end

        it 'does not return an error' do
          expect(execute['errors']).to be_nil
        end

        it 'does not return licensed work items' do
          data = execute['data'][container_name]['workItems']

          expect(data['count']).to eq(5)
          expect(data['edges'].count).to eq(5)
          expect(data['edges'].map { |node| node.dig('node', 'id') }).to match_array(
            project_issues.flat_map(&:to_gid).map(&:to_s)
          )
        end
      end
    end
  end

  context 'when skipping authorization' do
    shared_examples  'request with skipped abilities' do |abilities = []|
      it 'authorizes objects as expected' do
        expect_any_instance_of(Gitlab::Graphql::Authorize::ObjectAuthorization) do |authorization|
          expect(authorization).to receive(:ok).with(
            group.work_items.first,
            current_user,
            scope_validator: nil,
            skip_abilities: abilities
          )
        end

        post_graphql(query, current_user: current_user)
      end
    end

    context 'when authorize_issue_types_in_finder feature flag is enabled' do
      before do
        stub_feature_flags(authorize_issue_types_in_finder: true)
      end

      it_behaves_like 'request with skipped abilities', [:read_work_item]
    end

    context 'when authorize_issue_types_in_finder feature flag is disabled' do
      before do
        stub_feature_flags(authorize_issue_types_in_finder: false)
      end

      it_behaves_like 'request with skipped abilities', []
    end
  end

  def query(params = item_filter_params)
    graphql_query_for(
      'group',
      { 'fullPath' => query_full_path },
      query_graphql_field('workItems', params, fields)
    )
  end
end
