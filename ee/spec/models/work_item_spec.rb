# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItem, :elastic_helpers, feature_category: :team_planning do
  let_it_be(:reusable_project) { create(:project) }
  let_it_be(:reusable_group) { create(:group) }
  let_it_be(:user) { create(:user) }

  it 'has one `color`' do
    is_expected.to have_one(:color)
      .class_name('WorkItems::Color')
      .with_foreign_key('issue_id')
      .inverse_of(:work_item)
  end

  it 'has one `synced_epic`' do
    is_expected.to have_one(:synced_epic)
      .class_name('Epic')
      .with_foreign_key('issue_id')
      .inverse_of(:work_item)
  end

  it { is_expected.to have_one(:current_status).class_name('WorkItems::Statuses::CurrentStatus') }

  it 'has many `duo_workflow_links`' do
    is_expected.to have_many(:duo_workflow_links)
      .class_name('Ai::DuoWorkflows::WorkflowWorkItem').with_foreign_key(:work_item_id).inverse_of(:work_item)
  end

  it { is_expected.to have_many(:linked_duo_workflows).through(:duo_workflow_links).source(:workflow) }

  describe 'custom validations' do
    subject(:valid?) { work_item.valid? }

    describe 'due_date_after_start_date' do
      context 'when type is epic' do
        context 'when both values are not present' do
          let(:work_item) { build(:work_item, :epic, namespace: reusable_group) }

          it { is_expected.to be_truthy }
        end

        context 'when due date is before start date' do
          let(:work_item) do
            build(:work_item, :epic, namespace: reusable_group, due_date: 1.week.ago, start_date: 1.week.from_now)
          end

          it { is_expected.to be_truthy }
        end
      end
    end
  end

  describe '#sync_callback_class' do
    context 'with non existent callback class' do
      it 'returns nil' do
        expect(described_class.sync_callback_class('fake_association')).to be_nil
      end
    end

    context 'with existent callback class' do
      it 'returns nil' do
        expect(described_class.sync_callback_class('pending_escalations')).to eq(
          ::WorkItems::DataSync::NonWidgets::PendingEscalations
        )
      end
    end
  end

  describe '#supported_quick_action_commands' do
    let(:work_item) { build(:work_item, :issue) }

    subject { work_item.supported_quick_action_commands }

    before do
      stub_licensed_features(issuable_health_status: true, issue_weights: true)
    end

    context 'when work item supports the health status widget' do
      let(:work_item) { build(:work_item, :objective) }

      it 'returns health status related quick action commands' do
        is_expected.to include(:health_status, :clear_health_status)
      end
    end

    context 'when work item does not the health status widget' do
      let(:work_item) { build(:work_item, :task) }

      it 'omits assignee related quick action commands' do
        is_expected.not_to include(:health_status, :clear_health_status)
      end
    end

    context 'when work item supports the weight widget' do
      let(:work_item) { build(:work_item, :task) }

      it 'returns labels related quick action commands' do
        is_expected.to include(:weight, :clear_weight)
      end
    end

    context 'when work item does not support the weight widget' do
      let(:work_item) { build(:work_item, :objective) }

      it 'omits labels related quick action commands' do
        is_expected.not_to include(:weight, :clear_weight)
      end
    end

    it 'includes ee specific quick actions' do
      is_expected.to include(:q)
    end
  end

  describe 'callbacks' do
    describe 'record_create_action', :clean_gitlab_redis_shared_state do
      context 'when work item is of type epic' do
        it "triggers an internal event" do
          expect { create(:work_item, :epic, project: reusable_project, author: user) }
            .to trigger_internal_events('users_creating_work_items').with(
              project: reusable_project,
              namespace: reusable_project.project_namespace,
              user: user,
              additional_properties: {
                label: 'epic'
              }
            ).and increment_usage_metrics(
              'redis_hll_counters.count_distinct_user_id_from_create_work_type_epic_monthly',
              'redis_hll_counters.count_distinct_user_id_from_create_work_type_epic_weekly',
              'counts_weekly.aggregated_metrics.users_work_items',
              'counts_monthly.aggregated_metrics.users_work_items'
            )
        end
      end
    end
  end

  context 'with hierarchy' do
    let_it_be(:epic1) { create(:work_item, :epic, project: reusable_project) }
    let_it_be(:epic2) { create(:work_item, :epic, project: reusable_project) }
    let_it_be(:epic3) { create(:work_item, :epic, project: reusable_project) }
    let_it_be(:issue1) { create(:work_item, :issue, project: reusable_project) }
    let_it_be(:issue2) { create(:work_item, :issue, project: reusable_project) }
    let_it_be(:task1) { create(:work_item, :task, project: reusable_project) }
    let_it_be(:task2) { create(:work_item, :task, project: reusable_project) }

    let_it_be(:ignored_ancestor) { create(:work_item, :epic, project: reusable_project) }
    let_it_be(:ignored_descendant) { create(:work_item, :task, project: reusable_project) }

    # Create the hierarchy:
    # epic1 -> epic2 -> epic3 -> issue1 -> task1
    #                         \-> issue2 -> task2
    let_it_be(:link1) { create(:parent_link, work_item_parent: epic1, work_item: epic2) }
    let_it_be(:link2) { create(:parent_link, work_item_parent: epic2, work_item: epic3) }
    let_it_be(:link3) { create(:parent_link, work_item_parent: epic3, work_item: issue1) }
    let_it_be(:link4) { create(:parent_link, work_item_parent: epic3, work_item: issue2) }
    let_it_be(:link5) { create(:parent_link, work_item_parent: issue1, work_item: task1) }
    let_it_be(:link6) { create(:parent_link, work_item_parent: issue2, work_item: task2) }

    describe '#ancestors' do
      it 'returns all ancestors in ascending order' do
        expect(task1.ancestors).to eq([issue1, epic3, epic2, epic1])
      end

      it 'returns an empty array if there are no ancestors' do
        expect(epic1.ancestors).to be_empty
      end
    end

    describe '#ancestors_with_order' do
      it 'returns all ancestors in ascending order by default' do
        expect(task1.ancestors_with_order).to eq([issue1, epic3, epic2, epic1])
      end

      it 'returns all ancestors in ascending order when explicitly specified' do
        expect(task1.ancestors_with_order(hierarchy_order: :asc)).to eq([issue1, epic3, epic2, epic1])
      end

      it 'returns all ancestors in descending order' do
        expect(task1.ancestors_with_order(hierarchy_order: :desc)).to eq([epic1, epic2, epic3, issue1])
      end

      it 'returns an empty array if there are no ancestors' do
        expect(epic1.ancestors_with_order).to be_empty
      end

      context 'with mixed work item types' do
        it 'returns ancestors of all types in ascending order' do
          ancestors = task1.ancestors_with_order(hierarchy_order: :asc)

          expect(ancestors.map(&:work_item_type).map(&:base_type)).to eq(%w[issue epic epic epic])
        end

        it 'returns ancestors of all types in descending order' do
          ancestors = task1.ancestors_with_order(hierarchy_order: :desc)

          expect(ancestors.map(&:work_item_type).map(&:base_type)).to eq(%w[epic epic epic issue])
        end
      end

      context 'with branching hierarchy' do
        it 'returns correct ascending order for parallel branch' do
          expect(task2.ancestors_with_order(hierarchy_order: :asc)).to eq([issue2, epic3, epic2, epic1])
        end

        it 'returns correct descending order for parallel branch' do
          expect(task2.ancestors_with_order(hierarchy_order: :desc)).to eq([epic1, epic2, epic3, issue2])
        end

        it 'both branches return same root ancestor' do
          task1_ancestors = task1.ancestors_with_order(hierarchy_order: :asc)
          task2_ancestors = task2.ancestors_with_order(hierarchy_order: :asc)

          expect(task1_ancestors.last).to eq(epic1)
          expect(task2_ancestors.last).to eq(epic1)
        end
      end
    end

    describe '#descendants' do
      it 'returns all descendants' do
        expect(epic1.descendants).to match_array([epic2, epic3, issue1, issue2, task1, task2])
      end
    end

    describe '#same_type_base_and_ancestors' do
      it 'returns self and all ancestors of the same type in ascending order' do
        expect(epic3.same_type_base_and_ancestors).to eq([epic3, epic2, epic1])
      end

      it 'returns self if there are no ancestors of the same type' do
        expect(issue1.same_type_base_and_ancestors).to match_array([issue1])
      end
    end

    describe '#same_type_descendants_depth' do
      it 'returns max descendants depth including self' do
        # epic1 has epic2 and epic3 as same-type descendants, so depth is 3
        expect(epic1.same_type_descendants_depth).to eq(3)
      end

      it 'returns 1 if there are no descendants' do
        expect(task1.same_type_descendants_depth).to eq(1)
      end
    end
  end

  describe '#max_depth_reached?' do
    let_it_be(:work_item, freeze: false) { create(:work_item) }
    let(:child_type) { build(:work_item_system_defined_type) }

    context 'when there is no hierarchy restriction' do
      it 'returns false' do
        expect(work_item.max_depth_reached?(child_type)).to be false
      end
    end

    context 'when there is a hierarchy restriction with maximum depth' do
      context 'when work item type is the same as child type' do
        using RSpec::Parameterized::TableSyntax

        where(:work_item_base_type, :max_depth) do
          :epic      | 7
          :objective | 9
        end

        with_them do
          let(:work_item) { create(:work_item, work_item_base_type, project: reusable_project) }
          let(:child_type) { work_item.work_item_type }

          it 'returns true when depth is reached' do
            allow(work_item).to receive_message_chain(:same_type_base_and_ancestors, :count).and_return(max_depth)
            expect(work_item.max_depth_reached?(child_type)).to be true
          end

          it 'returns false when depth is not reached' do
            allow(work_item).to receive_message_chain(:same_type_base_and_ancestors, :count).and_return(max_depth - 1)
            expect(work_item.max_depth_reached?(child_type)).to be false
          end
        end
      end

      context 'when work item type is different from child type' do
        # Epic can have Issue children with max depth 1
        let(:work_item) { create(:work_item, :epic, project: reusable_project) }
        let(:child_type) { build(:work_item_system_defined_type, :issue) }
        let(:max_depth) { 1 } # Epic->Issue has max depth 1

        it 'returns true when depth is reached' do
          allow(work_item).to receive_message_chain(:hierarchy, :base_and_ancestors, :count).and_return(max_depth)
          expect(work_item.max_depth_reached?(child_type)).to be true
        end

        it 'returns false when depth is not reached' do
          allow(work_item).to receive_message_chain(:hierarchy, :base_and_ancestors, :count).and_return(max_depth - 1)
          expect(work_item.max_depth_reached?(child_type)).to be false
        end
      end
    end
  end

  describe '#widgets' do
    subject(:widgets) { build(:work_item).widgets }

    context "for widget definition" do
      it 'instantiates widgets with their widget definition' do
        expect(widgets.map(&:widget_definition))
          .to all(be_instance_of(WorkItems::TypesFramework::SystemDefined::WidgetDefinition))
      end
    end

    context 'for weight widget' do
      context 'when issuable weights is licensed' do
        before do
          stub_licensed_features(issue_weights: true)
        end

        it 'returns an instance of the weight widget' do
          is_expected.to include(instance_of(WorkItems::Widgets::Weight))
        end
      end

      context 'when issuable weights is unlicensed' do
        before do
          stub_licensed_features(issue_weights: false)
        end

        it 'omits an instance of the weight widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::Weight))
        end
      end
    end

    context 'for verification status widget', feature_category: :requirements_management do
      subject { build(:work_item, :requirement).widgets }

      context 'when requirements is licensed' do
        before do
          stub_licensed_features(requirements: true)
        end

        it 'returns an instance of the status widget' do
          is_expected.to include(instance_of(WorkItems::Widgets::VerificationStatus))
        end
      end

      context 'when verification status is unlicensed' do
        before do
          stub_licensed_features(requirements: false)
        end

        it 'omits an instance of the verification status widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::VerificationStatus))
        end
      end
    end

    context 'for iteration widget' do
      context 'when iterations is licensed' do
        let_it_be(:group) { create(:group) }
        let_it_be(:project) { create(:project, group: group) }

        subject { build(:work_item, *work_item_type, project: project).widgets }

        before do
          stub_licensed_features(iterations: true)
        end

        context 'when work item supports iteration' do
          where(:work_item_type) { [:task, :issue] }

          with_them do
            it 'returns an instance of the iteration widget' do
              is_expected.to include(instance_of(WorkItems::Widgets::Iteration))
            end
          end
        end

        context 'when work item does not support iteration' do
          let(:work_item_type) { :requirement }

          it 'omits an instance of the iteration widget' do
            is_expected.not_to include(instance_of(WorkItems::Widgets::Iteration))
          end
        end
      end

      context 'when iterations is unlicensed' do
        before do
          stub_licensed_features(iterations: false)
        end

        it 'omits an instance of the iteration widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::Iteration))
        end
      end
    end

    context 'for progress widget' do
      context 'when okrs is licensed' do
        subject { build(:work_item, *work_item_type).widgets }

        before do
          stub_licensed_features(okrs: true)
        end

        context 'when work item supports progress' do
          let(:work_item_type) { [:objective] }

          it 'returns an instance of the progress widget' do
            is_expected.to include(instance_of(WorkItems::Widgets::Progress))
          end
        end

        context 'when work item does not support progress' do
          let(:work_item_type) { :requirement }

          it 'omits an instance of the progress widget' do
            is_expected.not_to include(instance_of(WorkItems::Widgets::Progress))
          end
        end
      end

      context 'when okrs is unlicensed' do
        before do
          stub_licensed_features(okrs: false)
        end

        it 'omits an instance of the progress widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::Progress))
        end
      end
    end

    context 'for color widget' do
      context 'when epic color is licensed' do
        subject { build(:work_item, *work_item_type).widgets }

        before do
          stub_licensed_features(epic_colors: true)
        end

        context 'when work item supports color' do
          let(:work_item_type) { [:epic] }

          it 'returns an instance of the color widget' do
            is_expected.to include(instance_of(WorkItems::Widgets::Color))
          end
        end

        context 'when work item does not support color' do
          let(:work_item_type) { :requirement }

          it 'omits an instance of the color widget' do
            is_expected.not_to include(instance_of(WorkItems::Widgets::Color))
          end
        end
      end

      context 'when epic_colors is unlicensed' do
        before do
          stub_licensed_features(epic_colors: false)
        end

        it 'omits an instance of the color widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::Color))
        end
      end
    end

    context 'for health status widget' do
      context 'when issuable_health_status is licensed' do
        subject { build(:work_item, *work_item_type).widgets }

        before do
          stub_licensed_features(issuable_health_status: true)
        end

        context 'when work item supports health_status' do
          where(:work_item_type) { [:issue, :objective, :key_result] }

          with_them do
            it 'returns an instance of the health status widget' do
              is_expected.to include(instance_of(WorkItems::Widgets::HealthStatus))
            end
          end
        end

        context 'when work item does not support health status' do
          where(:work_item_type) { [:test_case, :requirement] }

          with_them do
            it 'omits an instance of the health status widget' do
              is_expected.not_to include(instance_of(WorkItems::Widgets::HealthStatus))
            end
          end
        end
      end

      context 'when issuable_health_status is unlicensed' do
        before do
          stub_licensed_features(issuable_health_status: false)
        end

        it 'omits an instance of the health status widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::HealthStatus))
        end
      end
    end

    context 'for legacy requirement widget', feature_category: :requirements_management do
      let(:work_item_type) { [:requirement] }

      context 'when requirements feature is licensed' do
        subject { build(:work_item, *work_item_type).widgets }

        before do
          stub_licensed_features(requirements: true)
        end

        context 'when work item supports legacy requirement' do
          it 'returns an instance of the legacy requirement widget' do
            is_expected.to include(instance_of(WorkItems::Widgets::RequirementLegacy))
          end
        end

        context 'when work item does not support legacy requirement' do
          where(:work_item_type) { [:test_case, :issue, :objective, :key_result] }

          with_them do
            it 'omits an instance of the legacy requirement widget' do
              is_expected.not_to include(instance_of(WorkItems::Widgets::RequirementLegacy))
            end
          end
        end
      end

      context 'when requirements feature is unlicensed' do
        before do
          stub_licensed_features(requirements: false)
        end

        it 'omits an instance of the legacy requirement widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::RequirementLegacy))
        end
      end
    end
  end

  describe '#average_progress_of_children' do
    let_it_be_with_reload(:parent_work_item) { create(:work_item, :objective, project: reusable_project) }
    let_it_be_with_reload(:child_work_item1) { create(:work_item, :objective, project: reusable_project) }
    let_it_be_with_reload(:child_work_item2) { create(:work_item, :objective, project: reusable_project) }
    let_it_be_with_reload(:child_work_item3) { create(:work_item, :objective, project: reusable_project) }
    let_it_be_with_reload(:child1_progress) { create(:progress, work_item: child_work_item1, progress: 20) }
    let_it_be_with_reload(:child2_progress) { create(:progress, work_item: child_work_item2, progress: 30) }
    let_it_be_with_reload(:child3_progress) { create(:progress, work_item: child_work_item3, progress: 30) }

    context 'when workitem has zero children' do
      it 'returns 0 as average' do
        expect(parent_work_item.average_progress_of_children).to eq(0)
      end
    end

    context 'when work item has children' do
      before_all do
        create(:parent_link, work_item: child_work_item1, work_item_parent: parent_work_item)
        create(:parent_link, work_item: child_work_item2, work_item_parent: parent_work_item)
      end

      it 'returns the average of children progress' do
        expect(parent_work_item.average_progress_of_children).to eq(25)
      end

      it 'rounds the average to lower number' do
        create(:parent_link, work_item: child_work_item3, work_item_parent: parent_work_item)

        expect(parent_work_item.average_progress_of_children).to eq(26)
      end
    end
  end

  it_behaves_like 'a collection filtered by test reports state', feature_category: :requirements_management do
    let_it_be(:requirement1) { create(:work_item, :requirement) }
    let_it_be(:requirement2) { create(:work_item, :requirement) }
    let_it_be(:requirement3) { create(:work_item, :requirement) }
    let_it_be(:requirement4) { create(:work_item, :requirement) }

    before do
      create(:test_report, requirement_issue: requirement1, state: :passed)
      create(:test_report, requirement_issue: requirement1, state: :failed)
      create(:test_report, requirement_issue: requirement2, state: :failed)
      create(:test_report, requirement_issue: requirement2, state: :passed)
      create(:test_report, requirement_issue: requirement3, state: :passed)
    end
  end

  describe '#linked_work_items', feature_category: :portfolio_management do
    let_it_be(:user) { create(:user) }

    let_it_be(:authorized_project) { create(:project, :private) }
    let_it_be(:work_item, freeze: false) { create(:work_item, project: authorized_project) }
    let_it_be(:authorized_item_a) { create(:work_item, project: authorized_project) }
    let_it_be(:authorized_item_b, freeze: false) { create(:work_item, project: authorized_project) }

    let_it_be(:unauthorized_project) { create(:project, :private) }
    let_it_be(:unauthorized_item_a) { create(:work_item, project: unauthorized_project) }
    let_it_be(:unauthorized_item_b, freeze: false) { create(:work_item, project: unauthorized_project) }

    let_it_be(:link_a) { create(:work_item_link, source: work_item, target: authorized_item_a, link_type: 'blocks') }
    let_it_be(:link_b, freeze: false) do
      create(:work_item_link, source: authorized_item_b, target: work_item, link_type: 'blocks')
    end

    let_it_be(:unauthorized_link_a) do
      create(:work_item_link, source: work_item, target: unauthorized_item_a, link_type: 'blocks')
    end

    let_it_be(:unauthorized_link_b, freeze: false) do
      create(:work_item_link, source: unauthorized_item_b, target: work_item, link_type: 'blocks')
    end

    before_all do
      authorized_project.add_guest(user)
    end

    it 'returns only authorized linked items for given user' do
      expect(work_item.linked_work_items(user))
        .to contain_exactly(authorized_item_a, authorized_item_b)
    end

    context 'when filtering by link type' do
      it 'returns authorized items with link type `blocks`' do
        expect(work_item.linked_work_items(user, link_type: 'blocks'))
          .to contain_exactly(authorized_item_a)
      end

      it 'returns authorized items with link type `is_blocked_by`' do
        expect(work_item.linked_work_items(user, link_type: 'is_blocked_by'))
          .to contain_exactly(authorized_item_b)
      end
    end
  end

  describe '.with_reminder_frequency' do
    let(:frequency) { 'weekly' }
    let_it_be(:weekly_reminder_work_item) { create(:work_item, project: reusable_project) }
    let_it_be(:weekly_progress) do
      create(:progress, work_item: weekly_reminder_work_item, reminder_frequency: 'weekly')
    end

    let_it_be(:monthly_reminder_work_item) { create(:work_item, project: reusable_project) }
    let_it_be(:montly_progress) do
      create(:progress, work_item: monthly_reminder_work_item, reminder_frequency: 'monthly')
    end

    let_it_be(:no_reminder_work_item) { create(:work_item, project: reusable_project) }

    subject { described_class.with_reminder_frequency(frequency) }

    it { is_expected.to contain_exactly(weekly_reminder_work_item) }
  end

  describe '.without_parent' do
    let_it_be(:parent_work_item) { create(:work_item, :objective, project: reusable_project) }
    let_it_be(:work_item_with_parent) { create(:work_item, :key_result, project: reusable_project) }
    let_it_be(:parent_link) do
      create(:parent_link, work_item_parent: parent_work_item, work_item: work_item_with_parent)
    end

    let_it_be(:work_item_without_parent) { create(:work_item, :key_result, project: reusable_project) }

    subject { described_class.without_parent }

    it { is_expected.to contain_exactly(parent_work_item, work_item_without_parent) }
  end

  describe '.with_assignees' do
    let_it_be(:user) { create(:user) }
    let_it_be(:with_assignee) { create(:work_item, project: reusable_project) }
    let_it_be(:without_assignee) { create(:work_item, :key_result, project: reusable_project) }

    before_all do
      with_assignee.assignees = [user]
    end

    subject { described_class.with_assignees }

    it { is_expected.to contain_exactly(with_assignee) }
  end

  describe '.with_descendents_of' do
    let_it_be(:parent_work_item) { create(:work_item, :objective, project: reusable_project) }
    let_it_be(:work_item_with_parent) { create(:work_item, :key_result, project: reusable_project) }
    let_it_be(:parent_link) do
      create(:parent_link, work_item_parent: parent_work_item, work_item: work_item_with_parent)
    end

    let_it_be(:work_item_without_child) { create(:work_item, :key_result, project: reusable_project) }

    subject { described_class.with_descendents_of([parent_work_item.id, work_item_without_child.id]) }

    it { is_expected.to contain_exactly(work_item_with_parent) }
  end

  describe '.with_previous_reminder_sent_before' do
    let_it_be(:work_item_without_progress) { create(:work_item, :objective, project: reusable_project) }
    let_it_be(:work_item_with_recent_reminder) { create(:work_item, :objective, project: reusable_project) }
    let_it_be(:work_item_with_stale_reminder) { create(:work_item, :objective, project: reusable_project) }
    let_it_be(:recent_reminder) do
      create(:progress, work_item: work_item_with_recent_reminder, last_reminder_sent_at: 1.day.ago)
    end

    let_it_be(:stale_reminder) do
      create(:progress, work_item: work_item_with_stale_reminder, last_reminder_sent_at: 3.days.ago)
    end

    subject { described_class.with_previous_reminder_sent_before(2.days.ago) }

    it { is_expected.to contain_exactly(work_item_without_progress, work_item_with_stale_reminder) }
  end

  # rubocop:disable RSpec/MultipleMemoizedHelpers -- Extra helpers are required for checking all scenarios
  describe 'status scopes' do
    let_it_be(:reusable_group_2) { create(:group) }
    let_it_be(:project) { create(:project, group: reusable_group) }
    let_it_be(:project_2) { create(:project, group: reusable_group_2) }

    let_it_be(:issue_work_item_type) { build(:work_item_system_defined_type, :issue) }

    let_it_be(:wi_no_status) { create(:work_item, :incident, project: project) }
    let_it_be(:wi_default_open) { create(:work_item, project: project, created_at: 2.days.ago) }
    let_it_be(:wi_default_closed) { create(:work_item, :closed, project: project, created_at: 2.days.ago) }
    let_it_be(:wi_default_duplicated) do
      create(:work_item, :closed, project: project, duplicated_to_id: wi_default_closed.id, created_at: 2.days.ago)
    end

    let_it_be(:system_defined_todo_status) { build(:work_item_system_defined_status, :to_do) }
    let_it_be(:system_defined_in_progress_status) { build(:work_item_system_defined_status, :in_progress) }
    let_it_be(:system_defined_done_status) { build(:work_item_system_defined_status, :done) }
    let_it_be(:system_defined_duplicate_status) { build(:work_item_system_defined_status, :duplicate) }
    let_it_be(:system_defined_wont_do_status) { build(:work_item_system_defined_status, :wont_do) }

    let_it_be(:wi_system_defined_todo) do
      create(:work_item, project: project, system_defined_status_id: system_defined_todo_status.id)
    end

    let_it_be(:wi_system_defined_in_progress) do
      create(:work_item, project: project, system_defined_status_id: system_defined_in_progress_status.id)
    end

    let_it_be(:wi_system_defined_done) do
      create(:work_item, :closed, project: project, system_defined_status_id: system_defined_done_status.id)
    end

    let_it_be(:wi_system_defined_duplicated) do
      create(:work_item, :closed, project: project, system_defined_status_id: system_defined_duplicate_status.id)
    end

    let_it_be(:wi_system_defined_wont_do) do
      create(:work_item, :closed, project: project, system_defined_status_id: system_defined_wont_do_status.id)
    end

    let_it_be_with_reload(:lifecycle) do
      create(:work_item_custom_lifecycle, namespace: reusable_group).tap do |lifecycle|
        # Skip validations so that we can skip the license check.
        # We can't stub licensed features for let_it_be blocks.
        build(:work_item_type_custom_lifecycle,
          namespace: reusable_group,
          work_item_type: issue_work_item_type,
          lifecycle: lifecycle
        ).save!(validate: false)
      end
    end

    let(:lifecycle_2) do
      create(:work_item_custom_lifecycle, namespace: reusable_group_2).tap do |lifecycle|
        build(:work_item_type_custom_lifecycle,
          namespace: reusable_group_2,
          work_item_type: issue_work_item_type,
          lifecycle: lifecycle
        ).save!(validate: false)
      end
    end

    let_it_be(:custom_status) do
      create(:work_item_custom_status,
        namespace: reusable_group,
        lifecycles: [lifecycle],
        converted_from_system_defined_status_identifier: nil
      )
    end

    let_it_be(:converted_in_progress_status) do
      create(:work_item_custom_status, :in_progress, namespace: reusable_group, lifecycles: [lifecycle])
    end

    let_it_be(:wi_custom_todo) do
      create(:work_item, project: project, custom_status_id: lifecycle.default_open_status_id)
    end

    let_it_be(:wi_custom_done) do
      create(:work_item, project: project, custom_status_id: lifecycle.default_closed_status_id)
    end

    let_it_be(:wi_custom_duplicated) do
      create(:work_item, project: project, custom_status_id: lifecycle.default_duplicate_status_id)
    end

    let_it_be(:wi_custom) { create(:work_item, project: project, custom_status_id: custom_status.id) }

    let_it_be(:wi_converted_in_progress) { create(:work_item, project: project) }

    let_it_be(:wi_converted_in_progress_current_status) do
      # Skip validations since we are simulating an old record
      # when the namespace still used the system defined lifecycle
      build(:work_item_current_status,
        work_item: wi_converted_in_progress,
        system_defined_status_id: system_defined_in_progress_status.id,
        updated_at: 2.days.ago
      ).save!(validate: false)
    end

    let(:wi_system_defined_todo_2) do
      create(:work_item, project: project_2, system_defined_status_id: system_defined_todo_status.id)
    end

    let(:wi_system_defined_done_2) do
      create(:work_item, :closed, project: project_2, system_defined_status_id: system_defined_done_status.id)
    end

    let(:wi_custom_todo_2) do
      create(:work_item, project: project_2, custom_status_id: lifecycle_2.default_open_status_id)
    end

    let(:wi_custom_done_2) do
      create(:work_item, project: project_2, custom_status_id: lifecycle_2.default_closed_status_id)
    end

    describe '.with_status' do
      let(:mapping) { nil }
      let(:status_roles) { [] }

      subject { described_class.with_status(status, mapping, status_roles: status_roles) }

      context 'with a system defined status' do
        let(:status) { system_defined_todo_status }

        it 'returns items with matching current_status or its equivalent fallback state' do
          is_expected.to contain_exactly(wi_system_defined_todo, wi_default_open)
        end
      end

      context 'with custom todo status' do
        let(:status) { lifecycle.default_open_status }

        it 'returns items with matching current_status or the system defined status it was converted from' do
          is_expected.to contain_exactly(wi_custom_todo, wi_system_defined_todo, wi_default_open)
        end

        context 'when status does not have converted_from_system_defined_status_identifier set' do
          before do
            status.update!(converted_from_system_defined_status_identifier: nil)
          end

          it 'returns only items with matching current_status' do
            is_expected.to contain_exactly(wi_custom_todo)
          end

          context 'when status role is provided' do
            let(:status_roles) do
              [{ role: :open, work_item_type_id: issue_work_item_type.id }]
            end

            it 'returns items with matching current_status or without a current_status of the same state' do
              is_expected.to contain_exactly(wi_custom_todo, wi_default_open)
            end
          end
        end
      end

      context 'with custom done status' do
        let(:status) { lifecycle.default_closed_status }

        it 'returns items with matching current_status or the system defined status it was converted from' do
          is_expected.to contain_exactly(wi_custom_done, wi_system_defined_done, wi_default_closed)
        end

        context 'when status does not have converted_from_system_defined_status_identifier set' do
          before do
            status.update!(converted_from_system_defined_status_identifier: nil)
          end

          it 'returns only items with matching current_status' do
            is_expected.to contain_exactly(wi_custom_done)
          end

          context 'when status role is provided' do
            let(:status_roles) do
              [{ role: :closed, work_item_type_id: issue_work_item_type.id }]
            end

            it 'returns items with matching current_status or without a current_status of the same state' do
              is_expected.to contain_exactly(wi_custom_done, wi_default_closed)
            end
          end
        end
      end

      context 'with custom duplicated status' do
        let(:status) { lifecycle.default_duplicate_status }

        it 'returns items with matching current_status or the system defined status it was converted from' do
          is_expected.to contain_exactly(wi_custom_duplicated, wi_system_defined_duplicated, wi_default_duplicated)
        end

        context 'when status does not have converted_from_system_defined_status_identifier set' do
          before do
            status.update!(converted_from_system_defined_status_identifier: nil)
          end

          it 'returns only items with matching current_status' do
            is_expected.to contain_exactly(wi_custom_duplicated)
          end

          context 'when status role is provided' do
            let(:status_roles) do
              [{ role: :duplicate, work_item_type_id: issue_work_item_type.id }]
            end

            it 'returns items with matching current_status or without a current_status of the same state' do
              is_expected.to contain_exactly(wi_custom_duplicated, wi_default_duplicated)
            end
          end
        end
      end

      context 'with a custom status' do
        let(:status) { custom_status }

        it 'returns items with matching current_status' do
          is_expected.to contain_exactly(wi_custom)
        end
      end

      context 'with mapping' do
        let_it_be(:wi_other_custom) { create(:work_item, project: project) }

        let(:status) { custom_status }
        let(:valid_from) { nil }
        let(:valid_until) { nil }
        let(:mapping) { custom_mapping }
        let(:custom_mapping) do
          create(:work_item_custom_status_mapping,
            namespace: reusable_group, work_item_type: issue_work_item_type,
            old_status: custom_status, new_status: lifecycle.default_open_status,
            valid_from: valid_from, valid_until: valid_until)
        end

        let(:converted_mapping) do
          create(:work_item_custom_status_mapping,
            namespace: reusable_group, work_item_type: issue_work_item_type,
            old_status: converted_in_progress_status, new_status: custom_status,
            valid_from: valid_from, valid_until: valid_until)
        end

        before_all do
          create(:work_item_current_status,
            work_item: wi_other_custom, custom_status: custom_status, updated_at: 2.days.ago)
        end

        it 'returns items with matching current_status' do
          is_expected.to contain_exactly(wi_custom, wi_other_custom)
        end

        context 'when mapping for converted status is provided' do
          let(:mapping) { converted_mapping }
          let(:status) { converted_in_progress_status }

          it 'returns items with matching current_status' do
            is_expected.to contain_exactly(wi_system_defined_in_progress, wi_converted_in_progress)
          end
        end

        context 'with valid_from' do
          let(:valid_from) { 1.day.ago }

          it 'returns items with matching current_status' do
            is_expected.to contain_exactly(wi_custom)
          end

          context 'and it covers both items' do
            let(:valid_from) { 3.days.ago }

            it 'returns items with matching current_status' do
              is_expected.to contain_exactly(wi_custom, wi_other_custom)
            end
          end

          context 'when mapping for converted status is provided' do
            let(:mapping) { converted_mapping }
            let(:status) { converted_in_progress_status }

            it 'returns items with matching current_status' do
              is_expected.to contain_exactly(wi_system_defined_in_progress)
            end
          end
        end

        context 'with valid_until' do
          let(:valid_until) { 1.day.ago }

          it 'returns items with matching current_status' do
            is_expected.to contain_exactly(wi_other_custom)
          end

          context 'and it covers no item' do
            let(:valid_until) { 3.days.ago }

            it 'returns no items' do
              is_expected.to be_empty
            end
          end

          context 'when mapping for converted status is provided' do
            let(:mapping) { converted_mapping }
            let(:status) { converted_in_progress_status }

            it 'returns items with matching current_status' do
              is_expected.to contain_exactly(wi_converted_in_progress)
            end
          end
        end

        context 'with both valid_from and valid_until' do
          let(:valid_from) { 1.day.ago }
          let(:valid_until) { 1.day.from_now }

          it 'returns items with matching current_status' do
            is_expected.to contain_exactly(wi_custom)
          end

          context 'and it covers only the item with older status update' do
            let(:valid_from) { 3.days.ago }
            let(:valid_until) { 1.day.ago }

            it 'returns items with matching current_status' do
              is_expected.to contain_exactly(wi_other_custom)
            end

            context 'when mapping for converted status is provided' do
              let(:mapping) { converted_mapping }
              let(:status) { converted_in_progress_status }

              it 'returns items with matching current_status' do
                is_expected.to contain_exactly(wi_converted_in_progress)
              end
            end
          end
        end

        context 'with old status role' do
          let!(:custom_mapping) do
            create(:work_item_custom_status_mapping,
              namespace: reusable_group, work_item_type: issue_work_item_type,
              old_status: old_status, old_status_role: old_status_role,
              new_status: target_status,
              valid_from: nil, valid_until: 1.day.ago)
          end

          context 'when set to open' do
            let!(:old_status) do
              create(:work_item_custom_status,
                :without_conversion_mapping,
                namespace: reusable_group
              )
            end

            let(:target_status) { custom_status }
            let(:old_status_role) { :open }

            it 'returns items with matching current_status' do
              is_expected.to contain_exactly(wi_other_custom, wi_default_open)
            end
          end

          context 'when set to closed' do
            let!(:old_status) do
              create(:work_item_custom_status,
                :closed,
                namespace: reusable_group,
                converted_from_system_defined_status_identifier: nil
              )
            end

            let!(:target_status) do
              create(:work_item_custom_status,
                :closed,
                namespace: reusable_group,
                lifecycles: [lifecycle],
                converted_from_system_defined_status_identifier: nil
              )
            end

            let(:old_status_role) { :closed }
            let(:status) { target_status }

            it 'returns items with matching current_status' do
              is_expected.to contain_exactly(wi_default_closed)
            end
          end

          context 'when set to duplicate' do
            let!(:old_status) do
              create(:work_item_custom_status,
                :duplicate,
                namespace: reusable_group,
                converted_from_system_defined_status_identifier: nil
              )
            end

            let!(:target_status) do
              create(:work_item_custom_status,
                :duplicate,
                namespace: reusable_group,
                lifecycles: [lifecycle],
                converted_from_system_defined_status_identifier: nil
              )
            end

            let(:old_status_role) { :duplicate }
            let(:status) { target_status }

            it 'returns items with matching current_status' do
              is_expected.to contain_exactly(wi_default_duplicated)
            end
          end
        end
      end
    end

    describe '.with_system_defined_status' do
      let(:mapping) { nil }

      subject { described_class.with_system_defined_status(status, mapping) }

      context 'with todo status' do
        let(:status) { system_defined_todo_status }

        it 'returns items with matching current_status or open items' do
          is_expected.to contain_exactly(wi_system_defined_todo, wi_default_open)
        end
      end

      context 'with done status' do
        let(:status) { system_defined_done_status }

        it 'returns items with matching current_status or closed items' do
          is_expected.to contain_exactly(wi_system_defined_done, wi_default_closed)
        end
      end

      context 'with duplicate status' do
        let(:status) { system_defined_duplicate_status }

        it 'returns items with matching current_status or duplicated items' do
          is_expected.to contain_exactly(wi_system_defined_duplicated, wi_default_duplicated)
        end
      end

      context 'with wont_do status' do
        let(:status) { system_defined_wont_do_status }

        it 'returns items with matching current_status' do
          is_expected.to contain_exactly(wi_system_defined_wont_do)
        end
      end

      context 'with a custom status' do
        let(:status) { custom_status }

        it 'returns no items' do
          is_expected.to be_empty
        end
      end

      context 'when mapping for converted status is provided' do
        let(:valid_from) { nil }
        let(:valid_until) { nil }
        let(:status) { system_defined_in_progress_status }
        let(:mapping) do
          create(:work_item_custom_status_mapping,
            namespace: reusable_group, work_item_type: issue_work_item_type,
            old_status: converted_in_progress_status, new_status: custom_status,
            valid_from: valid_from, valid_until: valid_until)
        end

        it 'returns items with matching current_status' do
          is_expected.to contain_exactly(wi_system_defined_in_progress, wi_converted_in_progress)
        end

        context 'when valid_until excludes item' do
          let(:valid_until) { 1.day.ago }

          it 'returns items with matching current_status' do
            is_expected.to contain_exactly(wi_converted_in_progress)
          end

          context 'and valid_from is provided' do
            let(:valid_from) { 3.days.ago }

            it 'returns items with matching current_status' do
              is_expected.to contain_exactly(wi_converted_in_progress)
            end
          end
        end

        context 'when valid_from excludes item' do
          let(:valid_from) { 1.day.ago }

          it 'returns items with matching current_status' do
            is_expected.to contain_exactly(wi_system_defined_in_progress)
          end
        end
      end
    end

    describe '.without_current_status' do
      it 'returns items that do not have an associated current_status' do
        expect(described_class.without_current_status).to contain_exactly(
          wi_default_open, wi_default_closed, wi_default_duplicated, wi_no_status
        )
      end
    end

    describe '.not_in_statuses' do
      subject { described_class.not_in_statuses(statuses) }

      context 'with empty statuses' do
        let(:statuses) { [] }

        it 'returns all work items' do
          is_expected.to contain_exactly(
            wi_default_open, wi_default_closed, wi_default_duplicated,
            wi_system_defined_todo, wi_system_defined_in_progress, wi_system_defined_done, wi_system_defined_duplicated,
            wi_system_defined_wont_do, wi_custom_todo, wi_custom_done, wi_custom_duplicated, wi_custom, wi_no_status,
            wi_converted_in_progress
          )
        end
      end

      context 'with system-defined statuses' do
        let(:statuses) do
          [
            system_defined_todo_status, system_defined_done_status,
            system_defined_duplicate_status, system_defined_wont_do_status
          ]
        end

        it 'excludes items with matching current_status or its equivalent fallback status' do
          is_expected.to contain_exactly(
            wi_custom_todo, wi_custom_done, wi_custom_duplicated, wi_custom, wi_no_status,
            wi_system_defined_in_progress, wi_converted_in_progress
          )
        end
      end

      context 'with custom statuses' do
        context 'with statuses that has system-defined mapping' do
          let(:statuses) do
            [
              lifecycle.default_open_status, lifecycle.default_closed_status,
              lifecycle.default_duplicate_status, converted_in_progress_status
            ]
          end

          it 'excludes items with custom status and mapped system-defined items' do
            is_expected.to contain_exactly(
              wi_system_defined_wont_do, wi_custom, wi_no_status
            )
          end
        end

        context 'with status without system-defined mapping' do
          let(:statuses) { [custom_status] }

          it 'excludes only items with the custom status' do
            is_expected.not_to include(wi_custom)
          end
        end
      end
    end

    describe '.order_status_asc' do
      let(:result) { described_class.where(id: work_items.map(&:id)).order_status_asc }

      context 'with system-defined statuses' do
        before do
          lifecycle.destroy!
        end

        context 'with explicitly set statuses' do
          let_it_be(:work_items) do
            [
              wi_system_defined_todo, wi_system_defined_in_progress, wi_system_defined_done,
              wi_system_defined_wont_do, wi_system_defined_duplicated
            ]
          end

          it 'sorts work items by status asc' do
            expect(result).to eq([
              wi_system_defined_todo,
              wi_system_defined_in_progress,
              wi_system_defined_done,
              wi_system_defined_wont_do,
              wi_system_defined_duplicated
            ])
          end
        end

        context 'with explicitly and implicitly set statuses' do
          let_it_be(:work_items) do
            [
              wi_default_open, wi_system_defined_todo, wi_system_defined_in_progress, wi_default_closed,
              wi_system_defined_done, wi_system_defined_wont_do, wi_default_duplicated, wi_system_defined_duplicated
            ]
          end

          it 'sorts work items by status asc' do
            expect(result).to eq([
              wi_system_defined_todo,
              wi_default_open,
              wi_system_defined_in_progress,
              wi_system_defined_done,
              wi_default_closed,
              wi_system_defined_wont_do,
              wi_system_defined_duplicated,
              wi_default_duplicated
            ])
          end
        end
      end

      context 'with custom statuses' do
        context 'with explicitly set statuses' do
          let_it_be(:work_items) do
            [wi_custom, wi_custom_todo, wi_converted_in_progress, wi_custom_done, wi_custom_duplicated]
          end

          it 'sorts work items by status asc' do
            expect(result).to eq([
              wi_custom,
              wi_custom_todo,
              wi_converted_in_progress,
              wi_custom_done,
              wi_custom_duplicated
            ])
          end
        end

        context 'with explicitly and implicitly set statuses' do
          let(:work_items) do
            [
              wi_custom, wi_custom_todo, wi_converted_in_progress, wi_custom_done, wi_custom_duplicated,
              wi_default_open, wi_default_closed, wi_default_duplicated
            ]
          end

          it 'sorts work items by status asc' do
            expect(result).to eq([
              wi_custom,
              wi_custom_todo,
              wi_default_open,
              wi_converted_in_progress,
              wi_custom_done,
              wi_default_closed,
              wi_custom_duplicated,
              wi_default_duplicated
            ])
          end
        end

        context 'with work items from multiple namespaces' do
          let(:work_items) do
            [wi_custom_todo, wi_custom_done, wi_custom_duplicated, wi_custom_todo_2, wi_custom_done_2]
          end

          it 'sorts work items by status asc' do
            expect(result).to eq([
              wi_custom_todo_2,
              wi_custom_todo,
              wi_custom_done_2,
              wi_custom_done,
              wi_custom_duplicated
            ])
          end
        end
      end

      context 'with status mappings' do
        let_it_be(:custom_to_do) do
          create(:work_item_custom_status, :without_conversion_mapping, category: :to_do,
            namespace: reusable_group, lifecycles: [lifecycle])
        end

        let_it_be(:mapped_in_progress) do
          create(:work_item_custom_status, :without_conversion_mapping, category: :in_progress,
            namespace: reusable_group, lifecycles: [lifecycle])
        end

        let_it_be(:mapped_in_progress_2) do
          create(:work_item_custom_status, :without_conversion_mapping, category: :in_progress,
            namespace: reusable_group, lifecycles: [lifecycle])
        end

        let_it_be(:custom_status_mapping) do
          create(:work_item_custom_status_mapping,
            old_status_id: lifecycle.default_open_status_id,
            new_status_id: mapped_in_progress.id,
            work_item_type_id: issue_work_item_type.id,
            namespace_id: reusable_group.id
          )
        end

        let_it_be(:expired_custom_status_mapping) do
          create(:work_item_custom_status_mapping,
            old_status_id: custom_to_do.id,
            new_status_id: mapped_in_progress.id,
            work_item_type_id: issue_work_item_type.id,
            namespace_id: reusable_group.id,
            valid_until: 1.day.ago
          )
        end

        let_it_be(:future_custom_status_mapping) do
          create(:work_item_custom_status_mapping,
            old_status_id: custom_to_do.id,
            new_status_id: mapped_in_progress_2.id,
            work_item_type_id: issue_work_item_type.id,
            namespace_id: reusable_group.id,
            valid_from: 1.day.from_now
          )
        end

        let_it_be(:wi_custom_mapped_in_progress) do
          create(:work_item, project: project, custom_status_id: lifecycle.default_open_status_id)
        end

        let_it_be(:wi_sd_mapped_in_progress) { create(:work_item, project: project) }

        let_it_be(:wi_sd_mapped_in_progress_current_status) do
          # Skip validations since we are simulating an old record
          # when the namespace still used the system defined lifecycle
          build(:work_item_current_status,
            work_item: wi_sd_mapped_in_progress,
            system_defined_status_id: system_defined_todo_status.id
          ).save!(validate: false)
        end

        let_it_be(:wi_with_time_bounded_mapping) do
          create(:work_item, project: project, custom_status_id: custom_to_do.id).tap do |wi|
            wi.current_status.update!(updated_at: 2.days.ago)
          end
        end

        let_it_be(:wi_with_future_mapping) do
          create(:work_item, project: project, custom_status_id: custom_to_do.id)
        end

        let(:work_items) do
          [
            wi_custom, wi_custom_mapped_in_progress, wi_sd_mapped_in_progress,
            wi_converted_in_progress, wi_custom_done, wi_custom_duplicated, wi_default_open,
            wi_default_closed, wi_default_duplicated, wi_with_time_bounded_mapping, wi_with_future_mapping
          ]
        end

        it 'sorts work items by status asc' do
          expect(result).to eq([
            wi_with_future_mapping,
            wi_custom,
            wi_default_open,
            wi_with_time_bounded_mapping,
            wi_sd_mapped_in_progress,
            wi_custom_mapped_in_progress,
            wi_converted_in_progress,
            wi_custom_done,
            wi_default_closed,
            wi_custom_duplicated,
            wi_default_duplicated
          ])
        end
      end

      context 'with system-defined and custom statuses from multiple namespaces' do
        let(:work_items) do
          [
            wi_custom_todo, wi_converted_in_progress, wi_custom_done,
            wi_system_defined_todo_2, wi_system_defined_done_2
          ]
        end

        it 'sorts work items by status asc' do
          expect(result).to eq([
            wi_system_defined_todo_2,
            wi_custom_todo,
            wi_converted_in_progress,
            wi_system_defined_done_2,
            wi_custom_done
          ])
        end
      end
    end

    describe '.order_status_desc' do
      let(:result) { described_class.where(id: work_items.map(&:id)).order_status_desc }

      context 'with system-defined statuses' do
        before do
          lifecycle.destroy!
        end

        context 'with explicitly set statuses' do
          let(:work_items) do
            [
              wi_system_defined_todo, wi_system_defined_in_progress, wi_system_defined_done,
              wi_system_defined_wont_do, wi_system_defined_duplicated
            ]
          end

          it 'sorts work items by status desc' do
            expect(result).to eq([
              wi_system_defined_wont_do,
              wi_system_defined_duplicated,
              wi_system_defined_done,
              wi_system_defined_in_progress,
              wi_system_defined_todo
            ])
          end
        end

        context 'with explicitly and implicitly set statuses' do
          let(:work_items) do
            [
              wi_default_open, wi_system_defined_todo, wi_system_defined_in_progress, wi_default_closed,
              wi_system_defined_done, wi_system_defined_wont_do, wi_default_duplicated, wi_system_defined_duplicated
            ]
          end

          it 'sorts work items by status desc' do
            expect(result).to eq([
              wi_system_defined_wont_do,
              wi_system_defined_duplicated,
              wi_default_duplicated,
              wi_system_defined_done,
              wi_default_closed,
              wi_system_defined_in_progress,
              wi_system_defined_todo,
              wi_default_open
            ])
          end
        end

        context 'with work items from multiple namespaces' do
          let(:work_items) do
            [wi_custom_todo, wi_custom_done, wi_custom_duplicated, wi_custom_todo_2, wi_custom_done_2]
          end

          it 'sorts work items by status desc' do
            expect(result).to eq([
              wi_custom_duplicated,
              wi_custom_done_2,
              wi_custom_done,
              wi_custom_todo_2,
              wi_custom_todo
            ])
          end
        end
      end

      context 'with custom statuses' do
        context 'with explicitly set statuses' do
          let(:work_items) do
            [wi_custom, wi_custom_todo, wi_converted_in_progress, wi_custom_done, wi_custom_duplicated]
          end

          it 'sorts work items by status desc' do
            expect(result).to eq([
              wi_custom_duplicated,
              wi_custom_done,
              wi_converted_in_progress,
              wi_custom,
              wi_custom_todo
            ])
          end
        end

        context 'with explicitly and implicitly set statuses' do
          let(:work_items) do
            [
              wi_custom, wi_custom_todo, wi_custom_done, wi_custom_duplicated, wi_default_open,
              wi_default_closed, wi_default_duplicated, wi_converted_in_progress
            ]
          end

          it 'sorts work items by status desc' do
            expect(result).to eq([
              wi_custom_duplicated,
              wi_default_duplicated,
              wi_custom_done,
              wi_default_closed,
              wi_converted_in_progress,
              wi_custom,
              wi_custom_todo,
              wi_default_open
            ])
          end
        end

        context 'with work items from multiple namespaces' do
          let(:work_items) do
            [wi_custom_todo, wi_custom_done, wi_custom_duplicated, wi_custom_todo_2, wi_custom_done_2]
          end

          it 'sorts work items by status desc' do
            expect(result).to eq([
              wi_custom_duplicated,
              wi_custom_done_2,
              wi_custom_done,
              wi_custom_todo_2,
              wi_custom_todo
            ])
          end
        end
      end

      context 'with system-defined and custom statuses from multiple namespaces' do
        let(:work_items) do
          [wi_custom_todo, wi_custom_done, wi_system_defined_todo_2, wi_system_defined_done_2]
        end

        it 'sorts work items by status asc' do
          expect(result).to eq([
            wi_system_defined_done_2,
            wi_custom_done,
            wi_system_defined_todo_2,
            wi_custom_todo
          ])
        end
      end
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers

  describe 'versioned descriptions' do
    it_behaves_like 'versioned description'

    context 'when it is a work item of type epic' do
      let(:type) { build(:work_item_system_defined_type, :epic) }
      let(:work_item) do
        create(:work_item, description: 'Original description', work_item_type: type, project: reusable_project)
      end

      it 'creates a versioned description on epic work item' do
        expect { work_item.update!(description: 'Another description') }
          .to change { work_item.own_description_versions.count }
      end

      context 'when set to skip description version' do
        it 'does not create a versioned description on epic work item' do
          expect { work_item.update!(description: 'Another description', skip_description_version: true) }
            .not_to change { work_item.own_description_versions.count }
        end
      end
    end
  end

  describe '#ensure_metrics!' do
    context 'with project-level work item' do
      subject(:create_work_item) { create(:work_item, project: reusable_project, work_item_type: type) }

      context 'when it is not a work item of type epic' do
        let(:type) { build(:work_item_system_defined_type, :issue) }

        it 'creates metrics after saving' do
          expect(create_work_item).to be_persisted

          expect(Issue::Metrics.count).to eq(1)
        end
      end

      context 'when it is a project work item of type epic' do
        let(:type) { build(:work_item_system_defined_type, :epic) }

        it 'creates metrics after saving' do
          expect(create_work_item).to be_persisted

          expect(Issue::Metrics.count).to eq(1)
        end
      end
    end

    context 'with grup-level work item' do
      subject(:create_work_item) do
        create(:work_item, namespace: reusable_group, work_item_type: build(:work_item_system_defined_type, :epic))
      end

      it 'does not create metrics after saving work item with type epic' do
        expect(create_work_item).to be_persisted

        expect(Issue::Metrics.count).to eq(0)
      end
    end
  end

  describe '#allowed_work_item_type_change' do
    let(:issue_type) { build(:work_item_system_defined_type, :issue) }

    context 'when epic work item does not have a synced legacy epic' do
      let(:work_item) { create(:work_item, :epic) }

      it 'is does change work item type from epic to issue' do
        work_item.assign_attributes(work_item_type_id: issue_type.id)

        expect(work_item).to be_valid
        expect(work_item.errors[:work_item_type_id]).to be_empty
      end
    end

    context 'when epic work item has a synced legacy epic' do
      let_it_be(:epic, freeze: false) { create(:epic, :with_synced_work_item) }
      let(:work_item) { epic.work_item }

      it 'is does not change work item type from epic to issue' do
        work_item.assign_attributes(work_item_type_id: issue_type.id)

        expect(work_item).not_to be_valid
        expect(work_item.errors[:work_item_type_id])
          .to include(_('cannot be changed to issue when the work item is a legacy epic synced work item'))
      end
    end

    # See https://gitlab.com/gitlab-org/gitlab/-/work_items/600334
    # Hierarchy restrictions are stored only for system-defined types, so the
    # validation must translate any custom type id to its delegation_source
    # (system-defined) id before consulting them.
    describe 'conversion to/from custom types', :request_store do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:non_converted_custom_type) { create(:work_item_custom_type, namespace: group) }
      let_it_be(:converted_from_issue) { create(:work_item_custom_type, :converted_from_issue, namespace: group) }
      let_it_be(:converted_from_task) { create(:work_item_custom_type, :converted_from_task, namespace: group) }

      # Work items + the parent_link are recreated per example because each
      # test mutates the work item (assigning a new work_item_type) and the
      # parent_link is consumed by the validation under test.
      let(:issue_work_item) { described_class.find(create(:work_item, :issue, project: project).id) }
      let(:task_work_item) { described_class.find(create(:work_item, :task, project: project).id) }

      before do
        stub_saas_features(namespace_scoped_work_item_types: true)
        create(:parent_link, work_item_parent: issue_work_item, work_item: task_work_item)
      end

      it 'allows converting Issue (with child Task) to a non-converted custom type — bug repro' do
        issue_work_item.work_item_type = non_converted_custom_type

        expect(issue_work_item).to be_valid
        expect(issue_work_item.errors[:work_item_type_id]).to be_empty
      end

      it 'allows converting Issue (with child Task) to a custom type converted from Issue' do
        issue_work_item.work_item_type = converted_from_issue

        expect(issue_work_item).to be_valid
        expect(issue_work_item.errors[:work_item_type_id]).to be_empty
      end

      it 'rejects converting Issue (with child Task) to a custom type converted from Task' do
        issue_work_item.work_item_type = converted_from_task

        expect(issue_work_item).not_to be_valid
        expect(issue_work_item.errors[:work_item_type_id]).to include(
          a_string_matching(/cannot be changed to .* with these child item types\./)
        )
      end

      it 'rejects converting Task to a non-converted custom type when parent is Issue' do
        task_work_item.work_item_type = non_converted_custom_type

        expect(task_work_item).not_to be_valid
        expect(task_work_item.errors[:work_item_type_id]).to include(
          a_string_matching(/cannot be changed to .* when linked to a parent/)
        )
      end

      it 'allows converting Task to a custom type converted from Task when parent is Issue' do
        task_work_item.work_item_type = converted_from_task

        expect(task_work_item).to be_valid
        expect(task_work_item.errors[:work_item_type_id]).to be_empty
      end
    end
  end

  describe '#use_elasticsearch?' do
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:work_item, freeze: false) { create(:work_item, namespace: namespace) }

    context 'when namespace does not use elasticsearch' do
      it 'returns false' do
        stub_ee_application_setting(elasticsearch_indexing: true, elasticsearch_limit_indexing: true)

        expect(work_item.use_elasticsearch?).to be_falsey
      end
    end

    context 'when work_item index is available and namesapce uses elasticsearch' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true, elasticsearch_limit_indexing: false)
      end

      it 'returns true' do
        expect(work_item.use_elasticsearch?).to be_truthy
      end
    end
  end

  describe '.descendant_ids_for' do
    let_it_be(:group) { create(:group) }
    let_it_be(:parent_epic) { create(:work_item, :epic, namespace: group) }
    let_it_be(:child_epic1) { create(:work_item, :epic, namespace: group) }
    let_it_be(:child_epic2) { create(:work_item, :epic, namespace: group) }
    let_it_be(:grandchild_epic) { create(:work_item, :epic, namespace: group) }
    let_it_be(:unrelated_epic) { create(:work_item, :epic, namespace: group) }
    let_it_be(:unrelated_subepic) { create(:work_item, :epic, namespace: group) }

    before_all do
      create(:parent_link, work_item_parent: parent_epic, work_item: child_epic1)
      create(:parent_link, work_item_parent: parent_epic, work_item: child_epic2)
      create(:parent_link, work_item_parent: child_epic1, work_item: grandchild_epic)
      create(:parent_link, work_item_parent: unrelated_epic, work_item: unrelated_subepic)
    end

    it 'returns all descendant IDs including base' do
      result = described_class.descendant_ids_for([parent_epic.id])

      expect(result).to match_array([parent_epic.id, child_epic1.id, child_epic2.id, grandchild_epic.id])
      expect(result).not_to include(unrelated_epic.id)
    end

    it 'returns empty array for blank input' do
      expect(described_class.descendant_ids_for([])).to eq([])
      expect(described_class.descendant_ids_for(nil)).to eq([])
    end

    it 'returns all descendants for multiple parents' do
      result = described_class.descendant_ids_for([parent_epic.id, unrelated_epic])

      expect(result).to match_array([parent_epic.id, child_epic1.id, child_epic2.id,
        grandchild_epic.id, unrelated_epic.id, unrelated_subepic.id])
    end

    context 'with work_item_type filter' do
      let_it_be(:parent_epic_with_issues) { create(:work_item, :epic, namespace: group) }
      let_it_be(:child_epic) { create(:work_item, :epic, namespace: group) }
      let_it_be(:child_issue) { create(:work_item, :issue, project: reusable_project) }

      before_all do
        create(:parent_link, work_item_parent: parent_epic_with_issues, work_item: child_epic)
        create(:parent_link, work_item_parent: parent_epic_with_issues, work_item: child_issue)
      end

      it 'filters by work item type for epics' do
        result = described_class.descendant_ids_for([parent_epic_with_issues.id], work_item_type: :epic)

        expect(result).to match_array([parent_epic_with_issues.id, child_epic.id])
        expect(result).not_to include(child_issue.id)
      end

      it 'filters by work item type for issues' do
        result = described_class.descendant_ids_for([parent_epic_with_issues.id], work_item_type: :issue)

        expect(result).not_to include(parent_epic_with_issues.id, child_epic.id)
        expect(result).to contain_exactly(child_issue.id)
      end
    end
  end

  describe '.work_item_children_by_relative_position' do
    subject { parent_item.reload.work_item_children_by_relative_position }

    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:parent_item) { create(:work_item, :epic, namespace: namespace) }
    let_it_be(:oldest_item) { create(:work_item, :epic, namespace: namespace) }
    let_it_be(:middle_item) { create(:work_item, :issue, project: reusable_project) }
    let_it_be(:newest_item) { create(:work_item, :issue, project: reusable_project) }
    let_it_be(:closed_item) { create(:work_item, :issue, :closed, project: reusable_project) }

    let_it_be_with_reload(:link_to_oldest_item) do
      create(:parent_link, work_item_parent: parent_item, work_item: oldest_item)
    end

    let_it_be_with_reload(:link_to_middle_item) do
      create(:parent_link, work_item_parent: parent_item, work_item: middle_item)
    end

    let_it_be_with_reload(:link_to_newest_item) do
      create(:parent_link, work_item_parent: parent_item, work_item: newest_item)
    end

    let_it_be_with_reload(:link_to_closed_tiem) do
      create(:parent_link, work_item_parent: parent_item, work_item: closed_item, relative_position: 1)
    end

    context 'when subepics are not available' do
      before do
        stub_licensed_features(subepics: false)
      end

      it 'does not raise an error when preloading the association' do
        items = described_class.where(id: parent_item.id).preload(
          work_item_children_by_relative_position: [:author, { project: :project_feature }]
        )

        expect { items.flat_map(&:work_item_children_by_relative_position) }.not_to raise_error
      end

      context 'when ordered by relative position does not include subepics' do
        using RSpec::Parameterized::TableSyntax

        where(:oldest_item_position, :middle_item_position, :newest_item_position, :expected_order) do
          nil | nil | nil | lazy { [middle_item, newest_item, closed_item] }
          nil | nil | 2   | lazy { [newest_item, middle_item, closed_item] }
          nil | 2   | 3   | lazy { [middle_item, newest_item, closed_item] }
          3   | 4   | 2   | lazy { [newest_item, middle_item, closed_item] }
          2   | 3   | 4   | lazy { [middle_item, newest_item, closed_item] }
          2   | 4   | 3   | lazy { [newest_item, middle_item, closed_item] }
          3   | 2   | 4   | lazy { [middle_item, newest_item, closed_item] }
          4   | 2   | 3   | lazy { [middle_item, newest_item, closed_item] }
          4   | 3   | 2   | lazy { [newest_item, middle_item, closed_item] }
          2   | 3   | 2   | lazy { [newest_item, middle_item, closed_item] }
        end

        with_them do
          before do
            link_to_oldest_item.update!(relative_position: oldest_item_position)
            link_to_middle_item.update!(relative_position: middle_item_position)
            link_to_newest_item.update!(relative_position: newest_item_position)
          end

          it { is_expected.to eq(expected_order) }
        end
      end
    end

    context 'when subepics are available' do
      before do
        stub_licensed_features(subepics: true)
      end

      # Skipped order related specs since they are tested in work_item_spec file in CE
      it 'return child epics as well in the children' do
        expect(parent_item.reload.work_item_children_by_relative_position).to eq([oldest_item, middle_item,
          newest_item, closed_item])
      end
    end
  end

  describe '#preload_indexing_data' do
    let_it_be(:work_item, freeze: false) { create(:work_item) }

    it 'preloads for indexing and avoid N+1 queries' do
      work_item = described_class.preload_indexing_data.first
      recorder = ActiveRecord::QueryRecorder.new do
        work_item.namespace
        work_item.labels
        work_item.project.project_feature
        work_item.milestone
      end
      expect(recorder.count).to be_zero
    end
  end

  describe '#elastic_reference' do
    let_it_be(:work_item, freeze: false) { create(:work_item) }

    it 'returns the string representation for the elasticsearch' do
      expect(work_item.elastic_reference).to eq("WorkItem|#{work_item.id}|#{work_item.es_parent}")
    end
  end

  describe '#es_parent' do
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:work_item, freeze: false) { create(:work_item, namespace: namespace) }

    it 'returns to correct routing id' do
      expect(work_item.es_parent).to eq("group_#{namespace.root_ancestor.id}")
    end
  end

  context 'when deleting a work item' do
    context 'and work item has award emojis' do
      let_it_be_with_reload(:work_item) { create(:work_item, :epic_with_legacy_epic) }
      let_it_be(:emoji_1) { create(:award_emoji, awardable: work_item) }
      let_it_be(:emoji_2) { create(:award_emoji, awardable: work_item) }
      let_it_be(:emoji_3) { create(:award_emoji, awardable: work_item) }
      let_it_be(:emoji_4) { create(:award_emoji) } # Not to be deleted

      it 'deletes award emoji when work item is destroyed' do
        expect { work_item.destroy! }.to change { ::AwardEmoji.count }.by(-3)
        expect(emoji_4.reload).to be_persisted
      end
    end
  end

  context 'with subscriptions' do
    context 'when type is Epic' do
      let_it_be(:epic, freeze: false) { create(:epic, group: reusable_group) }
      let_it_be(:work_item, freeze: false) { epic.work_item }
      let_it_be(:epic_subscription) { create(:subscription, user: user, subscribable: epic, subscribed: true) }

      context 'when subscriptions are read from the epic and the epic work item' do
        it 'returns subscriptions from both' do
          expect(epic.reload.subscriptions).to contain_exactly(epic_subscription)
          expect(work_item.reload.subscriptions).to contain_exactly(epic_subscription)
        end
      end
    end
  end

  describe '.linked_items_for' do
    let_it_be(:items, freeze: false) { create_list(:work_item, 3, project: reusable_project) }
    let_it_be(:linked_items, freeze: false) { create_list(:work_item, 3, project: reusable_project) }

    subject(:linked_by_type) { described_class.linked_items_for(items.pluck(:id), link_type: type_filter) }

    before do
      create(:work_item_link, source: items[0], target: linked_items[0], link_type: 'relates_to')
      create(:work_item_link, source: items[1], target: linked_items[1], link_type: 'blocks')
      create(:work_item_link, source: linked_items[2], target: items[2], link_type: 'blocks')
    end

    where(type_filter: %w[relates_to blocks is_blocked_by])

    with_them do
      it 'returns the linked items with the specified link type' do
        expect(linked_by_type.first.issue_link_type).to eq(type_filter)
        expect(linked_by_type.first.issue_link_type).to eq(type_filter)
      end
    end
  end

  describe '#status_with_fallback' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    let_it_be_with_reload(:work_item) { create(:work_item, :task, project: project, created_at: 2.days.ago) }

    before do
      stub_licensed_features(work_item_status: true)
    end

    subject(:status_with_fallback) { work_item.status_with_fallback }

    context 'with system-defined lifecycle' do
      let(:lifecycle) do
        WorkItems::Statuses::SystemDefined::Lifecycle.of_work_item_base_type(work_item.work_item_type.base_type)
      end

      context 'when current_status exists' do
        before do
          create(:work_item_current_status,
            work_item: work_item,
            system_defined_status_id: lifecycle.default_open_status_id
          )
        end

        it 'returns the current status' do
          expect(status_with_fallback.class).to eq(WorkItems::Statuses::SystemDefined::Status)
          expect(status_with_fallback.id).to eq(lifecycle.default_open_status_id)
        end
      end

      context 'when current_status does not exist' do
        context 'when state is open' do
          before do
            work_item.state = :opened
          end

          it 'returns the default open status' do
            expect(status_with_fallback.class).to eq(WorkItems::Statuses::SystemDefined::Status)
            expect(status_with_fallback.id).to eq(lifecycle.default_open_status_id)
          end
        end

        context 'when state is closed' do
          before do
            work_item.state = :closed
          end

          it 'returns the default closed status' do
            expect(status_with_fallback.class).to eq(WorkItems::Statuses::SystemDefined::Status)
            expect(status_with_fallback.id).to eq(lifecycle.default_closed_status_id)
          end

          context 'when work item is a duplicate' do
            before do
              work_item.duplicated_to = build_stubbed(:work_item)
            end

            it 'returns the default duplicated status' do
              expect(status_with_fallback.class).to eq(WorkItems::Statuses::SystemDefined::Status)
              expect(status_with_fallback.id).to eq(lifecycle.default_duplicate_status_id)
            end
          end
        end

        context 'when work item type does not have a lifecycle' do
          before do
            work_item.work_item_type = build(:work_item_system_defined_type, :incident)
          end

          it 'returns nil' do
            expect(status_with_fallback).to be_nil
          end
        end
      end
    end

    context 'with custom lifecycle' do
      let!(:lifecycle) do
        create(:work_item_custom_lifecycle, namespace: group, work_item_types: [work_item.work_item_type])
      end

      context 'when current_status exists with custom_status_id' do
        before do
          create(:work_item_current_status,
            work_item: work_item,
            custom_status_id: lifecycle.default_open_status_id
          )
        end

        it 'returns the current custom status' do
          expect(status_with_fallback.class).to eq(WorkItems::Statuses::Custom::Status)
          expect(status_with_fallback.id).to eq(lifecycle.default_open_status_id)
        end
      end

      context 'when current_status exists with system_defined_status_id' do
        before do
          # Skip validations since we are simulating an old record
          # when the namespace still used the system defined lifecycle
          build(:work_item_current_status,
            work_item: work_item,
            system_defined_status_id: lifecycle.default_open_status.converted_from_system_defined_status_identifier
          ).save!(validate: false)
        end

        it 'returns the converted custom status' do
          expect(status_with_fallback.class).to eq(WorkItems::Statuses::Custom::Status)
          expect(status_with_fallback.id).to eq(lifecycle.default_open_status_id)
        end
      end

      context 'when current_status does not exist' do
        context 'when state is open' do
          let_it_be(:non_converted_default_open_status) do
            create(:work_item_custom_status, :without_conversion_mapping, namespace: reusable_group)
          end

          before do
            work_item.state = :opened
          end

          it 'returns the default open status' do
            expect(status_with_fallback.class).to eq(WorkItems::Statuses::Custom::Status)
            expect(status_with_fallback.id).to eq(lifecycle.default_open_status_id)
          end

          context 'when using non-converted default status' do
            it 'returns the default open status' do
              lifecycle.update!(default_open_status: non_converted_default_open_status)

              expect(status_with_fallback.class).to eq(WorkItems::Statuses::Custom::Status)
              expect(status_with_fallback.id).to eq(non_converted_default_open_status.id)
            end
          end
        end

        context 'when state is closed' do
          let_it_be(:non_converted_default_closed_status) do
            create(:work_item_custom_status, :without_conversion_mapping, category: :done, namespace: reusable_group)
          end

          before do
            work_item.state = :closed
          end

          it 'returns the default closed status' do
            expect(status_with_fallback.class).to eq(WorkItems::Statuses::Custom::Status)
            expect(status_with_fallback.id).to eq(lifecycle.default_closed_status_id)
          end

          context 'when using non-converted default status' do
            it 'returns the default open status' do
              lifecycle.update!(default_closed_status: non_converted_default_closed_status)

              expect(status_with_fallback.class).to eq(WorkItems::Statuses::Custom::Status)
              expect(status_with_fallback.id).to eq(non_converted_default_closed_status.id)
            end
          end

          context 'when work item is a duplicate' do
            let_it_be(:non_converted_default_duplicate_status) do
              create(:work_item_custom_status, :without_conversion_mapping, category: :canceled,
                namespace: reusable_group)
            end

            before do
              work_item.duplicated_to = build_stubbed(:work_item)
            end

            it 'returns the default duplicated status' do
              expect(status_with_fallback.class).to eq(WorkItems::Statuses::Custom::Status)
              expect(status_with_fallback.id).to eq(lifecycle.default_duplicate_status_id)
            end

            context 'when using non-converted default status' do
              it 'returns the default duplicate status' do
                lifecycle.update!(default_duplicate_status: non_converted_default_duplicate_status)

                expect(status_with_fallback.class).to eq(WorkItems::Statuses::Custom::Status)
                expect(status_with_fallback.id).to eq(non_converted_default_duplicate_status.id)
              end
            end
          end
        end

        context 'when expired status mapping exists' do
          let!(:old_custom_status) { lifecycle.default_open_status }
          let!(:new_custom_status) { create(:work_item_custom_status, namespace: group, lifecycles: [lifecycle]) }
          let!(:status_mapping) do
            create(:work_item_custom_status_mapping,
              namespace: group,
              work_item_type: work_item.work_item_type,
              old_status: old_custom_status,
              new_status: new_custom_status,
              valid_until: 3.days.ago
            )
          end

          it 'returns the default status' do
            expect(status_with_fallback).to eq(old_custom_status)
          end
        end

        context 'when valid status mapping exists' do
          let!(:old_custom_status) { lifecycle.default_open_status }
          let!(:new_custom_status) { create(:work_item_custom_status, namespace: group, lifecycles: [lifecycle]) }
          let!(:status_mapping) do
            create(:work_item_custom_status_mapping,
              namespace: group,
              work_item_type: work_item.work_item_type,
              old_status: old_custom_status,
              new_status: new_custom_status,
              valid_from: 3.days.ago
            )
          end

          it 'returns the mapped status' do
            expect(status_with_fallback).to eq(new_custom_status)
          end
        end
      end
    end
  end

  describe '#current_status_with_fallback' do
    let_it_be(:lifecycle) { build(:work_item_system_defined_lifecycle) }
    let_it_be_with_reload(:work_item) { create(:work_item, :task) }

    before do
      stub_licensed_features(work_item_status: true)
    end

    subject(:current_status_with_fallback) { work_item.current_status_with_fallback }

    context 'when current_status exists' do
      let_it_be(:current_status) do
        create(:work_item_current_status, work_item: work_item, system_defined_status: lifecycle.default_open_status)
      end

      it 'returns the current status' do
        expect(current_status_with_fallback).to eq(current_status)
      end
    end

    context 'when current_status does not exist' do
      context 'when state is open' do
        let(:expected_current_status) do
          work_item.build_current_status(system_defined_status: lifecycle.default_open_status)
        end

        before do
          work_item.state = :opened
        end

        it 'returns the initialized current status with default open status as status' do
          expect(current_status_with_fallback.persisted?).to be_falsey
          expect(current_status_with_fallback.class).to eq(WorkItems::Statuses::CurrentStatus)
          expect(current_status_with_fallback.system_defined_status).to eq(lifecycle.default_open_status)
        end
      end

      context 'when state is closed' do
        before do
          work_item.state = :closed
        end

        it 'returns the initialized current status with default closed status as status' do
          expect(current_status_with_fallback.persisted?).to be_falsey
          expect(current_status_with_fallback.class).to eq(WorkItems::Statuses::CurrentStatus)
          expect(current_status_with_fallback.system_defined_status).to eq(lifecycle.default_closed_status)
        end

        context 'when work item is a duplicate' do
          before do
            work_item.duplicated_to = build_stubbed(:work_item)
          end

          it 'returns the initialized current status with default duplicate status as status' do
            expect(current_status_with_fallback.persisted?).to be_falsey
            expect(current_status_with_fallback.class).to eq(WorkItems::Statuses::CurrentStatus)
            expect(current_status_with_fallback.system_defined_status).to eq(lifecycle.default_duplicate_status)
          end
        end

        context 'when work item type does not have a lifecycle' do
          before do
            work_item.work_item_type = build(:work_item_system_defined_type, :incident)
          end

          it 'returns nil' do
            expect(current_status_with_fallback).to be_nil
          end
        end
      end
    end
  end

  describe '#supports_assignee?' do
    EE::WorkItems::TypesFramework::SystemDefined::Type::BASE_TYPES.pluck(:base_type).each do |base_type|
      specify do
        work_item = build(:work_item, base_type.to_sym)
        widgets = WorkItems::TypesFramework::SystemDefined::Definitions
          .const_get(base_type.camelize, false).widgets
        supports_assignee = widgets.include?('assignees')

        expect(work_item.supports_assignee?).to eq(supports_assignee)
      end
    end
  end

  describe '#supports_time_tracking?' do
    EE::WorkItems::TypesFramework::SystemDefined::Type::BASE_TYPES.pluck(:base_type).each do |base_type|
      specify do
        work_item = build(:work_item, base_type.to_sym)
        widgets = WorkItems::TypesFramework::SystemDefined::Definitions
          .const_get(base_type.camelize, false).widgets
        supports_time_tracking = widgets.include?('time_tracking')

        expect(work_item.supports_time_tracking?).to eq(supports_time_tracking)
      end
    end
  end
end
