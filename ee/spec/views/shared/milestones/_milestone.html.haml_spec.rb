# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'shared/milestones/_milestone.html.haml' do
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let_it_be_with_reload(:releases) { create_list(:release, 4, project: project) }
  let_it_be(:single_release) { create_list(:release, 1, project: project) }
  let_it_be(:milestone) { nil }

  let(:more_text) { '1 more release' }

  before do
    stub_licensed_features(group_milestone_project_releases: true)

    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:milestone).and_return(milestone)
  end

  context 'when a milestone is associated with 1 release' do
    let(:milestone) { create(:milestone, project: project, releases: single_release) }

    before do
      assign(:project, project)
    end

    it 'renders release name' do
      render

      expect(rendered).to have_content(single_release.first.name)
    end
  end

  context 'when a milestone is associated to a lot of releases' do
    let(:milestone) { create(:milestone, project: project, releases: releases) }

    before do
      assign(:project, project)
    end

    it 'renders "4 releases"' do
      render

      expect(rendered).to have_content("4 releases")
    end
  end
end
