# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Boards::Epics::RepositionService, feature_category: :planning_views do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, maintainer_of: group) }

  let_it_be(:epic) { create(:epic, group: group) }
  let_it_be_with_reload(:epic1) { create(:epic, group: group) }
  let_it_be_with_reload(:epic2) { create(:epic, group: group) }
  let_it_be_with_reload(:epic3) { create(:epic, group: group) }

  let_it_be(:board) { create(:epic_board, group: group) }
  let_it_be(:list) { create(:epic_list, epic_board: board, list_type: :backlog) }

  describe '#execute' do
    before do
      stub_licensed_features(epics: true, subepics: true, epic_colors: true)
    end

    subject(:reposition_epic) do
      described_class.new(epic: epic, current_user: user, params: opts).execute
    end

    def position(epic)
      epic.epic_board_positions.first&.relative_position
    end

    context 'when moving between 2 epics on the board' do
      let(:opts) do
        { move_between_ids: [epic2.id, epic1.id], board_id: board.id, list_id: list.id, board_group: group }
      end

      it 'moves the epic correctly' do
        reposition_epic

        expect(position(epic)).to be > position(epic2)

        # we don't create the position for epic below if it does not exist before the positioning
        expect(position(epic)).to be < position(epic1) if position(epic1)
      end
    end

    context 'when moving the epic to the end' do
      let(:opts) do
        { move_between_ids: [epic2.id, nil], board_id: board.id, list_id: list.id,
          board_group: group }
      end

      it 'moves the epic correctly' do
        reposition_epic

        expect(position(epic)).to be > position(epic2)
      end
    end

    context 'when the epic is in a subgroup' do
      let(:subgroup) { create(:group, parent: group) }
      let(:epic) { create(:epic, group: subgroup) }

      let(:opts) do
        { move_between_ids: [epic2.id, epic1.id], board_id: board.id, list_id: list.id,
          board_group: group }
      end

      it 'moves the epic correctly when moving between 2 epics' do
        reposition_epic

        expect(position(epic)).to be > position(epic2)
        expect(position(epic)).to be < position(epic1) if position(epic1)
      end
    end

    context 'when the list is closed' do
      let_it_be(:list) { create(:epic_list, epic_board: board, list_type: :closed) }

      let(:opts) do
        { move_between_ids: [epic2.id, epic1.id], board_id: board.id, list_id: list.id,
          board_group: group }
      end

      before do
        epic1.update!(state: :closed)
        epic2.update!(state: :closed)
        epic3.update!(state: :closed)
      end

      it 'moves the epic correctly when moving between 2 epics' do
        reposition_epic

        expect(position(epic)).to be > position(epic2)
        expect(position(epic)).to be < position(epic1) if position(epic1)
      end
    end

    # Tests with existing board positions
    context 'when board position records exist for all epics' do
      let_it_be_with_reload(:epic_position) do
        create(:epic_board_position, epic: epic, epic_board: board, relative_position: 1)
      end

      let_it_be_with_reload(:epic1_position) do
        create(:epic_board_position, epic: epic1, epic_board: board, relative_position: 30)
      end

      let_it_be_with_reload(:epic2_position) do
        create(:epic_board_position, epic: epic2, epic_board: board, relative_position: 20)
      end

      let_it_be_with_reload(:epic3_position) do
        create(:epic_board_position, epic: epic3, epic_board: board, relative_position: 10)
      end

      context 'when moving between 2 epics on the board' do
        let(:opts) do
          { move_between_ids: [epic2.id, epic1.id], board_id: board.id, list_id: list.id,
            board_group: group }
        end

        it 'moves the epic correctly' do
          reposition_epic

          expect(position(epic)).to be > position(epic2)
          expect(position(epic)).to be < position(epic1) if position(epic1)
        end

        it 'keeps epic3 on top of the board' do
          reposition_epic

          expect(position(epic3)).to be < position(epic2)
          expect(position(epic3)).to be < position(epic1)
        end
      end

      context 'when moving the epic to the beginning' do
        before do
          epic_position.update_column(:relative_position, 25)
        end

        let(:opts) do
          { move_between_ids: [nil, epic3.id], board_id: board.id, list_id: list.id,
            board_group: group }
        end

        it 'moves the epic correctly' do
          reposition_epic
          expect(epic_position.reload.relative_position).to be < epic3_position.relative_position
        end
      end

      context 'when moving the epic to the end' do
        let(:opts) do
          { move_between_ids: [epic1.id, nil], board_id: board.id, list_id: list.id,
            board_group: group }
        end

        it 'moves the epic correctly' do
          reposition_epic

          expect(position(epic)).to be > position(epic1)
        end

        it 'keeps epic3 on top of the board' do
          reposition_epic

          expect(position(epic3)).to be < position(epic2)
          expect(position(epic3)).to be < position(epic1)
        end
      end
    end

    # Tests with partial board positions
    context 'when the position does not exist for the record being moved' do
      let_it_be_with_reload(:epic1_position) do
        create(:epic_board_position, epic: epic1, epic_board: board, relative_position: 30)
      end

      let_it_be_with_reload(:epic2_position) do
        create(:epic_board_position, epic: epic2, epic_board: board, relative_position: 20)
      end

      let(:opts) do
        { move_between_ids: [epic2.id, epic1.id], board_id: board.id, list_id: list.id,
          board_group: group }
      end

      it 'moves the epic correctly when moving between 2 epics' do
        reposition_epic

        expect(position(epic)).to be > position(epic2)
        expect(position(epic)).to be < position(epic1) if position(epic1)
      end
    end

    context 'when the position exists for some records but not for higher ids' do
      let_it_be_with_reload(:epic2_position) do
        create(:epic_board_position, epic: epic2, epic_board: board, relative_position: 30)
      end

      let_it_be_with_reload(:epic_position) do
        create(:epic_board_position, epic: epic, epic_board: board, relative_position: 10)
      end

      let(:opts) do
        { move_between_ids: [epic2.id, epic1.id], board_id: board.id, list_id: list.id,
          board_group: group }
      end

      it 'moves the epic correctly' do
        reposition_epic

        expect(position(epic)).to be > position(epic2)
      end

      it 'does not create new position records' do
        expect { reposition_epic }.not_to change { Boards::EpicBoardPosition.count }
      end
    end

    context 'when the position does not exist for the records around the one being moved' do
      let_it_be_with_reload(:epic_position) do
        create(:epic_board_position, epic: epic, epic_board: board, relative_position: 10)
      end

      let(:opts) do
        { move_between_ids: [epic2.id, epic1.id], board_id: board.id, list_id: list.id,
          board_group: group }
      end

      it 'moves the epic correctly when moving between 2 epics' do
        reposition_epic

        expect(position(epic)).to be > position(epic2)
        expect(position(epic)).to be < position(epic1) if position(epic1)
      end
    end

    context 'when the group is private' do
      let_it_be(:private_group) do
        group = create(:group, :private)
        group
      end

      let_it_be(:private_epic) { create(:epic, group: private_group) }
      let_it_be(:private_epic1) { create(:epic, group: private_group) }
      let_it_be(:private_epic2) { create(:epic, group: private_group) }
      let_it_be(:private_board) { create(:epic_board, group: private_group) }
      let_it_be(:private_list) { create(:epic_list, epic_board: private_board, list_type: :backlog) }

      def reposition_private_epic
        described_class.new(
          epic: private_epic,
          current_user: user,
          params: {
            move_between_ids: [private_epic2.id, private_epic1.id],
            board_id: private_board.id,
            list_id: private_list.id,
            board_group: private_group
          }
        ).execute
      end

      context 'when user does not have access to private group' do
        it 'does not move the epic' do
          original_position = position(private_epic)

          reposition_private_epic

          expect(position(private_epic)).to eq(original_position)
        end
      end

      context 'when user has maintainer access to private group' do
        before_all do
          private_group.add_maintainer(user)
        end

        it 'moves the epic correctly when moving between 2 epics' do
          reposition_private_epic

          expect(position(private_epic)).to be > position(private_epic2)
          expect(position(private_epic)).to be < position(private_epic1) if position(private_epic1)
        end
      end
    end
  end
end
