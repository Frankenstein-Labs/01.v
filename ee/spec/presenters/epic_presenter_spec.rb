# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EpicPresenter, feature_category: :portfolio_management do
  include ::UsersHelper
  include Gitlab::Routing.url_helpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, path: "pukeko_parent_group") }
  let_it_be(:label1) { create(:group_label, group: group, title: 'Bug') }
  let_it_be(:label2) { create(:group_label, group: group, title: 'Feature') }
  let_it_be(:parent_epic) { create(:epic, group: group, start_date: Date.new(2000, 1, 10), due_date: Date.new(2000, 1, 20), iid: 10) }
  let_it_be_with_reload(:epic) { create(:epic, group: group, author: user, parent: parent_epic) }
  let_it_be_with_reload(:work_item) { epic.work_item }

  subject(:presenter) { described_class.new(epic, current_user: user) }

  describe 'reading data from work item' do
    let_it_be(:color) { create(:color, work_item: work_item, color: '#0052cc') }

    before_all do
      epic.update!(labels: [label1, label2])

      work_item.update!(
        title: 'Work Item Title',
        description: 'Work Item Description',
        confidential: true,
        state: :opened,
        created_at: Time.zone.parse('2022-03-01 10:00:00'),
        updated_at: Time.zone.parse('2022-03-15 14:30:00')
      )
    end

    it 'reads created_at from work item' do
      expect(presenter.created_at).to eq(work_item.created_at)
    end

    it 'reads updated_at from work item' do
      expect(presenter.updated_at).to eq(work_item.updated_at)
    end

    it 'reads state from work item' do
      expect(presenter.state).to eq('opened')
    end

    it 'reads lock_version from work item' do
      expect(presenter.lock_version).to eq(work_item.lock_version)
    end

    it 'reads labels from work item' do
      label_titles = presenter.labels.map(&:title)
      expect(label_titles).to contain_exactly('Bug', 'Feature')
    end

    it 'reads author from work item' do
      expect(presenter.author).to eq(work_item.author)
    end

    it 'reads confidential from work item' do
      expect(presenter.confidential).to be(true)
      expect(presenter.confidential?).to be(true)
    end

    it 'reads title from work item' do
      expect(presenter.title).to eq('Work Item Title')
    end

    it 'reads description from work item' do
      expect(presenter.description).to eq('Work Item Description')
    end

    it 'reads color from work item' do
      expect(presenter.color).to eq('#0052cc')
    end

    it 'reads text_color from work item' do
      expect(presenter.text_color).to eq('#FFFFFF')
    end
  end

  describe '#group_epic_path' do
    it 'returns correct path' do
      expect(presenter.group_epic_path).to eq group_epic_path(epic.group, epic)
    end
  end

  describe '#epic_reference' do
    it 'returns a reference' do
      expect(presenter.epic_reference).to eq "&#{epic.iid}"
    end

    it 'returns a full reference' do
      expect(presenter.epic_reference(full: true)).to eq "#{epic.parent.group.path}&#{epic.iid}"
    end
  end

  describe '#subscribed?' do
    it 'returns false when there is no current_user' do
      presenter = described_class.new(epic, current_user: nil)

      expect(presenter.subscribed?).to be(false)
    end

    it 'returns false when there is no current_user' do
      presenter = described_class.new(epic, current_user: epic.author)

      expect(presenter.subscribed?).to be(true)
    end
  end

  describe 'date attributes read from work item' do
    context 'with fixed dates' do
      let_it_be(:dates_source) do
        create(:work_items_dates_source,
          :fixed,
          work_item: work_item,
          start_date: Date.new(2010, 1, 1),
          due_date: Date.new(2010, 1, 3)
        )
      end

      it 'reads dates from work item', :aggregate_failures do
        expect(presenter.start_date).to eq(work_item.start_date)
        expect(presenter.start_date).to eq(Date.new(2010, 1, 1))

        expect(presenter.start_date_is_fixed?).to be(true)
        expect(presenter.start_date_fixed).to eq(Date.new(2010, 1, 1))

        expect(presenter.due_date).to eq(work_item.due_date)
        expect(presenter.due_date).to eq(Date.new(2010, 1, 3))

        expect(presenter.due_date_is_fixed?).to be(true)
        expect(presenter.due_date_fixed).to eq(Date.new(2010, 1, 3))
      end
    end

    context 'with inherited dates' do
      let_it_be(:dates_source) do
        create(:work_items_dates_source,
          work_item: work_item,
          start_date: Date.new(2010, 1, 2),
          due_date: Date.new(2010, 1, 4)
        )
      end

      it 'reads the dates from the work item', :aggregate_failures do
        expect(presenter.start_date_is_fixed?).to be(false)
        expect(presenter.start_date).to eq(Date.new(2010, 1, 2))

        expect(presenter.due_date_is_fixed?).to be(false)
        expect(presenter.due_date).to eq(Date.new(2010, 1, 4))
      end
    end
  end
end
