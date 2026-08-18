# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'API::WorkItems (group work items)', feature_category: :portfolio_management do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:editor) { create(:user) }

  let_it_be_with_reload(:group) { create(:group, :private, reporters: user) }
  let_it_be_with_reload(:group_label) { create(:group_label, group: group, title: 'group-label') }
  let_it_be_with_reload(:group_milestone) { create(:milestone, group: group, title: 'group-milestone') }
  let_it_be_with_reload(:group_work_item) do
    create(
      :work_item,
      :group_level,
      namespace: group,
      labels: [group_label],
      milestone: group_milestone,
      description: 'Group work item description'
    )
  end

  let_it_be_with_reload(:group_work_item2) { create(:work_item, :group_level, namespace: group) }

  let_it_be_with_reload(:project) do
    create(:project, :private, group: group, reporters: user)
  end

  before do
    stub_feature_flags(work_item_rest_api: user)
    stub_licensed_features(epics: true)
  end

  include_context 'with API work items shared helpers'

  describe 'GET /namespaces/:id/-/work_items' do
    context 'when listing group work items' do
      let_it_be(:namespace_record) { group }
      let(:primary_work_item) { group_work_item }
      let(:secondary_work_item) { group_work_item2 }
      let(:label) { group_label }
      let(:milestone) { group_milestone }
      let(:api_request_path) { "/namespaces/#{namespace_record.full_path}/-/work_items" }

      it_behaves_like 'work item listing endpoint'
      it_behaves_like 'work item listing filters'
      it_behaves_like 'work item listing EE iteration filters'
      it_behaves_like 'work item listing EE filters'

      context 'with linked_items feature' do
        let_it_be_with_reload(:list_subject_wi) { create(:work_item, :group_level, namespace: group) }
        let_it_be_with_reload(:list_blocked_wi) { create(:work_item, :group_level, namespace: group) }
        let_it_be_with_reload(:list_blocker_wi) { create(:work_item, :group_level, namespace: group) }

        before_all do
          create(:work_item_link, source: list_subject_wi, target: list_blocked_wi, link_type: 'blocks')
          create(:work_item_link, source: list_blocker_wi, target: list_subject_wi, link_type: 'blocks')
          list_subject_wi.update_blocking_issues_count!
        end

        it 'returns correct blocking/blocked_by counts per work item without N+1 queries' do
          request_params = { features: 'linked_items' }

          # Settle one-time lazy writes before the baseline so they don't skew the N+1 count.
          user.create_user_preference! unless user.user_preference
          user.update_column(:last_activity_on, Time.zone.today) unless user.last_activity_on == Time.zone.today

          # Warmup
          get api(api_request_path, user), params: request_params

          baseline = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            get api(api_request_path, user), params: request_params
          end

          extra_work_item = create(:work_item, :group_level, namespace: namespace_record)
          create(:work_item_link, source: list_blocker_wi, target: extra_work_item, link_type: 'blocks')

          # Settle first-request queries for any users created by the factories above before comparing.
          get api(api_request_path, user), params: request_params

          expect do
            get api(api_request_path, user), params: request_params
          end.to issue_same_number_of_queries_as(baseline).with_threshold(1)

          expect(response).to have_gitlab_http_status(:ok)
          # Value assertions guard against a missing preload: blocked_by_count falls back to 0
          # without the preload, so query-count parity alone wouldn't catch a regression.
          expect(work_item_json_for(list_subject_wi).fetch('features').fetch('linked_items')).to include(
            'blocking_count' => 1,
            'blocked_by_count' => 1
          )
          expect(work_item_json_for(extra_work_item).fetch('features').fetch('linked_items')).to include(
            'blocking_count' => 0,
            'blocked_by_count' => 1
          )
        end
      end

      context 'with hierarchy feature' do
        let_it_be(:group_epic) { create(:work_item, :epic, namespace: group) }
        let_it_be(:project_issue) { create(:work_item, :issue, project: project) }

        before_all do
          create(:parent_link, work_item: project_issue, work_item_parent: group_epic)
        end

        it "returns the parent's own namespace, not the child's" do
          get api("/namespaces/#{CGI.escape(project.project_namespace.full_path)}/-/work_items",
            user), params: { features: 'hierarchy' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(features_json_for(project_issue)).to include(
            'hierarchy' => a_hash_including(
              'parent' => a_hash_including(
                'id' => group_epic.id,
                'namespace' => a_hash_including('full_path' => group.full_path, 'kind' => 'group')
              )
            )
          )
        end
      end
    end
  end

  describe 'GET /namespaces/:id/-/work_items/:work_item_iid' do
    context 'when fetching a group work item' do
      let(:namespace_record) { group }
      let(:api_request_path) { "/namespaces/#{namespace_record.full_path}/-/work_items" }
      let(:primary_work_item) { group_work_item }
      let(:label) { group_label }

      it_behaves_like 'work item show endpoint'

      it_behaves_like 'authorizing granular token permissions', :read_work_item do
        let(:boundary_object) { group }
        let(:request) do
          get api("#{api_request_path}/#{primary_work_item.iid}", personal_access_token: pat)
        end
      end

      context 'with linked_items feature' do
        let_it_be_with_reload(:blocked_item) { create(:work_item, :group_level, namespace: group) }
        let_it_be_with_reload(:blocking_item) { create(:work_item, :group_level, namespace: group) }

        before_all do
          create(:work_item_link, source: group_work_item, target: blocked_item, link_type: 'blocks')
          create(:work_item_link, source: blocking_item, target: group_work_item, link_type: 'blocks')
          group_work_item.update_blocking_issues_count!
        end

        it 'returns blocking_count and blocked_by_count' do
          get api("#{api_request_path}/#{group_work_item.iid}", user), params: { features: 'linked_items' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.dig('features', 'linked_items')).to include(
            'blocking_count' => 1,
            'blocked_by_count' => 1
          )
        end
      end
    end
  end

  describe 'GET /groups/:id/-/work_items' do
    let_it_be(:namespace_record) { group }
    let(:primary_work_item) { group_work_item }
    let(:secondary_work_item) { group_work_item2 }
    let(:label) { group_label }
    let(:milestone) { group_milestone }
    let(:api_request_path) { "/groups/#{group.id}/-/work_items" }

    it_behaves_like 'work item listing endpoint'
    it_behaves_like 'work item listing filters'
    it_behaves_like 'work item listing EE iteration filters'

    it_behaves_like 'authorizing granular token permissions', :read_work_item do
      let(:boundary_object) { group }
      let(:request) do
        get api("/groups/#{group.id}/-/work_items", personal_access_token: pat)
      end
    end

    it_behaves_like 'work item N+1 query prevention'

    context 'with include_descendants filter' do
      let_it_be_with_reload(:subgroup) do
        create(:group, :private, parent: group).tap { |sub| sub.add_reporter(user) }
      end

      let_it_be_with_reload(:subgroup_project) do
        create(:project, :private, group: subgroup, reporters: user)
      end

      let_it_be_with_reload(:subgroup_project_work_item) { create(:work_item, project: subgroup_project) }

      it 'includes work items from descendant groups' do
        get api("/groups/#{group.id}/-/work_items", user), params: { include_descendants: true }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to include(subgroup_project_work_item.id)
      end

      it 'excludes work items from descendant groups by default' do
        get api("/groups/#{group.id}/-/work_items", user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).not_to include(subgroup_project_work_item.id)
      end
    end

    context 'with include_ancestors filter' do
      let_it_be_with_reload(:subgroup) do
        create(:group, :private, parent: group).tap { |sub| sub.add_reporter(user) }
      end

      it 'includes work items from ancestor groups' do
        get api("/groups/#{subgroup.id}/-/work_items", user), params: { include_ancestors: true }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to include(group_work_item.id, group_work_item2.id)
      end

      it 'excludes work items from ancestor groups by default' do
        get api("/groups/#{subgroup.id}/-/work_items", user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).not_to include(group_work_item.id, group_work_item2.id)
      end
    end

    context 'with include_archived filter' do
      let_it_be_with_reload(:archived_project) do
        create(:project, :archived, group: group, reporters: user)
      end

      let_it_be_with_reload(:archived_project_work_item) { create(:work_item, project: archived_project) }

      it 'excludes archived project work items by default' do
        get api("/groups/#{group.id}/-/work_items", user), params: { include_descendants: true }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).not_to include(archived_project_work_item.id)
      end

      it 'includes archived project work items when set to true' do
        get api("/groups/#{group.id}/-/work_items", user),
          params: { include_descendants: true, include_archived: true }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to include(archived_project_work_item.id)
      end
    end

    context 'with N+1 query prevention for EE fields' do
      let(:all_fields_param) { ::API::WorkItems::ALL_FIELDS.join(',') }
      let(:all_features_param) { ::API::WorkItems::FEATURE_SUPPORTED_VALUES.join(',') }
      let(:ee_request_params) { { features: all_features_param, fields: all_fields_param } }

      before do
        stub_licensed_features(iterations: true, issuable_health_status: true, epics: true, okrs: true)

        # Ensure one-time lazy writes are settled so they don't skew the N+1 count.
        # These records are normally created on first API request and vary by test ordering.
        user.create_user_preference! unless user.user_preference
        user.update_column(:last_activity_on, Time.zone.today) unless user.last_activity_on == Time.zone.today

        create_ee_work_items(namespace_record)

        2.times { get api(api_request_path, user), params: ee_request_params }
      end

      it 'does not cause N+1 queries for EE features' do
        baseline = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          get api(api_request_path, user), params: ee_request_params
        end

        initial_count = json_response.size

        create_ee_work_items(namespace_record)

        # Settle first-request queries for any users created by the factories above before comparing.
        get api(api_request_path, user), params: ee_request_params

        expect do
          get api(api_request_path, user), params: ee_request_params
        end.to issue_same_number_of_queries_as(baseline).with_threshold(1)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.size).to be > initial_count

        wi_sourced_by_work_item = json_response.find do |wi|
          wi.dig('features', 'start_and_due_date', 'start_date_sourcing_work_item')
        end
        expect(wi_sourced_by_work_item.dig('features', 'start_and_due_date', 'start_date_sourcing_work_item',
          'id')).to be_present
        expect(wi_sourced_by_work_item.dig('features', 'start_and_due_date', 'due_date_sourcing_work_item',
          'id')).to be_present

        wi_sourced_by_milestone = json_response.find do |wi|
          wi.dig('features', 'start_and_due_date', 'start_date_sourcing_milestone')
        end
        expect(wi_sourced_by_milestone.dig('features', 'start_and_due_date', 'start_date_sourcing_milestone',
          'id')).to be_present
        expect(wi_sourced_by_milestone.dig('features', 'start_and_due_date', 'due_date_sourcing_milestone',
          'id')).to be_present
      end

      def create_ee_work_items(namespace)
        iteration = create(:iteration, group: namespace)

        2.times do
          create_namespace_work_item(
            namespace,
            author: user,
            iteration: iteration,
            health_status: :on_track,
            start_date: Date.current,
            due_date: 1.week.from_now.to_date
          )
        end

        2.times do
          epic = create(:work_item, :epic, :group_level, namespace: namespace, author: user)
          create(:color, work_item: epic)
        end

        2.times do
          objective = create(:work_item, :objective, :group_level, namespace: namespace, author: user)
          create(:progress, work_item: objective)
        end

        sourcing_work_item = create(:work_item, :epic, :group_level, namespace: namespace, author: user)
        sourcing_milestone = create(:milestone, group: namespace)

        epic_sourced_by_work_item = create(:work_item, :epic, :group_level, namespace: namespace, author: user)
        create(:work_items_dates_source,
          work_item: epic_sourced_by_work_item,
          start_date_sourcing_work_item: sourcing_work_item,
          due_date_sourcing_work_item: sourcing_work_item)

        epic_sourced_by_milestone = create(:work_item, :epic, :group_level, namespace: namespace, author: user)
        create(:work_items_dates_source,
          work_item: epic_sourced_by_milestone,
          start_date_sourcing_milestone: sourcing_milestone,
          due_date_sourcing_milestone: sourcing_milestone)
      end
    end

    context 'when using an unescaped subgroup path' do
      let_it_be_with_reload(:subgroup) do
        create(:group, :private, parent: group).tap { |sub| sub.add_reporter(user) }
      end

      let_it_be_with_reload(:subgroup_work_item) do
        create(:work_item, :group_level, namespace: subgroup)
      end

      it 'returns subgroup work items' do
        get api("/groups/#{subgroup.full_path}/-/work_items", user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to contain_exactly(subgroup_work_item.id)
      end
    end
  end

  describe 'GET /groups/:id/-/work_items/:work_item_iid' do
    let(:api_request_path) { "/groups/#{group.id}/-/work_items" }
    let(:primary_work_item) { group_work_item }
    let(:label) { group_label }

    it_behaves_like 'work item show endpoint'
  end

  describe 'GET /projects/:id/-/work_items requirement visibility' do
    let_it_be(:regular_work_item) { create(:work_item, project: project) }
    let_it_be(:requirement_work_item) { create(:work_item, :requirement, project: project) }

    let(:api_request_path) { "/projects/#{project.id}/-/work_items" }

    before do
      stub_feature_flags(work_item_rest_api: false)
      stub_licensed_features(epics: true, requirements: true)
    end

    context 'when the user cannot read requirements (requirements_access_level disabled)' do
      before do
        project.project_feature.update!(requirements_access_level: ::ProjectFeature::DISABLED)
      end

      it 'excludes requirement-typed work items', :aggregate_failures do
        get api(api_request_path, user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to include(regular_work_item.id)
        expect(json_response.pluck('id')).not_to include(requirement_work_item.id)
      end
    end

    context 'when the user can read requirements' do
      it 'includes requirement-typed work items', :aggregate_failures do
        get api(api_request_path, user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.pluck('id')).to include(regular_work_item.id, requirement_work_item.id)
      end
    end
  end

  describe 'custom_fields widget' do
    include_context 'with group configured with custom fields'

    let_it_be_with_reload(:cf_user) { create(:user) }
    let_it_be_with_reload(:cf_project) { create(:project, group: group, reporters: cf_user) }
    let_it_be_with_reload(:cf_work_item) do
      create(:work_item, work_item_type: issue_type, project: cf_project)
    end

    before do
      stub_feature_flags(work_item_rest_api: cf_user)
      stub_licensed_features(custom_fields: true)
    end

    before_all do
      create(:work_item_text_field_value, work_item: cf_work_item, custom_field: text_field, value: 'text value')
      create(:work_item_number_field_value, work_item: cf_work_item, custom_field: number_field, value: 10)

      create(:work_item_select_field_value, work_item: cf_work_item, custom_field: select_field,
        custom_field_select_option: select_option_2)

      create(:work_item_select_field_value, work_item: cf_work_item, custom_field: multi_select_field,
        custom_field_select_option: multi_select_option_3)
      create(:work_item_select_field_value, work_item: cf_work_item, custom_field: multi_select_field,
        custom_field_select_option: multi_select_option_1)
    end

    describe 'GET /projects/:id/-/work_items/:work_item_iid' do
      subject(:custom_fields_json) do
        get api("/projects/#{cf_project.id}/-/work_items/#{cf_work_item.iid}", cf_user),
          params: { features: 'custom_fields' }

        json_response.dig('features', 'custom_fields', 'custom_field_values')
      end

      it 'returns the custom field values, matching GraphQL ordering and value types', :aggregate_failures do
        custom_fields_json

        expect(response).to have_gitlab_http_status(:ok)
        expect(custom_fields_json).to match(
          [
            {
              'custom_field' => a_hash_including('id' => select_field.id, 'field_type' => 'single_select'),
              'selected_options' => [a_hash_including('id' => select_option_2.id, 'value' => select_option_2.value)]
            },
            {
              'custom_field' => a_hash_including('id' => number_field.id, 'field_type' => 'number'),
              'value' => 10
            },
            {
              'custom_field' => a_hash_including('id' => date_field.id, 'field_type' => 'date'),
              'value' => nil
            },
            {
              'custom_field' => a_hash_including('id' => text_field.id, 'field_type' => 'text'),
              'value' => 'text value'
            },
            {
              'custom_field' => a_hash_including('id' => multi_select_field.id, 'field_type' => 'multi_select'),
              'selected_options' => contain_exactly(
                a_hash_including('id' => multi_select_option_1.id),
                a_hash_including('id' => multi_select_option_3.id)
              )
            }
          ]
        )
      end

      it 'exposes custom field metadata at parity with the GraphQL CustomField type', :aggregate_failures do
        custom_fields_json

        text_field_json = custom_fields_json.find { |v| v.dig('custom_field', 'id') == text_field.id }['custom_field']

        expect(text_field_json).to include(
          'id' => text_field.id,
          'name' => text_field.name,
          'field_type' => 'text',
          'active' => true,
          'created_at' => text_field.created_at.iso8601(3),
          'updated_at' => text_field.updated_at.iso8601(3),
          'work_item_types' => [a_hash_including('id' => issue_type.id, 'name' => issue_type.name)]
        )
        expect(text_field_json).not_to have_key('select_options')
      end

      it 'omits the widget when the licensed feature is unavailable' do
        stub_licensed_features(custom_fields: false)

        get api("/projects/#{cf_project.id}/-/work_items/#{cf_work_item.iid}", cf_user),
          params: { features: 'custom_fields' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.fetch('features')).not_to have_key('custom_fields')
      end

      it 'omits the widget when not requested' do
        get api("/projects/#{cf_project.id}/-/work_items/#{cf_work_item.iid}", cf_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).not_to have_key('features')
      end

      it 'returns 404 when the user cannot read the work item' do
        outsider = create(:user)

        get api("/projects/#{cf_project.id}/-/work_items/#{cf_work_item.iid}", outsider),
          params: { features: 'custom_fields' }

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'does not issue more queries as the number of custom fields grows', :aggregate_failures do
        path = api("/projects/#{cf_project.id}/-/work_items/#{cf_work_item.iid}", cf_user)

        get path, params: { features: 'custom_fields' }
        expect(response).to have_gitlab_http_status(:ok)

        control = ActiveRecord::QueryRecorder.new do
          get path, params: { features: 'custom_fields' }
        end

        create_list(:custom_field, 3, namespace: group, field_type: 'text', work_item_types: [issue_type])

        expect do
          get path, params: { features: 'custom_fields' }
        end.not_to exceed_query_limit(control)
      end
    end

    describe 'GET /projects/:id/-/work_items' do
      it 'returns custom field values per work item', :aggregate_failures do
        get api("/projects/#{cf_project.id}/-/work_items", cf_user), params: { features: 'custom_fields' }

        expect(response).to have_gitlab_http_status(:ok)

        work_item_json = json_response.find { |wi| wi['id'] == cf_work_item.id }
        values = work_item_json.dig('features', 'custom_fields', 'custom_field_values')

        expect(values).to include(
          a_hash_including(
            'custom_field' => a_hash_including('id' => text_field.id),
            'value' => 'text value'
          )
        )
      end

      it 'avoids N+1 queries when serializing custom fields for multiple work items', :aggregate_failures do
        path = api("/projects/#{cf_project.id}/-/work_items", cf_user)
        request_params = { features: 'custom_fields' }

        extra_field = create(:custom_field, namespace: group, field_type: 'text', work_item_types: [issue_type])

        get path, params: request_params
        expect(response).to have_gitlab_http_status(:ok)

        control = ActiveRecord::QueryRecorder.new do
          get path, params: request_params
        end

        extra_work_items = create_list(:work_item, 3, work_item_type: issue_type, project: cf_project)
        extra_work_items.each do |work_item|
          create(:work_item_text_field_value, work_item: work_item, custom_field: text_field, value: 'more text')
          create(:work_item_text_field_value, work_item: work_item, custom_field: extra_field, value: 'field 2')
        end

        expect do
          get path, params: request_params
        end.not_to exceed_query_limit(control)

        expect(response).to have_gitlab_http_status(:ok)
        extra_work_item = extra_work_items.first
        extra_values = work_item_json_for(extra_work_item).dig('features', 'custom_fields', 'custom_field_values')
        expect(extra_values).to include(
          a_hash_including(
            'custom_field' => a_hash_including('id' => text_field.id),
            'value' => 'more text'
          ),
          a_hash_including(
            'custom_field' => a_hash_including('id' => extra_field.id),
            'value' => 'field 2'
          )
        )
      end
    end
  end
end
