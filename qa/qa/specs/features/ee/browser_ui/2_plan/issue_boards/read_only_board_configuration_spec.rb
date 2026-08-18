# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', feature_category: :planning_views do
    describe 'Read-only board configuration' do
      let(:qa_user) { Runtime::User::Store.additional_test_user }

      let(:label_board_list) do
        EE::Resource::Board::BoardList::Project::LabelBoardList.fabricate_via_api!
      end

      before do
        Flow::Login.sign_in

        label_board_list.project.add_member(qa_user, Resource::Members::AccessLevel::GUEST)

        Flow::Login.sign_in(as: qa_user, skip_page_validation: true)

        label_board_list.project.visit!
        Page::Project::Menu.perform(&:go_to_issue_boards)
      end

      it 'shows board configuration to user without edit permission' do
        Page::Component::IssueBoard::Show.perform do |show|
          show.click_boards_config_button

          expect(show.board_scope_modal).to be_visible
          expect(show).not_to have_modal_board_name_field
        end
      end
    end
  end
end
