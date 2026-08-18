# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class WorkflowMergeRequest < ::ApplicationRecord
      include WorkflowLinkable

      self.table_name = :duo_workflows_workflow_merge_requests

      links_workflow_to :merge_request, class_name: 'MergeRequest', inverse_of: false

      enum :link_type, {
        # the merge request the flow was initiated against
        source: 0,
        # the merge request was created by the flow
        created: 1
      }, prefix: true
    end
  end
end
