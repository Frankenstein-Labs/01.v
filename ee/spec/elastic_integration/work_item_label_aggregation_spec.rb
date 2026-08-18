# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'WorkItem label filter with type aggregations', :elastic, :sidekiq_inline,
  feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:label) { create(:group_label, group: group, title: 'bug') }

  let_it_be(:issue_type) { WorkItems::TypesFramework::Provider.new.find_by_base_type(:issue) }
  let_it_be(:task_type) { WorkItems::TypesFramework::Provider.new.find_by_base_type(:task) }

  let_it_be(:issue_with_label) do
    create(:work_item, :issue, project: project, title: 'search term', labels: [label])
  end

  let_it_be(:task_without_label) do
    create(:work_item, :task, project: project, title: 'search term')
  end

  let(:helper) { Search::Elastic::Helper.default }
  let(:client) { helper.client }

  before_all do
    project.add_developer(user)
  end

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

    Elastic::ProcessBookkeepingService.track!(issue_with_label, task_without_label)
    ensure_elasticsearch_index!
  end

  describe 'type aggregations with label filters' do
    let(:query_builder) { ::Search::Elastic::WorkItemQueryBuilder }
    let(:base_options) do
      {
        current_user: user,
        project_ids: [project.id],
        group_ids: [group.id],
        search_level: :group,
        aggregation: true,
        public_and_internal_projects: false,
        index_name: ::Search::Elastic::References::WorkItem.index
      }
    end

    it 'returns counts for all work item types without label filter' do
      options = base_options
      query_hash = query_builder.build(query: 'search term', options: options)

      response = client.search(index: options[:index_name], body: query_hash)

      type_buckets = response.dig('aggregations', 'work_item_type_ids', 'buckets')
      type_counts = type_buckets.to_h { |bucket| [bucket['key'], bucket['doc_count']] }

      expect(type_counts[issue_type.id]).to eq(1)
      expect(type_counts[task_type.id]).to eq(1)
    end

    it 'returns counts only for labeled work items when label filter is applied' do
      options = base_options.merge(label_name: [label.title])
      query_hash = query_builder.build(query: 'search term', options: options)

      response = client.search(index: options[:index_name], body: query_hash)

      type_buckets = response.dig('aggregations', 'work_item_type_ids', 'buckets')
      type_counts = type_buckets.to_h { |bucket| [bucket['key'], bucket['doc_count']] }

      # Only the issue (which has the label) should appear in type counts
      expect(type_counts[issue_type.id]).to eq(1)
      expect(type_counts[task_type.id]).to be_nil
    end

    it 'returns zero counts when filtering by a label that no work items have' do
      non_existent_label = create(:group_label, group: group, title: 'nonexistent')
      options = base_options.merge(label_name: [non_existent_label.title])
      query_hash = query_builder.build(query: 'search term', options: options)

      response = client.search(index: options[:index_name], body: query_hash)

      type_buckets = response.dig('aggregations', 'work_item_type_ids', 'buckets')

      expect(type_buckets).to be_empty
    end

    context 'with multiple labels' do
      let_it_be(:feature_label) { create(:group_label, group: group, title: 'feature') }
      let_it_be(:issue_with_both_labels) do
        create(:work_item, :issue, project: project, title: 'search term', labels: [label, feature_label])
      end

      before do
        Elastic::ProcessBookkeepingService.track!(issue_with_both_labels)
        ensure_elasticsearch_index!
      end

      it 'applies AND logic for multiple label filters' do
        options = base_options.merge(label_name: [label.title, feature_label.title])
        query_hash = query_builder.build(query: 'search term', options: options)

        response = client.search(index: options[:index_name], body: query_hash)

        type_buckets = response.dig('aggregations', 'work_item_type_ids', 'buckets')
        type_counts = type_buckets.to_h { |bucket| [bucket['key'], bucket['doc_count']] }

        # Only the issue with BOTH labels should match (AND logic)
        expect(type_counts[issue_type.id]).to eq(1)
        expect(type_counts[task_type.id]).to be_nil
      end
    end
  end
end
