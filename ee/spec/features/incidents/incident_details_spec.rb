# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Incident details', :js, feature_category: :incident_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:reporter) { create(:user, reporter_of: project) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be_with_reload(:incident) { create(:incident, :with_escalation_status, project: project) }

  let(:current_user) { reporter }
  let(:sidebar) { page.find('.right-sidebar') }
  let(:escalation_status_container) { find_by_testid('escalation_status_container') }

  before do
    stub_feature_flags(hide_incident_management_features: false)
    sign_in(current_user)
  end

  describe 'escalation policy widget' do
    let(:escalation_policy_container) { within(sidebar) { find_by_testid('escalation_policy_container') } }

    shared_examples 'hides the escalation policy widget' do
      specify do
        visit_incident_with_expanded_sidebar

        expect(sidebar).not_to have_selector('[data-testid="escalation_policy_container"]')
      end
    end

    shared_examples 'hides the edit button' do
      specify do
        visit_incident_with_expanded_sidebar

        expect(escalation_policy_container).not_to have_selector('[data-testid="escalation-policy-edit"]')
      end
    end

    shared_examples 'shows the edit button' do
      specify do
        visit_incident_with_expanded_sidebar

        expect(escalation_policy_container).to have_selector('[data-testid="escalation-policy-edit"]')
      end
    end

    shared_examples 'shows empty state for escalation policy' do
      specify do
        visit_incident_with_expanded_sidebar
        assert_expanded_policy_values('None')

        collapse_sidebar
        assert_collapsed_policy_values('None', 'None')
      end
    end

    # Depends on escalation_policy being defined
    shared_examples 'shows attributes of assigned escalation policy' do
      specify do
        visit_incident_with_expanded_sidebar
        assert_expanded_policy_values(escalation_policy.name, href: true)

        collapse_sidebar
        assert_collapsed_policy_values('Paged', escalation_policy.name)
      end
    end

    describe 'escalation policies licensed feature available' do
      before do
        stub_licensed_features(oncall_schedules: true, escalation_policies: true)
      end

      context 'with escalation policies in the project' do
        let_it_be(:escalation_policy) { create(:incident_management_escalation_policy, project: project) }

        let(:edit_policy_widget) do
          within(escalation_policy_container) { find_by_testid('escalation-policy-edit-widget') }
        end

        context 'without escalation policy linked to incident' do
          context 'with only view permissions' do
            it_behaves_like 'shows empty state for escalation policy'
            it_behaves_like 'hides the edit button'
          end

          context 'with edit permissions' do
            let(:current_user) { developer }

            it_behaves_like 'shows empty state for escalation policy'

            it 'can set the policy for the incident' do
              visit_incident_with_expanded_sidebar

              assert_edit_button_exists_and_click
              assert_policy_in_list.click
              assert_expanded_policy_values(escalation_policy.name, href: true)
            end

            it 'can search for policies' do
              visit_incident_with_expanded_sidebar
              assert_edit_button_exists_and_click

              # List all
              assert_policy_in_list

              # Filter w/ match
              search_bar.send_keys escalation_policy.name.first(3)
              wait_for_requests
              assert_policy_in_list

              # Filter w/ no match
              search_bar.send_keys 'Bar'
              wait_for_requests
              expect(edit_policy_widget).to have_content 'No results found'
            end
          end
        end

        context 'with escalation policy linked to incident' do
          before do
            incident.escalation_status.update!(policy: escalation_policy, escalations_started_at: Time.current)
          end

          context 'with only view permissions' do
            it_behaves_like 'shows attributes of assigned escalation policy'
            it_behaves_like 'hides the edit button'
          end

          context 'with edit permissions' do
            let(:current_user) { developer }

            it_behaves_like 'shows attributes of assigned escalation policy'
            it_behaves_like 'shows the edit button'

            it 'can remove the policy from the incident' do
              visit_incident_with_expanded_sidebar

              assert_edit_button_exists_and_click
              assert_null_policy_in_list.click
              assert_expanded_policy_values('None')
            end

            context 'with alert associated with the incident' do
              let_it_be(:alert) { create(:alert_management_alert, issue: incident) }

              it_behaves_like 'shows attributes of assigned escalation policy'
              it_behaves_like 'shows the edit button'
            end
          end
        end

        private

        def assert_edit_button_exists_and_click
          expect(edit_policy_widget).to have_button('Edit')
          edit_button.click
          wait_for_requests
        end

        def assert_policy_in_list
          policy_item = within(edit_policy_widget) { find_by_testid('escalation-policy-items') }
          expect(policy_item).to have_content escalation_policy.name

          policy_item
        end

        def assert_null_policy_in_list
          null_policy_item = within(edit_policy_widget) { find_by_testid('listbox-reset-button') }
          expect(null_policy_item).to have_content 'No escalation policy'

          null_policy_item
        end

        def edit_button
          within(edit_policy_widget) { find_by_testid('escalation-policy-edit') }
        end

        def search_bar
          edit_policy_widget.find('.gl-listbox-search-input')
        end
      end

      context 'with no escalation policies in the project' do
        it_behaves_like 'shows empty state for escalation policy'

        it 'lets users open, view, and close the escalation policy help menu' do
          visit_incident_with_expanded_sidebar

          within(escalation_policy_container) { find_by_testid('help-button') }.click

          expect(escalation_policy_container).to have_content('Page your team')
          expect(escalation_policy_container).to have_content('Use escalation policies to automatically page your team')

          within(escalation_policy_container) { find_by_testid('close-help-button') }.click

          expect(escalation_policy_container).not_to have_content('Page your team')
        end
      end
    end

    describe 'escalation policies licensed feature unavailable' do
      it_behaves_like 'hides the escalation policy widget'
    end
  end

  describe 'escalation status dropdown' do
    let_it_be(:current_user, freeze: false) { developer }
    let_it_be(:help_info_text) { s_('IncidentManagement|Stops paging') }

    before do
      stub_licensed_features(oncall_schedules: true, escalation_policies: true)

      visit_incident_with_expanded_sidebar

      click_edit_status
    end

    it 'includes help info as a subtext for status ACKNOWLEDGED and RESOLVED' do
      expect(find_by_testid('listbox-item-ACKNOWLEDGED')).to have_text(help_info_text)
      expect(find_by_testid('listbox-item-RESOLVED')).to have_text(help_info_text)
    end

    it 'doesn\'t include help info as a subtext for status TRIGGERED' do
      expect(find_by_testid('listbox-item-TRIGGERED')).not_to have_text(help_info_text)
    end
  end

  describe 'timeline toggle button' do
    let_it_be(:toggle_button_selector) { "[data-testid='timeline-toggle-button']" }

    it 'by default, does not show timeline toggle button' do
      visit(incident_project_issues_path(project, incident))

      expect(page).not_to have_css(toggle_button_selector)
    end

    it 'with incident_timeline_view feature, shows timeline toggle button' do
      stub_licensed_features(incident_timeline_view: true)

      visit(incident_project_issues_path(project, incident))

      expect(page).to have_css(toggle_button_selector)
    end
  end

  private

  def visit_incident_with_collapsed_sidebar
    visit incident_project_issues_path(project, incident)
    wait_for_requests
    collapse_sidebar
  end

  def visit_incident_with_expanded_sidebar
    visit incident_project_issues_path(project, incident)
    wait_for_requests
    expand_sidebar
  end

  def expand_sidebar
    within(sidebar) { find_by_testid('chevron-double-lg-left-icon') }.click
  end

  def collapse_sidebar
    within(sidebar) { find_by_testid('chevron-double-lg-right-icon') }.click
  end

  def click_edit_status
    within(escalation_status_container) { find_by_testid('edit-button') }.click
  end

  def assert_collapsed_policy_values(collapsed_name, policy_name)
    expect(escalation_policy_container).to have_selector('[data-testid="mobile-icon"]')
    expect(escalation_policy_container).to have_content(collapsed_name)

    escalation_policy_container.hover
    expect(page).to have_content("Escalation policy: #{policy_name}")
  end

  def assert_expanded_policy_values(policy_name, href: false)
    expect(escalation_policy_container).to have_content('Escalation policy')

    if href
      expect(escalation_policy_container).to have_link(
        policy_name,
        href: project_incident_management_escalation_policies_path(project)
      )
    else
      expect(escalation_policy_container).to have_content(policy_name)
    end
  end
end
