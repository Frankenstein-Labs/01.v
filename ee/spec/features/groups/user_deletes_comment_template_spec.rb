# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Comment templates > User deletes comment template', :js,
  feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, owners: user) }
  let_it_be(:saved_reply) { create(:group_saved_reply, group: group) }

  before do
    stub_licensed_features(group_saved_replies: true)

    sign_in(user)

    visit group_comment_templates_path(group)

    wait_for_requests
  end

  it 'deletes a comment template' do
    click_button 'Comment template actions'
    find_by_testid('comment-template-delete-btn').click

    page.within('.gl-modal') do
      click_button 'Delete'
    end

    wait_for_requests

    expect(page).not_to have_content(saved_reply.name)
  end
end
