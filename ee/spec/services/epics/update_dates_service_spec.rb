# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Epics::UpdateDatesService, feature_category: :portfolio_management do
  let_it_be(:group) { create(:group, :internal) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be_with_reload(:epic) { create(:epic, group: group) }
  let_it_be(:issue) { create(:issue, project: project) }
  let(:work_item) { epic.work_item }

  before do
    stub_licensed_features(epics: true)
  end

  describe '#execute', :sidekiq_inline do
    subject(:execute) { described_class.new([epic]).execute }

    let_it_be_with_reload(:epic) { create(:epic, group: group) }

    let_it_be(:milestone1) do
      create(:milestone, group: group, start_date: Date.new(2000, 1, 1), due_date: Date.new(2001, 1, 10))
    end

    let_it_be(:milestone2) do
      create(:milestone, group: group, start_date: Date.new(2001, 1, 1), due_date: Date.new(2002, 1, 10))
    end

    let_it_be(:issue1) { create(:issue, epic: epic, project: project, milestone: milestone1) }
    let_it_be(:issue2) { create(:issue, epic: epic, project: project, milestone: milestone2) }

    let_it_be(:child_epic) do
      create(:epic, group: group, parent: epic, start_date: Date.new(1998, 1, 1), end_date: Date.new(1999, 1, 1))
    end

    let_it_be(:top_level_parent_epic) { create(:epic, group: group) }
    let_it_be(:parent_epic) { create(:epic, group: group, parent: top_level_parent_epic) }

    before do
      create(:work_items_dates_source, work_item: top_level_parent_epic.work_item)
      create(:work_items_dates_source, work_item: parent_epic.work_item)

      parent_link = create(:parent_link, work_item_parent: parent_epic.work_item, work_item: epic.work_item)
      epic.update_columns(parent_id: parent_epic.id, work_item_parent_link_id: parent_link.id)
    end

    it_behaves_like 'syncs all data from an epic to a work item'

    it 'calls the HierarchiesUpdateService for the work items' do
      expect_next_instance_of(::WorkItems::Widgets::RolledupDatesService::HierarchiesUpdateService,
        match_array(WorkItem.id_in(epic.issue_id))) do |service|
        expect(service).to receive(:execute).and_call_original
      end

      expect_next_instance_of(::WorkItems::Widgets::RolledupDatesService::HierarchiesUpdateService,
        match_array(WorkItem.id_in(epic.parent.issue_id))) do |service|
        expect(service).to receive(:execute).and_call_original
      end

      expect_next_instance_of(::WorkItems::Widgets::RolledupDatesService::HierarchiesUpdateService,
        match_array(WorkItem.id_in(parent_epic.parent.issue_id))) do |service|
        expect(service).to receive(:execute).and_call_original
      end

      described_class.new([epic]).execute
    end
  end
end
