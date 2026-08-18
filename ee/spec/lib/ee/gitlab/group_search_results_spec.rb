# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GroupSearchResults, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }

  subject(:search_results) { described_class.new(user, query, group: group) }

  before_all do
    create(:group_member, group: group, user: user)
    group.add_owner(user)
  end

  before do
    stub_licensed_features(epics: true)
  end

  describe '#epics' do
    context 'when searching' do
      let(:query) { 'foo' }
      let_it_be(:searchable_epic) { create(:epic, title: 'foo', group: group) }
      let_it_be(:another_searchable_epic) { create(:epic, title: 'foo 2', group: group) }
      let_it_be(:another_epic) { create(:epic) }

      it 'finds epics' do
        expect(search_results.objects('epics')).to match_array([searchable_epic, another_searchable_epic])
      end
    end

    context 'when ordering' do
      let(:scope) { 'epics' }
      let(:filters) { {} }

      let_it_be(:old_result) { create(:epic, group: group, title: 'sorted old', created_at: 1.month.ago) }
      let_it_be(:new_result) { create(:epic, group: group, title: 'sorted recent', created_at: 1.day.ago) }
      let_it_be(:very_old_result) { create(:epic, group: group, title: 'sorted very old', created_at: 1.year.ago) }

      let_it_be(:old_updated) { create(:epic, group: group, title: 'updated old', updated_at: 1.month.ago) }
      let_it_be(:new_updated) { create(:epic, group: group, title: 'updated recent', updated_at: 1.day.ago) }
      let_it_be(:very_old_updated) { create(:epic, group: group, title: 'updated very old', updated_at: 1.year.ago) }

      include_examples 'search results sorted' do
        let(:results_created) do
          described_class.new(user, 'sorted', Project.order(:id), group: group, sort: sort, filters: filters)
        end

        let(:results_updated) do
          described_class.new(user, 'updated', Project.order(:id), group: group, sort: sort, filters: filters)
        end
      end
    end
  end

  describe '#work_items' do
    let(:query) { 'foo' }
    let_it_be(:work_item) { create(:work_item, :group_level, namespace: group, title: 'foo work item') }
    let_it_be(:another_work_item) { create(:work_item, :group_level, namespace: group, title: 'foo another') }
    let_it_be(:unrelated_work_item) { create(:work_item, :group_level, title: 'bar') }

    context 'when searching for work items' do
      it 'finds work items matching the query' do
        results = search_results.work_items

        expect(results).to include(work_item, another_work_item)
        expect(results).not_to include(unrelated_work_item)
      end

      it 'includes descendants' do
        subgroup = create(:group, parent: group)
        subgroup_work_item = create(:work_item, :group_level, namespace: subgroup, title: 'foo subgroup')

        results = search_results.work_items

        expect(results).to include(subgroup_work_item)
      end

      it 'excludes ancestors' do
        parent_group = create(:group)
        group.update!(parent: parent_group)
        parent_work_item = create(:work_item, :group_level, namespace: parent_group, title: 'foo parent')

        results = search_results.work_items

        expect(results).not_to include(parent_work_item)
      end

      it 'searches by query using title' do
        results = search_results.work_items

        expect(results.map(&:title)).to all(include('foo'))
      end

      it 'accepts custom finder params' do
        closed_work_item = create(:work_item, :group_level, namespace: group, title: 'foo closed', state: :closed)

        results = search_results.work_items(state: 'closed')

        expect(results).to include(closed_work_item)
        expect(results).not_to include(work_item)
      end
    end

    context 'when applying sort' do
      let(:query) { 'sortable' }
      let_it_be(:old_work_item) do
        create(:work_item, :group_level, namespace: group, title: 'sortable old', created_at: 2.days.ago)
      end

      let_it_be(:new_work_item) do
        create(:work_item, :group_level, namespace: group, title: 'sortable new', created_at: 1.day.ago)
      end

      it 'applies sorting by created_at desc' do
        results_with_sort = described_class.new(user, 'sortable', group: group, sort: 'created_desc')
        sorted_results = results_with_sort.work_items

        expect(sorted_results.to_a).to match_array([new_work_item, old_work_item])
      end

      context 'when sorting by popularity for the work_items scope' do
        let(:scope) { 'work_items' }

        let_it_be(:less_popular_result) do
          create(:work_item, :group_level, namespace: group, title: 'popular less', upvotes_count: 10)
        end

        let_it_be(:popular_result) do
          create(:work_item, :group_level, namespace: group, title: 'popular more', upvotes_count: 100)
        end

        let_it_be(:non_popular_result) do
          create(:work_item, :group_level, namespace: group, title: 'popular non', upvotes_count: 1)
        end

        include_examples 'search results sorted by popularity' do
          let(:results_popular) { described_class.new(user, 'popular', group: group, sort: sort) }
        end
      end
    end
  end
end
