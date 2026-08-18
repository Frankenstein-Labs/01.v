# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::AdvancedFinders::WorkItemsFinder, :elastic_delete_by_query, :sidekiq_inline, feature_category: :markdown do
  let_it_be(:group)        { create(:group) }
  let_it_be(:project)      { create(:project, group: group) }
  let_it_be(:current_user) { create(:user) }

  let(:params)         { {} }
  let(:finder)         { described_class.new(current_user, context, resource_parent, params) }
  let(:context)        { instance_double(GraphQL::Query::Context) }
  let(:request_params) { { 'operationName' => 'GLQL' } }
  let(:url_query)      { 'useES=true' }
  let(:url)            { 'http://localhost' }
  let(:referer)        { "#{url}?#{url_query}" }

  let(:dummy_request) do
    instance_double(ActionDispatch::Request,
      params: request_params,
      referer: referer
    )
  end

  before do
    allow(context).to receive(:[]).with(:request).and_return(dummy_request)

    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  subject(:execute) { finder.execute.to_a }

  describe '#use_elasticsearch_finder?' do
    let(:resource_parent) { group }

    context 'when falling back to legacy finder' do
      context 'when the request is not allowed operation name' do
        # NOTE: We currently allow the following operation names:
        # GLQL, getWorkItemsFullEE, and getWorkItemsSlimEE
        let(:request_params) { { 'operationName' => 'Not allowed' } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when url param is not enabled' do
        let(:url_query) { 'useES=false' }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when elasticsearch is not enabled' do
        before do
          allow(Gitlab::CurrentSettings).to receive(:elasticsearch_search?).and_return(false)
        end

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when elasticsearch is not enabled per group' do
        before do
          allow(resource_parent).to receive(:use_elasticsearch?).and_return(false)
        end

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when elasticsearch indexing is paused' do
        before do
          stub_ee_application_setting(elasticsearch_pause_indexing: true)
        end

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be(false)
        end
      end

      context 'when not supported search param is used' do
        let(:params) { { not_suported: 'something' } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when not supported sort value is used' do
        let(:params) { { sort: 'not_supported' } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when `not` operator is used with supported filter' do
        let(:params) { { not: { author_username: current_user.username } } }

        it 'returns true' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end

      context 'when `not` operator is used with not supported filter' do
        let(:params) { { not: { not_suported: 'something' } } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when `not` operator is not a hash' do
        let(:params) { { not: 'something' } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when `or` operator is used with supported filter' do
        let(:params) { { or: { assignee_usernames: [current_user.username] } } }

        it 'returns true' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end

      context 'when `or` operator is used with not supported filter' do
        let(:params) { { or: { not_suported: 'something' } } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end

      context 'when `or` operator is not a hash' do
        let(:params) { { or: 'something' } }

        it 'returns false' do
          expect(finder.use_elasticsearch_finder?).to be_falsey
        end
      end
    end

    context 'when using ES finder' do
      context 'when all the conditions are met' do
        it 'returns true' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end

      context 'when exclude_group_work_items is used' do
        let(:params) { { exclude_group_work_items: true } }

        it 'returns true' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end

      # This spec ensures that all control arguments defined in Namespaces::WorkItemsResolver
      # are properly handled by the Advanced Finder. When new control arguments are added
      # to the resolver with default values, they must also be added to CONTROL_KEYS or
      # ALLOWED_ES_FILTERS to prevent validation failures that cause queries to fall back
      # to PostgreSQL. See https://gitlab.com/gitlab-org/gitlab/-/issues/573896 for context.
      context 'when GraphQL resolver control arguments are used' do
        let(:resolver_class) { Resolvers::Namespaces::WorkItemsResolver }
        let(:control_keys) { described_class::CONTROL_KEYS }
        let(:allowed_filters) { described_class::ALLOWED_ES_FILTERS }

        it 'all GROUP_NAMESPACE_ONLY_ARGS are in CONTROL_KEYS or ALLOWED_ES_FILTERS' do
          resolver_control_args = resolver_class::GROUP_NAMESPACE_ONLY_ARGS

          missing_keys = resolver_control_args - control_keys - allowed_filters - [:timeframe]

          expect(missing_keys).to be_empty,
            "The following arguments from Namespaces::WorkItemsResolver::GROUP_NAMESPACE_ONLY_ARGS " \
              "are missing from both CONTROL_KEYS and ALLOWED_ES_FILTERS: #{missing_keys.inspect}. " \
              "When adding new control arguments to the resolver, they must also be added to either " \
              "CONTROL_KEYS (if ignored by ES) or ALLOWED_ES_FILTERS (if supported by ES) " \
              "in ee/lib/ee/search/advanced_finders/work_items_finder.rb"
        end

        described_class::CONTROL_KEYS.each do |control_key|
          context "when #{control_key} is used" do
            let(:params) do
              value = control_key == :sort ? :created_desc : true
              { control_key => value }
            end

            it 'returns true and uses Elasticsearch' do
              expect(finder.use_elasticsearch_finder?).to be_truthy
            end
          end
        end
      end

      context 'when url param is missing (since we do not want to force using this param)' do
        let(:url_query) { '' }

        it 'returns true' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end

      context 'when the request is a getWorkItemsFullEE request' do
        let(:request_params) { { 'operationName' => 'getWorkItemsFullEE' } }

        it 'returns true' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end

      context 'when the request is a getWorkItemsSlimEE request' do
        let(:request_params) { { 'operationName' => 'getWorkItemsSlimEE' } }

        it 'returns true' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end
    end

    context 'when checking migration completion' do
      context 'when GLQL request is made' do
        let(:request_params) { { 'operationName' => 'GLQL' } }

        it 'returns true when all conditions are met' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end

      context 'when getWorkItemsFullEE request is made' do
        let(:request_params) { { 'operationName' => 'getWorkItemsFullEE' } }

        it 'returns true when all conditions are met' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end

      context 'when getWorkItemsSlimEE request is made' do
        let(:request_params) { { 'operationName' => 'getWorkItemsSlimEE' } }

        it 'returns true when all conditions are met' do
          expect(finder.use_elasticsearch_finder?).to be_truthy
        end
      end

      context 'when combined with other conditions' do
        let(:request_params) { { 'operationName' => 'GLQL' } }

        context 'when elasticsearch is disabled' do
          before do
            allow(Gitlab::CurrentSettings).to receive(:elasticsearch_search?).and_return(false)
          end

          it 'returns false due to elasticsearch being disabled' do
            expect(finder.use_elasticsearch_finder?).to be_falsey
          end
        end

        context 'when elasticsearch is not enabled per group' do
          before do
            allow(resource_parent).to receive(:use_elasticsearch?).and_return(false)
          end

          it 'returns false due to group not using elasticsearch' do
            expect(finder.use_elasticsearch_finder?).to be_falsey
          end
        end

        context 'when url param is disabled' do
          let(:url_query) { 'useES=false' }

          it 'returns false due to url param' do
            expect(finder.use_elasticsearch_finder?).to be_falsey
          end
        end
      end
    end

    context 'when work_item_type_ids param is used' do
      let(:params) do
        { work_item_type_ids: [1] }
      end

      it 'returns true' do
        expect(finder.use_elasticsearch_finder?).to be_truthy
      end
    end

    context 'when `not` operator is used with work_item_type_ids' do
      let(:params) do
        { not: { work_item_type_ids: [1] } }
      end

      it 'returns true' do
        expect(finder.use_elasticsearch_finder?).to be_truthy
      end
    end

    context 'when `not` operator is used with issue_types' do
      let(:params) do
        { not: { issue_types: ['task'] } }
      end

      it 'returns true' do
        expect(finder.use_elasticsearch_finder?).to be_truthy
      end
    end
  end

  describe '#parent_param=' do
    context 'when resource_parent is a Group' do
      let(:resource_parent) { group }

      it 'sets the group_id and leaves project_id nil' do
        finder.parent_param = resource_parent

        expect(finder.params[:project_id]).to be_nil
        expect(finder.params[:group_id]).to eq(resource_parent)
      end
    end

    context 'when resource_parent is a Project' do
      let_it_be(:resource_parent) { project }

      it 'sets the project_id and leaves group_id nil' do
        finder.parent_param = resource_parent

        expect(finder.params[:group_id]).to be_nil
        expect(finder.params[:project_id]).to eq(resource_parent)
      end
    end

    context 'when resource_parent is not allowed' do
      let_it_be(:resource_parent) { create(:merge_request) }

      it 'raises an error for unexpected parent type' do
        expect { finder.parent_param }.to raise_error(RuntimeError, 'Unexpected parent: MergeRequest')
      end
    end
  end

  describe '#execute' do
    context 'when resource_parent is a Group' do
      let(:resource_parent) { group }

      before_all do
        group.add_owner(current_user)
      end

      context 'when searching for author_username' do
        let(:another_user) { create(:user) }
        let(:work_item1_with_author) { create(:work_item, project: project, author: current_user) }
        let(:work_item2_with_author) { create(:work_item, project: project, author: another_user) }

        before do
          Elastic::ProcessBookkeepingService.track!(work_item1_with_author, work_item2_with_author)

          ensure_elasticsearch_index!
        end

        context 'when author_username param provided' do
          let(:params) do
            { author_username: [current_user.username] }
          end

          it 'returns work items with specified author username' do
            expect(execute).to contain_exactly(work_item1_with_author)
          end
        end

        context 'when not_author_username param provided' do
          let(:params) do
            {
              not: {
                author_username: [current_user.username]
              }
            }
          end

          it 'returns work items without specified author username' do
            expect(execute).to contain_exactly(work_item2_with_author)
          end
        end
      end

      context 'when searching with include_archived' do
        let_it_be(:archived_project) { create(:project, :archived, group: group) }
        let_it_be(:active_project) { create(:project, group: group) }
        let_it_be(:work_item_archived) { create(:work_item, project: archived_project) }
        let_it_be(:work_item_active) { create(:work_item, project: active_project) }

        before_all do
          group.add_owner(current_user)
        end

        before do
          Elastic::ProcessBookkeepingService.track!(work_item_archived, work_item_active)

          ensure_elasticsearch_index!
        end

        context 'when include_archived is false' do
          let(:params) { { include_archived: false } }

          it 'excludes work items from archived projects' do
            expect(execute).to contain_exactly(work_item_active)
          end
        end

        context 'when include_archived is true' do
          let(:params) { { include_archived: true } }

          it 'includes work items from archived projects' do
            expect(execute).to contain_exactly(work_item_archived, work_item_active)
          end
        end

        context 'when include_archived is not specified (defaults to false)' do
          let(:params) { {} }

          it 'excludes work items from archived projects by default' do
            expect(execute).to contain_exactly(work_item_active)
          end
        end
      end

      context 'when searching for milestone' do
        let(:milestone1) { create(:milestone, group: group) }
        let(:milestone2) { create(:milestone, group: group) }
        let(:work_item1_with_milestone) { create(:work_item, project: project, milestone: milestone1) }
        let(:work_item2_with_milestone) { create(:work_item, project: project, milestone: milestone2) }
        let(:work_item3_without_milestone) { create(:work_item, project: project) }

        before do
          Elastic::ProcessBookkeepingService.track!(
            work_item1_with_milestone,
            work_item2_with_milestone,
            work_item3_without_milestone
          )

          ensure_elasticsearch_index!
        end

        context 'when milestone_title param provided' do
          let(:params) do
            { milestone_title: [milestone1.title] }
          end

          it 'returns work items with specified title' do
            expect(execute).to contain_exactly(work_item1_with_milestone)
          end
        end

        context 'when not_milestone_title param provided' do
          let(:params) do
            {
              not: {
                milestone_title: [milestone2.title]
              }
            }
          end

          it 'returns work items without specified title' do
            expect(execute).to contain_exactly(work_item1_with_milestone, work_item3_without_milestone)
          end
        end

        context 'when milestone_title param with multiple titles provided' do
          let(:params) do
            { milestone_title: [milestone1.title, milestone2.title] }
          end

          it 'returns work items with specified titles' do
            expect(execute).to contain_exactly(work_item1_with_milestone, work_item2_with_milestone)
          end
        end

        context 'when milestone_wildcard_id with NONE provided' do
          let(:params) do
            { milestone_wildcard_id: 'NONE' }
          end

          it 'returns work items without milestone' do
            expect(execute).to contain_exactly(work_item3_without_milestone)
          end
        end

        context 'when milestone_wildcard_id with ANY provided' do
          let(:params) do
            { milestone_wildcard_id: 'ANY' }
          end

          it 'returns all work items with any milestone' do
            expect(execute).to contain_exactly(work_item1_with_milestone, work_item2_with_milestone)
          end
        end
      end

      context 'with milestone state wildcard filters' do
        let(:upcoming_milestone) do
          create(:milestone, group: group, start_date: 1.day.from_now, due_date: 1.week.from_now)
        end

        let(:started_milestone) do
          create(:milestone, group: group, start_date: 1.day.ago, due_date: 1.week.from_now)
        end

        let(:work_item_with_upcoming_milestone) do
          create(:work_item, project: project, milestone: upcoming_milestone)
        end

        let(:work_item_with_started_milestone) do
          create(:work_item, project: project, milestone: started_milestone)
        end

        before do
          Elastic::ProcessBookkeepingService.track!(
            work_item_with_upcoming_milestone,
            work_item_with_started_milestone
          )
          ensure_elasticsearch_index!
        end

        context 'when milestone_wildcard_id with UPCOMING provided' do
          let(:params) do
            { milestone_wildcard_id: 'UPCOMING' }
          end

          it 'returns work items with upcoming active milestones' do
            expect(execute).to contain_exactly(work_item_with_upcoming_milestone)
          end
        end

        context 'when milestone_wildcard_id with STARTED provided' do
          let(:params) do
            { milestone_wildcard_id: 'STARTED' }
          end

          it 'returns work items with started active milestones' do
            expect(execute).to contain_exactly(work_item_with_started_milestone)
          end
        end

        context 'when NOT milestone_wildcard_id with UPCOMING provided' do
          let(:params) do
            {
              not: {
                milestone_wildcard_id: 'UPCOMING'
              }
            }
          end

          it 'returns work items without upcoming milestones' do
            expect(execute).to contain_exactly(work_item_with_started_milestone)
          end
        end

        context 'when NOT milestone_wildcard_id with STARTED provided' do
          let(:params) do
            {
              not: {
                milestone_wildcard_id: 'STARTED'
              }
            }
          end

          it 'returns work items without started milestones' do
            expect(execute).to contain_exactly(work_item_with_upcoming_milestone)
          end
        end
      end

      context 'when searching for weight' do
        let(:work_item_with_weight_5) { create(:work_item, project: project, weight: 5) }
        let(:work_item_with_weight_10) { create(:work_item, project: project, weight: 10) }
        let(:work_item_without_weight) { create(:work_item, project: project, weight: nil) }

        before do
          Elastic::ProcessBookkeepingService.track!(
            work_item_with_weight_5,
            work_item_with_weight_10,
            work_item_without_weight
          )

          ensure_elasticsearch_index!
        end

        context 'when weight param provided' do
          let(:params) do
            { weight: '5' }
          end

          it 'returns work items with specified weight' do
            expect(execute).to contain_exactly(work_item_with_weight_5)
          end
        end

        context 'when not_weight param provided' do
          let(:params) do
            {
              not: {
                weight: '10'
              }
            }
          end

          it 'returns work items without specified weight' do
            expect(execute).to contain_exactly(work_item_with_weight_5, work_item_without_weight)
          end
        end

        context 'when weight_wildcard_id with ANY provided' do
          let(:params) do
            { weight_wildcard_id: 'ANY' }
          end

          it 'returns all work items with any weight' do
            expect(execute).to contain_exactly(work_item_with_weight_5, work_item_with_weight_10)
          end
        end

        context 'when weight_wildcard_id with NONE provided' do
          let(:params) do
            { weight_wildcard_id: 'NONE' }
          end

          it 'returns work items without weight' do
            expect(execute).to contain_exactly(work_item_without_weight)
          end
        end
      end

      context 'when searching for assignee' do
        let(:user1) { create(:user) }
        let(:user2) { create(:user) }
        let(:user3) { create(:user) }
        let(:work_item_assigned_to_user1) { create(:work_item, project: project, assignees: [user1]) }
        let(:work_item_assigned_to_user2) { create(:work_item, project: project, assignees: [user2]) }
        let(:work_item_assigned_to_user3) { create(:work_item, project: project, assignees: [user3]) }
        let(:work_item_assigned_to_multiple) { create(:work_item, project: project, assignees: [user1, user2]) }
        let(:work_item_without_assignee) { create(:work_item, project: project, assignees: []) }

        before do
          Elastic::ProcessBookkeepingService.track!(
            work_item_assigned_to_user1,
            work_item_assigned_to_user2,
            work_item_assigned_to_user3,
            work_item_assigned_to_multiple,
            work_item_without_assignee
          )

          ensure_elasticsearch_index!
        end

        context 'when assignee username provided' do
          let(:params) do
            { assignee_usernames: [user1.username] }
          end

          it 'returns work items assigned to specified user' do
            expect(execute).to contain_exactly(work_item_assigned_to_user1, work_item_assigned_to_multiple)
          end
        end

        context 'when multiple assignee usernames provided' do
          let(:params) do
            { assignee_usernames: [user1.username, user2.username] }
          end

          it 'returns work items assigned to all specified users' do
            expect(execute).to contain_exactly(work_item_assigned_to_multiple)
          end
        end

        context 'when not_assignee_usernames param provided' do
          let(:params) do
            {
              not: {
                assignee_usernames: [user2.username]
              }
            }
          end

          it 'returns work items not assigned to specified user' do
            expect(execute).to contain_exactly(
              work_item_assigned_to_user1,
              work_item_assigned_to_user3,
              work_item_without_assignee
            )
          end
        end

        context 'when or assignee param provided' do
          let(:params) do
            {
              or: {
                assignee_usernames: [user1.username, user3.username]
              }
            }
          end

          it 'returns work items assigned to any of the specified users' do
            expect(execute).to contain_exactly(
              work_item_assigned_to_user1,
              work_item_assigned_to_user3,
              work_item_assigned_to_multiple
            )
          end
        end

        context 'when assignee_wildcard_id with ANY provided' do
          let(:params) do
            { assignee_wildcard_id: 'ANY' }
          end

          it 'returns all work items with any assignee' do
            expect(execute).to contain_exactly(
              work_item_assigned_to_user1,
              work_item_assigned_to_user2,
              work_item_assigned_to_user3,
              work_item_assigned_to_multiple
            )
          end
        end

        context 'when assignee_wildcard_id with NONE provided' do
          let(:params) do
            { assignee_wildcard_id: 'NONE' }
          end

          it 'returns work items without assignee' do
            expect(execute).to contain_exactly(work_item_without_assignee)
          end
        end
      end

      context 'when searching for label_names' do
        let(:bug_label) { create(:label, project: project, title: 'bug') }
        let(:feature_label) { create(:label, project: project, title: 'feature') }
        let(:scoped_group_label) { create(:label, project: project, title: 'group::planner intelligence') }
        let(:different_scoped_label) { create(:label, project: project, title: 'priority::high') }

        let(:work_item_with_bug_label) { create(:work_item, project: project, labels: [bug_label]) }
        let(:work_item_with_feature_label) { create(:work_item, project: project, labels: [feature_label]) }
        let(:work_item_with_scoped_group_label) { create(:work_item, project: project, labels: [scoped_group_label]) }
        let(:work_item_with_different_scoped_label) do
          create(:work_item, project: project, labels: [different_scoped_label])
        end

        let(:work_item_with_multiple_labels) do
          create(:work_item, project: project, labels: [bug_label, scoped_group_label])
        end

        let(:work_item_without_labels) { create(:work_item, project: project, labels: []) }

        before do
          Elastic::ProcessBookkeepingService.track!(
            work_item_with_bug_label,
            work_item_with_feature_label,
            work_item_with_scoped_group_label,
            work_item_with_different_scoped_label,
            work_item_with_multiple_labels,
            work_item_without_labels
          )

          ensure_elasticsearch_index!
        end

        context 'when label_names param provided' do
          let(:params) do
            { label_name: ['bug'] }
          end

          it 'returns work items with specified label' do
            expect(execute).to contain_exactly(work_item_with_bug_label, work_item_with_multiple_labels)
          end
        end

        context 'when label_names param with wildcard provided' do
          let(:params) do
            { label_name: ['group::*'] }
          end

          it 'returns work items with scoped labels matching wildcard pattern' do
            expect(execute).to contain_exactly(work_item_with_scoped_group_label, work_item_with_multiple_labels)
          end
        end

        context 'when not_label_names param provided' do
          let(:params) do
            {
              not: {
                label_name: ['bug']
              }
            }
          end

          it 'returns work items without specified label' do
            expect(execute).to contain_exactly(
              work_item_with_feature_label,
              work_item_with_scoped_group_label,
              work_item_with_different_scoped_label,
              work_item_without_labels
            )
          end
        end

        context 'when or_label_names param provided' do
          let(:params) do
            {
              or: {
                label_names: %w[bug feature]
              }
            }
          end

          it 'returns work items with any of the specified labels' do
            expect(execute).to contain_exactly(
              work_item_with_bug_label,
              work_item_with_feature_label,
              work_item_with_multiple_labels
            )
          end
        end

        context 'when label_name with ANY provided' do
          let(:params) do
            { label_name: ['ANY'] }
          end

          it 'returns all work items with any label' do
            expect(execute).to contain_exactly(
              work_item_with_bug_label,
              work_item_with_feature_label,
              work_item_with_scoped_group_label,
              work_item_with_different_scoped_label,
              work_item_with_multiple_labels
            )
          end
        end

        context 'when label_name with NONE provided' do
          let(:params) do
            { label_name: ['NONE'] }
          end

          it 'returns work items without any labels' do
            expect(execute).to contain_exactly(work_item_without_labels)
          end
        end
      end

      context 'when searching for health_status' do
        let(:work_item_on_track) { create(:work_item, project: project, health_status: 'on_track') }
        let(:work_item_needs_attention) { create(:work_item, project: project, health_status: 'needs_attention') }
        let(:work_item_at_risk) { create(:work_item, project: project, health_status: 'at_risk') }
        let(:work_item_without_health_status) { create(:work_item, project: project, health_status: nil) }

        before do
          Elastic::ProcessBookkeepingService.track!(
            work_item_on_track,
            work_item_needs_attention,
            work_item_at_risk,
            work_item_without_health_status
          )

          ensure_elasticsearch_index!
        end

        context 'when health_status param provided' do
          let(:params) do
            { health_status_filter: 'on_track' }
          end

          it 'returns work items with specified health status' do
            expect(execute).to contain_exactly(work_item_on_track)
          end
        end

        context 'when multiple health_status values provided' do
          let(:params) do
            { health_status_filter: %w[on_track at_risk] }
          end

          it 'returns work items with any of the specified health statuses' do
            expect(execute).to contain_exactly(work_item_on_track, work_item_at_risk)
          end
        end

        context 'when not_health_status param provided' do
          let(:params) do
            {
              not: {
                health_status_filter: ['needs_attention']
              }
            }
          end

          it 'returns work items without specified health status' do
            expect(execute).to contain_exactly(work_item_on_track, work_item_at_risk, work_item_without_health_status)
          end
        end

        context 'when health_status_filter with ANY provided' do
          let(:params) do
            { health_status_filter: 'ANY' }
          end

          it 'returns all work items with any health status' do
            expect(execute).to contain_exactly(work_item_on_track, work_item_needs_attention, work_item_at_risk)
          end
        end

        context 'when health_status_filter with NONE provided' do
          let(:params) do
            { health_status_filter: 'NONE' }
          end

          it 'returns work items without health status' do
            expect(execute).to contain_exactly(work_item_without_health_status)
          end
        end
      end

      context 'when searching for state' do
        let(:opened_work_item) { create(:work_item, project: project, state: 'opened') }
        let(:closed_work_item) { create(:work_item, project: project, state: 'closed') }

        before do
          Elastic::ProcessBookkeepingService.track!(opened_work_item, closed_work_item)

          ensure_elasticsearch_index!
        end

        context 'when state param is opened' do
          let(:params) do
            { state: 'opened' }
          end

          it 'returns only opened work items' do
            expect(execute).to contain_exactly(opened_work_item)
          end
        end

        context 'when state param is closed' do
          let(:params) do
            { state: 'closed' }
          end

          it 'returns only closed work items' do
            expect(execute).to contain_exactly(closed_work_item)
          end
        end

        context 'when state param is all' do
          let(:params) do
            { state: 'all' }
          end

          it 'returns all work items regardless of state' do
            expect(execute).to contain_exactly(opened_work_item, closed_work_item)
          end
        end

        context 'when state param is not provided' do
          it 'returns all work items regardless of state' do
            expect(execute).to contain_exactly(opened_work_item, closed_work_item)
          end
        end
      end

      context 'when searching for issue_types' do
        let(:issue) { create(:work_item, :issue, project: project) }
        let(:task) { create(:work_item, :task, project: project) }
        let(:requirement) { create(:work_item, :requirement, project: project) }
        let(:incident) { create(:work_item, :incident, project: project) }
        let(:test_case) { create(:work_item, :test_case, project: project) }
        let(:objective) { create(:work_item, :objective, project: project) }
        let(:key_result) { create(:work_item, :key_result, project: project) }
        let(:epic) { create(:work_item, :epic, namespace: group) }
        let(:ticket) { create(:work_item, :ticket, project: project) }

        before do
          Elastic::ProcessBookkeepingService.track!(
            issue, task, requirement, incident, test_case,
            objective, key_result, epic, ticket
          )
          ensure_elasticsearch_index!
        end

        context 'when issue_types param with single type provided' do
          let(:params) do
            { issue_types: ['issue'] }
          end

          it 'returns only work items of specified type' do
            expect(execute).to contain_exactly(issue)
          end
        end

        context 'when issue_types param with multiple types provided' do
          let(:params) do
            { issue_types: %w[issue task] }
          end

          it 'returns work items of any specified types' do
            expect(execute).to contain_exactly(issue, task)
          end
        end

        context 'when issue_types param is not provided' do
          it 'returns all work items regardless of type' do
            expect(execute).to contain_exactly(
              issue, task, requirement, incident, test_case,
              objective, key_result, epic, ticket
            )
          end
        end

        context 'when issue_types param with all supported types provided' do
          let(:params) do
            { issue_types: %w[issue task requirement incident test_case objective key_result epic ticket] }
          end

          it 'returns work items of all specified types' do
            expect(execute).to contain_exactly(
              issue, task, requirement, incident, test_case,
              objective, key_result, epic, ticket
            )
          end
        end

        context 'when issue_types param with only epic provided' do
          let(:params) do
            { issue_types: ['epic'] }
          end

          it 'returns only epic work items' do
            expect(execute).to contain_exactly(epic)
          end
        end

        context 'when issue_types param with epic and issue provided' do
          let(:params) do
            { issue_types: %w[epic issue] }
          end

          it 'returns epic and issue work items' do
            expect(execute).to contain_exactly(epic, issue)
          end
        end
      end

      context 'when searching by work_item_type_ids' do
        let_it_be(:issue) { create(:work_item, :issue, project: project) }
        let_it_be(:task) { create(:work_item, :task, project: project) }
        let_it_be(:epic) { create(:work_item, :epic, namespace: group) }
        let_it_be(:incident) { create(:work_item, :incident, project: project) }

        before do
          Elastic::ProcessBookkeepingService.track!(issue, task, epic, incident)
          ensure_elasticsearch_index!
        end

        context 'when work_item_type_ids param with single type provided' do
          let(:params) do
            { work_item_type_ids: [issue.work_item_type_id] }
          end

          it 'returns only work items of specified type' do
            expect(execute).to contain_exactly(issue)
          end
        end

        context 'when work_item_type_ids param with multiple types provided' do
          let(:params) do
            { work_item_type_ids: [issue.work_item_type_id, task.work_item_type_id] }
          end

          it 'returns work items of any specified types' do
            expect(execute).to contain_exactly(issue, task)
          end
        end

        context 'when work_item_type_ids param includes epic' do
          let(:params) do
            { work_item_type_ids: [epic.work_item_type_id, issue.work_item_type_id] }
          end

          it 'returns epic and issue work items' do
            expect(execute).to contain_exactly(epic, issue)
          end
        end

        context 'when work_item_type_ids param is not provided' do
          it 'returns all work items regardless of type' do
            expect(execute).to contain_exactly(issue, task, epic, incident)
          end
        end

        context 'when negating with work_item_type_ids' do
          let(:params) do
            { not: { work_item_type_ids: [task.work_item_type_id] } }
          end

          it 'excludes work items of specified type' do
            expect(execute).to contain_exactly(issue, epic, incident)
          end
        end

        context 'when negating with issue_types' do
          let(:params) do
            { not: { issue_types: ['task'] } }
          end

          it 'excludes work items of specified type' do
            expect(execute).to contain_exactly(issue, epic, incident)
          end
        end

        context 'when work_item_type_ids takes precedence over issue_types' do
          let(:params) do
            { work_item_type_ids: [task.work_item_type_id], issue_types: ['issue'] }
          end

          it 'filters by work_item_type_ids' do
            expect(execute).to contain_exactly(task)
          end
        end
      end

      context 'when filtering by issue_types with confidential items' do
        let(:confidential_epic) { create(:work_item, :epic, namespace: group, confidential: true) }
        let(:confidential_issue) { create(:work_item, :issue, project: project, confidential: true) }

        let(:public_epic) { create(:work_item, :epic, namespace: group, confidential: false) }
        let(:public_issue) { create(:work_item, :issue, project: project, confidential: false) }

        before do
          Elastic::ProcessBookkeepingService.track!(
            confidential_epic, confidential_issue,
            public_epic, public_issue
          )
          ensure_elasticsearch_index!
        end

        context 'when user has permissions for confidential items' do
          before_all do
            project.add_developer(current_user)
          end

          let(:params) do
            { issue_types: %w[epic issue], confidential: true }
          end

          it 'returns confidential epic and issue work items' do
            expect(execute).to contain_exactly(confidential_epic, confidential_issue)
          end
        end

        context 'when user lacks permissions for confidential items' do
          let_it_be(:guest_user) { create(:user) }
          let(:finder) { described_class.new(guest_user, context, resource_parent, params) }
          let(:params) do
            { issue_types: %w[epic issue], confidential: true }
          end

          before_all do
            project.add_guest(guest_user)
          end

          it 'returns empty list due to insufficient permissions' do
            expect(execute).to be_empty
          end
        end

        context 'when filtering for public epic and issue types' do
          let(:params) do
            { issue_types: %w[epic issue], confidential: false }
          end

          it 'returns only public epic and issue work items' do
            expect(execute).to contain_exactly(public_epic, public_issue)
          end
        end
      end

      context 'when resource_parent is a private Group without user access' do
        let_it_be(:private_group) { create(:group, :private) }
        let_it_be(:private_project) { create(:project, group: private_group) }
        let_it_be(:user_without_access) { create(:user) }

        let(:resource_parent) { private_group }
        let(:finder) { described_class.new(user_without_access, context, resource_parent, params) }

        let_it_be(:epic_in_private_group) { create(:work_item, :epic, namespace: private_group) }
        let_it_be(:issue_in_private_project) { create(:work_item, :issue, project: private_project) }
        let_it_be(:confidential_epic) { create(:work_item, :epic, namespace: private_group, confidential: true) }
        let_it_be(:confidential_issue) { create(:work_item, :issue, project: private_project, confidential: true) }

        before do
          Elastic::ProcessBookkeepingService.track!(
            epic_in_private_group,
            issue_in_private_project,
            confidential_epic,
            confidential_issue
          )
          ensure_elasticsearch_index!
        end

        context 'when filtering by issue_types' do
          let(:params) do
            { issue_types: %w[epic issue] }
          end

          it 'returns empty list due to no access to private group' do
            expect(execute).to be_empty
          end
        end

        context 'when user is added as guest to the private group' do
          before_all do
            private_group.add_guest(user_without_access)
          end

          let(:finder) { described_class.new(user_without_access, context, resource_parent, params) }

          context 'when filtering for public items' do
            let(:params) do
              { issue_types: %w[epic issue], confidential: false }
            end

            it 'returns only non-confidential items' do
              expect(execute).to contain_exactly(epic_in_private_group, issue_in_private_project)
            end
          end

          context 'when filtering for confidential items' do
            let(:params) do
              { issue_types: %w[epic issue], confidential: true }
            end

            it 'returns empty list as guest cannot see confidential items' do
              expect(execute).to be_empty
            end
          end
        end

        context 'when user is added as developer to the private group' do
          before_all do
            private_group.add_developer(user_without_access)
          end

          let(:finder) { described_class.new(user_without_access, context, resource_parent, params) }

          context 'when filtering for confidential items' do
            let(:params) do
              { issue_types: %w[epic issue], confidential: true }
            end

            it 'returns confidential items as developer has access' do
              expect(execute).to contain_exactly(confidential_epic, confidential_issue)
            end
          end
        end
      end

      context 'when searching for confidential' do
        let(:confidential_work_item) { create(:work_item, project: project, confidential: true) }
        let(:non_confidential_work_item) { create(:work_item, project: project, confidential: false) }

        before_all do
          project.add_owner(current_user)
        end

        before do
          Elastic::ProcessBookkeepingService.track!(
            confidential_work_item,
            non_confidential_work_item
          )

          ensure_elasticsearch_index!
        end

        context 'when confidential param is true' do
          let(:params) do
            { confidential: true }
          end

          it 'returns only confidential work items' do
            expect(execute).to contain_exactly(confidential_work_item)
          end
        end

        context 'when confidential param is false' do
          let(:params) do
            { confidential: false }
          end

          it 'returns only non-confidential work items' do
            expect(execute).to contain_exactly(non_confidential_work_item)
          end
        end

        context 'when confidential param is not provided' do
          it 'returns all work items regardless of confidential status' do
            expect(execute).to contain_exactly(confidential_work_item, non_confidential_work_item)
          end
        end

        context 'when user lacks permissions for confidential items' do
          let_it_be(:guest_user) { create(:user) }
          let(:params) { { confidential: true } }
          let(:finder) { described_class.new(guest_user, context, resource_parent, params) }

          before_all do
            project.add_guest(guest_user)
          end

          it 'returns no confidential work items due to insufficient permissions' do
            expect(execute).to be_empty
          end
        end
      end

      context 'when searching by dates', :freeze_time do
        context 'when searching for due dates' do
          let(:due_today) { Time.current.beginning_of_day }
          let(:due_yesterday) { 1.day.ago.beginning_of_day }
          let(:due_tomorrow) { 1.day.from_now.beginning_of_day }

          let(:work_item_due_yesterday) { create(:work_item, project: project, due_date: due_yesterday) }
          let(:work_item_due_today) { create(:work_item, project: project, due_date: due_today) }
          let(:work_item_due_tomorrow) { create(:work_item, project: project, due_date: due_tomorrow) }
          let(:work_item_without_due_date) { create(:work_item, project: project, due_date: nil) }

          before do
            Elastic::ProcessBookkeepingService.track!(
              work_item_due_yesterday,
              work_item_due_today,
              work_item_due_tomorrow,
              work_item_without_due_date
            )

            ensure_elasticsearch_index!
          end

          context 'when due_after param provided' do
            let(:params) do
              { due_after: due_today }
            end

            it 'returns work items due after specified date' do
              expect(execute).to contain_exactly(work_item_due_today, work_item_due_tomorrow)
            end
          end

          context 'when due_before param provided' do
            let(:params) do
              { due_before: due_today }
            end

            it 'returns work items due before specified date' do
              expect(execute).to contain_exactly(work_item_due_yesterday, work_item_due_today)
            end
          end

          context 'when both due_after and due_before params provided' do
            let(:params) do
              { due_after: due_yesterday, due_before: due_tomorrow }
            end

            it 'returns work items due within specified date range' do
              expect(execute).to contain_exactly(
                work_item_due_yesterday,
                work_item_due_today,
                work_item_due_tomorrow
              )
            end
          end
        end

        context 'when searching for created dates' do
          let(:created_yesterday) { 1.day.ago }
          let(:created_today) { Time.current }
          let(:created_tomorrow) { 1.day.from_now }

          let!(:work_item_created_yesterday) do
            create(:work_item, project: project, created_at: created_yesterday)
          end

          let!(:work_item_created_today) { create(:work_item, project: project, created_at: created_today) }
          let!(:work_item_created_tomorrow) { create(:work_item, project: project, created_at: created_tomorrow) }

          before do
            Elastic::ProcessBookkeepingService.track!(
              work_item_created_yesterday,
              work_item_created_today,
              work_item_created_tomorrow
            )

            ensure_elasticsearch_index!
          end

          context 'when created_after param provided' do
            let(:params) do
              { created_after: created_today }
            end

            it 'returns work items created after specified date' do
              expect(execute).to contain_exactly(work_item_created_today, work_item_created_tomorrow)
            end
          end

          context 'when created_before param provided' do
            let(:params) do
              { created_before: created_today }
            end

            it 'returns work items created before specified date' do
              expect(execute).to contain_exactly(work_item_created_yesterday, work_item_created_today)
            end
          end

          context 'when both created_after and created_before params provided' do
            let(:params) do
              { created_after: created_yesterday, created_before: created_tomorrow }
            end

            it 'returns work items created within specified date range' do
              expect(execute).to contain_exactly(
                work_item_created_yesterday,
                work_item_created_today,
                work_item_created_tomorrow
              )
            end
          end
        end

        context 'when searching for updated dates' do
          let(:updated_yesterday) { 1.day.ago }
          let(:updated_today) { Time.current }
          let(:updated_tomorrow) { 1.day.from_now }

          let!(:work_item_updated_yesterday) do
            create(:work_item, project: project, updated_at: updated_yesterday)
          end

          let!(:work_item_updated_today) { create(:work_item, project: project, updated_at: updated_today) }
          let!(:work_item_updated_tomorrow) { create(:work_item, project: project, updated_at: updated_tomorrow) }

          before do
            Elastic::ProcessBookkeepingService.track!(
              work_item_updated_yesterday,
              work_item_updated_today,
              work_item_updated_tomorrow
            )

            ensure_elasticsearch_index!
          end

          context 'when updated_after param provided' do
            let(:params) do
              { updated_after: updated_today }
            end

            it 'returns work items updated after specified date' do
              expect(execute).to contain_exactly(work_item_updated_today, work_item_updated_tomorrow)
            end
          end

          context 'when updated_before param provided' do
            let(:params) do
              { updated_before: updated_today }
            end

            it 'returns work items updated before specified date' do
              expect(execute).to contain_exactly(work_item_updated_yesterday, work_item_updated_today)
            end
          end

          context 'when both updated_after and updated_before params provided' do
            let(:params) do
              { updated_after: updated_yesterday, updated_before: updated_tomorrow }
            end

            it 'returns work items updated within specified date range' do
              expect(execute).to contain_exactly(
                work_item_updated_yesterday,
                work_item_updated_today,
                work_item_updated_tomorrow
              )
            end
          end
        end

        context 'when searching for closed dates' do
          let(:closed_yesterday) { 1.day.ago }
          let(:closed_today) { Time.current }
          let(:closed_tomorrow) { 1.day.from_now }

          let!(:work_item_closed_yesterday) do
            create(:work_item, project: project, state: 'closed', closed_at: closed_yesterday)
          end

          let!(:work_item_closed_today) do
            create(:work_item, project: project, state: 'closed', closed_at: closed_today)
          end

          let!(:work_item_closed_tomorrow) do
            create(:work_item, project: project, state: 'closed', closed_at: closed_tomorrow)
          end

          let!(:work_item_still_open) { create(:work_item, project: project, state: 'opened') }

          before do
            Elastic::ProcessBookkeepingService.track!(
              work_item_closed_yesterday,
              work_item_closed_today,
              work_item_closed_tomorrow,
              work_item_still_open
            )

            ensure_elasticsearch_index!
          end

          context 'when closed_after param provided' do
            let(:params) do
              { closed_after: closed_today }
            end

            it 'returns work items closed after specified date' do
              expect(execute).to contain_exactly(work_item_closed_today, work_item_closed_tomorrow)
            end
          end

          context 'when closed_before param provided' do
            let(:params) do
              { closed_before: closed_today }
            end

            it 'returns work items closed before specified date' do
              expect(execute).to contain_exactly(work_item_closed_yesterday, work_item_closed_today)
            end
          end

          context 'when both closed_after and closed_before params provided' do
            let(:params) do
              { closed_after: closed_yesterday, closed_before: closed_tomorrow }
            end

            it 'returns work items closed within specified date range' do
              expect(execute).to contain_exactly(
                work_item_closed_yesterday,
                work_item_closed_today,
                work_item_closed_tomorrow
              )
            end
          end
        end
      end

      context 'when searching for iids' do
        let!(:work_item1) { create(:work_item, project: project) }
        let!(:work_item2) { create(:work_item, project: project) }

        before do
          Elastic::ProcessBookkeepingService.track!(work_item1, work_item2)

          ensure_elasticsearch_index!
        end

        context 'when iids param with single iid provided' do
          let(:params) do
            { iids: [work_item1.iid] }
          end

          it 'returns work item with specified iid' do
            expect(execute).to contain_exactly(work_item1)
          end
        end

        context 'when iids param with multiple iids provided' do
          let(:params) do
            { iids: [work_item1.iid, work_item2.iid] }
          end

          it 'returns work items with specified iids' do
            expect(execute).to contain_exactly(work_item1, work_item2)
          end
        end

        context 'when iids param with non-existent iid provided' do
          let(:params) do
            { iids: [999999] }
          end

          it 'returns no work items' do
            expect(execute).to be_empty
          end
        end
      end

      context 'when sorting work items' do
        context 'when sorting by created_at', :freeze_time do
          let_it_be(:work_item_created_first) { create(:work_item, project: project, created_at: 2.days.ago) }
          let_it_be(:work_item_created_second) { create(:work_item, project: project, created_at: 1.day.ago) }
          let_it_be(:work_item_created_third) { create(:work_item, project: project, created_at: Time.current) }

          before do
            Elastic::ProcessBookkeepingService.track!(
              work_item_created_first,
              work_item_created_second,
              work_item_created_third
            )
            ensure_elasticsearch_index!
          end

          context 'with created_asc' do
            let(:params) { { sort: 'created_asc' } }

            it 'returns work items sorted by creation date ascending' do
              expect(execute).to eq([work_item_created_first, work_item_created_second, work_item_created_third])
            end
          end

          context 'with created_desc' do
            let(:params) { { sort: 'created_desc' } }

            it 'returns work items sorted by creation date descending' do
              expect(execute).to eq([work_item_created_third, work_item_created_second, work_item_created_first])
            end
          end
        end

        context 'when sorting by updated_at', :freeze_time do
          let_it_be(:work_item_updated_first) { create(:work_item, project: project, updated_at: 2.days.ago) }
          let_it_be(:work_item_updated_second) { create(:work_item, project: project, updated_at: 1.day.ago) }
          let_it_be(:work_item_updated_third) { create(:work_item, project: project, updated_at: Time.current) }

          before do
            Elastic::ProcessBookkeepingService.track!(
              work_item_updated_first,
              work_item_updated_second,
              work_item_updated_third
            )
            ensure_elasticsearch_index!
          end

          context 'with updated_asc' do
            let(:params) { { sort: 'updated_asc' } }

            it 'returns work items sorted by update date ascending' do
              expect(execute).to eq([work_item_updated_first, work_item_updated_second, work_item_updated_third])
            end
          end

          context 'with updated_desc' do
            let(:params) { { sort: 'updated_desc' } }

            it 'returns work items sorted by update date descending' do
              expect(execute).to eq([work_item_updated_third, work_item_updated_second, work_item_updated_first])
            end
          end
        end

        context 'when sorting by weight' do
          let_it_be(:work_item_with_weight_5) { create(:work_item, project: project, weight: 5) }
          let_it_be(:work_item_with_weight_10) { create(:work_item, project: project, weight: 10) }
          let_it_be(:work_item_without_weight) { create(:work_item, project: project, weight: nil) }

          before do
            Elastic::ProcessBookkeepingService.track!(
              work_item_with_weight_5,
              work_item_with_weight_10,
              work_item_without_weight
            )
            ensure_elasticsearch_index!
          end

          context 'with weight_asc' do
            let(:params) { { sort: 'weight_asc' } }

            it 'returns work items sorted by weight ascending (nulls last)' do
              expect(execute).to eq([work_item_with_weight_5, work_item_with_weight_10, work_item_without_weight])
            end
          end

          context 'with weight_desc' do
            let(:params) { { sort: 'weight_desc' } }

            it 'returns work items sorted by weight descending (nulls last)' do
              expect(execute).to eq([work_item_with_weight_10, work_item_with_weight_5, work_item_without_weight])
            end
          end
        end

        context 'when sorting by health_status' do
          let_it_be(:work_item_on_track) { create(:work_item, project: project, health_status: 'on_track') }
          let_it_be(:work_item_needs_attention) do
            create(:work_item, project: project, health_status: 'needs_attention')
          end

          let_it_be(:work_item_at_risk) { create(:work_item, project: project, health_status: 'at_risk') }

          before do
            Elastic::ProcessBookkeepingService.track!(
              work_item_on_track,
              work_item_needs_attention,
              work_item_at_risk
            )
            ensure_elasticsearch_index!
          end

          context 'with health_status_asc' do
            let(:params) { { sort: 'health_status_asc' } }

            it 'returns work items sorted by health status ascending' do
              expect(execute).to eq([work_item_on_track, work_item_needs_attention, work_item_at_risk])
            end
          end

          context 'with health_status_desc' do
            let(:params) { { sort: 'health_status_desc' } }

            it 'returns work items sorted by health status descending' do
              expect(execute).to eq([work_item_at_risk, work_item_needs_attention, work_item_on_track])
            end
          end
        end

        context 'when sorting by closed_at', :freeze_time do
          let_it_be(:work_item_closed_first) do
            create(:work_item, project: project, state: 'closed', closed_at: 3.days.ago)
          end

          let_it_be(:work_item_closed_second) do
            create(:work_item, project: project, state: 'closed', closed_at: 1.day.ago)
          end

          let_it_be(:work_item_open) { create(:work_item, project: project, state: 'opened') }

          before do
            Elastic::ProcessBookkeepingService.track!(
              work_item_closed_first,
              work_item_closed_second,
              work_item_open
            )
            ensure_elasticsearch_index!
          end

          context 'with closed_asc' do
            let(:params) { { sort: 'closed_at_asc' } }

            it 'returns work items sorted by closed date ascending (open items last)' do
              expect(execute).to eq([work_item_closed_first, work_item_closed_second, work_item_open])
            end
          end

          context 'with closed_desc' do
            let(:params) { { sort: 'closed_at_desc' } }

            it 'returns work items sorted by closed date descending (open items last)' do
              expect(execute).to eq([work_item_closed_second, work_item_closed_first, work_item_open])
            end
          end
        end

        context 'when sorting by due_date', :freeze_time do
          let_it_be(:work_item_due_yesterday) { create(:work_item, project: project, due_date: 1.day.ago) }
          let_it_be(:work_item_due_tomorrow) { create(:work_item, project: project, due_date: 1.day.from_now) }
          let_it_be(:work_item_due_next_week) { create(:work_item, project: project, due_date: 1.week.from_now) }

          before do
            Elastic::ProcessBookkeepingService.track!(
              work_item_due_yesterday,
              work_item_due_tomorrow,
              work_item_due_next_week
            )
            ensure_elasticsearch_index!
          end

          context 'with due_asc' do
            let(:params) { { sort: 'due_date_asc' } }

            it 'returns work items sorted by due date ascending' do
              expect(execute).to eq([work_item_due_yesterday, work_item_due_tomorrow, work_item_due_next_week])
            end
          end

          context 'with due_desc' do
            let(:params) { { sort: 'due_date_desc' } }

            it 'returns work items sorted by due date descending' do
              expect(execute).to eq([work_item_due_next_week, work_item_due_tomorrow, work_item_due_yesterday])
            end
          end
        end

        context 'when sorting by milestone_due', :freeze_time do
          let_it_be(:milestone_due_soon) { create(:milestone, group: group, due_date: 2.days.from_now) }
          let_it_be(:milestone_due_later) { create(:milestone, group: group, due_date: 1.week.from_now) }
          let_it_be(:work_item_milestone_soon) { create(:work_item, project: project, milestone: milestone_due_soon) }
          let_it_be(:work_item_milestone_later) { create(:work_item, project: project, milestone: milestone_due_later) }
          let_it_be(:work_item_no_milestone) { create(:work_item, project: project) }

          before do
            Elastic::ProcessBookkeepingService.track!(
              work_item_milestone_soon,
              work_item_milestone_later,
              work_item_no_milestone
            )
            ensure_elasticsearch_index!
          end

          context 'with milestone_due_asc' do
            let(:params) { { sort: 'milestone_due_asc' } }

            it 'returns work items sorted by milestone due date ascending' do
              expect(execute).to eq([work_item_milestone_soon, work_item_milestone_later, work_item_no_milestone])
            end
          end

          context 'with milestone_due_desc' do
            let(:params) { { sort: 'milestone_due_desc' } }

            it 'returns work items sorted by milestone due date descending' do
              expect(execute).to eq([work_item_milestone_later, work_item_milestone_soon, work_item_no_milestone])
            end
          end
        end

        context 'when sorting by popularity' do
          let_it_be(:work_item_popular) { create(:work_item, project: project, upvotes_count: 10) }
          let_it_be(:work_item_less_popular) { create(:work_item, project: project, upvotes_count: 5) }
          let_it_be(:work_item_unpopular) { create(:work_item, project: project, upvotes_count: 0) }

          before do
            Elastic::ProcessBookkeepingService.track!(
              work_item_popular,
              work_item_less_popular,
              work_item_unpopular
            )
            ensure_elasticsearch_index!
          end

          context 'with popularity_asc' do
            let(:params) { { sort: 'popularity_asc' } }

            it 'returns work items sorted by popularity ascending' do
              expect(execute).to eq([work_item_unpopular, work_item_less_popular, work_item_popular])
            end
          end

          context 'with popularity_desc' do
            let(:params) { { sort: 'popularity_desc' } }

            it 'returns work items sorted by popularity descending' do
              expect(execute).to eq([work_item_popular, work_item_less_popular, work_item_unpopular])
            end
          end
        end

        context 'when sort param is not provided', :freeze_time do
          let_it_be(:work_item_created_first) { create(:work_item, project: project, created_at: 2.days.ago) }
          let(:params) { {} }
          let_it_be(:work_item_created_second) { create(:work_item, project: project, created_at: 1.day.ago) }
          let_it_be(:work_item_created_third) { create(:work_item, project: project, created_at: Time.current) }

          before do
            Elastic::ProcessBookkeepingService.track!(
              work_item_created_first,
              work_item_created_second,
              work_item_created_third
            )
            ensure_elasticsearch_index!
          end

          it 'uses default sorting (created_desc)' do
            expect(execute).to eq([work_item_created_third, work_item_created_second, work_item_created_first])
          end
        end
      end
    end

    context 'when resource_parent is a Project' do
      let_it_be(:other_project) { create(:project, namespace: group) }
      let(:resource_parent) { project }

      let_it_be(:work_item_in_project) { create(:work_item, project: project) }
      let_it_be(:work_item_in_other_project) { create(:work_item, project: other_project) }

      before_all do
        project.add_reporter(current_user)
        other_project.add_reporter(current_user)
      end

      before do
        Elastic::ProcessBookkeepingService.track!(
          work_item_in_project,
          work_item_in_other_project
        )

        ensure_elasticsearch_index!
      end

      it 'returns work items only from the specified project' do
        expect(execute).to contain_exactly(work_item_in_project)
      end

      context 'when resource_parent is a private Project' do
        let_it_be(:private_project) { create(:project, :private, namespace: group) }
        let_it_be(:user_without_access) { create(:user) }
        let(:resource_parent) { private_project }

        let_it_be(:work_item_in_private_project) { create(:work_item, project: private_project) }

        before do
          Elastic::ProcessBookkeepingService.track!(work_item_in_private_project)
          ensure_elasticsearch_index!
        end

        context 'when user has no access to private project' do
          let(:finder) { described_class.new(user_without_access, context, resource_parent, params) }

          it 'returns no work items due to insufficient permissions' do
            expect(execute).to be_empty
          end
        end
      end
    end

    context 'when resource_parent is a public Group with mixed project visibility' do
      let_it_be(:public_group) { create(:group, :public) }
      let_it_be(:public_project_in_group) { create(:project, :public, namespace: public_group) }
      let_it_be(:private_project_in_group) { create(:project, :private, namespace: public_group) }
      let_it_be(:user_without_private_access) { create(:user) }

      let(:resource_parent) { public_group }

      let_it_be(:work_item_in_public_project) { create(:work_item, project: public_project_in_group) }
      let_it_be(:work_item_in_private_project) { create(:work_item, project: private_project_in_group) }

      before_all do
        # Give current_user access to both projects,
        # while user_without_private_access has no explicit access to private project
        public_project_in_group.add_reporter(current_user)
        private_project_in_group.add_reporter(current_user)
      end

      before do
        Elastic::ProcessBookkeepingService.track!(
          work_item_in_public_project,
          work_item_in_private_project
        )

        ensure_elasticsearch_index!
      end

      context 'when user has access to both projects' do
        let(:finder) { described_class.new(current_user, context, resource_parent, params) }

        it 'returns work items from both public and private projects' do
          expect(execute).to contain_exactly(work_item_in_public_project, work_item_in_private_project)
        end
      end

      context 'when user has access only to public project' do
        let(:finder) { described_class.new(user_without_private_access, context, resource_parent, params) }

        it 'returns only work items from public project' do
          expect(execute).to contain_exactly(work_item_in_public_project)
        end
      end
    end
  end

  describe '#es_search_options' do
    let(:resource_parent) { group }
    let(:finder) { described_class.new(current_user, context, resource_parent, params) }

    subject(:es_search_options) { finder.es_search_options }

    it 'includes index_name' do
      expect(es_search_options[:index_name]).to eq(Search::Elastic::References::WorkItem.index)
    end

    it 'includes root_ancestor_ids' do
      expect(es_search_options[:root_ancestor_ids]).to eq([group.root_ancestor.id])
    end

    context 'when resource_parent is a Project' do
      let(:resource_parent) { project }

      it 'includes root_ancestor_ids from project namespace' do
        expect(es_search_options[:root_ancestor_ids]).to eq([project.root_ancestor.id])
      end
    end

    context 'when resource_parent is a Group' do
      let(:resource_parent) { group }

      it 'includes root_ancestor_ids from group' do
        expect(es_search_options[:root_ancestor_ids]).to eq([group.root_ancestor.id])
      end
    end

    context 'with nested group structure' do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:child_group) { create(:group, parent: parent_group) }
      let_it_be(:grandchild_group) { create(:group, parent: child_group) }
      let(:resource_parent) { grandchild_group }

      it 'includes root_ancestor_ids from the top-level group' do
        expect(es_search_options[:root_ancestor_ids]).to eq([parent_group.id])
      end
    end
  end

  describe '#root_ancestor_ids' do
    let(:resource_parent) { group }
    let(:finder) { described_class.new(current_user, context, resource_parent, params) }

    subject(:root_ancestor_ids) { finder.root_ancestor_ids }

    it 'returns an array with root ancestor id' do
      expect(root_ancestor_ids).to eq([group.root_ancestor.id])
    end

    context 'when resource_parent is a Project' do
      let(:resource_parent) { project }

      it 'returns root ancestor id from project namespace' do
        expect(root_ancestor_ids).to eq([project.root_ancestor.id])
      end
    end

    context 'when resource_parent is a Group' do
      let(:resource_parent) { group }

      it 'returns root ancestor id from group' do
        expect(root_ancestor_ids).to eq([group.root_ancestor.id])
      end
    end
  end

  describe 'Elasticsearch routing parameter' do
    let(:resource_parent) { group }
    let(:finder) { described_class.new(current_user, context, resource_parent, params) }

    before_all do
      group.add_reporter(current_user)
    end

    context 'when executing a query for a group' do
      it 'includes routing parameter in the Elasticsearch request' do
        finder.execute.to_a

        assert_routing_field("group_#{group.root_ancestor.id}")
      end
    end

    context 'when executing a query for a project' do
      let(:resource_parent) { project }

      before_all do
        project.add_reporter(current_user)
      end

      it 'includes routing parameter in the Elasticsearch request' do
        finder.execute.to_a

        assert_routing_field("group_#{project.root_ancestor.id}")
      end
    end

    context 'with nested group structure' do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:child_group) { create(:group, parent: parent_group) }
      let(:resource_parent) { child_group }

      before_all do
        child_group.add_reporter(current_user)
      end

      it 'routes to the root ancestor group' do
        finder.execute.to_a

        assert_routing_field("group_#{parent_group.id}")
      end
    end
  end
end
