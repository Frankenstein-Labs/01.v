# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ConsistencyChecks::BackfillIssueLinkOccurrenceIdCheck,
  feature_category: :vulnerability_management do
  it_behaves_like 'backfill link occurrence id check',
    log_message: 'Backfilled vulnerability_occurrence_id in vulnerability_issue_links' do
    let_it_be(:issue) { create(:issue, project: project) }

    def create_link(vulnerability_occurrence_id:)
      create(:vulnerabilities_issue_link,
        vulnerability: vulnerability,
        issue: issue,
        vulnerability_occurrence_id: vulnerability_occurrence_id)
    end

    def create_link_for_other_project(other_vulnerability, other_project)
      other_issue = create(:issue, project: other_project)
      create(:vulnerabilities_issue_link,
        vulnerability: other_vulnerability,
        issue: other_issue,
        vulnerability_occurrence_id: nil)
    end
  end
end
