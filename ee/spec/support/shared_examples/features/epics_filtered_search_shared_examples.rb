# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'filtered search bar' do |tokens, sort_options, current_sort_option, has_display_drawer: false|
  minimum_values_for_token = {
    # Count must be at least 2 as current user are available by default
    "Author" => 2,

    # Count must be at least 3 as `None` & `Any` are available by default
    "Label" => 3,

    # Count must be at least 1. The roadmap's milestone token has no `Upcoming` & `Started`
    # defaults, so this is only the milestones the group has.
    "Milestone" => 1,

    # Count must be at least 1
    "Epic" => 1,

    # Count must be at least 3 as `None` & `Any` are available by default
    "My reaction" => 3
  }

  # A token with several operators shows the operator list first, and only loads its value
  # suggestions once an operator is picked. A token with a single operator has it applied
  # already, so there is nothing to pick.
  def open_token(token_name)
    select_tokens token_name

    expect(page).to have_css('.gl-filtered-search-token-active')

    operator_selector = '.gl-filtered-search-token-active .gl-filtered-search-token-operator'
    click_on '=', match: :first if has_no_css?(operator_selector, wait: 0)
  end

  describe 'filtered search bar tokens list' do
    tokens.each do |token|
      it "renders values for token '#{token}' correctly" do
        open_token token

        expect(page.find('.gl-filtered-search-suggestion-list')).to have_selector('li.gl-filtered-search-suggestion', minimum: minimum_values_for_token[token])
      end
    end
  end

  describe 'filtered search bar sort dropdown' do
    sort_options.each do |sort_option|
      it "renders sort option '#{sort_option}' correctly" do
        click_button 'Display' if has_display_drawer
        click_button current_sort_option

        expect(page).to have_selector('[role="option"]', text: sort_option)
      end
    end
  end
end
