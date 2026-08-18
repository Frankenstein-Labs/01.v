# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User activates Jira', :js, feature_category: :team_planning do
  include_context 'project integration activation'
  include_context 'project integration Jira context'

  describe 'user sets and activates Jira integration' do
    before do
      server_info = { key: 'value' }.to_json
      client_info = { key: 'value' }.to_json
      stub_request(:get, test_url).with(basic_auth: %w[username password]).to_return(body: server_info)
      stub_request(:get, client_url).with(basic_auth: %w[username password]).to_return(body: client_info)
    end

    context 'when Jira connection test succeeds' do
      before do
        stub_licensed_features(jira_issues_integration: true)

        visit_project_integration('Jira')
        fill_form
        find('label', text: 'View Jira issues').click
        fill_in 'Jira project keys', with: 'AB,CD'
        click_test_then_save_integration(expect_test_to_fail: false)
      end

      it 'adds Jira links to "Issues" sidebar menu' do
        within_testid('super-sidebar') do
          click_button 'Plan'
          expect(page).to have_link('Jira issues', href: project_integrations_jira_issues_path(project))
          expect(page).to have_link('Open Jira', href: url)
          expect(page).not_to have_link(exact_text: 'Jira')
        end
      end
    end

    context 'when jira_issues_integration feature is not available' do
      before do
        stub_licensed_features(jira_issues_integration: false)

        visit_project_integration('Jira')
        fill_form
        find('label', text: 'View Jira issues').click
        click_save_integration
      end

      it 'does not show Jira links in "Issues" sidebar menu' do
        within_testid('super-sidebar') do
          click_button 'Plan'
          expect(page).not_to have_link('Jira issues')
          expect(page).not_to have_link('Open Jira')
          expect(page).to have_link(exact_text: 'Jira', href: url)
        end
      end
    end
  end
end
