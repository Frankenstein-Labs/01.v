# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Status filters', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:group_2) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:project_2) { create(:project, group: group_2) }

  let_it_be(:group_label) { create(:group_label, group: group) }
  let(:board) { create(:board, resource_parent: resource_parent) }
  let(:label_list) { create(:list, board: board, label: group_label) }

  let_it_be(:issue_work_item_type) { build(:work_item_system_defined_type, :issue) }
  let_it_be(:task_work_item_type) { build(:work_item_system_defined_type, :task) }

  let_it_be(:work_item_1) { create(:work_item, :issue, project: project, labels: [group_label]) }
  let_it_be(:work_item_2) { create(:work_item, :task, project: project, labels: [group_label]) }
  let_it_be(:work_item_3) { create(:work_item, :task, project: project, labels: [group_label]) }
  let_it_be(:work_item_4) { create(:work_item, :task, project: project, labels: [group_label]) }
  let_it_be(:work_item_5) { create(:work_item, :issue, project: project_2) }

  let_it_be(:current_user) { create(:user, guest_of: [group, group_2]) }

  let(:expected_work_items) { [work_item_1, work_item_2, work_item_3] }
  let(:expected_unfiltered_work_items) { [work_item_1, work_item_2, work_item_3, work_item_4] }
  let(:expected_work_items_across_namespaces) { [work_item_1, work_item_2, work_item_3, work_item_5] }

  before do
    stub_licensed_features(work_item_status: true)
  end

  shared_examples 'a filtered list' do
    it 'filters by status argument', :aggregate_failures do
      post_graphql(query, current_user: current_user)

      model_ids = items.map { |item| GlobalID.parse(item['id']).model_id.to_i }

      expect(model_ids.size).to eq(expected_work_items.size)
      expect(model_ids).to match_array(expected_work_items.map(&:id))
    end
  end

  shared_examples 'an unfiltered list' do
    it 'does not filter by status argument' do
      post_graphql(query, current_user: current_user)

      model_ids = items.map { |item| GlobalID.parse(item['id']).model_id.to_i }

      expect(model_ids.size).to eq(expected_unfiltered_work_items.size)
      expect(model_ids).to match_array(expected_unfiltered_work_items.map(&:id))
    end
  end

  shared_examples 'supports filtering by status ID' do
    let(:params) { { status: { id: status.to_global_id } } }

    context 'when filtering by valid ID' do
      it_behaves_like 'a filtered list'
    end

    context 'when filtering by invalid ID' do
      let(:params) { { status: { id: "gid://gitlab/WorkItems::Statuses::SystemDefined::Status/999" } } }

      it 'returns an error' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to contain_exactly(
          hash_including('message' => "Status doesn't exist.")
        )
      end
    end

    context 'when status param is not given' do
      let(:params) { {} }

      it_behaves_like 'an unfiltered list'
    end
  end

  shared_examples 'supports filtering by status name' do
    let(:params) { { status: { name: status.name } } }

    context 'when filtering by valid name' do
      it_behaves_like 'a filtered list'
    end

    context 'when filtering by invalid name' do
      let(:params) { { status: { name: 'invalid' } } }

      it 'returns an empty result' do
        post_graphql(query, current_user: current_user)

        expect_graphql_errors_to_be_empty

        model_ids = items.map { |item| GlobalID.parse(item['id']).model_id.to_i }

        expect(model_ids).to be_empty
      end
    end
  end

  shared_examples 'supports filtering by status name across namespaces' do
    let(:params) { { status: { name: status.name } } }

    context 'when filtering by valid name' do
      it 'filters by status argument' do
        post_graphql(query, current_user: current_user)

        model_ids = items.map { |item| GlobalID.parse(item['id']).model_id.to_i }

        expect(model_ids.size).to eq(expected_work_items_across_namespaces.size)
        expect(model_ids).to match_array(expected_work_items_across_namespaces.map(&:id))
      end
    end

    context 'when filtering by invalid name' do
      let(:params) { { status: { name: 'invalid' } } }

      it 'returns an empty result' do
        post_graphql(query, current_user: current_user)

        expect_graphql_errors_to_be_empty

        model_ids = items.map { |item| GlobalID.parse(item['id']).model_id.to_i }

        expect(model_ids).to be_empty
      end
    end
  end

  shared_examples 'does not support filtering by both status ID and name' do
    let(:params) { { status: { id: status.to_global_id, name: status.name } } }

    it 'returns an error' do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to contain_exactly(
        hash_including('message' => 'Only one of [id, name] arguments is allowed at the same time.')
      )
    end
  end

  shared_examples 'filtering by status' do
    context 'for work items' do
      let(:query) do
        graphql_query_for(resource_parent.class.name.downcase, { full_path: resource_parent.full_path },
          query_nodes(:work_items, :id, args: params)
        )
      end

      let(:items) { graphql_data.dig(resource_parent.class.name.downcase, 'workItems', 'nodes') }

      context 'when querying group.workItems' do
        let_it_be(:resource_parent) { group }

        before do
          params[:include_descendants] = true
        end

        it_behaves_like 'supports filtering by status ID'
        it_behaves_like 'supports filtering by status name'
        it_behaves_like 'does not support filtering by both status ID and name'
      end

      context 'when querying project.workItems' do
        let_it_be(:resource_parent) { project }

        it_behaves_like 'supports filtering by status ID'
        it_behaves_like 'supports filtering by status name'
        it_behaves_like 'does not support filtering by both status ID and name'
      end
    end

    # Temporarily legacy issues need to be filterable by status for
    # the legacy issue list and legacy issue boards.
    context 'for issue lists' do
      let(:query) do
        graphql_query_for(resource_parent.class.name.downcase, { full_path: resource_parent.full_path },
          query_nodes(:issues, :id, args: params)
        )
      end

      let(:items) { graphql_data.dig(resource_parent.class.name.downcase, 'issues', 'nodes') }

      context 'when querying group.issues' do
        let_it_be(:resource_parent) { group }

        it_behaves_like 'supports filtering by status ID'
        it_behaves_like 'supports filtering by status name'
        it_behaves_like 'does not support filtering by both status ID and name'
      end

      context 'when querying project.issues' do
        let_it_be(:resource_parent) { project }

        it_behaves_like 'supports filtering by status ID'
        it_behaves_like 'supports filtering by status name'
        it_behaves_like 'does not support filtering by both status ID and name'
      end

      context 'when querying issues' do
        let(:query) { graphql_query_for(:issues, params) }
        let(:items) { graphql_data.dig('issues', 'nodes') }

        it_behaves_like 'supports filtering by status name across namespaces'
      end
    end

    context 'for issue boards' do
      let(:query) do
        graphql_query_for(resource_parent.class.name.downcase, { full_path: resource_parent.full_path },
          <<~BOARDS
            boards(first: 1) {
              nodes {
                lists(id: "#{label_list.to_global_id}") {
                  nodes {
                    issues(#{attributes_to_graphql(filters: params)}) {
                      nodes {
                        id
                      }
                    }
                  }
                }
              }
            }
          BOARDS
        )
      end

      let(:items) do
        graphql_data.dig(resource_parent.class.name.downcase, 'boards', 'nodes')[0]
          .dig('lists', 'nodes')[0]
          .dig('issues', 'nodes')
      end

      context 'when querying group.board.lists.issues' do
        let_it_be(:resource_parent) { group }

        it_behaves_like 'supports filtering by status ID'
        it_behaves_like 'supports filtering by status name'
        it_behaves_like 'does not support filtering by both status ID and name'
      end

      context 'when querying project.board.lists.issues' do
        let_it_be(:resource_parent) { project }

        it_behaves_like 'supports filtering by status ID'
        it_behaves_like 'supports filtering by status name'
        it_behaves_like 'does not support filtering by both status ID and name'
      end
    end
  end

  context 'with system defined statuses' do
    let_it_be(:current_status_1) { create(:work_item_current_status, work_item: work_item_1) }
    let_it_be(:current_status_2) { create(:work_item_current_status, work_item: work_item_2) }
    let_it_be(:current_status_4) do
      create(:work_item_current_status, work_item: work_item_4, system_defined_status_id: 2)
    end

    let_it_be(:status) { build(:work_item_system_defined_status, :to_do) }

    it_behaves_like 'filtering by status'
  end

  context 'with custom statuses' do
    let_it_be(:current_status_1) { create(:work_item_current_status, work_item: work_item_1) }

    let_it_be(:lifecycle) do
      create(:work_item_custom_lifecycle, namespace: group).tap do |lifecycle|
        # Skip validations so that we can skip the license check.
        # We can't stub licensed features for let_it_be blocks.
        build(:work_item_type_custom_lifecycle,
          namespace: group,
          work_item_type: issue_work_item_type,
          lifecycle: lifecycle
        ).save!(validate: false)

        build(:work_item_type_custom_lifecycle,
          namespace: group,
          work_item_type: task_work_item_type,
          lifecycle: lifecycle
        ).save!(validate: false)
      end
    end

    let_it_be(:lifecycle_2) do
      create(:work_item_custom_lifecycle, namespace: group_2).tap do |lifecycle|
        # Skip validations so that we can skip the license check.
        # We can't stub licensed features for let_it_be blocks.
        build(:work_item_type_custom_lifecycle,
          namespace: group_2,
          work_item_type: issue_work_item_type,
          lifecycle: lifecycle
        ).save!(validate: false)

        build(:work_item_type_custom_lifecycle,
          namespace: group_2,
          work_item_type: task_work_item_type,
          lifecycle: lifecycle
        ).save!(validate: false)
      end
    end

    let_it_be(:status) { lifecycle.default_open_status }

    let_it_be(:current_status_2) do
      create(:work_item_current_status, :custom, work_item: work_item_2, custom_status: status)
    end

    let_it_be(:current_status_4) do
      create(:work_item_current_status, :custom, work_item: work_item_4, custom_status: lifecycle.default_closed_status)
    end

    it_behaves_like 'filtering by status'

    # rubocop:disable RSpec/MultipleMemoizedHelpers -- we need additional memoization to fully test all paths
    context 'with status mappings' do
      let_it_be(:old_status) do
        create(:work_item_custom_status, :without_conversion_mapping, namespace: group).tap do |status|
          create(:work_item_custom_lifecycle_status, lifecycle: lifecycle, status: status)
        end
      end

      let_it_be(:new_status) do
        create(:work_item_custom_status, :without_conversion_mapping, namespace: group).tap do |status|
          create(:work_item_custom_lifecycle_status, lifecycle: lifecycle, status: status)
        end
      end

      let_it_be(:another_status) do
        create(:work_item_custom_status, :without_conversion_mapping, namespace: group).tap do |status|
          create(:work_item_custom_lifecycle_status, lifecycle: lifecycle, status: status)
        end
      end

      let_it_be(:converted_custom_status) do
        create(:work_item_custom_status, :in_progress, namespace: group).tap do |status|
          create(:work_item_custom_lifecycle_status, lifecycle: lifecycle, status: status)
        end
      end

      let_it_be(:work_item_issue_with_new_status) do
        create(:work_item, :issue, project: project, labels: [group_label]).tap do |wi|
          create(:work_item_current_status, :custom, work_item: wi, custom_status: new_status, updated_at: 1.day.ago)
        end
      end

      let_it_be(:work_item_issue_old) do
        create(:work_item, :issue, project: project, labels: [group_label]).tap do |wi|
          create(:work_item_current_status, :custom, work_item: wi, custom_status: old_status, updated_at: 1.day.ago)
        end
      end

      let_it_be(:work_item_issue_older) do
        create(:work_item, :issue, project: project, labels: [group_label]).tap do |wi|
          create(:work_item_current_status, :custom, work_item: wi, custom_status: old_status, updated_at: 5.days.ago)
        end
      end

      let_it_be(:work_item_task_recent) do
        create(:work_item, :task, project: project, labels: [group_label]).tap do |wi|
          create(:work_item_current_status, :custom, work_item: wi, custom_status: old_status, updated_at: 2.hours.ago)
        end
      end

      let_it_be(:work_item_issue_with_another_status) do
        create(:work_item, :issue, project: project, labels: [group_label]).tap do |wi|
          create(:work_item_current_status, :custom, work_item: wi, custom_status: another_status,
            updated_at: 1.day.ago)
        end
      end

      let_it_be(:work_item_issue_with_system_status) do
        create(:work_item, :issue, project: project, labels: [group_label]).tap do |wi|
          # Skip validations since we are simulating an old record
          # when the namespace still used the system defined lifecycle
          build(:work_item_current_status,
            work_item: wi,
            system_defined_status_id: converted_custom_status.converted_from_system_defined_status_identifier,
            updated_at: 2.days.ago
          ).save!(validate: false)
        end
      end

      let(:status) { new_status }

      let(:expected_unfiltered_work_items) do
        [work_item_1, work_item_2, work_item_3, work_item_4, work_item_issue_with_new_status,
          work_item_issue_old, work_item_issue_older, work_item_task_recent,
          work_item_issue_with_another_status, work_item_issue_with_system_status]
      end

      let(:expected_work_items_across_namespaces) { expected_work_items }

      context 'when unbounded mapping for both work item types is present' do
        before_all do
          [issue_work_item_type, task_work_item_type].each do |wit|
            create(:work_item_custom_status_mapping,
              namespace: group,
              work_item_type: wit,
              old_status: old_status,
              new_status: new_status,
              valid_from: nil,
              valid_until: nil
            )
          end
        end

        let(:expected_work_items) do
          [work_item_issue_with_new_status, work_item_issue_old, work_item_issue_older,
            work_item_task_recent]
        end

        it_behaves_like 'filtering by status'
      end

      context 'when valid_until mapping for issues is present' do
        before_all do
          create(:work_item_custom_status_mapping,
            namespace: group,
            work_item_type: issue_work_item_type,
            old_status: old_status,
            new_status: new_status,
            valid_from: nil,
            valid_until: 3.days.ago
          )
        end

        let(:expected_work_items) { [work_item_issue_with_new_status, work_item_issue_older] }

        it_behaves_like 'filtering by status'
      end

      context 'when two mappings for issues are present with different time constraints' do
        before_all do
          create(:work_item_custom_status_mapping,
            namespace: group,
            work_item_type: issue_work_item_type,
            old_status: old_status,
            new_status: new_status,
            valid_from: nil,
            valid_until: 3.days.ago
          )
          create(:work_item_custom_status_mapping,
            namespace: group,
            work_item_type: issue_work_item_type,
            old_status: old_status,
            new_status: new_status,
            valid_from: 2.days.ago,
            valid_until: nil
          )
        end

        let(:expected_work_items) { [work_item_issue_with_new_status, work_item_issue_old, work_item_issue_older] }

        it_behaves_like 'filtering by status'
      end

      context 'when two mappings for issues are present to different statuses' do
        before_all do
          create(:work_item_custom_status_mapping,
            namespace: group,
            work_item_type: issue_work_item_type,
            old_status: old_status,
            new_status: new_status,
            valid_from: nil,
            valid_until: nil
          )
          create(:work_item_custom_status_mapping,
            namespace: group,
            work_item_type: issue_work_item_type,
            old_status: another_status,
            new_status: new_status,
            valid_from: nil,
            valid_until: nil
          )
        end

        let(:expected_work_items) do
          [work_item_issue_with_new_status, work_item_issue_old, work_item_issue_older,
            work_item_issue_with_another_status]
        end

        it_behaves_like 'filtering by status'
      end

      context 'when mapping for issues exists for converted system-defined status' do
        let(:valid_from) { nil }
        let(:valid_until) { nil }
        let!(:mapping) do
          create(:work_item_custom_status_mapping,
            namespace: group,
            work_item_type: issue_work_item_type,
            old_status: converted_custom_status,
            new_status: new_status,
            valid_from: valid_from,
            valid_until: valid_until
          )
        end

        let(:expected_work_items) { [work_item_issue_with_new_status, work_item_issue_with_system_status] }

        it_behaves_like 'filtering by status'

        context 'when filtering for the converted status while the status still exists for tasks' do
          let_it_be(:work_item_task_with_converted_status) do
            create(:work_item, :task, project: project, labels: [group_label]).tap do |wi|
              create(:work_item_current_status, :custom, work_item: wi, custom_status: converted_custom_status)
            end
          end

          let(:status) { converted_custom_status }
          # work_item_issue_with_system_status must not be included although the current_status data match
          # the direct filter. The exclude condition removes this item from the result.
          let(:expected_work_items) { [work_item_task_with_converted_status] }
          let(:expected_unfiltered_work_items) do
            super() << work_item_task_with_converted_status
          end

          it_behaves_like 'filtering by status'
        end

        context 'with time constraints that include the item with system-defined current status' do
          let(:valid_from) { 3.days.ago }
          let(:valid_until) { 1.day.ago }

          it_behaves_like 'filtering by status'
        end

        context 'with time constraints that exclude the item with system-defined current status' do
          let(:valid_until) { 3.days.ago }
          let(:expected_work_items) { [work_item_issue_with_new_status] }

          it_behaves_like 'filtering by status'
        end
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end
end
