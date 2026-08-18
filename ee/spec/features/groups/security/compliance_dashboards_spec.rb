# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Compliance Dashboard', :js, feature_category: :compliance_management do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:user) { current_user }
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group, path: 'c-subgroup') }

  let_it_be(:framework1) { create(:compliance_framework) }
  let_it_be(:framework2) { create(:compliance_framework) }

  let_it_be(:subgroup_project) { create(:project, namespace: subgroup, path: 'project', compliance_framework_settings: [create(:compliance_framework_project_setting, compliance_management_framework: framework1)]) }
  let_it_be(:project) { create(:project, :repository, :public, namespace: group, path: 'b-project', compliance_framework_settings: [create(:compliance_framework_project_setting, compliance_management_framework: framework2)]) }
  let_it_be(:project_2) { create(:project, :repository, :public, namespace: group, path: 'a-project') }

  before do
    stub_licensed_features(
      compliance_framework: true,
      custom_compliance_frameworks: true,
      group_level_compliance_dashboard: true,
      group_level_compliance_adherence_report: true,
      group_level_compliance_violations_report: true)
    group.add_owner(user)
    sign_in(user)
  end

  context 'tab selection' do
    before do
      visit group_security_compliance_dashboard_path(group)
      wait_for_all_requests
    end

    it 'has the `Overview` tab selected by default' do
      page.within('.gl-tabs') do
        expect(find('[aria-selected="true"]').text).to eq('Overview')
      end
    end

    context 'when `Status` tab is clicked' do
      it 'has the status tab selected' do
        page.within('.gl-tabs') do
          click_link _('Status')

          expect(find('[aria-selected="true"]').text).to eq('Status')
        end
      end
    end

    context 'when `Violations` tab is clicked' do
      it 'has the violations tab selected' do
        page.within('.gl-tabs') do
          click_link _('Violations')

          expect(find('[aria-selected="true"]').text).to eq('Violations')
        end
      end
    end

    context 'when `Projects` tab is clicked' do
      it 'has the projects tab selected' do
        page.within('.gl-tabs') do
          click_link _('Projects')

          expect(find('[aria-selected="true"]').text).to eq('Projects')
        end
      end

      it 'displays list of projects with their frameworks' do
        visit group_security_compliance_dashboard_path(group, vueroute: :projects)
        wait_for_requests

        expect(all('tbody > tr').count).to eq(3)

        expect(first_row).to have_content(project_2.name)
        expect(first_row).to have_content(project_2.full_path)
        expect(first_row).to have_content("No frameworks")
        expect(first_row).to have_selector('[aria-label="Select frameworks"]')

        expect(second_row).to have_content(project.name)
        expect(second_row).to have_content(project.full_path)
        expect(second_row).to have_content(framework2.name)
        expect(second_row).to have_selector('[aria-label="Select frameworks"]')

        expect(third_row).to have_content(subgroup_project.name)
        expect(third_row).to have_content(subgroup_project.full_path)
        expect(third_row).to have_content(framework1.name)
        expect(third_row).to have_selector('[aria-label="Select frameworks"]')
      end
    end

    context 'when `Frameworks` tab is clicked' do
      it 'has the `Frameworks` tab selected' do
        page.within('.gl-tabs') do
          click_link _('Frameworks')

          expect(find('[aria-selected="true"]').text).to eq('Frameworks')
        end
      end
    end
  end

  context 'overview tab' do
    let(:expected_path) { group_security_compliance_dashboard_path(group, vueroute: :dashboard) }

    before do
      visit group_security_compliance_dashboard_path(group)
    end

    it 'shows the overview tab by default' do
      expect(page).to have_current_path(expected_path)
    end
  end

  context 'violations tab' do
    it 'shows the violations report table', :aggregate_failures do
      visit group_security_compliance_dashboard_path(group, vueroute: :violations)

      page.within('table') do
        expect(page).to have_content 'Status'
        expect(page).to have_content 'Violated control and framework'
        expect(page).to have_content 'Audit Event'
        expect(page).to have_content 'Project'
        expect(page).to have_content 'Date detected'
        expect(page).to have_content 'Action'
      end
    end

    context 'when there are no compliance violations' do
      before do
        visit group_security_compliance_dashboard_path(group, vueroute: :violations)
      end

      it 'shows an empty state' do
        expect(page).to have_content('No violations found')
      end
    end

    context 'when there are project compliance violations' do
      let_it_be(:framework) { create(:compliance_framework, namespace: group) }
      let_it_be(:requirement) { create(:compliance_requirement, framework: framework, namespace: group) }
      let_it_be(:control1) { create(:compliance_requirements_control, :minimum_approvals_required_2, compliance_requirement: requirement) }
      let_it_be(:control2) { create(:compliance_requirements_control, :default_branch_protected, compliance_requirement: requirement) }

      let_it_be(:audit_event1) { create(:audit_events_project_audit_event, project_id: project.id) }
      let_it_be(:audit_event2) { create(:audit_events_project_audit_event, project_id: project_2.id) }

      let_it_be(:violation1) do
        create(:project_compliance_violation,
          namespace: project.namespace,
          project: project,
          compliance_control: control1,
          audit_event_id: audit_event1.id,
          audit_event_table_name: :project_audit_events,
          status: :detected,
          created_at: 1.day.ago
        )
      end

      let_it_be(:violation2) do
        create(:project_compliance_violation,
          namespace: project_2.namespace,
          project: project_2,
          compliance_control: control2,
          audit_event_id: audit_event2.id,
          audit_event_table_name: :project_audit_events,
          status: :in_review,
          created_at: 7.days.ago
        )
      end

      before do
        visit group_security_compliance_dashboard_path(group, vueroute: :violations)
        wait_for_requests
      end

      it 'shows the compliance violations with details', :aggregate_failures do
        expect(all('tbody > tr').count).to eq(2)

        expect(first_row).to have_content('Detected')
        expect(first_row).to have_content('At least two approvals')
        expect(first_row).to have_content(project.name)
        expect(first_row).to have_content(1.day.ago.to_date.to_s)

        expect(second_row).to have_content('In review')
        expect(second_row).to have_content('Default branch protected')
        expect(second_row).to have_content(project_2.name)
        expect(second_row).to have_content(7.days.ago.to_date.to_s)
      end

      it 'can sort the violations by clicking on a column header' do
        expect(first_row).to have_content(project.name)
        expect(second_row).to have_content(project_2.name)

        click_column_header 'Status'

        expect(first_row).to have_content(project.name)
        expect(second_row).to have_content(project_2.name)

        click_column_header 'Status'

        expect(first_row).to have_content(project_2.name)
        expect(second_row).to have_content(project.name)
      end
    end
  end

  context 'exports' do
    before do
      visit group_security_compliance_dashboard_path(group)
    end

    it 'shows all export dropdowns within the dropdown' do
      within_testid('exports-disclosure-dropdown') do
        click_button _('Export')

        expect(page).to have_content('Send email of the chosen report as CSV')
        expect(page).to have_content('Export merge request violations report')
        expect(page).to have_content('Export list of project frameworks')
        expect(page).to have_content('Export custody report of a specific commit')
      end
    end

    context 'when exporting custody report of a specific commit' do
      it 'shows the form and buttons' do
        within_testid('exports-disclosure-dropdown') do
          click_button _('Export')
          click_button _('Export custody report of a specific commit')

          expect(page).to have_content('Cancel')
          expect(page).to have_content('Export custody report')
        end
      end
    end
  end

  def first_row
    find('tbody tr', match: :first)
  end

  def second_row
    all('tbody tr')[1]
  end

  def third_row
    all('tbody tr')[2]
  end

  def drawer_user_avatar
    page.within('.gl-drawer') do
      first('.js-user-link')
    end
  end

  def set_date_range(start_date, end_date)
    within_testid('violations-date-range-picker') do
      all('input')[0].set(start_date)
      all('input')[0].native.send_keys(:return)
      all('input')[1].set(end_date)
      all('input')[1].native.send_keys(:return)
    end
  end

  def filter_by_project(project)
    within_testid('violations-project-dropdown') do
      find('.dropdown-projects').click

      find('input[aria-label="Search"]').set(project.name)
      wait_for_requests

      find('.gl-new-dropdown-item[role="option"]').click
      find('.dropdown-projects').click
    end

    page.find('body').click
  end

  def click_column_header(name)
    page.within('thead') do
      find('div', text: name).click
      wait_for_requests
    end
  end
end
