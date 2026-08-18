# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Blocked deployment job page', :js, feature_category: :continuous_integration do
  let(:project) { create(:project, :repository) }
  let(:user) { create(:user) }
  let(:ci_build) { create(:ci_build, :manual, environment: 'production', project: project) }
  let(:environment) { create(:environment, name: 'production', project: project) }
  let(:approval_rules) do
    [
      create(
        :protected_environment_approval_rule,
        :maintainer_access,
        required_approvals: 1
      )
    ]
  end

  let(:protected_environment) do
    create(
      :protected_environment,
      name: environment.name,
      project: project,
      approval_rules: approval_rules
    )
  end

  let(:deployment) do
    create(
      :deployment,
      :blocked,
      project: project,
      environment: environment,
      deployable: ci_build
    )
  end

  before do
    stub_licensed_features(protected_environments: true)

    deployment
    protected_environment

    project.add_developer(user)
    sign_in(user)

    visit(project_job_path(project, ci_build))
  end

  it 'displays a button linking to the environments page' do
    expected_path = project_environment_deployment_path(project, environment, deployment)

    expect(page).to have_text('Waiting for approvals')
    expect(page).to have_link('View deployment details page', href: expected_path)

    find_by_testid('job-empty-state-action').click

    expect(page).to have_current_path(expected_path)
  end
end
