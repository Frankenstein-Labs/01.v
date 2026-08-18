# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Issues sub nav EE', :js, feature_category: :planning_views do
  let(:user) { create(:user) }
  let(:project) { create(:project) }

  before do
    project.add_maintainer(user)
    sign_in(user)

    visit project_issues_path(project)
  end

  it 'has a `Issue boards` item' do
    within_testid 'super-sidebar' do
      expect(page).to have_link 'Issue boards'
    end
  end
end
