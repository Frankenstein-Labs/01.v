# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "projects/security/compliance_dashboards/show", type: :view, feature_category: :compliance_management do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:project) { build_stubbed(:project, group: group) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(user, :read_compliance_adherence_report, project).and_return(true)
    allow(Ability).to receive(:allowed?).with(user, :read_compliance_violations_report, project).and_return(true)

    assign(:project, project)
  end

  it 'renders with the correct data attributes', :aggregate_failures do
    render

    expect(rendered).to have_selector('#js-compliance-report')
    expect(rendered).to have_selector("[data-base-path='#{project_security_compliance_dashboard_path(project)}']")
    expect(rendered).to have_selector("[data-project-path='#{project.full_path}']")
    expect(rendered).to have_selector("[data-root-ancestor-path='#{group.root_ancestor.full_path}']")
    expect(rendered).to have_selector("[data-feature-adherence-report-enabled='true']")
    expect(rendered).to have_selector("[data-feature-violations-report-enabled='true']")
    expect(rendered).to have_selector("[data-feature-projects-report-enabled='true']")

    expect(rendered).not_to have_selector("[data-feature-frameworks-report-enabled='true']")
  end
end
