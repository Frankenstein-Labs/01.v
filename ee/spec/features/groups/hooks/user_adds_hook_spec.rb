# frozen_string_literal: true

require "spec_helper"

RSpec.describe "User adds hook", feature_category: :webhooks do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:url) { "http://example.org" }

  before do
    group.add_owner(user)

    sign_in(user)

    visit(group_hooks_path(group))
  end

  it "adds new hook", :js do
    click_button 'Add new webhook'
    fill_in 'Name (optional)', with: 'New group hook'
    fill_in 'Description (optional)', with: 'A new group hook for testing'
    fill_in 'URL', with: url

    initial_count = GroupHook.count

    click_button("Add webhook")

    expect(page).to have_current_path group_hooks_path(group), ignore_query: true
    expect(page).to have_content(url)
    expect(GroupHook.count).to eq(initial_count + 1)
  end
end
