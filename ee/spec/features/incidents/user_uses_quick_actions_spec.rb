# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Incidents > User uses EE quick actions', :js, feature_category: :incident_management do
  include Features::NotesHelpers

  describe 'incident-only commands' do
    let_it_be(:user, freeze: false) { create(:user) }
    let_it_be(:project, freeze: false) { create(:project) }
    let_it_be_with_reload(:incident) { create(:incident, project: project) }

    let_it_be(:escalation_policy, freeze: false) do
      create(:incident_management_escalation_policy, project: project, name: 'spec policy')
    end

    let_it_be_with_reload(:escalation_status) do
      create(:incident_management_issuable_escalation_status, issue: incident)
    end

    before do
      project.add_developer(user)
      sign_in(user)
      visit project_issue_path(project, incident)
    end

    it_behaves_like 'zoom quick actions ee'
    it_behaves_like 'link quick actions'
    it_behaves_like 'status page quick actions'
    it_behaves_like 'page quick action'
  end
end
