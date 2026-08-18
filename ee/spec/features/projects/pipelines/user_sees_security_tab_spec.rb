# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Pipeline > User sees security tab", :js, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project, :repository) }
  let(:user) { project.creator }
  let(:ci_pipeline) do
    create(:ee_ci_pipeline, :success, :with_sast_report, project: project)
  end

  let(:vulnerabilities_scanner) do
    create(
      :vulnerabilities_scanner,
      project: project
    )
  end

  let!(:security_scan) do
    create(
      :security_scan,
      :latest_successful,
      pipeline: ci_pipeline,
      build: ci_pipeline.builds.first,
      project: project
    )
  end

  # There does not seem to be a practical way to override the default per_page in Grape, so we need to
  # create > 20 findings here to check pagination is working.
  let!(:security_finding) do
    create_list(
      :security_finding,
      21, # rubocop:disable FactoryBot/ExcessiveCreateList -- see note above
      :with_finding_data,
      scanner: vulnerabilities_scanner,
      scan: security_scan,
      deduplicated: true
    )
  end

  before do
    stub_licensed_features(
      security_dashboard: true,
      sast: true
    )
  end

  it "shows the pipeline security findings" do
    project.add_developer(user)
    sign_in(user)

    visit security_project_pipeline_path(project, ci_pipeline)
    expect(page).to have_content "Results show vulnerability findings from the latest successful pipeline."

    # Results should be paginated
    expect(page).to have_content("Test finding", count: 20)

    click_on("Next")
    expect(page).to have_content("Test finding", count: 1)
  end
end
