# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects > Comment templates > User creates comment template', :js,
  feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, owners: user) }

  before do
    stub_licensed_features(project_saved_replies: true)

    sign_in(user)

    visit project_comment_templates_path(project)

    wait_for_requests
  end

  it 'creates a new comment template' do
    click_button 'Add new'
    find_by_testid('comment-template-name-input').set('test')
    find_by_testid('comment-template-content-input').set('Test content')

    click_button 'Save'

    wait_for_requests

    expect(page).to have_content('Comment templates')
    expect(page).to have_content('test')
    expect(page).to have_content('Test content')
  end
end
