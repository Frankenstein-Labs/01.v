# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::AggregateChildIssuesService, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:grandparent_work_item) { create(:work_item, :epic, namespace: group) }
  let_it_be(:parent_work_item1) do
    create(:work_item, :epic, namespace: group, start_date: Date.new(2024, 1, 1), due_date: Date.new(2024, 12, 31))
  end

  let_it_be(:parent_work_item2) do
    create(:work_item, :epic, namespace: group, state: :closed, start_date: Date.new(2024, 2, 1),
      due_date: Date.new(2024, 6, 30))
  end

  let_it_be_with_reload(:child_issue1) { create(:work_item, :issue, project: project, weight: 2, state: :opened) }
  let_it_be_with_reload(:child_issue2) { create(:work_item, :issue, project: project, weight: 3, state: :opened) }
  let_it_be(:child_issue3) { create(:work_item, :issue, project: project, weight: 0, state: :closed) }

  let(:work_item_ids) { [parent_work_item1.id, parent_work_item2.id] }
  let(:limit) { 100 }
  let(:count_health_status) { false }

  subject(:service) do
    described_class.new(
      work_item_ids: work_item_ids,
      limit: limit,
      count_health_status: count_health_status
    )
  end

  before_all do
    create(:parent_link, work_item_parent: grandparent_work_item, work_item: parent_work_item1)
    create(:parent_link, work_item_parent: parent_work_item1, work_item: parent_work_item2)
    create(:parent_link, work_item_parent: parent_work_item1, work_item: child_issue1)
    create(:parent_link, work_item_parent: parent_work_item1, work_item: child_issue2)
    create(:parent_link, work_item_parent: parent_work_item2, work_item: child_issue3)
  end

  describe '#execute' do
    context 'when work_item_ids is empty' do
      let(:work_item_ids) { [] }

      it 'returns empty array' do
        expect(service.execute).to eq([])
      end
    end

    context 'when work_item_ids has values' do
      it 'returns complete aggregated issue metadata for multiple work items' do
        result = service.execute

        parent1_opened = result.find do |r|
          r["id"] == parent_work_item1.id && r["issues_state_id"] == Issue.available_states[:opened]
        end
        parent2_closed = result.find do |r|
          r["id"] == parent_work_item2.id && r["issues_state_id"] == Issue.available_states[:closed]
        end

        expect(parent1_opened).to eq({
          "work_item_state_id" => Issue.available_states[:opened],
          "id" => parent_work_item1.id,
          "iid" => parent_work_item1.iid,
          "issues_count" => 2,
          "issues_state_id" => Issue.available_states[:opened],
          "issues_weight_sum" => 5,
          "parent_id" => grandparent_work_item.id,
          "start_date" => Date.new(2024, 1, 1),
          "end_date" => Date.new(2024, 12, 31)
        })

        expect(parent2_closed).to eq({
          "work_item_state_id" => Issue.available_states[:closed],
          "id" => parent_work_item2.id,
          "iid" => parent_work_item2.iid,
          "issues_count" => 1,
          "issues_state_id" => Issue.available_states[:closed],
          "issues_weight_sum" => 0,
          "parent_id" => parent_work_item1.id,
          "start_date" => Date.new(2024, 2, 1),
          "end_date" => Date.new(2024, 6, 30)
        })
      end

      it 'groups results by parent work item and child issue state' do
        results = service.execute

        results_with_issues = results.reject { |r| r[:issues_state_id].nil? }
        opened_count = results_with_issues.count { |r| r[:issues_state_id] == Issue.available_states[:opened] }
        closed_count = results_with_issues.count { |r| r[:issues_state_id] == Issue.available_states[:closed] }

        expect(opened_count).to eq(1)
        expect(closed_count).to eq(1)
      end
    end

    context 'when count_health_status is true' do
      let_it_be_with_reload(:child_issue4) { create(:work_item, :issue, project: project, state: :opened) }
      let_it_be_with_reload(:child_issue5) { create(:work_item, :issue, project: project, state: :opened) }
      let_it_be_with_reload(:child_issue6) { create(:work_item, :issue, project: project, state: :opened) }

      let(:count_health_status) { true }

      before_all do
        create(:parent_link, work_item_parent: parent_work_item1, work_item: child_issue4)
        create(:parent_link, work_item_parent: parent_work_item1, work_item: child_issue5)
        create(:parent_link, work_item_parent: parent_work_item2, work_item: child_issue6)
      end

      before do
        child_issue1.update_column(:health_status, Issue.health_statuses[:on_track])
        child_issue2.update_column(:health_status, Issue.health_statuses[:needs_attention])
        child_issue4.update_column(:health_status, Issue.health_statuses[:at_risk])
        child_issue5.update_column(:health_status, Issue.health_statuses[:on_track])
        child_issue6.update_column(:health_status, Issue.health_statuses[:at_risk])
      end

      it 'returns complete structure with all health status counts' do
        result = service.execute

        parent1_opened = result.find do |r|
          r["id"] == parent_work_item1.id && r["issues_state_id"] == Issue.available_states[:opened]
        end
        parent2_closed = result.find do |r|
          r["id"] == parent_work_item2.id && r["issues_state_id"] == Issue.available_states[:closed]
        end
        parent2_opened = result.find do |r|
          r["id"] == parent_work_item2.id && r["issues_state_id"] == Issue.available_states[:opened]
        end

        expect(parent1_opened).to eq({
          "work_item_state_id" => Issue.available_states[:opened],
          "id" => parent_work_item1.id,
          "iid" => parent_work_item1.iid,
          "issues_count" => 4,
          "issues_state_id" => Issue.available_states[:opened],
          "issues_weight_sum" => 5,
          "parent_id" => grandparent_work_item.id,
          "issues_on_track" => 2,
          "issues_needs_attention" => 1,
          "issues_at_risk" => 1,
          "start_date" => Date.new(2024, 1, 1),
          "end_date" => Date.new(2024, 12, 31)
        })

        expect(parent2_closed).to eq({
          "work_item_state_id" => Issue.available_states[:closed],
          "id" => parent_work_item2.id,
          "iid" => parent_work_item2.iid,
          "issues_count" => 1,
          "issues_state_id" => Issue.available_states[:closed],
          "issues_weight_sum" => 0,
          "parent_id" => parent_work_item1.id,
          "issues_on_track" => 0,
          "issues_needs_attention" => 0,
          "issues_at_risk" => 0,
          "start_date" => Date.new(2024, 2, 1),
          "end_date" => Date.new(2024, 6, 30)
        })

        expect(parent2_opened).to eq({
          "work_item_state_id" => Issue.available_states[:closed],
          "id" => parent_work_item2.id,
          "iid" => parent_work_item2.iid,
          "issues_count" => 1,
          "issues_state_id" => Issue.available_states[:opened],
          "issues_weight_sum" => 0,
          "parent_id" => parent_work_item1.id,
          "issues_on_track" => 0,
          "issues_needs_attention" => 0,
          "issues_at_risk" => 1,
          "start_date" => Date.new(2024, 2, 1),
          "end_date" => Date.new(2024, 6, 30)
        })
      end
    end

    context 'with limit parameter' do
      let(:limit) { 1 }

      it 'respects the limit' do
        results = service.execute

        expect(results.length).to be <= limit
      end
    end
  end
end
