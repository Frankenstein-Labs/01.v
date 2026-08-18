# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::RolledupDatesFinder, :aggregate_failures, feature_category: :portfolio_management do
  # Use fixed dates so the spec doesn't depend on when Time.current is evaluated. With relative dates (e.g. 1.day.ago),
  # the two sides of the assertion can be evaluated against different "now" values that disagree by ~1 day.
  fixed_today = Date.new(2025, 1, 15)

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be_with_reload(:epic_work_item) { create(:work_item, :epic, namespace: group) }

  let_it_be(:other_child_epic) do
    create(
      :work_item,
      :epic,
      namespace: group,
      start_date: fixed_today - 1,
      due_date: fixed_today + 1
    ).tap do |work_item|
      create(:parent_link, work_item: work_item, work_item_parent: epic_work_item)
    end
  end

  let_it_be_with_reload(:child_epic) do
    create(
      :work_item,
      :epic,
      namespace: group,
      start_date: fixed_today,
      due_date: fixed_today + 2
    ).tap do |work_item|
      create(:parent_link, work_item: work_item, work_item_parent: epic_work_item)
    end
  end

  subject(:finder) { described_class.new(epic_work_item) }

  describe '#minimum_start_date' do
    it 'returns a WorkItems::DatesSource query' do
      start_date = finder.minimum_start_date

      expect(start_date).to be_a(ActiveRecord::Relation)
      expect(start_date.first.attributes).to eq(
        'issue_id' => nil,
        'start_date' => other_child_epic.start_date,
        'start_date_sourcing_work_item_id' => other_child_epic.id,
        'start_date_sourcing_milestone_id' => nil)
    end
  end

  describe '#maximum_due_date' do
    it 'returns a WorkItems::DatesSource query' do
      due_date = finder.maximum_due_date

      expect(due_date).to be_a(ActiveRecord::Relation)
      expect(due_date.first.attributes).to eq(
        'issue_id' => nil,
        'due_date' => child_epic.due_date,
        'due_date_sourcing_work_item_id' => child_epic.id,
        'due_date_sourcing_milestone_id' => nil)
    end
  end

  describe '#attributes_for' do
    it 'raises an error when an unknown field is given' do
      expect { finder.attributes_for(:foobar) }
        .to raise_error(ArgumentError, "unknown field 'foobar'")
    end

    context 'when the wider range comes from a child work_item' do
      it 'returns the right attributes' do
        expect(finder.attributes_for(:start_date)).to eq(
          'issue_id' => nil,
          'start_date' => other_child_epic.start_date,
          'start_date_sourcing_work_item_id' => other_child_epic.id,
          'start_date_sourcing_milestone_id' => nil)

        expect(finder.attributes_for(:due_date)).to eq(
          'issue_id' => nil,
          'due_date' => child_epic.due_date,
          'due_date_sourcing_work_item_id' => child_epic.id,
          'due_date_sourcing_milestone_id' => nil)
      end
    end

    context 'when the wider range comes from a child work_item dates source' do
      let_it_be(:milestone) do
        create(
          :milestone,
          group: group,
          start_date: fixed_today - 2,
          due_date: fixed_today + 2).tap do |milestone|
            create(:work_item, :issue, namespace: group, milestone: milestone).tap do |work_item|
              create(:parent_link, work_item: work_item, work_item_parent: epic_work_item)
            end
          end
      end

      let_it_be(:dates_source) do
        create(
          :work_items_dates_source,
          :fixed,
          work_item: child_epic,
          start_date: fixed_today - 3,
          due_date: fixed_today + 3)
      end

      it 'returns the right attributes' do
        expect(finder.attributes_for(:start_date)).to eq(
          'issue_id' => nil,
          'start_date' => child_epic.dates_source.start_date,
          'start_date_sourcing_work_item_id' => child_epic.id,
          'start_date_sourcing_milestone_id' => nil)

        expect(finder.attributes_for(:due_date)).to eq(
          'issue_id' => nil,
          'due_date' => child_epic.dates_source.due_date,
          'due_date_sourcing_work_item_id' => child_epic.id,
          'due_date_sourcing_milestone_id' => nil)
      end
    end

    context 'when the wider range comes from a child work_item issue milestone' do
      let_it_be(:milestone) do
        create(
          :milestone,
          group: group,
          start_date: fixed_today - 3,
          due_date: fixed_today + 3
        ).tap do |milestone|
          create(:work_item, :issue, namespace: group, milestone: milestone).tap do |work_item|
            create(:parent_link, work_item: work_item, work_item_parent: epic_work_item)
          end
        end
      end

      let_it_be(:dates_source) do
        create(
          :work_items_dates_source,
          :fixed,
          work_item: child_epic,
          start_date: fixed_today - 2,
          due_date: fixed_today + 2)
      end

      it 'returns the right attributes' do
        expect(finder.attributes_for(:start_date)).to eq(
          'issue_id' => nil,
          'start_date' => milestone.start_date,
          'start_date_sourcing_work_item_id' => nil,
          'start_date_sourcing_milestone_id' => milestone.id)

        expect(finder.attributes_for(:due_date)).to eq(
          'issue_id' => nil,
          'due_date' => milestone.due_date,
          'due_date_sourcing_work_item_id' => nil,
          'due_date_sourcing_milestone_id' => milestone.id)
      end
    end

    context 'when the wider range comes from different sources' do
      let_it_be(:milestone) do
        create(:milestone, group: group, due_date: child_epic.due_date + 1.day).tap do |milestone|
          create(:work_item, :issue, namespace: group, milestone: milestone).tap do |work_item|
            create(:parent_link, work_item: work_item, work_item_parent: epic_work_item)
          end
        end
      end

      it 'returns the right attributes' do
        expect(finder.attributes_for(:start_date)).to eq(
          'issue_id' => nil,
          'start_date' => other_child_epic.start_date,
          'start_date_sourcing_work_item_id' => other_child_epic.id,
          'start_date_sourcing_milestone_id' => nil)

        expect(finder.attributes_for(:due_date)).to eq(
          'issue_id' => nil,
          'due_date' => milestone.due_date,
          'due_date_sourcing_work_item_id' => nil,
          'due_date_sourcing_milestone_id' => milestone.id)
      end
    end

    context 'when the wider range comes from child issue' do
      context 'when dates are from issue attributes' do
        let_it_be(:child_issue) do
          create(
            :work_item,
            :issue,
            project: project,
            start_date: fixed_today - 3,
            due_date: fixed_today + 3
          ).tap do |work_item|
            create(:parent_link, work_item: work_item, work_item_parent: epic_work_item)
          end
        end

        it 'returns the right attributes' do
          expect(finder.attributes_for(:start_date)).to eq(
            'issue_id' => nil,
            'start_date' => child_issue.start_date,
            'start_date_sourcing_work_item_id' => child_issue.id,
            'start_date_sourcing_milestone_id' => nil)

          expect(finder.attributes_for(:due_date)).to eq(
            'issue_id' => nil,
            'due_date' => child_issue.due_date,
            'due_date_sourcing_work_item_id' => child_issue.id,
            'due_date_sourcing_milestone_id' => nil)
        end
      end

      context 'when dates are from issue dates source' do
        let_it_be(:child_issue) do
          create(
            :work_item,
            :issue,
            project: project,
            start_date: fixed_today - 3,
            due_date: fixed_today + 3
          ).tap do |work_item|
            create(:parent_link, work_item: work_item, work_item_parent: epic_work_item)
            create(:work_items_dates_source,
              :fixed, work_item: work_item, start_date: fixed_today - 4, due_date: fixed_today + 4
            )
          end
        end

        it 'returns the right attributes' do
          expect(finder.attributes_for(:start_date)).to eq(
            'issue_id' => nil,
            'start_date' => child_issue.dates_source.start_date,
            'start_date_sourcing_work_item_id' => child_issue.id,
            'start_date_sourcing_milestone_id' => nil)

          expect(finder.attributes_for(:due_date)).to eq(
            'issue_id' => nil,
            'due_date' => child_issue.dates_source.due_date,
            'due_date_sourcing_work_item_id' => child_issue.id,
            'due_date_sourcing_milestone_id' => nil)
        end
      end
    end
  end

  context 'when a child work item is neither an Epic nor an Issue' do
    let_it_be_with_reload(:child_task) do
      create(
        :work_item,
        :issue,
        project: project,
        start_date: child_epic.start_date - 1.day,
        due_date: child_epic.due_date + 1.day
      ).tap do |work_item|
        create(:parent_link, work_item: work_item, work_item_parent: child_epic)
        work_item.update_column(:work_item_type_id, 5) # set work item type to Task, intentionally avoid validation
        work_item.reload
        child_epic.reload
      end
    end

    subject(:finder) { described_class.new(child_epic) }

    it 'rolls up the dates from the child work item regardless of its type' do
      expect(finder.minimum_start_date.first.attributes).to eq(
        'issue_id' => nil,
        'start_date' => child_task.start_date,
        'start_date_sourcing_work_item_id' => child_task.id,
        'start_date_sourcing_milestone_id' => nil)

      expect(finder.maximum_due_date.first.attributes).to eq(
        'issue_id' => nil,
        'due_date' => child_task.due_date,
        'due_date_sourcing_work_item_id' => child_task.id,
        'due_date_sourcing_milestone_id' => nil)
    end

    context 'when the child work item dates come from a dates source' do
      let_it_be(:dates_source) do
        create(
          :work_items_dates_source,
          :fixed,
          work_item: child_task,
          start_date: child_task.start_date - 1.day,
          due_date: child_task.due_date + 1.day)
      end

      it 'rolls up the dates from the child work item dates source' do
        expect(finder.minimum_start_date.first.attributes).to eq(
          'issue_id' => nil,
          'start_date' => child_task.dates_source.start_date,
          'start_date_sourcing_work_item_id' => child_task.id,
          'start_date_sourcing_milestone_id' => nil)

        expect(finder.maximum_due_date.first.attributes).to eq(
          'issue_id' => nil,
          'due_date' => child_task.dates_source.due_date,
          'due_date_sourcing_work_item_id' => child_task.id,
          'due_date_sourcing_milestone_id' => nil)
      end
    end

    context 'when the child work item is assigned a milestone' do
      let_it_be(:milestone) do
        create(
          :milestone,
          group: group,
          start_date: child_task.start_date - 1.day,
          due_date: child_task.due_date + 1.day)
      end

      before do
        child_task.update_column(:milestone_id, milestone.id)
      end

      it 'rolls up the dates from the milestone' do
        expect(finder.minimum_start_date.first.attributes).to eq(
          'issue_id' => nil,
          'start_date' => milestone.start_date,
          'start_date_sourcing_work_item_id' => nil,
          'start_date_sourcing_milestone_id' => milestone.id)

        expect(finder.maximum_due_date.first.attributes).to eq(
          'issue_id' => nil,
          'due_date' => milestone.due_date,
          'due_date_sourcing_work_item_id' => nil,
          'due_date_sourcing_milestone_id' => milestone.id)
      end
    end
  end
end
