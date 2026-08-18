# frozen_string_literal: true

require "spec_helper"

RSpec.describe ::WorkItems::Widgets::RolledupDatesService::HierarchiesUpdateService,
  :aggregate_failures,
  feature_category: :team_planning do
    let_it_be(:group) { create(:group) }
    let_it_be(:start_date) { 1.day.ago.to_date }
    let_it_be(:due_date) { 1.day.from_now.to_date }

    let_it_be_with_reload(:milestone) do
      create(:milestone, group: group, start_date: start_date, due_date: due_date)
    end

    let_it_be(:work_item_1, freeze: false) do
      create(:work_item, :epic, namespace: group).tap do |parent|
        create(:work_item, :issue, namespace: group, milestone: milestone).tap do |work_item|
          create(:parent_link, work_item: work_item, work_item_parent: parent)
        end
      end
    end

    let_it_be(:work_item_2, freeze: false) do
      create(:work_item, :epic, namespace: group).tap do |parent|
        create(:work_item, :issue, namespace: group, milestone: milestone).tap do |work_item|
          create(:parent_link, work_item: work_item, work_item_parent: parent)
        end
      end
    end

    let_it_be(:work_item_fixed_dates) do
      create(:work_item, :epic, namespace: group).tap do |parent|
        create(:work_items_dates_source, work_item: parent, start_date_is_fixed: true, due_date_is_fixed: true)
        create(:work_item, :issue, namespace: group, milestone: milestone).tap do |work_item|
          create(:parent_link, work_item: work_item, work_item_parent: parent)
        end
      end
    end

    let_it_be_with_reload(:epic_1) { create(:epic, group: group, work_item: work_item_1) }
    let_it_be_with_reload(:epic_2) { create(:epic, group: group, work_item: work_item_2) }

    let(:work_items) { WorkItem.id_in([work_item_1.id, work_item_2.id, work_item_fixed_dates.id]) }

    subject(:service) { described_class.new(work_items) }

    shared_examples 'syncs work item dates sources to epics' do
      specify do
        service.execute

        epic_1.reload
        work_item_1.dates_source.reload
        expect(epic_1.start_date)
          .to eq(work_item_1.dates_source.start_date)
        expect(epic_1.start_date_fixed)
          .to eq(work_item_1.dates_source.start_date_fixed)
        expect(epic_1.start_date_is_fixed || false)
          .to eq(work_item_1.dates_source.start_date_is_fixed)
        expect(epic_1.start_date_sourcing_milestone_id)
          .to eq(work_item_1.dates_source.start_date_sourcing_milestone_id)
        expect(epic_1.start_date_sourcing_epic_id)
          .to eq(work_item_1.dates_source.start_date_sourcing_work_item&.sync_object&.id)
        expect(epic_1.due_date)
          .to eq(work_item_1.dates_source.due_date)
        expect(epic_1.due_date_fixed)
          .to eq(work_item_1.dates_source.due_date_fixed)
        expect(epic_1.due_date_is_fixed || false)
          .to eq(work_item_1.dates_source.due_date_is_fixed)
        expect(epic_1.due_date_sourcing_milestone_id)
          .to eq(work_item_1.dates_source.due_date_sourcing_milestone_id)
        expect(epic_1.due_date_sourcing_epic_id)
          .to eq(work_item_1.dates_source.due_date_sourcing_work_item&.sync_object&.id)

        epic_2.reload
        work_item_2.dates_source.reload
        expect(epic_2.start_date)
          .to eq(work_item_2.dates_source.start_date)
        expect(epic_2.start_date_fixed)
          .to eq(work_item_2.dates_source.start_date_fixed)
        expect(epic_2.start_date_is_fixed || false)
          .to eq(work_item_2.dates_source.start_date_is_fixed)
        expect(epic_2.start_date_sourcing_milestone_id)
          .to eq(work_item_2.dates_source.start_date_sourcing_milestone_id)
        expect(epic_2.start_date_sourcing_epic_id)
          .to eq(work_item_2.dates_source.start_date_sourcing_work_item&.sync_object&.id)
        expect(epic_2.due_date)
          .to eq(work_item_2.dates_source.due_date)
        expect(epic_2.due_date_fixed)
          .to eq(work_item_2.dates_source.due_date_fixed)
        expect(epic_2.due_date_is_fixed || false)
          .to eq(work_item_2.dates_source.due_date_is_fixed)
        expect(epic_2.due_date_sourcing_milestone_id)
          .to eq(work_item_2.dates_source.due_date_sourcing_milestone_id)
        expect(epic_2.due_date_sourcing_epic_id)
          .to eq(work_item_2.dates_source.due_date_sourcing_work_item&.sync_object&.id)
      end
    end

    it "enqueues the parent epic update" do
      parent = create(:work_item, :epic, namespace: group).tap do |parent|
        create(:parent_link, work_item: work_item_1, work_item_parent: parent)
      end

      expect(::WorkItems::RolledupDates::UpdateMultipleRolledupDatesWorker)
        .to receive(:perform_async)
        .with([parent.id])

      service.execute
    end

    it "does not update parents part of a cyclic hierarchies" do
      work_item_1_parent = create(:work_item, :epic, namespace: group).tap do |parent|
        create(:parent_link, work_item_parent: parent, work_item: work_item_1)
      end
      create(:work_item, :epic, namespace: group).tap do |child|
        create(:parent_link, work_item_parent: work_item_1, work_item: child)
        build(:parent_link, work_item_parent: child, work_item: work_item_1_parent).save!(validate: false)
      end

      expect(::WorkItems::RolledupDates::UpdateMultipleRolledupDatesWorker)
        .not_to receive(:perform_async)

      service.execute
    end

    it "updates the start_date and due_date from milestone" do
      expect { service.execute }
        .to change { work_item_1.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
        .and change { work_item_1.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
        .and change { work_item_1.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
        .and change { work_item_1.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
        .and change { work_item_2.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
        .and change { work_item_2.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
        .and change { work_item_2.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
        .and change { work_item_2.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
        .and not_change { work_item_fixed_dates.reload.dates_source.start_date }
        .and not_change { work_item_fixed_dates.dates_source&.due_date }
    end

    include_examples 'syncs work item dates sources to epics'

    context "and the minimal start date comes from a child work_item" do
      let_it_be(:earliest_start_date) { start_date - 1 }

      let_it_be(:child) do
        create(:work_item, :epic, namespace: group, start_date: earliest_start_date).tap do |work_item|
          create(:parent_link, work_item: work_item, work_item_parent: work_item_1)
        end
      end

      include_examples 'syncs work item dates sources to epics'

      it "updates the start_date and due_date" do
        expect { service.execute }
          .to change { work_item_1.reload.dates_source&.start_date }.from(nil).to(earliest_start_date)
          .and change { work_item_1.reload.dates_source&.start_date_sourcing_work_item_id }.from(nil).to(child.id)
          .and change { work_item_1.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
          .and change { work_item_1.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_2.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
          .and change { work_item_2.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_2.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
          .and change { work_item_2.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and not_change { work_item_fixed_dates.reload.dates_source.start_date }
          .and not_change { work_item_fixed_dates.dates_source&.due_date }
      end
    end

    context "and the maximum due date comes from a child work_item" do
      let_it_be(:latest_due_date) { due_date + 1 }

      let_it_be(:child) do
        create(:work_item, :epic, namespace: group, due_date: latest_due_date).tap do |work_item|
          create(:parent_link, work_item: work_item, work_item_parent: work_item_1)
        end
      end

      include_examples 'syncs work item dates sources to epics'

      it "updates the start_date and due_date" do
        expect { service.execute }
          .to change { work_item_1.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
          .and change { work_item_1.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_1.reload.dates_source&.due_date }.from(nil).to(latest_due_date)
          .and change { work_item_1.reload.dates_source&.due_date_sourcing_work_item_id }.from(nil).to(child.id)
          .and change { work_item_2.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
          .and change { work_item_2.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_2.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
          .and change { work_item_2.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and not_change { work_item_fixed_dates.reload.dates_source.start_date }
          .and not_change { work_item_fixed_dates.dates_source&.due_date }
      end
    end

    context "and the minimal start date comes from a child work_item's dates_source" do
      let_it_be(:earliest_start_date) { start_date - 1 }

      let_it_be(:child) do
        create(:work_item, :epic, namespace: group) do |work_item|
          create(:work_items_dates_source, :fixed, work_item: work_item, start_date: earliest_start_date)
          create(:parent_link, work_item: work_item, work_item_parent: work_item_1)
        end
      end

      include_examples 'syncs work item dates sources to epics'

      it "updates the start_date and due_date" do
        expect { service.execute }
          .to change { work_item_1.reload.dates_source&.start_date }.from(nil).to(earliest_start_date)
          .and change { work_item_1.reload.dates_source&.start_date_sourcing_work_item_id }.from(nil).to(child.id)
          .and change { work_item_1.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
          .and change { work_item_1.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_2.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
          .and change { work_item_2.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_2.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
          .and change { work_item_2.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and not_change { work_item_fixed_dates.reload.dates_source.start_date }
          .and not_change { work_item_fixed_dates.dates_source&.due_date }
      end
    end

    context "and the maximum due date comes from a child work_item's dates_source" do
      let_it_be(:latest_due_date) { due_date + 1 }

      let_it_be(:child) do
        create(:work_item, :epic, namespace: group).tap do |work_item|
          create(:work_items_dates_source, :fixed, work_item: work_item, due_date: latest_due_date)
          create(:parent_link, work_item: work_item, work_item_parent: work_item_1)
        end
      end

      include_examples 'syncs work item dates sources to epics'

      it "updates the start_date and due_date" do
        expect { service.execute }
          .to change { work_item_1.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
          .and change { work_item_1.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_1.reload.dates_source&.due_date }.from(nil).to(latest_due_date)
          .and change { work_item_1.reload.dates_source&.due_date_sourcing_work_item_id }.from(nil).to(child.id)
          .and change { work_item_2.reload.dates_source&.start_date }.from(nil).to(milestone.start_date)
          .and change { work_item_2.reload.dates_source&.start_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and change { work_item_2.reload.dates_source&.due_date }.from(nil).to(milestone.due_date)
          .and change { work_item_2.reload.dates_source&.due_date_sourcing_milestone_id }.from(nil).to(milestone.id)
          .and not_change { work_item_fixed_dates.reload.dates_source.start_date }
          .and not_change { work_item_fixed_dates.dates_source&.due_date }
      end
    end

    context 'when no dates_sources records exist' do
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:start_date) { Time.zone.today }
      let_it_be(:due_date) { Time.zone.tomorrow }

      let_it_be_with_reload(:work_item_without_dates_source) do
        create(:work_item, :issue, project: project, start_date: start_date, due_date: due_date).tap do |child|
          create(:parent_link, work_item: child, work_item_parent: work_item_1)
        end
      end

      let(:work_items) do
        WorkItem.id_in([work_item_1.id, work_item_2.id, work_item_fixed_dates.id, work_item_without_dates_source.id])
      end

      it 'ensures to create the records and sets correct default values' do
        expect(work_item_without_dates_source.dates_source).to be_nil

        # We have multiple child work items that do not have a dates_source
        expect { service.execute }.to change { WorkItems::DatesSource.count }.by(3)

        expect(work_item_without_dates_source.reload.dates_source).to have_attributes(
          start_date: start_date, due_date: due_date, start_date_fixed: start_date, due_date_fixed: due_date,
          start_date_is_fixed: true, due_date_is_fixed: true
        )
      end
    end
  end
