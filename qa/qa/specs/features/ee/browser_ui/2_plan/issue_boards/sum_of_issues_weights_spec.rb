# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', feature_category: :planning_views do
    describe 'Sum of issues weights on issue board' do
      let(:label_board_list) do
        EE::Resource::Board::BoardList::Project::LabelBoardList.fabricate_via_api!
      end

      let(:label) { 'Testing' }
      let(:weight_for_issue_1) { 5 }
      let(:weight_for_issue_2) { 3 }

      before do
        Flow::Login.sign_in

        create(:issue, project: label_board_list.project, labels: [label], weight: weight_for_issue_1)
        create(:issue, project: label_board_list.project, labels: [label], weight: weight_for_issue_2)

        label_board_list.project.visit!
        Page::Project::Menu.perform(&:go_to_issue_boards)
      end

      it 'shows the sum of issues weights in the board list\'s header' do
        Page::Component::IssueBoard::Show.perform do |show|
          expect(show.boards_list_header_with_index(1)).to have_content(weight_for_issue_1 + weight_for_issue_2)
        end
      end
    end
  end
end
