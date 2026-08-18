# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Incident Management index', :js, feature_category: :incident_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:incident) { create(:incident, project: project) }

  before do
    stub_feature_flags(hide_incident_management_features: false)
    sign_in(developer)
  end

  context 'when a developer displays the incident list' do
    it 'has expected columns' do
      visit project_incidents_path(project)
      wait_for_requests
      table = page.find('.gl-table')

      expect(table).to have_content('Severity')
      expect(table).to have_content('Incident')
      expect(table).to have_content('Status')
      expect(table).to have_content('Date created')
      expect(table).to have_content('Assignees')

      expect(table).not_to have_content('Time to SLA')
      expect(table).not_to have_content('Published')
    end

    shared_examples 'enabled SLA feature' do
      it 'includes the SLA column' do
        visit project_incidents_path(project)
        wait_for_requests

        expect(page.find('.gl-table')).to have_content('Time to SLA')
      end
    end

    context 'with SLA feature available through license' do
      before do
        stub_licensed_features(incident_sla: true)
      end

      it_behaves_like 'enabled SLA feature'
    end

    context 'with SLA feature available through usage ping features' do
      before do
        stub_usage_ping_features(true)
      end

      it_behaves_like 'enabled SLA feature'
    end

    context 'with Status Page feature available' do
      before do
        stub_licensed_features(status_page: true)
      end

      it 'includes the Published column' do
        visit project_incidents_path(project)
        wait_for_requests

        expect(page.find('.gl-table')).to have_content('Published')
      end
    end
  end
end
