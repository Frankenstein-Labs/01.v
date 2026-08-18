# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work Items Integration (GraphQL fixtures)', type: :request, feature_category: :team_planning do
  include ApiHelpers
  include GraphqlHelpers
  include JavaScriptFixturesHelpers

  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:project, freeze: false) { create(:project, :repository, group: group) }
  let_it_be(:label1, freeze: false) { create(:label, project: project, title: 'To Do', color: '#F0AD4E') }
  let_it_be(:label2, freeze: false) { create(:label, project: project, title: 'Doing', color: '#5CB85C') }
  let_it_be(:assignable_user, freeze: false) { create(:user, username: 'assignable_user', name: 'Assignable User') }
  let_it_be(:milestone, freeze: false) { create(:milestone, project: project, title: 'v1.0') }
  let_it_be(:iteration_cadence, freeze: false) { create(:iterations_cadence, group: group) }
  let_it_be(:iteration, freeze: false) { create(:iteration, iterations_cadence: iteration_cadence, group: group) }
  let_it_be(:work_item, freeze: false) do
    create(:work_item, :issue, project: project, title: 'Dependent test issue',
      author: user, assignees: [user], milestone: milestone,
      iteration: iteration, start_date: 5.days.ago, due_date: 10.days.from_now, weight: 3,
      health_status: :on_track)
  end

  let_it_be(:second_work_item, freeze: false) do
    create(:work_item, :issue, project: project, title: 'Second test issue', author: user, labels: [label1])
  end

  let_it_be(:closed_work_item, freeze: false) do
    create(:work_item, :issue, :closed, project: project, title: 'Closed test issue', author: user)
  end

  # Labelled so the label filter fixtures return distinct sets: without a second
  # labelled item, `Any` collapses into `= To Do` and `None` into `!= To Do`.
  # `Any` and `is one of` still return the same rows because the seed has only two
  # labels; the variables assertions are what keep those two cases distinguishable.
  let_it_be(:child_task, freeze: false) do
    create(:work_item, :task, project: project, title: 'Child task', author: user, labels: [label2])
  end

  let_it_be(:child_task_parent_link, freeze: false) do
    create(:parent_link, work_item: child_task, work_item_parent: second_work_item)
  end

  let_it_be(:second_work_item_note, freeze: false) do
    create(:note, noteable: second_work_item, project: project, author: user, note: 'Test comment')
  end

  let_it_be(:second_work_item_upvote, freeze: false) do
    create(:award_emoji, :upvote, awardable: second_work_item, user: user)
  end

  let_it_be(:blocking_work_item, freeze: false) do
    create(:work_item, :issue, project: project, title: 'Blocking issue', author: user)
  end

  let_it_be(:blocking_link, freeze: false) do
    create(:work_item_link, source: blocking_work_item, target: second_work_item, link_type: :blocks)
  end

  let_it_be(:work_item_body_reaction, freeze: false) do
    create(:award_emoji, awardable: work_item, name: '100', user: assignable_user)
  end

  let_it_be(:work_item_reaction_note, freeze: false) do
    create(:note, noteable: work_item, project: project, author: user, note: 'Reaction note')
  end

  let_it_be(:work_item_note_reaction, freeze: false) do
    create(:award_emoji, awardable: work_item_reaction_note, name: 'grinning', user: assignable_user)
  end

  # Created last so it does not renumber the DB ids of the work items above, which
  # the drawer/list fixtures and the hard-coded `workItemId` test helper depend on.
  let_it_be(:linkable_work_item, freeze: false) do
    create(:work_item, :issue, project: project, title: 'Linkable test issue', author: user)
  end

  base_output_path = 'graphql/work_items/integration/'

  before_all do
    project.add_maintainer(user)
    project.add_developer(assignable_user)
  end

  before do
    stub_licensed_features(
      epics: true,
      subepics: true,
      issuable_health_status: true,
      issue_weights: true,
      iterations: true,
      blocked_work_items: true,
      work_item_status: true,
      scoped_labels: true,
      custom_fields: true
    )
    sign_in(user)
  end

  describe GraphQL::Query do
    it "#{base_output_path}work_item_metadata.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/work_item_metadata.query.graphql', ee: true
      )
      post_graphql(query, current_user: user, variables: { fullPath: project.full_path })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_work_items_full.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/list/graphql/get_work_items_full.query.graphql', ee: true
      )
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        sort: 'CREATED_DESC',
        state: 'opened',
        firstPageSize: 20
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_work_items_full_closed.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/list/graphql/get_work_items_full.query.graphql', ee: true
      )
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        sort: 'CREATED_DESC',
        state: 'closed',
        firstPageSize: 20
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_work_items_slim.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/list/graphql/get_work_items_slim.query.graphql', ee: true
      )
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        sort: 'CREATED_DESC',
        state: 'opened',
        firstPageSize: 20
      })
      expect_graphql_errors_to_be_empty
    end

    label_filters = {
      'with_label' => { labelName: ['To Do'] },
      'without_specific_label' => { not: { labelName: ['To Do'] } },
      'with_no_label' => { labelName: ['None'] },
      'with_any_label' => { labelName: ['Any'] },
      'with_any_of_labels' => { or: { labelNames: ['To Do', 'Doing'] } }
    }
    list_query_kinds = %w[slim full].freeze

    label_filters.each do |suffix, filter_variables|
      list_query_kinds.each do |query_kind|
        it "#{base_output_path}get_work_items_#{query_kind}_#{suffix}.query.graphql.json" do
          query = get_graphql_query_as_string(
            "work_items/list/graphql/get_work_items_#{query_kind}.query.graphql", ee: true
          )
          post_graphql(query, current_user: user, variables: {
            fullPath: project.full_path,
            sort: 'CREATED_DESC',
            state: 'opened',
            firstPageSize: 20,
            **filter_variables
          })
          expect_graphql_errors_to_be_empty
        end
      end
    end

    it "#{base_output_path}namespace_work_item.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/work_item_by_iid.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        iid: work_item.iid.to_s
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}namespace_work_item_features.query.graphql.json" do
      allow_unlimited_graphql_complexity

      query = get_graphql_query_as_string(
        'work_items/graphql/work_item_by_iid.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        iid: work_item.iid.to_s,
        useWorkItemFeatures: true
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}current_user.query.graphql.json" do
      query = get_graphql_query_as_string(
        'graphql_shared/queries/current_user.query.graphql'
      )
      post_graphql(query, current_user: user)
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_user.query.graphql.json" do
      query = get_graphql_query_as_string(
        'graphql_shared/queries/get_user_callouts.query.graphql'
      )
      post_graphql(query, current_user: user)
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}workspace_permissions.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/workspace_permissions.query.graphql'
      )
      post_graphql(query, current_user: user, variables: { fullPath: project.full_path })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}namespace_work_item_types.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/namespace_work_item_types.query.graphql'
      )
      post_graphql(query, current_user: user, variables: { fullPath: project.full_path })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}work_item_ancestors_query.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/work_item_ancestors.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        id: work_item.to_global_id.to_s
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}work_item_notes_by_iid.query.graphql.json" do
      allow_unlimited_graphql_complexity

      query = get_graphql_query_as_string(
        'work_items/graphql/notes/work_item_notes_by_iid.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        iid: work_item.iid.to_s
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}work_item_linked_items.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/work_item_linked_items.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        iid: work_item.iid.to_s
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}work_item_linked_items_features.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/work_item_linked_items.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        iid: work_item.iid.to_s,
        useWorkItemFeatures: true
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_allowed_work_item_child_types.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/work_item_allowed_children.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        id: work_item.to_global_id.to_s
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_allowed_work_item_parent_types.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/work_item_allowed_parent_types.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        id: work_item.to_global_id.to_s
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_work_item_notifications_by_id.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/get_work_item_notifications_by_id.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        id: work_item.to_global_id.to_s
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}work_item_tree_query.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/work_item_tree.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        id: work_item.to_global_id.to_s
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}project_generate_description_permissions.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/ai_permissions_for_project.query.graphql'
      )
      post_graphql(query, current_user: user, variables: { fullPath: project.full_path })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}project_work_item_award_emojis.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/award_emoji.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        iid: work_item.iid.to_s
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}work_item_participants.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/work_item_participants.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        iid: work_item.iid.to_s
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_work_item_design_list.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/components/design_management/graphql/design_collection.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        id: work_item.to_global_id.to_s
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}namespace_paths.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/namespace_paths.query.graphql'
      )
      post_graphql(query, current_user: user, variables: { fullPath: project.full_path })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}work_item_vulnerabilities.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/work_item_vulnerabilities.query.graphql', ee: true
      )
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        iid: work_item.iid.to_s
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}namespace_merge_requests_enabled.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/namespace_merge_requests_enabled.query.graphql'
      )
      post_graphql(query, current_user: user, variables: { fullPath: project.full_path })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_project_root_ref.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/get_project_root_ref.query.graphql'
      )
      post_graphql(query, current_user: user, variables: { projectFullPath: project.full_path })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}work_item_development.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/work_item_development.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        id: work_item.to_global_id.to_s
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}group_workspace_permissions.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/group_workspace_permissions.query.graphql'
      )
      post_graphql(query, current_user: user, variables: { fullPath: group.full_path })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}has_work_items.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/list/graphql/has_work_items.query.graphql'
      )
      post_graphql(query, current_user: user, variables: { fullPath: project.full_path })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}work_item_description_templates_list.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/work_item_description_templates_list.query.graphql'
      )
      post_graphql(query, current_user: user, variables: { fullPath: project.full_path })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}project_labels.query.graphql.json" do
      query = get_graphql_query_as_string(
        'sidebar/components/labels/labels_select_widget/graphql/project_labels.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        searchTerm: ''
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}workspace_autocomplete_users_search.query.graphql.json" do
      query = get_graphql_query_as_string(
        'graphql_shared/queries/workspace_autocomplete_users.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        search: '',
        isProject: true
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_user_work_items_preferences.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/get_user_preferences.query.graphql'
      )
      issue_type = ::WorkItems::TypesFramework::Provider.new.find_by_base_type(:issue)
      post_graphql(query, current_user: user, variables: {
        namespace: project.full_path,
        workItemTypeId: issue_type.to_global_id.to_s
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}namespace_custom_field_names.query.graphql.json" do
      query = get_graphql_query_as_string(
        'vue_shared/components/filtered_search_bar/queries/custom_field_names.query.graphql',
        ee: true
      )
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        active: true
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}work_item_types_configuration.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/work_item_types_configuration.query.graphql'
      )
      post_graphql(query, current_user: user, variables: { fullPath: project.full_path })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}project_milestones.query.graphql.json" do
      query = get_graphql_query_as_string(
        'sidebar/queries/project_milestones.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        title: '',
        state: 'active',
        first: 20
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_duo_workflow_status_check.query.graphql.json" do
      query = get_graphql_query_as_string(
        'ai/graphql/get_duo_workflow_status_check.query.graphql', ee: true
      )
      post_graphql(query, current_user: user, variables: { projectPath: project.full_path })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}work_item_email_participants_by_iid.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/notes/work_item_email_participants_by_iid.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        iid: work_item.iid.to_s
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_configured_flows.query.graphql.json" do
      query = get_graphql_query_as_string(
        'ai/graphql/get_configured_flows.query.graphql', ee: true
      )
      post_graphql(query, current_user: user, variables: {
        projectId: project.to_global_id.to_s
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}open_child_item_count.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/open_child_count.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        iid: second_work_item.iid.to_s
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}work_item_time_tracking.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/work_item_time_tracking.query.graphql'
      )
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        iid: work_item.iid.to_s
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}get_work_items_rest.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/list/graphql/get_work_items_rest.query.graphql', ee: true
      )
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        sort: 'CREATED_DESC',
        state: 'opened',
        firstPageSize: 20
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}project_work_items.query.graphql.json" do
      query = get_graphql_query_as_string(
        'work_items/graphql/project_work_items.query.graphql'
      )
      # Scope the search to the single linkable item so the token selector in the
      # linked-items spec returns one predictable result to click.
      post_graphql(query, current_user: user, variables: {
        fullPath: project.full_path,
        searchTerm: 'Linkable test issue'
      })
      expect_graphql_errors_to_be_empty
    end
  end

  describe 'REST endpoints' do
    it "#{base_output_path}can_create_branch.json" do
      get "/#{project.full_path}/-/issues/#{work_item.iid}/can_create_branch.json"

      expect(response).to be_successful
    end
  end

  describe 'Mutations' do
    it "#{base_output_path}update_work_item.mutation.graphql.json" do
      mutation = get_graphql_query_as_string(
        'work_items/graphql/update_work_item.mutation.graphql'
      )
      post_graphql(mutation, current_user: user, variables: {
        input: {
          id: work_item.to_global_id.to_s,
          title: work_item.title
        }
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}update_work_item_labels.mutation.graphql.json" do
      mutation = get_graphql_query_as_string(
        'work_items/graphql/update_work_item.mutation.graphql'
      )
      post_graphql(mutation, current_user: user, variables: {
        input: {
          id: work_item.to_global_id.to_s,
          labelsWidget: {
            addLabelIds: [label2.to_global_id.to_s]
          }
        }
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}update_work_item_milestone.mutation.graphql.json" do
      mutation = get_graphql_query_as_string(
        'work_items/graphql/update_work_item.mutation.graphql'
      )
      post_graphql(mutation, current_user: user, variables: {
        input: {
          id: work_item.to_global_id.to_s,
          milestoneWidget: {
            milestoneId: milestone.to_global_id.to_s
          }
        }
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}create_work_item_note.mutation.graphql.json" do
      mutation = get_graphql_query_as_string(
        'work_items/graphql/notes/create_work_item_note.mutation.graphql'
      )
      post_graphql(mutation, current_user: user, variables: {
        input: {
          noteableId: work_item.to_global_id.to_s,
          body: 'Test comment from drawer'
        }
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}update_work_item_assignees.mutation.graphql.json" do
      mutation = get_graphql_query_as_string(
        'work_items/graphql/update_work_item.mutation.graphql'
      )
      post_graphql(mutation, current_user: user, variables: {
        input: {
          id: work_item.to_global_id.to_s,
          assigneesWidget: {
            assigneeIds: [assignable_user.to_global_id.to_s]
          }
        }
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}add_linked_items.mutation.graphql.json" do
      mutation = get_graphql_query_as_string(
        'work_items/graphql/add_linked_items.mutation.graphql'
      )
      post_graphql(mutation, current_user: user, variables: {
        input: {
          id: work_item.to_global_id.to_s,
          linkType: 'RELATED',
          workItemsIds: [blocking_work_item.to_global_id.to_s]
        },
        useWorkItemFeatures: false
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}add_linked_items_features.mutation.graphql.json" do
      mutation = get_graphql_query_as_string(
        'work_items/graphql/add_linked_items.mutation.graphql'
      )
      post_graphql(mutation, current_user: user, variables: {
        input: {
          id: work_item.to_global_id.to_s,
          linkType: 'RELATED',
          workItemsIds: [closed_work_item.to_global_id.to_s]
        },
        useWorkItemFeatures: true
      })
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}remove_linked_items.mutation.graphql.json" do
      mutation = get_graphql_query_as_string(
        'work_items/graphql/remove_linked_items.mutation.graphql'
      )
      post_graphql(mutation, current_user: user, variables: {
        input: {
          id: second_work_item.to_global_id.to_s,
          workItemsIds: [blocking_work_item.to_global_id.to_s]
        }
      })
      expect_graphql_errors_to_be_empty
    end
  end

  describe API::WorkItems::List do
    it "#{base_output_path}rest_work_items_list.json" do
      get api("/namespaces/#{project.full_path}/-/work_items", user),
        params: {
          fields: 'id,iid,global_id,title,title_html,state,created_at,updated_at,closed_at,reference,web_path,
          author,work_item_type,namespace',
          features: 'labels,assignees,milestone,start_and_due_date,status,
          health_status,weight,iteration,hierarchy,linked_items,award_emoji,development'
        }

      expect(response).to have_gitlab_http_status(:ok)
    end
  end
end
