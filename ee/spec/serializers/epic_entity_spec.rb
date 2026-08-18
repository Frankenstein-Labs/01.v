# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EpicEntity, feature_category: :portfolio_management do
  subject(:entity) { described_class.new(resource, request: request).as_json }

  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:label1, freeze: false) { create(:group_label, group: group, title: 'Bug') }
  let_it_be(:label2, freeze: false) { create(:group_label, group: group, title: 'Feature') }
  let_it_be_with_reload(:resource) { create(:epic, group: group) }
  let_it_be(:color, freeze: false) { create(:color, work_item: resource.work_item, color: '#0052cc') }
  let_it_be_with_reload(:work_item) { resource.work_item }

  let(:request) { double('request', current_user: user) }

  before_all do
    resource.update!(labels: [label1, label2])

    work_item.update!(
      confidential: true,
      state: :opened,
      created_at: Time.zone.parse('2022-03-01 10:00:00'),
      updated_at: Time.zone.parse('2022-03-15 14:30:00')
    )
  end

  it 'reads data from the work item', :aggregate_failures do
    expect(entity[:created_at]).to eq(work_item.created_at)
    expect(entity[:updated_at]).to eq(work_item.updated_at)

    expect(entity[:state]).to eq('opened')

    expect(entity[:lock_version]).to eq(work_item.lock_version)
    expect(entity[:confidential]).to be(true)

    expect(entity[:color]).to eq('#0052cc')
    expect(entity[:text_color]).to eq('#FFFFFF')

    label_titles = entity[:labels].pluck(:title)
    expect(label_titles).to contain_exactly('Bug', 'Feature')
  end

  it_behaves_like 'issuable entity current_user properties'

  describe 'date attributes read from work item' do
    context 'with fixed dates' do
      let_it_be(:dates_source, freeze: false) do
        create(:work_items_dates_source,
          :fixed,
          work_item: work_item,
          start_date: Date.new(2010, 1, 1),
          due_date: Date.new(2010, 1, 3)
        )
      end

      it 'reads dates from work item', :aggregate_failures do
        expect(entity[:start_date]).to eq(work_item.start_date)
        expect(entity[:start_date]).to eq(Date.new(2010, 1, 1))

        expect(entity[:start_date_is_fixed]).to be(true)
        expect(entity[:start_date_fixed]).to eq(Date.new(2010, 1, 1))

        expect(entity[:end_date]).to eq(work_item.due_date)
        expect(entity[:due_date]).to eq(work_item.due_date)
        expect(entity[:due_date]).to eq(Date.new(2010, 1, 3))

        expect(entity[:due_date_is_fixed]).to be(true)
        expect(entity[:due_date_fixed]).to eq(Date.new(2010, 1, 3))
      end
    end

    context 'with inherited dates' do
      let_it_be(:dates_source, freeze: false) do
        create(:work_items_dates_source,
          work_item: work_item,
          start_date: Date.new(2010, 1, 2),
          due_date: Date.new(2010, 1, 4)
        )
      end

      it 'reads the dates from the work item', :aggregate_failures do
        expect(entity[:start_date_is_fixed]).to be(false)
        expect(entity[:start_date_from_milestones]).to eq(Date.new(2010, 1, 2))

        expect(entity[:due_date_is_fixed]).to be(false)
        expect(entity[:due_date_from_milestones]).to eq(Date.new(2010, 1, 4))
      end
    end
  end

  describe 'group attributes' do
    it 'exposes group_name' do
      expect(subject[:group_name]).to eq(group.name)
    end

    it 'exposes group_full_name' do
      expect(subject[:group_full_name]).to eq(group.full_name)
    end

    it 'exposes group_full_path' do
      expect(subject[:group_full_path]).to eq(group.full_path)
    end
  end

  describe 'confidential epic docs path' do
    context 'when epic is confidential' do
      it 'includes confidential_epics_docs_path' do
        expect(subject[:confidential_epics_docs_path]).to be_present
        expect(subject[:confidential_epics_docs_path]).to include('make-an-epic-confidential')
      end
    end

    context 'when epic is not confidential' do
      let_it_be(:public_epic, freeze: false) { create(:epic, group: group, confidential: false) }

      subject { described_class.new(public_epic, request: request).as_json }

      it 'does not include confidential_epics_docs_path' do
        expect(subject).not_to have_key(:confidential_epics_docs_path)
      end
    end
  end
end
