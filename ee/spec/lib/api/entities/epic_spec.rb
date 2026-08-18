# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::Epic, feature_category: :portfolio_management do
  subject(:entity) { described_class.new(epic, options).as_json }

  let_it_be(:group) { create(:group) }
  let_it_be(:author) { create(:user) }
  let_it_be(:parent_epic) { create(:epic, group: group) }
  let_it_be(:label1) { create(:group_label, group: group, title: 'Label 1') }
  let_it_be(:label2) { create(:group_label, group: group, title: 'Label 2') }

  let_it_be_with_reload(:epic) { create(:epic, group: group, parent: parent_epic) }
  let_it_be(:work_item, freeze: false) { epic.work_item }
  let_it_be(:color) { create(:color, work_item: work_item, color: '#0052cc') }

  let(:options) { {} }

  before_all do
    work_item.update!(labels: [label1, label2])

    work_item.update!(
      author: author,
      title: 'Work Item Title',
      description: 'Work Item Description',
      confidential: true,
      state: :closed,
      closed_at: Time.zone.parse('2022-01-23 10:00:00'),
      created_at: Time.zone.parse('2022-01-15 10:00:00'),
      updated_at: Time.zone.parse('2022-01-20 15:30:00'),
      start_date: Date.new(2022, 1, 1),
      due_date: Date.new(2022, 12, 31),
      imported_from: 'github'
    )
  end

  it 'reads data from the work item', :aggregate_failures do
    expect(entity[:id]).to eq(epic.id)
    expect(entity[:work_item_id]).to eq(work_item.id)
    expect(entity[:iid]).to eq(work_item.iid)
    expect(entity[:group_id]).to eq(group.id)

    expect(entity[:title]).to eq('Work Item Title')
    expect(entity[:description]).to eq('Work Item Description')

    expect(entity[:confidential]).to be(true)
    expect(entity[:state]).to eq('closed')

    expect(entity[:color]).to eq("#0052cc")
    expect(entity[:text_color]).to eq("#FFFFFF")

    expect(entity[:parent_id]).to eq(parent_epic.id)
    expect(entity[:parent_iid]).to eq(parent_epic.iid)

    expect(entity[:author][:id]).to eq(work_item.author.id)
    expect(entity[:author][:id]).to eq(author.id)

    expect(entity[:created_at]).to eq(work_item.created_at)
    expect(entity[:updated_at]).to eq(work_item.updated_at)
    expect(entity[:closed_at]).to eq(work_item.closed_at)

    expect(entity[:imported]).to be(true)
    expect(entity[:imported_from]).to eq('github')

    label_titles = entity[:labels]
    expect(label_titles).to contain_exactly('Label 1', 'Label 2')
  end

  context 'when epic has no parent' do
    let_it_be(:epic_without_parent) { create(:epic, group: group, parent: nil) }

    subject(:entity) { described_class.new(epic_without_parent, options).as_json }

    it 'returns nil for parent_id and parent_iid' do
      expect(entity[:parent_id]).to be_nil
      expect(entity[:parent_iid]).to be_nil
    end
  end

  describe 'date attributes read from work item' do
    it 'reads start_date from work item' do
      expect(entity[:start_date]).to eq(Date.new(2022, 1, 1))
    end

    it 'reads due_date (end_date) from work item' do
      expect(entity[:end_date]).to eq(Date.new(2022, 12, 31))
      expect(entity[:due_date]).to eq(Date.new(2022, 12, 31))
    end

    context 'with fixed dates' do
      let_it_be(:dates_source) do
        create(:work_items_dates_source,
          :fixed,
          work_item: work_item,
          start_date: Date.new(2010, 1, 1),
          due_date: Date.new(2010, 1, 3)
        )
      end

      subject(:entity) { described_class.new(epic, options).as_json }

      it 'reads dates from work item', :aggregate_failures do
        expect(entity[:start_date_is_fixed]).to be(true)
        expect(entity[:start_date_fixed]).to eq(Date.new(2010, 1, 1))
        expect(entity[:due_date_is_fixed]).to be(true)
        expect(entity[:due_date_fixed]).to eq(Date.new(2010, 1, 3))
      end
    end

    context 'with inherited dates' do
      let_it_be(:dates_source) do
        create(:work_items_dates_source,
          work_item: work_item,
          start_date: Date.new(2010, 1, 1),
          due_date: Date.new(2010, 1, 3)
        )
      end

      subject(:entity) { described_class.new(epic, options).as_json }

      it 'reads the dates from the work item' do
        expect(entity[:start_date_is_fixed]).to be(false)
        expect(entity[:start_date_from_inherited_source]).to eq(Date.new(2010, 1, 1).to_time.iso8601)

        expect(entity[:due_date_is_fixed]).to be(false)
        expect(entity[:due_date_from_inherited_source]).to eq(Date.new(2010, 1, 3).to_time.iso8601)
      end
    end
  end

  context 'with with_labels_details option' do
    let(:options) { { with_labels_details: true } }

    it 'returns detailed label information' do
      expect(entity[:labels]).to be_an(Array)
      expect(entity[:labels].first).to include(:id, :name, :color, :description)
    end
  end

  describe '_links' do
    it 'includes parent link when epic has parent' do
      expect(entity[:_links][:parent]).to be_present
      expect(entity[:_links][:parent]).to include("/api/v4/groups/#{group.id}/epics/#{parent_epic.iid}")
    end

    context 'when epic has no parent' do
      let_it_be(:epic_without_parent) { create(:epic, group: group, parent: nil) }

      subject(:entity) { described_class.new(epic_without_parent, options).as_json }

      it 'does not include parent link' do
        expect(entity[:_links][:parent]).to be_nil
      end
    end
  end
end
