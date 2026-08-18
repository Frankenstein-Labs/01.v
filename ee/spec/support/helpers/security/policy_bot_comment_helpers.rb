# frozen_string_literal: true

module Security
  module PolicyBotCommentHelpers
    def create_policy_bot_comment(merge_request, violated_reports: '')
      create(:note, project: merge_request.project, noteable: merge_request,
        author: Users::Internal.in_organization(merge_request.project.organization).security_bot,
        note: [
          Security::ScanResultPolicies::PolicyViolationComment::MESSAGE_HEADER,
          "<!-- violated_reports: #{violated_reports} -->",
          "<!-- optional_approvals: #{violated_reports} -->",
          "Comment body"
        ].join("\n"))
    end
  end
end
