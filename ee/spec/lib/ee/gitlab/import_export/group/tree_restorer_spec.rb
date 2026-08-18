# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ImportExport::Group::TreeRestorer, feature_category: :importers do
  include ImportExport::CommonUtil

  let(:user) { create(:user) }
  let(:group) { create(:group, name: 'group', path: 'group') }
  let(:shared) { Gitlab::ImportExport::Shared.new(group) }
  let(:group_tree_restorer) { described_class.new(user: user, shared: shared, group: group) }

  before do
    stub_licensed_features(epics: true, board_assignee_lists: true, board_milestone_lists: true)

    setup_import_export_config('group_exports/light', 'ee')
    group.add_owner(user)
  end

  describe 'restore group tree' do
    before do
      group_tree_restorer.restore
    end

    context 'epics' do
      it 'has group epics' do
        expect(group.epics.count).to eq(3)
        expect(group.work_items.count).to eq(3)

        group.epics.each do |epic|
          expect(epic.work_item).not_to be_nil

          diff = Gitlab::EpicWorkItemSync::Diff.new(epic, epic.work_item, strict_equal: true)
          expect(diff.attributes).to be_empty
        end
      end

      it 'has award emoji' do
        expect(group.epics.find_by_iid(1).award_emoji.first.name).to eq(AwardEmoji::THUMBS_UP)
      end

      it 'preserves epic state' do
        expect(group.epics.find_by_iid(1).state).to eq('opened')
        expect(group.epics.find_by_iid(2).state).to eq('closed')
        expect(group.epics.find_by_iid(3).state).to eq('opened')
      end
    end

    context 'epic notes' do
      it 'has epic notes' do
        expect(group.epics.find_by_iid(1).notes.count).to eq(1)
      end

      it 'has award emoji on epic notes' do
        expect(group.epics.find_by_iid(1).notes.first.award_emoji.first.name).to eq('drum')
      end

      it 'has system note metadata' do
        note = group.epics.find_by_title('system notes').notes.first

        expect(note.system).to be(true)
        expect(note.system_note_metadata.action).to eq('relate_epic')
      end
    end

    context 'epic labels' do
      it 'has epic labels' do
        label = group.epics.first.labels.first

        expect(group.epics.first.labels.count).to eq(1)
        expect(label.title).to eq('title')
        expect(label.description).to eq('description')
        expect(label.color).to be_color('#cd2c5c')
      end
    end

    context 'epic resource state events' do
      it 'has resource state events' do
        event = group.epics.first.resource_state_events.first

        expect(event.state).to eq('closed')
      end
    end

    context 'board lists' do
      it 'has milestone & assignee lists' do
        lists = group.boards.find_by(name: 'first board').lists

        expect(lists.map(&:list_type)).to contain_exactly('assignee', 'milestone')
      end
    end

    context 'epic board' do
      it 'has epic board lists' do
        epic_lists = group.epic_boards.find_by(name: 'first epic board').epic_lists

        expect(epic_lists.map(&:list_type)).to contain_exactly('backlog', 'label', 'closed')
      end
    end

    context 'boards' do
      it 'has user generated milestones' do
        board = group.boards.find_by(name: 'second board')

        expect(board.milestone.title).to eq 'v4.0'
      end

      it 'does not have predefined milestones' do
        board = group.boards.find_by(name: 'first board')

        expect(board.milestone).to be_nil
      end
    end

    context 'iteration candences', :aggregate_failures do
      it 'has cadence information' do
        cadence = group.iterations_cadences.first

        expect(cadence.title).to eq('title')
        expect(cadence.description).to eq('description')
        expect(cadence.automatic).to be(false)
        expect(cadence.roll_over).to be(false)
      end

      it 'has iterations within cadences' do
        iteration = group.iterations_cadences.first.iterations.first

        expect(iteration.iid).to eq(1)
        expect(iteration.title).to be_nil
        expect(iteration.state).to eq('closed')
        expect(iteration.description).to eq('description')
        expect(iteration.sequence).to eq(1)
      end
    end
  end
end
