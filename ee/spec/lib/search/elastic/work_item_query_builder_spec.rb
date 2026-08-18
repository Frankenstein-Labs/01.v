# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::WorkItemQueryBuilder, :elastic_helpers, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, developers: user) }

  let(:work_item_type) { FactoryBot.build(:work_item_system_defined_type, :epic) }
  let(:base_options) do
    {
      current_user: user,
      project_ids: project_ids,
      group_ids: [],
      klass: Issue, # For rendering the UI
      index_name: ::Search::Elastic::References::WorkItem.index,
      not_work_item_type_ids: [work_item_type.id],
      public_and_internal_projects: false,
      search_level: :global,
      related_ids: [1]
    }
  end

  let(:query) { 'foo' }
  let(:project_ids) { [project.id] }
  let(:options) { base_options }

  subject(:build) { described_class.build(query: query, options: options) }

  it 'contains all expected filters' do
    assert_names_in_query(build, with: %w[
      work_item:multi_match:and:search_terms
      work_item:multi_match_phrase:search_terms
      filters:permissions:global:project_visibility_level:public_and_internal
      filters:not_hidden
      filters:not_work_item_type_ids
      filters:non_archived
      filters:confidentiality:projects:non_confidential
      filters:confidentiality:projects:confidential
      filters:confidentiality:projects:confidential:as_author
      filters:confidentiality:projects:confidential:as_assignee
      filters:confidentiality:projects:private:project:member
    ])
  end

  describe 'query' do
    context 'when query is an iid' do
      let(:query) { '#1' }

      it 'returns the expected query' do
        assert_names_in_query(build,
          with: %w[work_item:related:iid doc:is_a:work_item],
          without: %w[work_item:multi_match:and:search_terms
            work_item:multi_match_phrase:search_terms work_item:related:ids])
      end
    end

    context 'when query is text' do
      it 'returns the expected query' do
        assert_names_in_query(build,
          with: %w[work_item:multi_match:and:search_terms work_item:multi_match_phrase:search_terms],
          without: %w[work_item:match:search_terms])
      end

      describe 'related id query' do
        context 'for global search' do
          context 'when on saas', :saas do
            it 'does not contain work_item:related:ids in query' do
              assert_names_in_query(build, without: %w[work_item:related:ids])
            end
          end

          context 'when not on saas' do
            it 'contains work_item:related:ids in query' do
              assert_names_in_query(build, with: %w[work_item:related:ids])
            end
          end
        end

        context 'for group search' do
          let(:options) { base_options.merge(search_level: :group, group_ids: [1], project_ids: [1]) }

          it 'contains work_item:related:ids in query' do
            assert_names_in_query(build, with: %w[work_item:related:ids])
          end
        end

        context 'for project search' do
          let(:options) { base_options.merge(search_level: :project, group_ids: [], project_ids: [1]) }

          it 'contains work_item:related:ids in query' do
            assert_names_in_query(build, with: %w[work_item:related:ids])
          end
        end

        context 'when options[:related_ids] is not sent' do
          let(:options) do
            base_options.tap { |hash| hash.delete(:related_ids) }
          end

          it 'returns the expected query' do
            assert_names_in_query(build,
              with: %w[work_item:multi_match:and:search_terms work_item:multi_match_phrase:search_terms],
              without: %w[work_item:match:search_terms work_item:related:ids])
          end
        end
      end

      context 'when advanced query syntax is used' do
        let(:query) { 'foo -default' }

        it 'returns the expected query' do
          assert_names_in_query(build,
            with: %w[work_item:match:search_terms],
            without: %w[work_item:multi_match:and:search_terms
              work_item:multi_match_phrase:search_terms])
        end
      end
    end
  end

  describe 'fields' do
    it 'defaults to iid (heavily boosted), title, and description' do
      assert_fields_in_query(build, with: %w[iid^50 title^2 description])
    end

    context 'when fields option is provided' do
      let(:options) { base_options.merge(fields: ['title']) }

      it 'uses the provided fields' do
        assert_fields_in_query(build, with: %w[title], without: %w[iid^50 title^2 description])
      end
    end
  end

  describe 'filters' do
    let_it_be(:group) { create(:group) }
    let_it_be(:private_project) { create(:project, :private, group: group) }
    let_it_be(:authorized_project) { create(:project, developers: [user], group: group) }
    let_it_be(:label) { create(:label, project: authorized_project, title: 'My Label') }
    let(:project_ids) { [authorized_project.id, private_project.id] }

    it_behaves_like 'a query filtered by archived'
    it_behaves_like 'a query filtered by hidden'
    it_behaves_like 'a query filtered by state'

    it_behaves_like 'a query filtered by confidentiality' do
      let(:query_name_project_membership) { 'filters:confidentiality:projects:private:project:member' }
    end

    it_behaves_like 'a query filtered by author'
    it_behaves_like 'a query filtered by labels'
    it_behaves_like 'a query filtered by project authorization'

    context 'when current_user is nil' do
      let(:options) { base_options.merge(current_user: nil) }

      it 'restricts the visibility filter to public projects only' do
        assert_names_in_query(build,
          with: %w[filters:permissions:global:project_visibility_level:public],
          without: %w[filters:permissions:global:project_visibility_level:public_and_internal])
      end
    end

    context 'with milestones' do
      let_it_be(:milestone) { create(:milestone, project: authorized_project) }

      it 'does not apply milestone filters by default' do
        assert_names_in_query(build,
          without: %w[
            filters:milestone_title
            filters:not_milestone_title
            filters:none_milestones
            filters:any_milestones
          ])
      end

      context 'when milestone_title option is provided' do
        let(:options) { base_options.merge(milestone_title: milestone.title) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:milestone_title])
        end
      end

      context 'when not_milestone_title option is provided' do
        let(:options) { base_options.merge(not_milestone_title: milestone.title) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:not_milestone_title])
        end
      end

      context 'when none_milestones option is provided' do
        let(:options) { base_options.merge(none_milestones: true) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:none_milestones])
        end
      end

      context 'when any_milestones option is provided' do
        let(:options) { base_options.merge(any_milestones: true) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:any_milestones])
        end
      end
    end

    describe 'assignees' do
      let_it_be(:assignee_user) { create(:user) }
      let_it_be(:other_user) { create(:user) }

      it 'does not apply assignee filters by default' do
        assert_names_in_query(build,
          without: %w[
            filters:assignee_ids
            filters:not_assignee_ids
            filters:or_assignee_ids
            filters:none_assignees
            filters:any_assignees
          ])
      end

      context 'when assignee_ids option is provided' do
        let(:options) { base_options.merge(assignee_ids: [assignee_user.id, other_user.id]) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:assignee_ids])
        end
      end

      context 'when not_assignee_ids option is provided' do
        let(:options) { base_options.merge(not_assignee_ids: [assignee_user.id, other_user.id]) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:not_assignee_ids])
        end
      end

      context 'when or_assignee_ids option is provided' do
        let(:options) { base_options.merge(or_assignee_ids: [assignee_user.id, other_user.id]) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:or_assignee_ids])
        end
      end

      context 'when none_assignees option is provided' do
        let(:options) { base_options.merge(none_assignees: true) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:none_assignees])
        end
      end

      context 'when any_assignees option is provided' do
        let(:options) { base_options.merge(any_assignees: true) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:any_assignees])
        end
      end

      context 'when multiple assignee options are provided' do
        let(:options) do
          base_options.merge(
            assignee_ids: [assignee_user.id],
            not_assignee_ids: [other_user.id],
            or_assignee_ids: [assignee_user.id, other_user.id],
            none_assignees: true,
            any_assignees: true
          )
        end

        it 'applies all provided assignee filters' do
          assert_names_in_query(build, with: %w[
            filters:assignee_ids
            filters:not_assignee_ids
            filters:or_assignee_ids
            filters:none_assignees
            filters:any_assignees
          ])
        end
      end
    end

    describe 'label names' do
      it 'does not apply label filters by default' do
        assert_names_in_query(build,
          without: %w[
            filters:label_names
            filters:not_label_names
            filters:or_label_names
            filters:none_label_names
            filters:any_label_names
          ])
      end

      context 'when label_names option is provided' do
        let(:options) { base_options.merge(label_names: ['workflow::*', 'backend']) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:label_names])
        end
      end

      context 'when not_label_names option is provided' do
        let(:options) { base_options.merge(not_label_names: ['workflow::in dev', 'group::*']) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:not_label_names])
        end
      end

      context 'when or_label_names option is provided' do
        let(:options) { base_options.merge(or_label_names: ['workflow::*', 'group::planner intelligence']) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:or_label_names])
        end
      end

      context 'when none_label_names option is provided' do
        let(:options) { base_options.merge(none_label_names: true) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:none_label_names])
        end
      end

      context 'when any_label_names option is provided' do
        let(:options) { base_options.merge(any_label_names: true) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:any_label_names])
        end
      end

      context 'when multiple label options are provided' do
        let(:options) do
          base_options.merge(
            label_names: ['workflow::complete'],
            not_label_names: ['group::*'],
            or_label_names: %w[backend frontend],
            none_label_names: false,
            any_label_names: false
          )
        end

        it 'applies all provided label filters' do
          assert_names_in_query(build, with: %w[
            filters:label_names
            filters:not_label_names
            filters:or_label_names
          ])
        end
      end

      context 'when mixed ANY with nested filters' do
        let(:options) do
          base_options.merge(
            any_label_names: true,
            not_label_names: ['workflow::in dev'],
            or_label_names: %w[frontend backend]
          )
        end

        it 'applies all provided label filters' do
          assert_names_in_query(build, with: %w[
            filters:any_label_names
            filters:not_label_names
            filters:or_label_names
          ])
        end
      end

      context 'when mixed NONE with nested filters' do
        let(:options) do
          base_options.merge(
            none_label_names: true,
            not_label_names: ['group::*'],
            or_label_names: %w[frontend backend]
          )
        end

        it 'applies all provided label filters' do
          assert_names_in_query(build, with: %w[
            filters:none_label_names
            filters:not_label_names
            filters:or_label_names
          ])
        end
      end
    end

    describe 'weight' do
      it 'does not apply weight filters by default' do
        assert_names_in_query(build,
          without: %w[
            filters:weight
            filters:not_weight
            filters:none_weight
            filters:any_weight
          ])
      end

      context 'when weight option is provided' do
        let(:options) { base_options.merge(weight: 3) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:weight])
        end
      end

      context 'when not_weight option is provided' do
        let(:options) { base_options.merge(not_weight: 2) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:not_weight])
        end
      end

      context 'when none_weight option is provided' do
        let(:options) { base_options.merge(none_weight: true) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:none_weight])
        end
      end

      context 'when any_weight option is provided' do
        let(:options) { base_options.merge(any_weight: true) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:any_weight])
        end
      end
    end

    describe 'health_status' do
      it 'does not apply health_status filters by default' do
        assert_names_in_query(build,
          without: %w[
            filters:health_status
            filters:not_health_status
            filters:none_health_status
            filters:any_health_status
          ])
      end

      context 'when health_status option is provided' do
        let(:options) { base_options.merge(health_status: [1]) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:health_status])
        end
      end

      context 'when not_health_status option is provided' do
        let(:options) { base_options.merge(not_health_status: [2]) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:not_health_status])
        end
      end

      context 'when none_health_status option is provided' do
        let(:options) { base_options.merge(none_health_status: true) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:none_health_status])
        end
      end

      context 'when any_health_status option is provided' do
        let(:options) { base_options.merge(any_health_status: true) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:any_health_status])
        end
      end
    end

    describe 'closed_at' do
      it 'does not apply closed_at filters by default' do
        assert_names_in_query(build,
          without: %w[
            filters:closed_after
            filters:closed_before
          ])
      end

      context 'when closed_after option is provided' do
        let(:options) { base_options.merge(closed_after: '2025-01-01T00:00:00Z') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:closed_after])
        end
      end

      context 'when closed_before option is provided' do
        let(:options) { base_options.merge(closed_before: '2025-12-31T23:59:59Z') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:closed_before])
        end
      end

      context 'when both closed_after and closed_before options are provided' do
        let(:options) do
          base_options.merge(closed_after: '2025-01-01T00:00:00Z', closed_before: '2025-12-31T23:59:59Z')
        end

        it 'applies both filters' do
          assert_names_in_query(build, with: %w[filters:closed_after filters:closed_before])
        end
      end
    end

    describe 'created_at' do
      it 'does not apply created_at filters by default' do
        assert_names_in_query(build,
          without: %w[
            filters:created_after
            filters:created_before
          ])
      end

      context 'when created_after option is provided' do
        let(:options) { base_options.merge(created_after: '2025-01-01T00:00:00Z') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:created_after])
        end
      end

      context 'when created_before option is provided' do
        let(:options) { base_options.merge(created_before: '2025-12-31T23:59:59Z') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:created_before])
        end
      end

      context 'when both created_after and created_before options are provided' do
        let(:options) do
          base_options.merge(created_after: '2025-01-01T00:00:00Z', created_before: '2025-12-31T23:59:59Z')
        end

        it 'applies both filters' do
          assert_names_in_query(build, with: %w[filters:created_after filters:created_before])
        end
      end
    end

    describe 'updated_at' do
      it 'does not apply updated_at filters by default' do
        assert_names_in_query(build,
          without: %w[
            filters:updated_after
            filters:updated_before
          ])
      end

      context 'when updated_after option is provided' do
        let(:options) { base_options.merge(updated_after: '2025-01-01T00:00:00Z') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:updated_after])
        end
      end

      context 'when updated_before option is provided' do
        let(:options) { base_options.merge(updated_before: '2025-12-31T23:59:59Z') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:updated_before])
        end
      end

      context 'when both updated_after and updated_before options are provided' do
        let(:options) do
          base_options.merge(updated_after: '2025-01-01T00:00:00Z', updated_before: '2025-12-31T23:59:59Z')
        end

        it 'applies both filters' do
          assert_names_in_query(build, with: %w[filters:updated_after filters:updated_before])
        end
      end
    end

    describe 'due_date' do
      it 'does not apply due_date filters by default' do
        assert_names_in_query(build,
          without: %w[
            filters:due_after
            filters:due_before
          ])
      end

      context 'when due_after option is provided' do
        let(:options) { base_options.merge(due_after: '2025-01-01T00:00:00Z') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:due_after])
        end
      end

      context 'when due_before option is provided' do
        let(:options) { base_options.merge(due_before: '2025-12-31T23:59:59Z') }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:due_before])
        end
      end

      context 'when both due_after and due_before options are provided' do
        let(:options) { base_options.merge(due_after: '2025-01-01T00:00:00Z', due_before: '2025-12-31T23:59:59Z') }

        it 'applies both filters' do
          assert_names_in_query(build, with: %w[filters:due_after filters:due_before])
        end
      end
    end

    describe 'iids' do
      it 'does not apply iids filter by default' do
        assert_names_in_query(build,
          without: %w[
            filters:iids
          ])
      end

      context 'when iids option is provided with single iid' do
        let(:options) { base_options.merge(iids: [1]) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:iids])
        end
      end

      context 'when iids option is provided with multiple iids' do
        let(:options) { base_options.merge(iids: [1, 2, 3]) }

        it 'applies the filter' do
          assert_names_in_query(build, with: %w[filters:iids])
        end
      end
    end
  end

  describe 'aggregations' do
    let(:options) { base_options.merge(aggregation: true) }

    it 'includes both labels and work_item_type_ids aggregations' do
      expect(build[:aggs].keys).to contain_exactly('labels', 'work_item_type_ids')
    end

    it 'sets size to 0' do
      expect(build[:size]).to eq(0)
    end

    it 'does not apply work_item_type_ids filter so aggregation reflects all types' do
      options[:work_item_type_ids] = [1, 2]
      result = build
      # The filter should not be in the query bool filters
      filter_terms = result.dig(:query, :bool, :filter).to_s
      expect(filter_terms).not_to include('work_item_type_id')
      # But the aggregation should still be present
      expect(result[:aggs].keys).to include('work_item_type_ids')
    end
  end

  it_behaves_like 'a sorted query'

  describe 'formats' do
    it_behaves_like 'a query that sets source_fields'
    it_behaves_like 'a query formatted for size'
    it_behaves_like 'a query that is paginated'
  end

  describe 'group work items (epics)' do
    let_it_be(:epics_test_user) { create(:user) }
    let_it_be(:public_group) { create(:group, :public) }
    let_it_be(:private_group) { create(:group, :private) }
    let_it_be(:private_project) { create(:project, :private, namespace: private_group) }

    let(:epic_type_id) { FactoryBot.build(:work_item_system_defined_type, :epic).id }
    let(:current_user) { epics_test_user }
    let(:base_options) do
      {
        current_user: current_user,
        project_ids: [],
        group_ids: [],
        klass: WorkItem,
        index_name: ::Search::Elastic::References::WorkItem.index,
        work_item_type_ids: [epic_type_id],
        public_and_internal_projects: false,
        search_level: :global
      }
    end

    let(:options) { base_options }

    subject(:build) { described_class.build(query: query, options: options) }

    it 'contains group-level filters' do
      assert_names_in_query(build, with: %w[
        work_item:multi_match:and:search_terms
        work_item:multi_match_phrase:search_terms
        filters:permissions:global
        filters:permissions:global:namespace_visibility_level:public_and_internal
        filters:not_hidden
        filters:work_item_type_ids
        filters:non_archived
        filters:confidentiality:groups:non_confidential
      ])
    end

    describe 'confidentiality' do
      context 'when user has role set in min_access_level_confidential option' do
        context 'in group' do
          it 'applies the expected membership filters' do
            private_group.add_planner(epics_test_user)

            assert_names_in_query(build,
              with: %w[filters:confidentiality:groups:non_confidential
                filters:confidentiality:groups:confidential
                filters:confidentiality:groups:confidential:as_assignee
                filters:confidentiality:groups:private:ancestry_filter:descendants],
              without: %w[filters:confidentiality:groups:public_and_internal:ancestry_filter:descendants
                filters:confidentiality:groups:public_and_internal:confidential:as_author])
          end
        end

        context 'in project' do
          it 'applies the expected membership filters' do
            private_project.add_planner(epics_test_user)

            assert_names_in_query(build,
              with: %w[filters:confidentiality:groups:non_confidential
                filters:confidentiality:groups:confidential
                filters:confidentiality:groups:confidential:as_assignee
                filters:confidentiality:groups:private:ancestry_filter:descendants],
              without: %w[filters:confidentiality:groups:public_and_internal:confidential:as_author
                filters:confidentiality:groups:public_and_internal:ancestry_filter:descendants])
          end
        end
      end

      context 'when user does not have role' do
        it 'only applies the author or assignee confidential filters and non-confidential filters' do
          assert_names_in_query(build,
            with: %w[filters:confidentiality:groups:non_confidential
              filters:confidentiality:groups:confidential
              filters:confidentiality:groups:confidential:as_assignee],
            without: %w[filters:confidentiality:groups:private:ancestry_filter:descendants
              filters:confidentiality:groups:public_and_internal:ancestry_filter:descendants
              filters:confidentiality:groups:public_and_internal:confidential:as_author])
        end
      end

      context 'when there is no user' do
        let(:current_user) { nil }

        it 'only applies the non-confidential filter' do
          assert_names_in_query(build,
            with: %w[filters:confidentiality:groups:non_confidential],
            without: %w[filters:confidentiality:groups:confidential:as_author
              filters:confidentiality:groups:confidential:as_assignee
              filters:confidentiality:groups:confidential
              filters:confidentiality:groups:private:ancestry_filter:descendants
              filters:confidentiality:groups:public_and_internal:ancestry_filter:descendants])
        end
      end

      context 'when user can read all resources' do
        before do
          allow(epics_test_user).to receive(:can_read_all_resources?).and_return(true)
        end

        it 'applies no confidential filters' do
          assert_names_in_query(build,
            without: %w[filters:confidentiality:groups:non_confidential
              filters:confidentiality:groups:confidential
              filters:confidentiality:groups:public_and_internal:confidential:as_author
              filters:confidentiality:groups:public_and_internal:confidential:as_assignee
              filters:confidentiality:groups:public_and_internal:ancestry_filter:descendants
              filters:confidentiality:groups:private:ancestry_filter:descendants])
        end
      end
    end
  end

  describe 'authorization and features options' do
    let(:epic_type_id) { ::WorkItems::TypesFramework::Provider.new.find_by_base_type(:epic).id }
    let(:issue_type_id) { ::WorkItems::TypesFramework::Provider.new.find_by_base_type(:issue).id }
    let(:task_type_id) { ::WorkItems::TypesFramework::Provider.new.find_by_base_type(:task).id }

    context 'when no work_item_type_ids filter is provided' do
      let(:options) { base_options.except(:not_work_item_type_ids) }

      it 'does not set issues_access_level filter that would exclude group work items' do
        assert_names_in_query(build,
          without: %w[filters:permissions:global:issues_access_level:enabled_or_private])
      end

      it 'includes group confidentiality filters for epics' do
        assert_names_in_query(build,
          with: %w[filters:confidentiality:groups:non_confidential])
      end
    end

    context 'when filtering by epic type only' do
      let(:options) { base_options.merge(work_item_type_ids: [epic_type_id]).except(:not_work_item_type_ids) }

      it 'does not set issues_access_level filter' do
        assert_names_in_query(build,
          without: %w[filters:permissions:global:issues_access_level:enabled_or_private])
      end

      it 'includes group confidentiality filters for epics' do
        assert_names_in_query(build,
          with: %w[filters:confidentiality:groups:non_confidential])
      end
    end

    context 'when filtering by issue type only' do
      let(:options) { base_options.merge(work_item_type_ids: [issue_type_id]).except(:not_work_item_type_ids) }

      it 'does not include group confidentiality filters' do
        assert_names_in_query(build,
          without: %w[filters:confidentiality:groups:non_confidential])
      end
    end

    context 'when filtering by both epic and issue types' do
      let(:options) do
        base_options.merge(work_item_type_ids: [epic_type_id, issue_type_id]).except(:not_work_item_type_ids)
      end

      it 'does not set issues_access_level filter to avoid excluding epics' do
        assert_names_in_query(build,
          without: %w[filters:permissions:global:issues_access_level:enabled_or_private])
      end

      it 'includes group confidentiality filters for epics' do
        assert_names_in_query(build,
          with: %w[filters:confidentiality:groups:non_confidential])
      end
    end

    context 'when filtering by epic, issue, and task types' do
      let(:options) do
        base_options.merge(work_item_type_ids: [epic_type_id, issue_type_id, task_type_id])
          .except(:not_work_item_type_ids)
      end

      it 'does not set issues_access_level filter to avoid excluding epics' do
        assert_names_in_query(build,
          without: %w[filters:permissions:global:issues_access_level:enabled_or_private])
      end

      it 'includes group confidentiality filters for epics' do
        assert_names_in_query(build,
          with: %w[filters:confidentiality:groups:non_confidential])
      end
    end
  end
end
