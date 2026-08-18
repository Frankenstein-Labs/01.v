# frozen_string_literal: true

module BoardHelpers
  def load_epic_swimlanes
    page.find("[data-testid='board-options-dropdown'] button").click
    page.find("[data-testid='epic-swimlanes-toggle-item']").click

    wait_for_requests
  end

  def load_unassigned_issues
    page.find("[data-testid='unassigned-lane-toggle']").click

    wait_for_requests
  end
end
