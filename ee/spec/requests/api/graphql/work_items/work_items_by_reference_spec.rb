# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.workItemsByReference (EE)', feature_category: :portfolio_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:public_group) { create(:group, :public, guests: current_user) }
  let_it_be(:private_group) { create(:group, :private) }
  let_it_be(:public_project) { create(:project, :repository, :public, group: public_group) }
  let_it_be(:task) { create(:work_item, :task, project: public_project) }
  let_it_be(:work_item_epic1) { create(:work_item, :epic, namespace: public_group) }
  let_it_be(:work_item_epic2) { create(:work_item, :epic_with_legacy_epic, namespace: public_group) }
  let_it_be(:work_item_epic3) { create(:work_item, :epic, namespace: public_group) }
  let_it_be(:private_work_item_epic) { create(:work_item, :epic, namespace: private_group) }
  let_it_be(:legacy_epic1) { create(:epic, group: public_group) }
  let_it_be(:legacy_epic2) { create(:epic, group: public_group) }
  let_it_be(:legacy_issue1) { create(:issue, project: public_project) }
  let_it_be(:legacy_issue2) { create(:issue, project: public_project) }
  # Ensure support bot user is created so creation doesn't count towards query limit
  # See https://gitlab.com/gitlab-org/gitlab/-/issues/509629
  let_it_be(:support_bot) { create(:support_bot) }

  let(:references) do
    [
      task.to_reference(full: true),
      work_item_epic1.to_reference(full: true),
      Gitlab::UrlBuilder.build(work_item_epic2),
      work_item_url(work_item_epic3), # UrlBuilder creates an /epics/ URL while we also want to test /work_items/ URLs
      private_work_item_epic.to_reference(full: true),
      Gitlab::UrlBuilder.build(legacy_epic1),
      legacy_epic2.to_reference(full: true),
      Gitlab::UrlBuilder.build(legacy_issue1),
      legacy_issue2.to_reference(full: true)
    ]
  end

  before do
    stub_licensed_features(epics: true)
  end

  shared_examples 'response with accessible work items' do
    let(:issue_work_item1) { WorkItem.find(legacy_issue1.id) }
    let(:issue_work_item2) { WorkItem.find(legacy_issue2.id) }

    let(:items) do
      [
        issue_work_item2, issue_work_item1, legacy_epic2.work_item, legacy_epic1.work_item,
        work_item_epic3, work_item_epic2, work_item_epic1, task
      ]
    end

    it_behaves_like 'a working graphql query that returns data' do
      before do
        post_graphql(query, current_user: current_user)
      end
    end

    it 'returns accessible work item' do
      post_graphql(query, current_user: current_user)

      expected_items = items.map { |item| a_graphql_entity_for(item) }
      expect(graphql_data_at('workItemsByReference', 'nodes')).to match(expected_items)
    end

    it 'avoids N+1 queries', :use_sql_query_cache do
      post_graphql(query, current_user: current_user) # warm up

      references1 = [task, work_item_epic1, work_item_epic2].map { |item| item.to_reference(full: true) }
      control_count = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        post_graphql(query(refs: references1), current_user: current_user)
      end

      expect(graphql_data_at('workItemsByReference', 'nodes').size).to eq(3)

      extra_work_items = create_list(:work_item, 3, :epic, namespace: public_group)
      references2 = references1 + extra_work_items.map { |item| item.to_reference(full: true) }

      # Allow threshold for URL determination logic in MR !213411
      expect do
        post_graphql(query(refs: references2), current_user: current_user)
      end.not_to exceed_all_query_limit(control_count).with_threshold(3)

      expect(graphql_data_at('workItemsByReference', 'nodes').size).to eq(6)
    end

    context 'with access to private group' do
      let(:items) do
        [
          issue_work_item2, issue_work_item1, legacy_epic2.work_item, legacy_epic1.work_item,
          private_work_item_epic, work_item_epic3, work_item_epic2, work_item_epic1, task
        ]
      end

      before_all do
        private_group.add_guest(current_user)
      end

      it 'returns accessible work item' do
        post_graphql(query, current_user: current_user)

        expected_items = items.map { |item| a_graphql_entity_for(item) }
        expect(graphql_data_at('workItemsByReference', 'nodes')).to match(expected_items)
      end
    end
  end

  context 'when context is a project' do
    let(:path) { public_project.full_path }

    it_behaves_like 'response with accessible work items'
  end

  context 'when context is a group' do
    let(:path) { public_group.full_path }

    it_behaves_like 'response with accessible work items'
  end

  def query(namespace_path: path, refs: references)
    fields = <<~GRAPHQL
      nodes {
        id
        title
      }
    GRAPHQL

    graphql_query_for('workItemsByReference', { contextNamespacePath: namespace_path, refs: refs }, fields)
  end
end
