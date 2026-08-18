# frozen_string_literal: true

module MergeRequests
  class MergeAuditEventService
    attr_reader :merge_request

    def initialize(merge_request:)
      @merge_request = merge_request
    end

    def execute
      return unless merge_request.merged?

      audit_context = {
        name: 'merge_request_merged',
        author: merged_by,
        scope: merge_request.project,
        target: merge_request,
        message: 'Merge request merged',
        additional_details: audit_details
      }

      ::Gitlab::Audit::Auditor.audit(audit_context)
    end

    private

    def audit_details
      {
        title: merge_request.title,
        description: merge_request.description,
        required_approvals: required_approvals,
        approval_count: approval_count,
        approvers: approvers,
        approving_committers: approving_committers,
        approving_author: approving_author,
        merged_at: merged_at,
        commit_shas: commit_shas,
        target_branch: merge_request.target_branch,
        target_project_id: merge_request.target_project.id
      }
    end

    def approval_count
      merge_request.approvals.count
    end

    def approvers
      merge_request.approved_by_users.map(&:username).sort
    end

    def approving_committers
      approvers.select { |approver| approver.in? committers }
    end

    def committers
      @committers ||= merge_request
        .committers(with_merge_commits: true, lazy: true, include_author_when_signed: true)
        .map(&:username)
    end

    def author
      merge_request.author.username
    end

    def approving_author
      author.in? approvers
    end

    def merged_by
      merge_request.metrics.merged_by || Gitlab::Audit::DeletedAuthor.new(id: -3, name: 'Unknown User')
    end

    def merged_at
      merge_request.merged_at
    end

    def commit_shas
      merge_request.merge_request_diff&.commit_shas
    end

    def required_approvals
      merge_request.approvals_required
    end
  end
end
