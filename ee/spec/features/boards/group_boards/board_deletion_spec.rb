# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group Boards', :js, feature_category: :planning_views do
  let(:group) { create(:group) }
  let!(:board_ux) { create(:board, group: group, name: 'UX') }
  let!(:board_dev) { create(:board, group: group, name: 'Dev') }
  let(:user) { create(:group_member, user: create(:user), group: group).user }

  before do
    stub_licensed_features(multiple_group_issue_boards: true)
    sign_in(user)
    visit group_boards_path(group)
    wait_for_requests
  end

  it 'deletes a group issue board' do
    find_by_testid('boards-config-button').click

    wait_for_requests

    find_by_testid('delete-board-button').click

    find_by_testid('save-changes-button').click

    click_boards_dropdown

    expect(page).not_to have_content(board_dev.name)
    expect(page).to have_content(board_ux.name)
  end

  def click_boards_dropdown
    find_by_testid('boards-dropdown').click
  end
end
