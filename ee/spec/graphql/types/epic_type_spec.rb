# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Epic'], feature_category: :portfolio_management do
  include GraphqlHelpers
  include_context 'includes EpicAggregate constants'

  before do
    stub_licensed_features(epics: true)
  end

  let_it_be(:group) { create(:group) }

  let(:fields) do
    %i[
      id iid work_item_id title titleHtml description descriptionHtml confidential state group
      parent author labels start_date start_date_is_fixed start_date_fixed
      start_date_from_milestones start_date_from_inherited_source due_date
      due_date_is_fixed due_date_fixed due_date_from_milestones due_date_from_inherited_source
      closed_at created_at updated_at children has_children has_children_within_timeframe has_issues
      has_parent web_path web_url relation_path reference issues user_permissions
      notes discussions relative_position subscribed participants
      descendant_counts descendant_weight_sum upvotes downvotes
      user_notes_count user_discussions_count health_status current_user_todos
      award_emoji events ancestors color text_color blocked blocking_count
      blocked_by_count blocked_by_epics default_project_for_issue_creation
      commenters name linked_work_items
    ]
  end

  it { expect(described_class.interfaces).to include(Types::CurrentUserTodos) }

  it { expect(described_class.interfaces).to include(Types::TodoableInterface) }

  it { expect(described_class).to expose_permissions_using(Types::PermissionTypes::Epic) }

  it { expect(described_class.graphql_name).to eq('Epic') }

  it { expect(described_class).to require_graphql_authorizations(:read_epic) }

  it { expect(described_class).to have_graphql_fields(fields) }

  it { expect(described_class).to have_graphql_field(:subscribed, complexity: 5) }

  it { expect(described_class).to have_graphql_field(:participants, complexity: 5) }

  it { expect(described_class).to have_graphql_field(:blocking_count, complexity: 5) }

  it { expect(described_class).to have_graphql_field(:blocked_by_epics, complexity: 5) }

  it { expect(described_class).to have_graphql_field(:award_emoji) }

  it { expect(described_class).to have_graphql_field(:linked_work_items, complexity: 5) }

  context 'for work_item_id' do
    let_it_be(:epic) { create(:epic, group: group) }

    it 'resolves correct work item ID' do
      expect(resolve_field(:work_item_id, epic)).to eq(epic.work_item.to_gid)
    end
  end

  describe 'relation_path' do
    let_it_be(:parent_epic) { create(:epic, group: group) }

    context 'when the epic has a parent' do
      shared_examples 'relation path when epic has a parent' do
        it 'returns the correct URL' do
          expect(resolve_field(:relation_path, object)).to eq(
            "#{::Gitlab::Routing.url_helpers.group_epic_path(object.parent.group, object.parent.iid)}/links/" \
              "#{object.id}"
          )
        end
      end

      context 'when epic is in same group' do
        let_it_be(:object) { create(:epic, parent: parent_epic, group: group) }

        it_behaves_like 'relation path when epic has a parent'
      end

      context 'when epic is in a subgroup' do
        let_it_be(:subgroup) { create(:group, parent: group) }
        let_it_be(:object) { create(:epic, parent: parent_epic, group: subgroup) }

        it_behaves_like 'relation path when epic has a parent'
      end

      context 'when epic is in different group hierarchy' do
        let_it_be(:group2) { create(:group) }
        let_it_be(:object) { create(:epic, parent: parent_epic, group: group2) }

        it_behaves_like 'relation path when epic has a parent'
      end
    end

    context 'when the epic has no parent' do
      let_it_be(:object) { create(:epic, group: group) }

      it 'returns the correct URL' do
        expect(resolve_field(:relation_path, object)).to be_nil
      end
    end
  end

  describe 'healthStatus' do
    let_it_be(:object) { create(:epic) }

    it 'uses lazy calculation' do
      expect_next_instance_of(
        Gitlab::Graphql::Aggregations::Epics::LazyEpicAggregate,
        anything,
        object.id,
        HEALTH_STATUS_SUM
      ) { nil }

      resolved_field = resolve_field(:health_status, object)

      expect(resolved_field).to be_kind_of(GraphQL::Execution::Lazy)
    end
  end

  describe 'date attributes read from work item' do
    context 'with fixed dates' do
      let_it_be(:epic) { create(:epic, group: group) }
      let_it_be(:work_item) { epic.work_item }
      let_it_be(:dates_source) do
        create(:work_items_dates_source,
          :fixed,
          work_item: work_item,
          start_date: Date.new(2010, 1, 1),
          due_date: Date.new(2010, 1, 3)
        )
      end

      it 'reads dates from work item', :aggregate_failures do
        expect(resolve_field(:start_date, epic)).to eq(work_item.start_date)
        expect(resolve_field(:start_date, epic)).to eq(Date.new(2010, 1, 1))

        expect(resolve_field(:start_date_is_fixed, epic)).to be(true)
        expect(resolve_field(:start_date_fixed, epic)).to eq(Date.new(2010, 1, 1))

        expect(resolve_field(:due_date, epic)).to eq(work_item.due_date)
        expect(resolve_field(:due_date, epic)).to eq(Date.new(2010, 1, 3))

        expect(resolve_field(:due_date_is_fixed, epic)).to be(true)
        expect(resolve_field(:due_date_fixed, epic)).to eq(Date.new(2010, 1, 3))
      end
    end

    context 'with inherited dates' do
      let_it_be(:epic) { create(:epic, group: group) }
      let_it_be(:work_item) { epic.work_item }
      let_it_be(:dates_source) do
        create(:work_items_dates_source,
          work_item: work_item,
          start_date: Date.new(2010, 1, 2),
          due_date: Date.new(2010, 1, 4)
        )
      end

      it 'reads the dates from the work item', :aggregate_failures do
        expect(resolve_field(:start_date_is_fixed, epic)).to be(false)
        expect(resolve_field(:start_date, epic)).to eq(Date.new(2010, 1, 2))

        expect(resolve_field(:due_date_is_fixed, epic)).to be(false)
        expect(resolve_field(:due_date, epic)).to eq(Date.new(2010, 1, 4))
      end
    end
  end
end
