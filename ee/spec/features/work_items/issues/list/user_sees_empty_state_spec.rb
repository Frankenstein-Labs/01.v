# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Issues', :js, feature_category: :planning_views do
  let_it_be(:project) { create(:project, :private) }
  let_it_be(:auditor) { create(:user, auditor: true) }
  let_it_be(:user) { create(:user) }

  shared_examples 'empty state' do |expect_button|
    it "shows empty state #{expect_button ? 'with' : 'without'} \"Create issue\" button" do
      visit project_work_items_path(project)

      expect(page).to have_content('Track bugs, plan features, and organize your efforts with work items')
      expect(page.has_link?('New item', exact: true)).to be(expect_button)
    end
  end

  context 'when signed in user is an Auditor' do
    before do
      sign_in(auditor)
    end

    context 'when user is not a member of the project' do
      it_behaves_like 'empty state', false
    end

    context 'when user is a member of the project' do
      before_all do
        project.add_guest(auditor)
      end

      it_behaves_like 'empty state', true
    end
  end
end
