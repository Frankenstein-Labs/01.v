# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::GroupBoards, feature_category: :planning_views do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:non_member) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be_with_reload(:board_parent) { create(:group, :public, owners: user) }

  let_it_be(:project) { create(:project, :public, namespace: board_parent) }

  let_it_be(:dev_label) do
    create(:group_label, title: 'Development', color: '#FFAABB', group: board_parent)
  end

  let_it_be(:test_label) do
    create(:group_label, title: 'Testing', color: '#FFAACC', group: board_parent)
  end

  let_it_be(:ux_label) do
    create(:group_label, title: 'UX', color: '#FF0000', group: board_parent)
  end

  let_it_be_with_reload(:dev_list) do
    create(:list, label: dev_label, position: 1)
  end

  let_it_be_with_reload(:test_list) do
    create(:list, label: test_label, position: 2)
  end

  let_it_be_with_reload(:milestone) { create(:milestone, group: board_parent) }
  let_it_be_with_reload(:board_label) { create(:group_label, group: board_parent) }

  let_it_be_with_reload(:board) do
    create(:board, group: board_parent,
      milestone: milestone,
      assignee: user,
      label_ids: [board_label.id],
      lists: [dev_list, test_list])
  end

  it_behaves_like 'group and project boards', "/groups/:id/boards", true
  it_behaves_like 'multiple and scoped issue boards', "/groups/:id/boards"

  describe 'POST /groups/:id/boards/:board_id/lists' do
    let(:url) { "/groups/#{board_parent.id}/boards/#{board.id}/lists" }

    it_behaves_like 'milestone board list'
    it_behaves_like 'assignee board list'
    it_behaves_like 'iteration board list' do
      let_it_be(:iteration) { create(:iteration, iterations_cadence: create(:iterations_cadence, group: board_parent)) }
    end
  end

  describe 'POST /groups/:id/boards' do
    let(:url) { "/groups/#{board_parent.id}/boards" }

    before do
      stub_licensed_features(multiple_group_issue_boards: true)
    end

    it_behaves_like 'authorizing granular token permissions', :create_issue_board do
      let(:boundary_object) { board_parent }
      let(:request) { post api(url, personal_access_token: pat), params: { name: 'New Board' } }
    end
  end

  describe 'DELETE /groups/:id/boards/:board_id' do
    let(:url) { "/groups/#{board_parent.id}/boards/#{board.id}" }

    before do
      stub_licensed_features(multiple_group_issue_boards: true)
    end

    it_behaves_like 'authorizing granular token permissions', :delete_issue_board do
      let(:boundary_object) { board_parent }
      let(:request) { delete api(url, personal_access_token: pat) }
    end
  end
end
