# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Boards::Lists::ListService, feature_category: :planning_views do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project) }
    let_it_be(:group_project) { create(:project, group: group) }
    let!(:backlog_list) { board.lists.backlog.first }
    let!(:closed_list) { board.lists.closed.first }
    let!(:label_list) { create(:list, board: board, label: label) }

    before do
      stub_licensed_features(board_assignee_lists: false, board_milestone_lists: false, board_iteration_lists: false)
    end

    def execute_service
      service.execute(Board.find(board.id))
    end

    shared_examples 'list service for board with assignee lists' do
      let!(:assignee_list) { create_board_list(:user_list, board) }

      context 'when the feature is enabled' do
        before do
          stub_licensed_features(board_assignee_lists: true)
        end

        it 'returns all lists' do
          expect(execute_service).to match_array [backlog_list, label_list, assignee_list, closed_list]
        end
      end

      context 'when the feature is disabled' do
        it 'filters out assignee lists that might have been created while subscribed' do
          expect(execute_service).to match_array [backlog_list, label_list, closed_list]
        end
      end
    end

    shared_examples 'list service for board with milestone lists' do
      let!(:milestone_list) { create_board_list(:milestone_list, board) }

      context 'when the feature is enabled' do
        before do
          stub_licensed_features(board_milestone_lists: true)
        end

        it 'returns all lists' do
          expect(execute_service)
            .to match_array([backlog_list, label_list, milestone_list, closed_list])
        end
      end

      context 'when the feature is disabled' do
        it 'filters out assignee lists that might have been created while subscribed' do
          expect(execute_service).to match_array [backlog_list, label_list, closed_list]
        end
      end
    end

    shared_examples 'list service for board with iteration lists' do
      let!(:iteration_list) { create_board_list(:iteration_list, board) }

      context 'when the feature is enabled' do
        before do
          stub_licensed_features(board_iteration_lists: true)
        end

        it 'returns all lists' do
          expect(execute_service)
            .to match_array([backlog_list, label_list, iteration_list, closed_list])
        end
      end

      context 'when feature is disabled' do
        it 'filters out iteration lists that might have been created while subscribed' do
          expect(execute_service).to match_array [backlog_list, label_list, closed_list]
        end
      end
    end

    shared_examples 'list service for board with status lists' do
      let!(:status_list) { create_board_list(:status_list, board) }

      before do
        stub_licensed_features(board_status_lists: true)
      end

      shared_examples 'filters out status lists' do
        it 'filters out status lists' do
          expect(execute_service).to match_array([backlog_list, label_list, closed_list])
        end
      end

      it 'returns all lists' do
        expect(execute_service).to match_array([backlog_list, label_list, status_list, closed_list])
      end

      context 'when feature is disabled' do
        before do
          stub_licensed_features(board_status_lists: false)
        end

        it_behaves_like 'filters out status lists'
      end
    end

    context 'when board parent is a project in user namespace' do
      let_it_be(:board) { create(:board, project: project) }
      let_it_be(:label) { create(:label, project: project) }
      let(:service) { described_class.new(project, user) }

      it_behaves_like 'list service for board with assignee lists'
      it_behaves_like 'list service for board with milestone lists'

      context 'with iteration lists' do
        let!(:iteration_list) { create_board_list(:iteration_list, board) }

        before do
          stub_licensed_features(board_iteration_lists: true)
        end

        it 'filters out iteration lists' do
          expect(execute_service).not_to include(iteration_list)
        end
      end

      context 'with status lists' do
        let!(:status_list) { create_board_list(:status_list, board) }

        before do
          stub_licensed_features(board_status_lists: true)
        end

        it 'filters out status lists' do
          expect(execute_service).not_to include(status_list)
        end
      end
    end

    context 'when board parent is a project in group namespace' do
      let_it_be(:board) { create(:board, project: group_project) }
      let_it_be(:label) { create(:label, project: group_project) }
      let(:service) { described_class.new(group_project, user) }

      it_behaves_like 'list service for board with assignee lists'
      it_behaves_like 'list service for board with milestone lists'
      it_behaves_like 'list service for board with iteration lists'
      it_behaves_like 'list service for board with status lists'
    end

    context 'when board parent is a group' do
      let_it_be(:board) { create(:board, group: group) }
      let_it_be(:label) { create(:group_label, group: group) }
      let(:service) { described_class.new(group, user) }

      it_behaves_like 'list service for board with assignee lists'
      it_behaves_like 'list service for board with milestone lists'
      it_behaves_like 'list service for board with iteration lists'
      it_behaves_like 'list service for board with status lists'
    end
  end

  def create_board_list(factory, board)
    build(factory, board: board).tap do |list|
      list.send(:ensure_group_or_project) # Necessary as this is called on a before_validation callback
      list.save!(validate: false)
    end
  end
end
