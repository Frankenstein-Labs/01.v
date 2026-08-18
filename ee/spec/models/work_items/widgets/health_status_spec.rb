# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::HealthStatus, feature_category: :team_planning do
  let_it_be(:work_item) { create(:work_item, :objective, health_status: :on_track) }

  describe '.quick_action_params' do
    subject { described_class.quick_action_params }

    it { is_expected.to include(:health_status) }
  end

  describe '#health_status' do
    subject { described_class.new(work_item).health_status }

    it { is_expected.to eq(work_item.health_status) }
  end

  describe '#rolled_up_health_status' do
    let_it_be(:project) { work_item.project }
    let_it_be(:sub_objective) { create(:work_item, :objective, project: project, health_status: :on_track) }
    let_it_be(:sub_objective_2) { create(:work_item, :objective, project: project, health_status: :at_risk) }
    let_it_be(:sub_sub_objective) do
      create(:work_item, :objective, :closed, project: project, health_status: :needs_attention)
    end

    let_it_be(:key_result) { create(:work_item, :key_result, project: project, health_status: :on_track) }
    let_it_be(:key_result_2) { create(:work_item, :key_result, project: project, health_status: :needs_attention) }
    let_it_be(:key_result_3) { create(:work_item, :key_result, :closed, project: project, health_status: :at_risk) }

    subject { described_class.new(work_item).rolled_up_health_status }

    before_all do
      create(:parent_link, work_item_parent: work_item, work_item: sub_objective)
      create(:parent_link, work_item_parent: work_item, work_item: sub_objective_2)
      create(:parent_link, work_item_parent: sub_objective, work_item: sub_sub_objective)
      create(:parent_link, work_item_parent: sub_objective, work_item: key_result)
      create(:parent_link, work_item_parent: sub_sub_objective, work_item: key_result_2)
      create(:parent_link, work_item_parent: sub_objective_2, work_item: key_result_3)
    end

    it 'returns rolled up health status counts' do
      is_expected.to contain_exactly(
        {
          health_status: "on_track",
          count: 2
        },
        {
          health_status: "needs_attention",
          count: 1
        },
        {
          health_status: "at_risk",
          count: 1
        }
      )
    end
  end
end
