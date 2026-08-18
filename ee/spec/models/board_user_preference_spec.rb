# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BoardUserPreference do
  before do
    create(:board_user_preference)
  end

  describe 'relationships' do
    it { is_expected.to belong_to(:board) }
    it { is_expected.to belong_to(:user) }

    it do
      is_expected.to validate_uniqueness_of(:user_id).scoped_to(:board_id)
                       .with_message("should have only one board preference per user")
    end
  end

  describe 'callbacks' do
    describe 'ensure_group_or_project' do
      let_it_be(:user) { create(:user) }
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }

      context 'when board belongs to a group' do
        let_it_be(:board) { create(:board, group: group) }

        it 'sets group_id from the parent board' do
          board_user_preference = described_class.create!(board: board, user: user)

          expect(board_user_preference.group_id).to eq(board.group_id)
          expect(board_user_preference.project_id).to be_nil
        end
      end

      context 'when board belongs to a project' do
        let_it_be(:board) { create(:board, project: project) }

        it 'sets project_id from the parent board' do
          board_user_preference = described_class.create!(board: board, user: user)

          expect(board_user_preference.project_id).to eq(board.project_id)
          expect(board_user_preference.group_id).to be_nil
        end
      end
    end
  end
end
