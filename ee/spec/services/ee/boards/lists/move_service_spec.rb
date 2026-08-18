# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Boards::Lists::MoveService, feature_category: :planning_views do
  describe '#execute' do
    let_it_be(:project) { create(:project) }
    let_it_be(:board) { create(:board, project: project) }
    let_it_be(:user) { create(:user) }

    context 'when board has multiple movable list types' do
      before do
        stub_licensed_features(board_assignee_lists: true)
      end

      let!(:user_list) { create(:user_list, board: board, position: 0) }
      let!(:label_list) { create(:list, board: board, list_type: :label, position: 1) }
      let!(:other_user_list) { create(:user_list, board: board, position: 2) }
      let!(:other_label_list) { create(:list, board: board, list_type: :label, position: 3) }

      it 'allows list movement' do
        service = described_class.new(project, user, position: other_label_list.position)

        service.execute(label_list)

        expect(ordered_lists).to eq([user_list, other_user_list, other_label_list, label_list])
      end
    end

    def ordered_lists
      board.lists.movable.reorder(:position)
    end
  end
end
