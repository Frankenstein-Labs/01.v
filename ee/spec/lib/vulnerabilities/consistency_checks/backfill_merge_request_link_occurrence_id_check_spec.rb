# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ConsistencyChecks::BackfillMergeRequestLinkOccurrenceIdCheck,
  feature_category: :vulnerability_management do
  it_behaves_like 'backfill link occurrence id check',
    log_message: 'Backfilled vulnerability_occurrence_id in vulnerability_merge_request_links' do
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }

    def create_link(vulnerability_occurrence_id:)
      create(:vulnerabilities_merge_request_link,
        vulnerability: vulnerability,
        merge_request: merge_request,
        vulnerability_occurrence_id: vulnerability_occurrence_id)
    end

    def create_link_for_other_project(other_vulnerability, other_project)
      other_mr = create(:merge_request, source_project: other_project)
      create(:vulnerabilities_merge_request_link,
        vulnerability: other_vulnerability,
        merge_request: other_mr,
        vulnerability_occurrence_id: nil)
    end
  end
end
