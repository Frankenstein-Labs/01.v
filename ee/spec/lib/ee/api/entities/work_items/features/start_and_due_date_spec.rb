# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::WorkItems::Features::StartAndDueDate, feature_category: :team_planning do
  let(:start_date) { Date.new(2025, 1, 2) }
  let(:due_date) { Date.new(2025, 1, 16) }
  let_it_be(:sourcing_work_item) { create(:work_item) }
  let_it_be(:sourcing_milestone) { build_stubbed(:milestone) }

  let(:widget) do
    instance_double(
      WorkItems::Widgets::StartAndDueDate,
      start_date: start_date,
      due_date: due_date,
      can_rollup?: true,
      fixed?: false,
      start_date_sourcing_work_item: sourcing_work_item,
      start_date_sourcing_milestone: nil,
      due_date_sourcing_work_item: nil,
      due_date_sourcing_milestone: sourcing_milestone
    )
  end

  subject(:representation) { described_class.new(widget).as_json }

  it 'exposes the fields' do
    expect(representation).to include(start_date: start_date, due_date: due_date)
    expect(representation[:roll_up]).to be(true)
    expect(representation[:is_fixed]).to be(false)
    expect(representation[:start_date_sourcing_work_item]).to include(id: sourcing_work_item.id,
      iid: sourcing_work_item.iid)
    expect(representation[:start_date_sourcing_milestone]).to be_nil
    expect(representation[:due_date_sourcing_work_item]).to be_nil
    expect(representation[:due_date_sourcing_milestone]).to include(id: sourcing_milestone.id,
      title: sourcing_milestone.title)
  end

  context 'when sourcing fields are all nil' do
    let(:widget) do
      instance_double(
        WorkItems::Widgets::StartAndDueDate,
        start_date: nil,
        due_date: nil,
        can_rollup?: false,
        fixed?: true,
        start_date_sourcing_work_item: nil,
        start_date_sourcing_milestone: nil,
        due_date_sourcing_work_item: nil,
        due_date_sourcing_milestone: nil
      )
    end

    it 'exposes nil for all sourcing fields and correct boolean values' do
      expect(representation[:roll_up]).to be(false)
      expect(representation[:is_fixed]).to be(true)
      expect(representation[:start_date_sourcing_work_item]).to be_nil
      expect(representation[:start_date_sourcing_milestone]).to be_nil
      expect(representation[:due_date_sourcing_work_item]).to be_nil
      expect(representation[:due_date_sourcing_milestone]).to be_nil
    end
  end
end
