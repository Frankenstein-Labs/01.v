# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Open in Workspace button', :js, feature_category: :workspaces do
  let_it_be(:project) { create(:project, :public) }
  let(:user) { project.creator }
  let(:merge_request) { create(:merge_request, source_project: project) }

  before do
    stub_licensed_features(remote_development: true)
    sign_in(user)
  end

  context 'when the user is on the Merge Request page' do
    before do
      visit(merge_request_path(merge_request))
    end

    it 'they should be able to click on Open in Workspace' do
      # noinspection RubyArgCount -- Rubymine is incorrectly thinking this is an invalid block argument
      within '.merge-request' do
        click_button 'Code'
      end

      new_tab = window_opened_by do
        click_link 'Open in Workspace'
      end

      switch_to_window new_tab

      expect(page).to have_selector('.page-title.gl-text-size-h-display', text: 'New workspace')
    end
  end
end
