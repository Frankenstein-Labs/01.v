# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountDistinctMergedMergeRequestsUsingApprovalRulesMetric do
  let_it_be_with_reload(:merge_request) { create(:merge_request) }
  let_it_be(:approval_rule_1) { create(:approval_merge_request_rule, merge_request: merge_request) }
  let_it_be(:approval_rule_2) { create(:approval_merge_request_rule, merge_request: merge_request) }

  let_it_be(:other_merge_request) { create(:merge_request) }
  let_it_be(:approval_rule_3) { create(:approval_merge_request_rule, merge_request: other_merge_request) }
  let_it_be_with_reload(:other_merged_merge_request) { create(:merge_request) }

  let(:expected_value) { 1 }
  let(:expected_query) { 'SELECT COUNT(DISTINCT "merge_requests"."id") FROM "merge_requests" INNER JOIN "approval_merge_request_rules" ON "approval_merge_request_rules"."merge_request_id" = "merge_requests"."id" WHERE "merge_requests"."state_id" = 3' }

  before do
    merge_request.mark_as_merged! unless merge_request.merged?
    other_merged_merge_request.mark_as_merged! unless other_merged_merge_request.merged?
  end

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all' }
end
