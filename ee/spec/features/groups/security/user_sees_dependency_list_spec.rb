# frozen_string_literal: true

require "spec_helper"

RSpec.describe "User sees dependency list", :js, feature_category: :vulnerability_management do
  let_it_be(:owner) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:ci_pipeline) { create(:ee_ci_pipeline, :with_cyclonedx_pypi_only, project: project) }

  before do
    stub_licensed_features(
      security_dashboard: true,
      dependency_scanning: true
    )
  end

  before_all do
    Gitlab::ExclusiveLease.skipping_transaction_check do
      # `before_all` runs in a transaction which triggers LeaseWithinTransactionError.
      # Skip the check since it only happens in tests.
      Sidekiq::Worker.skipping_transaction_check do
        ::Sbom::Ingestion::IngestReportsService.execute(ci_pipeline)
      end
    end
    group.add_owner(owner)
    sign_in(owner)
  end

  it "shows the dependency list" do
    visit(group_dependencies_path(group))

    # The default sort order of the page is by 'Severity' which orders by
    # `sbom_occurrences.hightest_severity_level NULL LAST`.  All of the test
    # data is NULL for this field so the order is indeterminate.
    # So just check for some content and the right number of elements.
    within_testid("dependencies-table-content") do
      expect(page).to have_content "beautifulsoup4"
      expect(page).to have_content "soupsieve"
      expect(page).to have_selector("tbody tr", count: 12)
    end

    within(".gl-sorting") do
      click_on "Severity"
      find("li", text: "Component name").click
    end

    within_testid("dependencies-table-content") do
      expect(find("tbody tr:first-child")).to have_content "beautifulsoup4"
      expect(find("tbody tr:last-child")).to have_content "soupsieve"
    end
  end
end
