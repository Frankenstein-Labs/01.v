# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EpicBaseEntity, feature_category: :portfolio_management do
  let(:group) { build(:group) }
  let(:epic) { build(:epic, group: group) }

  subject(:entity) { described_class.new(epic).as_json }

  describe 'basic attributes read from work item' do
    context 'when due_date and start_date are present' do
      before do
        epic.work_item.update!(
          title: 'Base Title',
          start_date: Date.new(2022, 6, 1),
          due_date: Date.new(2022, 12, 31)
        )
      end

      it 'reads from work item' do
        expect(entity[:id]).to eq(epic.id)
        expect(entity[:iid]).to eq(epic.work_item.iid)
        expect(entity[:title]).to eq('Base Title')
        expect(entity[:group_id]).to eq(epic.work_item.namespace_id)
        expect(entity[:group_id]).to eq(group.id)

        expect(entity[:human_readable_end_date]).to eq('Dec 31, 2022')
        expect(entity[:human_readable_timestamp]).to include('Past due')

        expect(entity[:url]).to eq("/groups/#{group.full_path}/-/epics/#{epic.iid}")
      end
    end

    context 'when dates are not present' do
      before do
        epic.work_item.update!(start_date: nil, due_date: nil)
      end

      it 'returns nil for human_readable dates' do
        expect(entity[:human_readable_end_date]).to be_nil
        expect(entity[:human_readable_timestamp]).to be_nil
      end
    end
  end
end
